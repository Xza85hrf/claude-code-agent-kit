#!/usr/bin/env bash
# ollama-batch.sh — Batch parallel Ollama calls with retry
#
# Replaces parallel ollama_chat MCP calls to avoid sibling cascade failures (ADR-006).
# Calls Ollama API directly via curl, batches tasks, retries on failure.
#
# Usage:
#   # Multiple tasks inline:
#   bash .claude/scripts/ollama-batch.sh \
#     --model "minimax-m2.7:cloud" \
#     --task "Generate auth middleware in TypeScript" \
#     --task "Generate user model with Prisma" \
#     --task "Write vitest tests for auth"
#
#   # Tasks from file (one per line):
#   bash .claude/scripts/ollama-batch.sh --model "minimax-m2.7:cloud" --file tasks.txt
#
#   # Custom batch size and system prompt:
#   bash .claude/scripts/ollama-batch.sh \
#     --model "minimax-m2.7:cloud" \
#     --batch-size 2 \
#     --system "You are a TypeScript expert. Output only code, no commentary." \
#     --task "..." --task "..."
#
# Options:
#   --model MODEL        Primary model (default: glm-5.1:cloud)
#   --fallback MODEL     Fallback model on failure (default: glm-5.1:cloud)
#   --batch-size N       Max parallel tasks per batch (default: 3)
#   --system PROMPT      System prompt for all tasks
#   --task "TASK"        Add a task (repeat for multiple)
#   --file FILE          Load tasks from file (one per line, # comments skipped)
#   --format FORMAT      Output format: markdown (default) or json
#   --outdir DIR         Output directory (default: /tmp/ollama-batch-TIMESTAMP)
#   --retries N          Max retries per task (default: 1)
#   --timeout SECS       Per-task timeout (default: 120)
#   --summarize          Generate consolidated SUMMARY.md after batch (PTC-inspired context optimization)
#   --summary-model M    Model for summary generation (default: glm-5.1:cloud)
#
# Output:
#   Each task result saved to OUTDIR/task-NN.md (or .json)
#   Summary printed to stdout for Opus to review
#
# Why this exists:
#   Parallel ollama_chat MCP calls suffer from sibling cascade failures —
#   if ANY one call fails, ALL siblings are cancelled. This script bypasses
#   MCP entirely by calling the Ollama HTTP API with curl, running tasks in
#   controlled batches with per-task retry.
#
# Cloud auth:
#   Cloud models (*.cloud) require Ollama account auth. If you get "unauthorized":
#   1. Run `ollama signin` on the host (Windows/macOS) to refresh session
#   2. OLLAMA_API_KEY env var is sent as Bearer token if set
#   3. Fallback: use local models (gpt-oss:20b, deepcoder, glm-4.7-flash)

set -euo pipefail

# ── Defaults ──
source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
source "${BASH_SOURCE[0]%/*}/model-config.sh" 2>/dev/null || true
MODEL="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}"
FALLBACK="${MODEL_WORKER_REVIEW:-minimax-m2.7:cloud}"
BATCH_SIZE=3
SYSTEM_PROMPT="You are a skilled software engineer. Be concrete and specific. Output code with brief explanations. No preamble."
FORMAT="markdown"
OUTDIR=""
MAX_RETRIES=1
TIMEOUT=120
OLLAMA_API_KEY="${OLLAMA_API_KEY:-}"
SUMMARIZE=false
SUMMARY_MODEL="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}"
declare -a TASKS=()
TASK_FILE=""

# ── Parse args ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)      MODEL="$2"; shift 2 ;;
    --fallback)   FALLBACK="$2"; shift 2 ;;
    --batch-size) BATCH_SIZE="$2"; shift 2 ;;
    --system)     SYSTEM_PROMPT="$2"; shift 2 ;;
    --task)       TASKS+=("$2"); shift 2 ;;
    --file)       TASK_FILE="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --outdir)     OUTDIR="$2"; shift 2 ;;
    --retries)    MAX_RETRIES="$2"; shift 2 ;;
    --timeout)    TIMEOUT="$2"; shift 2 ;;
    --summarize)  SUMMARIZE=true; shift ;;
    --summary-model) SUMMARY_MODEL="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Load tasks from file if provided
if [[ -n "$TASK_FILE" ]]; then
  if [[ ! -f "$TASK_FILE" ]]; then
    echo "ERROR: Task file not found: $TASK_FILE" >&2
    exit 1
  fi
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    TASKS+=("$line")
  done < "$TASK_FILE"
fi

