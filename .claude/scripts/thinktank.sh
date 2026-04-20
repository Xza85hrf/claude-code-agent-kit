#!/usr/bin/env bash
# thinktank.sh — Multi-model decision consultation engine
# Primary: Ollama cloud models (free)
# Fallback: Paid APIs (DeepSeek, Gemini, OpenAI) if cloud fails
# Default models (all free, with paid fallbacks):
#   1. nemotron-3-super:cloud (free)  → fallback: DeepSeek API ($0.14/M)
#   2. glm-5.1:cloud          (free)  → fallback: Gemini API ($0.30/M)
#   3. deepseek-v3.2:cloud    (free)  → fallback: OpenAI API ($0.25/M)
# Cost: ~$0.00 per consultation (free Ollama cloud), ~$0.01 if all fall back to paid
#
# Usage:
#   bash .claude/scripts/thinktank.sh --question "WebSockets vs SSE for real-time updates?"
#   bash .claude/scripts/thinktank.sh --question "Best auth strategy?" --models "nemotron,glm-5"
#   bash .claude/scripts/thinktank.sh --question "Redis vs in-memory?" --context "$(cat src/cache.ts)"
#   bash .claude/scripts/thinktank.sh --question "React RSC?" --cache-topic "react-rsc"

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model-config.sh" 2>/dev/null || true

# ── Defaults ──
QUESTION=""
CONTEXT=""
FOCUS=""
MODELS="nemotron,glm-5,deepseek-v3.2,openai"
CACHE_TOPIC=""
TIMEOUT=30
VERBOSE=false
OUTDIR=""

# ── Parse args ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --question)    QUESTION="$2"; shift 2 ;;
    --context)     CONTEXT="$2"; shift 2 ;;
    --focus)       FOCUS="$2"; shift 2 ;;
    --models)      MODELS="$2"; shift 2 ;;
    --cache-topic) CACHE_TOPIC="$2"; shift 2 ;;
    --timeout)     TIMEOUT="$2"; shift 2 ;;
    --verbose)     VERBOSE=true; shift ;;
    --outdir)      OUTDIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$QUESTION" ]]; then
  echo "ERROR: --question is required" >&2
  exit 1
fi

if [[ -z "$OUTDIR" ]]; then
  OUTDIR="/tmp/thinktank-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUTDIR"

# ── Truncate context ──
if [[ -n "$CONTEXT" ]]; then
  CONTEXT="${CONTEXT:0:2000}"
fi

# ── Build prompts ── load from centralized role templates
ROLE_LOADER="$SCRIPT_DIR/load-prompt-role.sh"
if [[ -x "$ROLE_LOADER" ]]; then
  SYS_PROMPT="$(bash "$ROLE_LOADER" architect)"
else
  SYS_PROMPT="You are a senior software architect in a thinktank consulted on technical decisions.

Rules:
- State your recommendation clearly at the top
- List 2-3 key trade-offs with real-world implications
- Be specific and concrete (no generic advice)
- If relevant, state what would change your recommendation
- Keep under 300 words"
fi

if [[ -n "$FOCUS" ]]; then
  SYS_PROMPT="${SYS_PROMPT}
Focus areas: ${FOCUS}"
fi

USER_PROMPT="$QUESTION"
if [[ -n "$CONTEXT" ]]; then
  USER_PROMPT="${USER_PROMPT}

Context:
${CONTEXT}"
fi

echo "=== Thinktank: Consulting models ==="
echo "    Question: ${QUESTION:0:80}"
echo "    Models: $MODELS"
echo ""

