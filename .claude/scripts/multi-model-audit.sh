#!/usr/bin/env bash
# multi-model-audit.sh — Multi-model code audit with consensus aggregation
#
# Runs the same code review prompt through 3-4 cheap models in parallel,
# aggregates findings by consensus (2+ models agree = confirmed issue).
# Opus only sees the summary, saving context tokens.
#
# Usage:
#   # Review a git diff:
#   bash .claude/scripts/multi-model-audit.sh --diff HEAD~1
#
#   # Review specific files:
#   bash .claude/scripts/multi-model-audit.sh --files "src/auth.ts src/db.ts"
#
#   # Review with custom focus:
#   bash .claude/scripts/multi-model-audit.sh --diff HEAD~3 --focus "security,performance"
#
#   # Use specific models:
#   bash .claude/scripts/multi-model-audit.sh --diff HEAD~1 --models "openai:gpt-5.1-codex-mini,ollama:glm-5.1:cloud"
#
# Options:
#   --diff REF           Git diff reference (e.g., HEAD~1, main, SHA)
#   --files "F1 F2..."   Space-separated file paths to review
#   --focus AREAS        Comma-separated focus areas (security,performance,bugs,style,a11y)
#   --models "M1,M2..."  Comma-separated model list (overrides defaults)
#   --outdir DIR         Output directory (default: /tmp/audit-TIMESTAMP)
#   --verbose            Show individual model responses
#
# Default models (all cheap):
#   1. OpenAI GPT-5-mini          ($0.25/M in, $2/M out)   — via OpenAI API
#   2. Ollama glm-5.1:cloud       (free)                   — via Ollama API
#   3. DeepSeek V3.2 chat         ($0.14/M in, $0.42/M)   — via DeepSeek API
#   4. Gemini 3 Flash Preview     ($0.30/M in, $2.50/M)   — via Gemini API
#   5. Codex CLI glm-5.1:cloud    (free)                   — via Codex + Ollama
#
# Output:
#   Consensus report printed to stdout. Individual reports in OUTDIR/.
#
# Prerequisites:
#   - OPENAI_API_KEY in env (for GPT-5-mini)
#   - OLLAMA_API_KEY in env (for cloud models) OR local Ollama running
#   - DEEPSEEK_API_KEY in env (for DeepSeek)
#   - GEMINI_API_KEY in env (for Gemini Flash)
#   Missing keys = skip that model (graceful degradation)

set -uo pipefail

# ── Load config (API keys, endpoints, model assignments) ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model-config.sh" 2>/dev/null
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTDIR="/tmp/audit-${TIMESTAMP}"
DIFF_REF=""
FILES=""
FOCUS="bugs,security,logic,performance"
CUSTOM_MODELS=""
VERBOSE=false
TIMEOUT=60

# ── Parse args ──────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff)      DIFF_REF="$2"; shift 2 ;;
    --files)     FILES="$2"; shift 2 ;;
    --focus)     FOCUS="$2"; shift 2 ;;
    --models)    CUSTOM_MODELS="$2"; shift 2 ;;
    --outdir)    OUTDIR="$2"; shift 2 ;;
    --verbose)   VERBOSE=true; shift ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    *)           echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUTDIR"

# ── CRG blast-radius pre-pass (optional) ───────────────
# If code-review-graph is installed, narrow scope to affected files only
CRG_BIN="$HOME/.local/share/crg-venv/bin/code-review-graph"
CRG_CONTEXT=""
if [[ -x "$CRG_BIN" ]] && [[ -n "$DIFF_REF" || -z "$FILES" ]]; then
  CRG_IMPACT=$("$CRG_BIN" impact --format json 2>/dev/null || true)
  if [[ -n "$CRG_IMPACT" ]] && echo "$CRG_IMPACT" | jq empty 2>/dev/null; then
    CRG_FILES=$(echo "$CRG_IMPACT" | jq -r '.affected_files[]? // empty' 2>/dev/null | head -20)
    if [[ -n "$CRG_FILES" ]]; then
      CRG_CONTEXT="CRG blast radius: $(echo "$CRG_FILES" | wc -l | tr -d ' ') affected files"
      echo "  [CRG] Narrowed scope to $(echo "$CRG_FILES" | wc -l | tr -d ' ') affected files"
    fi
  fi
fi