if [[ ${#TASKS[@]} -eq 0 ]]; then
  echo "ERROR: No tasks provided. Use --task or --file." >&2
  exit 1
fi

# Create output directory
if [[ -z "$OUTDIR" ]]; then
  OUTDIR="/tmp/ollama-batch-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUTDIR"

# ── Pre-flight ──
if ! curl -s --max-time 5 "$OLLAMA_HOST/" >/dev/null 2>&1; then
  echo "ERROR: Ollama not reachable at $OLLAMA_HOST" >&2
  exit 1
fi

TOTAL=${#TASKS[@]}
echo "=== Ollama Batch: $TOTAL tasks, model=$MODEL, batch_size=$BATCH_SIZE ==="
echo "    Output: $OUTDIR"
echo ""

# ── Performance log ──
LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/worker-performance.log"

# ── Core: call Ollama API ──
call_ollama() {
  local model="$1"
  local task="$2"
  local outfile="$3"
  local task_num="$4"

  # Build JSON payload
  local payload
  payload=$(jq -n \
    --arg model "$model" \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$task" \
    '{
      model: $model,
      messages: [
        { role: "system", content: $system },
        { role: "user", content: $user }
      ],
      stream: false
    }')

  local start_time
  start_time=$(date +%s)

  # Build auth header if API key is available (required for cloud models)
  local auth_args=()
  if [[ -n "$OLLAMA_API_KEY" ]]; then
    auth_args+=(-H "Authorization: Bearer $OLLAMA_API_KEY")
  fi

  # Call Ollama chat API
  local response
  local http_code
  http_code=$(curl -s -w "%{http_code}" -o "$outfile.raw" \
    --max-time "$TIMEOUT" \
    -H "Content-Type: application/json" \
    "${auth_args[@]}" \
    -d "$payload" \
    "$OLLAMA_HOST/api/chat" 2>/dev/null)

  local end_time
  end_time=$(date +%s)
  local elapsed=$(( end_time - start_time ))

  # Check for success
  if [[ "$http_code" == "200" ]] && [[ -f "$outfile.raw" ]]; then
    # Extract message content from response
    local content
    content=$(jq -r '.message.content // empty' "$outfile.raw" 2>/dev/null)
    if [[ -n "$content" ]]; then
      echo "$content" > "$outfile"
      rm -f "$outfile.raw"
      # Log success
      log_result "$model" "$task" "success" "$elapsed" "$task_num"
      return 0
    fi
  fi

  # Extract error message if available
  local error_msg
  error_msg=$(jq -r '.error // "unknown error"' "$outfile.raw" 2>/dev/null || echo "HTTP $http_code")
  rm -f "$outfile.raw"
  echo "ERROR: $error_msg" > "$outfile"

  # Log failure
  log_result "$model" "$task" "fail:$error_msg" "$elapsed" "$task_num"
  return 1
}

log_result() {
  local model="$1" task="$2" status="$3" elapsed="$4" task_num="$5"
  if [[ -d "$(dirname "$LOG_FILE")" ]] && command -v jq &>/dev/null; then
    jq -n -c \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg model "$model" \
      --arg task "${task:0:200}" \
      --arg status "$status" \
      --arg tier "tier2_batch" \
      --argjson elapsed "$elapsed" \
      --arg task_num "$task_num" \
      --arg batch_id "$(basename "$OUTDIR")" \
      '{"ts":$ts,"model":$model,"task":$task,"status":$status,"tier":$tier,"elapsed_s":$elapsed,"task_num":$task_num,"batch_id":$batch_id}' \
      >> "$LOG_FILE" 2>/dev/null
  fi
}

# ── Run a single task with retry ──
run_task() {
  local idx="$1"
  local task="${TASKS[$idx]}"
  local task_num=$(printf "%02d" $((idx + 1)))
  local ext="md"
  [[ "$FORMAT" == "json" ]] && ext="json"
  local outfile="$OUTDIR/task-${task_num}.${ext}"

  echo "  [${task_num}/${TOTAL}] Starting: ${task:0:80}..."

  # Try primary model
  if call_ollama "$MODEL" "$task" "$outfile" "$task_num"; then
    echo "  [${task_num}/${TOTAL}] OK (${MODEL})"
    return 0
  fi

  # Retry with fallback
  local attempt=0
  while [[ $attempt -lt $MAX_RETRIES ]]; do
    attempt=$((attempt + 1))
    echo "  [${task_num}/${TOTAL}] RETRY $attempt with $FALLBACK..."
    if call_ollama "$FALLBACK" "$task" "$outfile" "$task_num"; then
      echo "  [${task_num}/${TOTAL}] OK (${FALLBACK}, retry $attempt)"
      return 0
    fi
  done

  echo "  [${task_num}/${TOTAL}] FAILED after $((MAX_RETRIES + 1)) attempts"
  return 1
}

# ── Batch execution ──
SUCCEEDED=0
FAILED=0
FAILED_TASKS=()

batch_start=0
while [[ $batch_start -lt $TOTAL ]]; do
  batch_end=$((batch_start + BATCH_SIZE))
  [[ $batch_end -gt $TOTAL ]] && batch_end=$TOTAL

  echo "--- Batch $((batch_start / BATCH_SIZE + 1)): tasks $((batch_start + 1))-${batch_end} ---"

  # Launch batch in parallel (background jobs)
  declare -a PIDS=()
  for ((i = batch_start; i < batch_end; i++)); do
    run_task "$i" &
    PIDS+=($!)
  done

  # Wait for all in this batch
  for pid in "${PIDS[@]}"; do
    if wait "$pid"; then
      SUCCEEDED=$((SUCCEEDED + 1))
    else
      FAILED=$((FAILED + 1))
    fi
  done

  batch_start=$batch_end
done

# ── Summary ──
echo ""
echo "=== Batch Complete ==="
echo "  Total:     $TOTAL"
echo "  Succeeded: $SUCCEEDED"
echo "  Failed:    $FAILED"
echo "  Output:    $OUTDIR/"
echo ""

# List output files with sizes
for f in "$OUTDIR"/task-*; do
  [[ -f "$f" ]] || continue
  size=$(wc -c < "$f")
  status="OK"
  if head -1 "$f" | grep -q "^ERROR:"; then
    status="FAILED"
  fi
  echo "  $(basename "$f") — ${size}B — ${status}"
done

echo ""
echo "=== Results ==="
# Print each result with a header
for f in "$OUTDIR"/task-*; do
  [[ -f "$f" ]] || continue
  fname=$(basename "$f")
  idx="${fname#task-}"
  idx="${idx%%.*}"
  idx=$((10#$idx - 1))
  echo ""
  echo "──── Task $((idx + 1)): ${TASKS[$idx]:0:100} ────"
  cat "$f"
  echo ""
done

# ── Optional: PTC-inspired batch summarization ──
# Keeps intermediate results out of Opus context — only summary enters the conversation
if [[ "$SUMMARIZE" == "true" ]]; then
  echo ""
  echo "=== Generating Summary (PTC-inspired context optimization) ==="

  # Build summary prompt from all task outputs
  summary_prompt="Summarize these batch worker outputs concisely (max 300 words).
Batch: $TOTAL tasks, Succeeded: $SUCCEEDED, Failed: $FAILED.

"
  for f in "$OUTDIR"/task-*; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    idx="${fname#task-}"
    idx="${idx%%.*}"
    idx=$((10#$idx - 1))
    task_desc="${TASKS[$idx]:0:120}"
    task_content=$(head -c 4000 "$f")
    summary_prompt+="## Task $((idx + 1)): ${task_desc}
\`\`\`
${task_content}
\`\`\`

"
  done

  summary_prompt+="Produce:
1. One-line status (X/Y succeeded)
2. Per-task: 1-line summary of what was generated + any issues
3. Files ready for integration vs needing rework
4. Recommended next steps (1 sentence)"

  # Auth header for cloud models
  declare -a summary_auth_args=()
  if [[ -n "$OLLAMA_API_KEY" ]]; then
    summary_auth_args=(-H "Authorization: Bearer $OLLAMA_API_KEY")
  fi

  SUMMARY_FILE="$OUTDIR/SUMMARY.md"
  s_http=$(curl -s -w "%{http_code}" -o "${SUMMARY_FILE}.raw" \
    --max-time 120 \
    -H "Content-Type: application/json" \
    "${summary_auth_args[@]}" \
    -d "$(jq -n \
      --arg model "$SUMMARY_MODEL" \
      --arg system "You are a concise code review expert. Synthesize batch outputs into ONE actionable summary." \
      --arg user "$summary_prompt" \
      '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $user}], stream: false}')" \
    "$OLLAMA_HOST/api/chat" 2>/dev/null)

  if [[ "$s_http" == "200" ]] && jq -e '.message.content' "${SUMMARY_FILE}.raw" >/dev/null 2>&1; then
    jq -r '.message.content' "${SUMMARY_FILE}.raw" > "$SUMMARY_FILE"
    rm -f "${SUMMARY_FILE}.raw"
    echo "  Summary: $SUMMARY_FILE"
    echo ""
    cat "$SUMMARY_FILE"
  else
    rm -f "${SUMMARY_FILE}.raw"
    echo "  Summary generation failed (HTTP $s_http), skipping"
  fi
fi

exit $([[ $FAILED -gt 0 ]] && echo 1 || echo 0)