# ── Helper: call Ollama cloud model ──
_call_ollama_model() {
  local model="$1" outfile="$2"
  local -a headers=(-H "Content-Type: application/json")
  [[ -n "${OLLAMA_API_KEY:-}" ]] && headers+=(-H "Authorization: Bearer $OLLAMA_API_KEY")
  local payload
  payload=$(jq -n --arg sys "$SYS_PROMPT" --arg usr "$USER_PROMPT" --arg m "$model" '{
    model: $m,
    messages: [{role:"system",content:$sys},{role:"user",content:$usr}],
    stream: false,
    think: true
  }')
  local response content
  response=$(curl -sS --max-time "$TIMEOUT" "${headers[@]}" \
    -d "$payload" "${OLLAMA_HOST:-http://localhost:11434}/api/chat" 2>/dev/null)
  # With think:true, models return .thinking (reasoning) + .content (answer)
  # Prefer .content (final answer), fall back to .thinking (reasoning-only models)
  content=$(echo "$response" | jq -r '
    if (.message.content // "" | length) > 0 then
      (if (.message.thinking // "" | length) > 0 then "**Reasoning:**\n" + .message.thinking + "\n\n**Answer:**\n" + .message.content else .message.content end)
    elif (.message.thinking // "" | length) > 0 then .message.thinking
    else empty end' 2>/dev/null)
  if [[ -n "$content" ]]; then
    echo "$content" > "$outfile"
    return 0
  fi
  return 1
}

# ── Helper: call DeepSeek API ──
_call_deepseek_api() {
  local outfile="$1"
  [[ -z "${DEEPSEEK_API_KEY:-}" ]] && return 1
  local payload
  payload=$(jq -n --arg sys "$SYS_PROMPT" --arg usr "$USER_PROMPT" '{
    model: "deepseek-chat",
    messages: [{role:"system",content:$sys},{role:"user",content:$usr}],
    max_tokens: 800, temperature: 0.7
  }')
  local response content
  response=$(curl -sS --max-time "$TIMEOUT" \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${DEEPSEEK_API_URL:-https://api.deepseek.com/v1/chat/completions}" 2>/dev/null)
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  if [[ -n "$content" ]]; then
    echo "$content" > "$outfile"
    return 0
  fi
  return 1
}

# ── Helper: call Gemini API ──
_call_gemini_api() {
  local outfile="$1"
  [[ -z "${GEMINI_API_KEY:-}" ]] && return 1
  local model="${MODEL_AUDIT_GEMINI:-gemini-3-flash-preview}"
  local base_url="${GEMINI_API_URL:-https://generativelanguage.googleapis.com/v1beta/models}"
  local url="${base_url}/${model}:generateContent?key=${GEMINI_API_KEY}"
  local payload
  payload=$(jq -n --arg sys "$SYS_PROMPT" --arg usr "$USER_PROMPT" '{
    system_instruction: {parts:[{text:$sys}]},
    contents: [{parts:[{text:$usr}]}],
    generationConfig: {maxOutputTokens:800, temperature:0.7}
  }')
  local response content
  response=$(curl -sS --max-time "$TIMEOUT" \
    -H "Content-Type: application/json" \
    -d "$payload" "$url" 2>/dev/null)
  content=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
  if [[ -n "$content" ]]; then
    echo "$content" > "$outfile"
    return 0
  fi
  return 1
}

# ── Helper: call OpenAI API ──
_call_openai_api() {
  local outfile="$1"
  [[ -z "${OPENAI_API_KEY:-}" ]] && return 1
  local model="${MODEL_AUDIT_OPENAI:-gpt-5.1-codex-mini}"
  local payload api_url
  if [[ "$model" == *codex* ]]; then
    # Codex models use /v1/responses endpoint with different format
    api_url="https://api.openai.com/v1/responses"
    payload=$(jq -n --arg sys "$SYS_PROMPT" --arg usr "$USER_PROMPT" --arg m "$model" '{
      model: $m,
      instructions: $sys,
      input: $usr,
      max_output_tokens: 800,
      reasoning: {effort: "medium"}
    }')
  else
    api_url="${OPENAI_API_URL:-https://api.openai.com/v1/chat/completions}"
    payload=$(jq -n --arg sys "$SYS_PROMPT" --arg usr "$USER_PROMPT" --arg m "$model" '{
      model: $m,
      messages: [{role:"system",content:$sys},{role:"user",content:$usr}],
      max_completion_tokens: 800, temperature: 0.7
    }')
  fi
  local response content
  response=$(curl -sS --max-time "$TIMEOUT" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$api_url" 2>/dev/null)
  if [[ "$model" == *codex* ]]; then
    content=$(echo "$response" | jq -r '.output[] | select(.type=="message") | .content[] | select(.type=="output_text") | .text // empty' 2>/dev/null)
  else
    content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  fi
  if [[ -n "$content" ]]; then
    echo "$content" > "$outfile"
    return 0
  fi
  return 1
}

# ── Model slots: Ollama cloud primary → paid API fallback ──

call_nemotron() {
  local outfile="$OUTDIR/nemotron.md"
  if _call_ollama_model "${MODEL_WORKER_AGENTIC:-nemotron-3-super:cloud}" "$outfile"; then
    echo "${MODEL_WORKER_AGENTIC:-nemotron-3-super:cloud}" > "$outfile.model"
    return 0
  fi
  if _call_deepseek_api "$outfile"; then
    echo "deepseek-chat (fallback)" > "$outfile.model"
    return 0
  fi
  echo "ERROR: No response from nemotron-3-super:cloud or DeepSeek API" > "$outfile"
  return 1
}

call_glm5() {
  local outfile="$OUTDIR/glm-5.md"
  if _call_ollama_model "${MODEL_WORKER_PRIMARY}" "$outfile"; then
    echo "${MODEL_WORKER_PRIMARY}" > "$outfile.model"
    return 0
  fi
  if _call_gemini_api "$outfile"; then
    echo "gemini-3-flash (fallback)" > "$outfile.model"
    return 0
  fi
  echo "ERROR: No response from ${MODEL_WORKER_PRIMARY} or Gemini API" > "$outfile"
  return 1
}

call_deepseek_v3() {
  local outfile="$OUTDIR/deepseek-v3.2.md"
  if _call_ollama_model "${MODEL_WORKER_REASONING}" "$outfile"; then
    echo "${MODEL_WORKER_REASONING}" > "$outfile.model"
    return 0
  fi
  if _call_openai_api "$outfile"; then
    echo "gpt-5.1-codex-mini (fallback)" > "$outfile.model"
    return 0
  fi
  echo "ERROR: No response from deepseek-v3.2:cloud or OpenAI API" > "$outfile"
  return 1
}

# ── Launch in parallel ──
IFS=',' read -ra MODEL_LIST <<< "$MODELS"
PIDS=()
NAMES=()

for model in "${MODEL_LIST[@]}"; do
  model=$(echo "$model" | xargs)
  case "$model" in
    nemotron|qwen3.5) call_nemotron &  PIDS+=($!); NAMES+=("Nemotron-3-Super (agentic)") ;;
    glm-5|glm5)    call_glm5 &       PIDS+=($!); NAMES+=("GLM-5.1 (architecture)") ;;
    deepseek-v3.2) call_deepseek_v3 & PIDS+=($!); NAMES+=("DeepSeek V3.2 (structural)") ;;
    # Legacy direct-API slots (backward compat)
    deepseek)
      (outfile="$OUTDIR/deepseek.md"; _call_deepseek_api "$outfile" || echo "ERROR: No response" > "$outfile") &
      PIDS+=($!); NAMES+=("DeepSeek API (direct)") ;;
    openai)
      (outfile="$OUTDIR/openai.md"; _call_openai_api "$outfile" || echo "ERROR: No response" > "$outfile") &
      PIDS+=($!); NAMES+=("OpenAI API (direct)") ;;
    gemini)
      (outfile="$OUTDIR/gemini.md"; _call_gemini_api "$outfile" || echo "ERROR: No response" > "$outfile") &
      PIDS+=($!); NAMES+=("Gemini API (direct)") ;;
    *) echo "WARNING: Unknown model '$model'" >&2 ;;
  esac
done

# ── Contrarian slot: adversarial persona to strip sycophancy (Anthropic PSM research) ──
# Uses first model's provider but with skeptical system prompt
call_contrarian() {
  local outfile="$OUTDIR/contrarian.md"
  local CONTRARIAN_PROMPT="You are a skeptical senior engineer who finds flaws in every proposal.
Your job is to find the WORST aspect of this approach and argue against it.
Do NOT agree with the proposal. Find genuine weaknesses, edge cases that break it,
hidden costs, or maintenance burdens. If you cannot find real flaws, say so honestly.
Keep under 250 words."

  local payload
  payload=$(jq -n --arg sys "$CONTRARIAN_PROMPT" --arg usr "$USER_PROMPT" --arg m "${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}" '{
    model: $m,
    messages: [{role:"system",content:$sys},{role:"user",content:$usr}],
    stream: false
  }')

  local -a headers=(-H "Content-Type: application/json")
  [[ -n "${OLLAMA_API_KEY:-}" ]] && headers+=(-H "Authorization: Bearer $OLLAMA_API_KEY")

  local response
  response=$(curl -s --max-time 30 "${OLLAMA_HOST}/api/chat" "${headers[@]}" -d "$payload" 2>/dev/null)
  local content
  content=$(echo "$response" | jq -r '.message.content // empty' 2>/dev/null)

  if [[ -n "$content" && ${#content} -gt 20 ]]; then
    echo "$content" > "$outfile"
    echo "${MODEL_WORKER_PRIMARY:-glm-5.1:cloud} (contrarian)" > "$outfile.model"
    return 0
  fi
  echo "SKIP: contrarian unavailable" > "$outfile"
  return 1
}

call_contrarian &
PIDS+=($!)
NAMES+=("Contrarian (adversarial)")

# ── Wait ──
SUCCEEDED=0
FAILED=0
for pid in "${PIDS[@]}"; do
  if wait "$pid" 2>/dev/null; then SUCCEEDED=$((SUCCEEDED + 1)); else FAILED=$((FAILED + 1)); fi
done

echo "    Results: $SUCCEEDED succeeded, $FAILED failed"
echo ""

# ── Synthesize ──
{
  echo "# Thinktank Consultation"
  echo ""
  echo "## Question"
  echo "$QUESTION"
  echo ""

  if [[ -n "$CONTEXT" ]]; then
    echo "## Context"
    echo "${CONTEXT:0:300}..."
    echo ""
  fi

  echo "## Expert Opinions"
  echo ""

  RESPONSE_COUNT=0
  for i in "${!MODEL_LIST[@]}"; do
    model=$(echo "${MODEL_LIST[$i]}" | xargs)
    outfile="$OUTDIR/${model}.md"
    [[ -f "$outfile" ]] || continue
    content=$(cat "$outfile")
    [[ "$content" == SKIP:* || "$content" == "ERROR:"* ]] && continue

    label="${NAMES[$i]:-$model}"
    if [[ -f "$outfile.model" ]]; then
      actual_model=$(cat "$outfile.model")
      label="$label [via $actual_model]"
    fi
    echo "### $label"
    echo ""
    if [[ "$VERBOSE" == true ]]; then
      echo "$content"
    else
      echo "$content" | head -5
      echo ""
      echo "*(Full: $outfile)*"
    fi
    echo ""
    echo "---"
    echo ""
    RESPONSE_COUNT=$((RESPONSE_COUNT + 1))
  done

  # Contrarian view (sycophancy triangulation — Anthropic PSM research)
  contrarian_file="$OUTDIR/contrarian.md"
  if [[ -f "$contrarian_file" ]]; then
    contrarian_content=$(cat "$contrarian_file")
    if [[ "$contrarian_content" != SKIP:* && "$contrarian_content" != "ERROR:"* ]]; then
      echo "## Contrarian View (adversarial)"
      echo ""
      echo "$contrarian_content" | head -8
      echo ""
      echo "---"
      echo ""
    fi
  fi

  echo "## Synthesis"
  echo ""
  echo "**Models consulted:** $RESPONSE_COUNT (+ contrarian)"
  echo ""
  echo "**Decision guidance:**"
  if [[ $RESPONSE_COUNT -ge 3 ]]; then
    echo "- If all models agree AND contrarian found no real flaws → very strong signal"
    echo "- If all models agree but contrarian found valid concern → strong, address the concern"
    echo "- If majority agrees → likely correct, note the dissent"
    echo "- If split → genuine trade-off, user preference matters"
    echo "- If all disagree → complex problem, need more context"
  elif [[ $RESPONSE_COUNT -ge 2 ]]; then
    echo "- $RESPONSE_COUNT models responded — limited consensus, consider re-running with more"
  else
    echo "- Only $RESPONSE_COUNT model responded — check API keys for better coverage"
  fi
} | tee "$OUTDIR/synthesis.md"

# ── Cache if requested ──
if [[ -n "$CACHE_TOPIC" ]]; then
  CACHE_SCRIPT="$SCRIPT_DIR/knowledge-cache.sh"
  if [[ -x "$CACHE_SCRIPT" ]]; then
    full_content=$(cat "$OUTDIR/synthesis.md")
    bash "$CACHE_SCRIPT" --set "$CACHE_TOPIC" \
      --tags "thinktank,decision" \
      --source "thinktank" \
      --content "$full_content" 2>/dev/null && \
    echo "" && echo "    Cached as: $CACHE_TOPIC"
  fi
fi

echo ""
echo "    Full responses: $OUTDIR/"