# ── Get code to review ──────────────────────────────────
CODE=""
if [[ -n "$DIFF_REF" ]]; then
  CODE=$(git diff "$DIFF_REF" 2>/dev/null || echo "ERROR: git diff failed for $DIFF_REF")
elif [[ -n "$FILES" ]]; then
  for f in $FILES; do
    if [[ -f "$f" ]]; then
      CODE+="--- $f ---\n$(cat "$f")\n\n"
    fi
  done
else
  # Default: unstaged + staged changes
  CODE=$(git diff HEAD 2>/dev/null || git diff 2>/dev/null || echo "No changes found")
fi

if [[ -z "$CODE" || "$CODE" == "No changes found" ]]; then
  echo "No code changes to review."
  exit 0
fi

# Truncate if too large (keep first 8000 chars for cheap models)
if [[ ${#CODE} -gt 8000 ]]; then
  CODE="${CODE:0:8000}\n\n[... truncated at 8000 chars for cost efficiency ...]"
fi

# ── Review prompt ───────────────────────────────────────
REVIEW_PROMPT="You are a code reviewer. Review this code diff for: ${FOCUS}.
${CRG_CONTEXT:+
Blast radius analysis: ${CRG_CONTEXT}. Focus your review on the affected files and their callers.
}

For each issue found, output EXACTLY this format (one per line):
SEVERITY: [critical|important|minor] | CATEGORY: [${FOCUS// /|}] | FILE: [filename] | LINE: [line number or range] | ISSUE: [one-line description]

Only report real issues. Do NOT report style preferences or nitpicks.
If no issues found, output: NO_ISSUES_FOUND

Code to review:
${CODE}"

# ── Model runners ───────────────────────────────────────

run_openai() {
  local key="${OPENAI_API_KEY:-}"
  [[ -z "$key" ]] && { echo "SKIP:openai:no_api_key"; return; }

  local model="${1:-gpt-5.1-codex-mini}"

  if [[ "$model" == *codex* ]]; then
    local response
    response=$(curl -s --max-time "$TIMEOUT" "https://api.openai.com/v1/responses" \
      -H "Authorization: Bearer $key" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg model "$model" --arg prompt "$REVIEW_PROMPT" '{
        model: $model,
        input: $prompt,
        max_output_tokens: 8000,
        reasoning: {effort: "medium"}
      }')" 2>/dev/null)
    local content
    content=$(echo "$response" | jq -r '.output[] | select(.type=="message") | .content[] | select(.type=="output_text") | .text // empty' 2>/dev/null)
    if [[ -n "$content" ]]; then
      echo "$content"
    else
      echo "ERROR:openai:$(echo "$response" | jq -r '.error.message // "unknown"' 2>/dev/null)"
    fi
  else
    local response
    response=$(curl -s --max-time "$TIMEOUT" "$OPENAI_API_URL" \
      -H "Authorization: Bearer $key" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg model "$model" --arg prompt "$REVIEW_PROMPT" '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        max_completion_tokens: 8000
      }')" 2>/dev/null)
    local content
    content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    if [[ -n "$content" ]]; then
      echo "$content"
    else
      local err
      err=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
      local raw_content
      raw_content=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)
      if [[ "$raw_content" == "" && -n "$(echo "$response" | jq -r '.id // empty' 2>/dev/null)" ]]; then
        echo "NO_ISSUES_FOUND"
      else
        echo "ERROR:openai:${err:-unknown_error}"
      fi
    fi
  fi
}

run_ollama() {
  local model="${1:-${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}}"
  local auth_header=""
  [[ -n "${OLLAMA_API_KEY:-}" ]] && auth_header="Authorization: Bearer $OLLAMA_API_KEY"

  local response
  response=$(curl -s --max-time "$TIMEOUT" "${OLLAMA_HOST}/api/chat" \
    ${auth_header:+-H "$auth_header"} \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$model" --arg prompt "$REVIEW_PROMPT" '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      stream: false,
      think: true,
      options: {temperature: 0.1}
    }')" 2>/dev/null)

  local content thinking
  thinking=$(echo "$response" | jq -r '.message.thinking // empty' 2>/dev/null)
  content=$(echo "$response" | jq -r '.message.content // empty' 2>/dev/null)
  # Reasoning models may put output in .thinking instead of .content
  [[ -z "$content" && -n "$thinking" ]] && content="$thinking"
  if [[ -n "$content" ]]; then
    echo "$content"
  else
    echo "ERROR:ollama:$(echo "$response" | jq -r '.error // "unknown"' 2>/dev/null)"
  fi
}

run_deepseek() {
  local key="${DEEPSEEK_API_KEY:-}"
  [[ -z "$key" ]] && { echo "SKIP:deepseek:no_api_key"; return; }

  local response
  response=$(curl -s --max-time "$TIMEOUT" "$DEEPSEEK_API_URL" \
    -H "Authorization: Bearer $key" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$REVIEW_PROMPT" '{
      model: "'"${MODEL_AUDIT_DEEPSEEK:-deepseek-chat}"'",
      messages: [{role: "user", content: $prompt}],
      temperature: 0.1,
      max_tokens: 2000
    }')" 2>/dev/null)

  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  if [[ -n "$content" ]]; then
    echo "$content"
  else
    echo "ERROR:deepseek:unknown"
  fi
}

run_gemini() {
  local key="${GEMINI_API_KEY:-}"
  [[ -z "$key" ]] && { echo "SKIP:gemini:no_api_key"; return; }

  local model="gemini-3-flash-preview"
  local response
  response=$(curl -s --max-time "$TIMEOUT" \
    "${GEMINI_API_URL}/${model}:generateContent?key=${key}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$REVIEW_PROMPT" '{
      contents: [{parts: [{text: $prompt}]}],
      generationConfig: {temperature: 0.1, maxOutputTokens: 2000}
    }')" 2>/dev/null)

  local content
  content=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
  if [[ -n "$content" ]]; then
    echo "$content"
  else
    local err
    err=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    echo "ERROR:gemini:${err:-$(echo "$response" | head -c 200)}"
  fi
}

run_codex() {
  command -v codex &>/dev/null || { echo "SKIP:codex:not_installed"; return; }
  [[ -z "${OLLAMA_API_KEY:-}" ]] && { echo "SKIP:codex:no_ollama_key"; return; }

  local model="${1:-${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}}"
  local content
  content=$(timeout "$TIMEOUT" codex exec --oss -m "$model" --full-auto "$REVIEW_PROMPT" 2>/dev/null)
  if [[ -n "$content" ]]; then
    echo "$content"
  else
    echo "ERROR:codex:empty_response"
  fi
}

# ── Run models in parallel ──────────────────────────────
echo "## Multi-Model Code Audit"
echo "Focus: ${FOCUS}"
echo "Models running in parallel..."
echo ""

# Determine which models to run
if [[ -n "$CUSTOM_MODELS" ]]; then
  IFS=',' read -ra MODEL_LIST <<< "$CUSTOM_MODELS"
else
  MODEL_LIST=("openai:${MODEL_AUDIT_OPENAI}" "ollama:${MODEL_AUDIT_OLLAMA}" "deepseek:${MODEL_AUDIT_DEEPSEEK}" "gemini:${MODEL_AUDIT_GEMINI}" "codex:${MODEL_AUDIT_CODEX:-glm-5.1:cloud}")
fi

PIDS=()
MODEL_NAMES=()

for entry in "${MODEL_LIST[@]}"; do
  provider="${entry%%:*}"
  model="${entry#*:}"

  case "$provider" in
    openai)
      run_openai "$model" > "$OUTDIR/openai.txt" 2>/dev/null &
      PIDS+=($!)
      MODEL_NAMES+=("OpenAI $model")
      ;;
    ollama)
      run_ollama "$model" > "$OUTDIR/ollama.txt" 2>/dev/null &
      PIDS+=($!)
      MODEL_NAMES+=("Ollama $model")
      ;;
    deepseek)
      run_deepseek > "$OUTDIR/deepseek.txt" 2>/dev/null &
      PIDS+=($!)
      MODEL_NAMES+=("DeepSeek V3")
      ;;
    gemini)
      run_gemini > "$OUTDIR/gemini.txt" 2>/dev/null &
      PIDS+=($!)
      MODEL_NAMES+=("Gemini Flash")
      ;;
    codex)
      run_codex "$model" > "$OUTDIR/codex.txt" 2>/dev/null &
      PIDS+=($!)
      MODEL_NAMES+=("Codex $model")
      ;;
  esac
