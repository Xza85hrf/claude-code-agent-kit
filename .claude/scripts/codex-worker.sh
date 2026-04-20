#!/usr/bin/env bash
# codex-worker.sh — Dispatch tasks to OpenAI Codex CLI via Ollama (Tier 6)
#
# Usage:
#   bash .claude/scripts/codex-worker.sh "Review this plan for risks" --model glm-5.1:cloud
#   bash .claude/scripts/codex-worker.sh "List all TODO comments in src/" --json
#   bash .claude/scripts/codex-worker.sh "Refactor auth module" --model qwen3-coder-next:cloud
#   bash .claude/scripts/codex-worker.sh "What does spawn-worker.sh do?" --read-only
#
# Flags:
#   --model MODEL   Ollama model (default: glm-5.1:cloud, override: CODEX_DEFAULT_MODEL)
#   --json          JSONL streaming output
#   --full-auto     Skip all approval prompts (default: true)
#   --read-only     Sandbox: read-only (default)
#   --write         Sandbox: allow writes
#   --timeout SECS  Kill after N seconds (default: 120)
#   --output FILE   Write final message to file

set -euo pipefail

TASK=""
# Source model config for centralized model names
SCRIPT_DIR_CW="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_CW/model-config.sh" 2>/dev/null || true
MODEL="${CODEX_DEFAULT_MODEL:-${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}}"
JSON_MODE=false
FULL_AUTO=true
SANDBOX_MODE=true
TIMEOUT_SECS=120
OUTPUT_FILE=""

# Source shared defaults
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/env-defaults.sh" 2>/dev/null || true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model) MODEL="$2"; shift 2 ;;
        --json) JSON_MODE=true; shift ;;
        --full-auto) FULL_AUTO=true; shift ;;
        --read-only) SANDBOX_MODE=true; shift ;;
        --write) SANDBOX_MODE=false; shift ;;
        --timeout) TIMEOUT_SECS="$2"; shift 2 ;;
        --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
        -*) echo "Unknown flag: $1" >&2; exit 1 ;;
        *) [[ -z "$TASK" ]] && TASK="$1"; shift ;;
    esac
done

[[ -z "$TASK" ]] && { echo "Error: TASK argument required" >&2; exit 1; }

# Pre-flight
command -v codex &>/dev/null || { echo "Error: codex CLI not found. Install: npm i -g @openai/codex" >&2; exit 1; }
[[ -z "${OLLAMA_API_KEY:-}" ]] && { echo "Error: OLLAMA_API_KEY not set" >&2; exit 1; }

# Build codex flags
CODEX_ARGS=(exec --oss -m "$MODEL")
[[ "$FULL_AUTO" == true ]] && CODEX_ARGS+=(--full-auto)
[[ "$JSON_MODE" == true ]] && CODEX_ARGS+=(--json)
[[ -n "$OUTPUT_FILE" ]] && CODEX_ARGS+=(-o "$OUTPUT_FILE")
CODEX_ARGS+=("$TASK")

# Performance logging
LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/worker-performance.log"
START_TIME=$(date +%s)
OUTPUT_CAPTURE="/tmp/codex-worker-${START_TIME}-$$.log"

EXIT_CODE=0
timeout "$TIMEOUT_SECS" codex "${CODEX_ARGS[@]}" 2>/dev/null | tee "$OUTPUT_CAPTURE" || EXIT_CODE=$?

[[ $EXIT_CODE -eq 124 ]] && echo "WARNING: Codex worker timed out after ${TIMEOUT_SECS}s" >&2

# Log Tier 6 performance
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

if [ -d "$(dirname "$LOG_FILE")" ] && command -v jq &>/dev/null; then
  jq -n -c \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg model "$MODEL" \
    --arg task "${TASK:0:200}" \
    --arg status "$([ $EXIT_CODE -eq 0 ] && echo 'success' || echo 'fail')" \
    --arg tier "tier6" \
    --argjson exit_code "$EXIT_CODE" \
    --argjson elapsed "$ELAPSED" \
    --arg output_file "$OUTPUT_CAPTURE" \
    --argjson json_mode "$([ "$JSON_MODE" = true ] && echo true || echo false)" \
    '{"ts":$ts,"model":$model,"task":$task,"status":$status,"tier":$tier,"exit_code":$exit_code,"elapsed_s":$elapsed,"output_file":$output_file,"json_mode":$json_mode}' \
    >> "$LOG_FILE" 2>/dev/null
fi

echo "--- Codex output: $OUTPUT_CAPTURE ---" >&2
exit $EXIT_CODE