done

# Wait for all models
SUCCEEDED=0
FAILED=0
for i in "${!PIDS[@]}"; do
  if wait "${PIDS[$i]}" 2>/dev/null; then
    result=$(cat "$OUTDIR/$(echo "${MODEL_LIST[$i]}" | cut -d: -f1).txt" 2>/dev/null)
    if [[ "$result" != ERROR:* && "$result" != SKIP:* ]]; then
      ((SUCCEEDED++))
      echo "  [OK] ${MODEL_NAMES[$i]}"
    else
      ((FAILED++))
      echo "  [SKIP] ${MODEL_NAMES[$i]}: $result"
    fi
  else
    ((FAILED++))
    echo "  [FAIL] ${MODEL_NAMES[$i]}: timeout or error"
  fi
done

echo ""
echo "Models responded: ${SUCCEEDED}/${#PIDS[@]}"
echo ""

# ── Consensus aggregation ──────────────────────────────
# Extract structured issues from each model's output and find consensus

echo "## Consensus Report"
echo ""

# Collect all SEVERITY lines from all outputs
ALL_ISSUES=""
for f in "$OUTDIR"/*.txt; do
  [[ -f "$f" ]] || continue
  provider=$(basename "$f" .txt)
  # Extract lines matching our format
  while IFS= read -r line; do
    if [[ "$line" == SEVERITY:* ]]; then
      ALL_ISSUES+="${provider}|${line}\n"
    fi
  done < "$f"
done

if [[ -z "$ALL_ISSUES" ]]; then
  # Check if all models said no issues
  NO_ISSUES_COUNT=0
  for f in "$OUTDIR"/*.txt; do
    [[ -f "$f" ]] || continue
    if grep -q "NO_ISSUES_FOUND" "$f" 2>/dev/null; then
      ((NO_ISSUES_COUNT++))
    fi
  done

  if [[ $NO_ISSUES_COUNT -ge 2 ]]; then
    echo "### No Issues Found (${NO_ISSUES_COUNT} models agree)"
    echo ""
    echo "All responding models found no significant issues."
  else
    echo "### Raw Results (no structured issues extracted)"
    echo ""
    echo "Models did not use structured format. See individual reports:"
    for f in "$OUTDIR"/*.txt; do
      [[ -f "$f" ]] || continue
      provider=$(basename "$f" .txt)
      echo ""
      echo "--- ${provider} ---"
      head -30 "$f"
      echo ""
    done
  fi
else
  # Parse and count similar issues (simplified: group by ISSUE text similarity)
  echo "### Issues by Consensus"
  echo ""
  echo "**Confirmed (2+ models):**"
  # Simple approach: extract ISSUE fields, sort, count duplicates
  echo -e "$ALL_ISSUES" | grep -oP 'ISSUE: \K.*' | sort | uniq -c | sort -rn | while read -r count issue; do
    if [[ "$count" -ge 2 ]]; then
      echo "  - [${count} models] $issue"
    fi
  done

  echo ""
  echo "**Possible (1 model only):**"
  echo -e "$ALL_ISSUES" | grep -oP 'ISSUE: \K.*' | sort | uniq -c | sort -rn | while read -r count issue; do
    if [[ "$count" -eq 1 ]]; then
      echo "  - $issue"
    fi
  done
fi

echo ""
echo "---"
echo "Full reports: ${OUTDIR}/"
if [[ "$VERBOSE" == true ]]; then
  echo ""
  echo "## Individual Model Reports"
  for f in "$OUTDIR"/*.txt; do
    [[ -f "$f" ]] || continue
    provider=$(basename "$f" .txt)
    echo ""
    echo "### ${provider}"
    cat "$f"
  done
fi

# ── Log to performance tracker ──────────────────────────
LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/audit-performance.log"
echo "[$(date -Iseconds)] models=${SUCCEEDED}/${#PIDS[@]} focus=${FOCUS} diff=${DIFF_REF:-files}" >> "$LOG_FILE" 2>/dev/null || true

# ── Create audit-pass token for review gate ──────────────
# Token allows git push without being blocked by review-gate.sh (4h TTL)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -n "$CURRENT_BRANCH" && "$SUCCEEDED" -gt 0 ]]; then
    BRANCH_TOKEN=$(echo "$CURRENT_BRANCH" | tr '/' '-')
    TOKEN_FILE="$PROJECT_DIR/.claude/.audit-pass-${BRANCH_TOKEN}"
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"models\":$SUCCEEDED,\"branch\":\"$CURRENT_BRANCH\"}" > "$TOKEN_FILE" 2>/dev/null || true
    echo "Audit pass token created for branch: $CURRENT_BRANCH (valid 4 hours)"
fi
