#!/bin/bash
# spawn-worker.sh — Spawn a full Claude Code worker powered by Ollama
#
# Usage from Opus (via Bash tool):
#   bash .claude/scripts/spawn-worker.sh "minimax-m2.7:cloud" "Implement auth middleware following patterns in src/auth/"
#   bash .claude/scripts/spawn-worker.sh "glm-5.1:cloud" "Review and refactor src/utils/ to remove duplication"
#   bash .claude/scripts/spawn-worker.sh "minimax-m2.7:cloud" "task" --retry "qwen3-coder-next:cloud"
#   bash .claude/scripts/spawn-worker.sh "qwen3-coder-next:cloud" "List files" --max-turns 2  # Quick test (capped turns)
#   bash .claude/scripts/spawn-worker.sh "glm-5.1:cloud" "Review plan" --codex        # Tier 6: route to Codex CLI
#   bash .claude/scripts/spawn-worker.sh "glm-5.1:cloud" "Shell task" --engine codex  # Tier 1b: Codex for shell/DevOps
#
# What this does:
#   Spawns a claude -p instance with ANTHROPIC_BASE_URL pointing at Ollama.
#   The worker gets FULL Claude Code tools (Read, Write, Edit, Bash, Grep, Glob).
#   Worker runs autonomously in --permission-mode bypassPermissions.
#   Output is returned as text for Opus to review.
#
# Environment:
#   OLLAMA_HOST    — Ollama base URL (default: http://localhost:11434)
#   OLLAMA_AUTH_TOKEN — Auth token for cloud models (default: ollama)

set -euo pipefail

MODEL="${1:?Usage: spawn-worker.sh MODEL TASK [--max-turns N] [--read-only] [--timeout S] [--repeat-prompt]}"
TASK="${2:?Usage: spawn-worker.sh MODEL TASK [--max-turns N] [--read-only] [--timeout S] [--repeat-prompt]}"
# Source shared defaults (OLLAMA_HOST, SCRIPTS_DIR, CLAUDE_PROJECT_DIR)
source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
# Source model config for fallback defaults
source "${BASH_SOURCE[0]%/*}/model-config.sh" 2>/dev/null || true
# Shared Ollama cap detection — flips .worker-status=capped on observed
# quota-error output so delegation-reminder.sh downgrades BLOCK to
# allow-with-warning on subsequent writes. See lib/worker-quota.sh.
source "${BASH_SOURCE[0]%/*}/../lib/worker-quota.sh" 2>/dev/null || true
MAX_TURNS=""
READ_ONLY=false
TIMEOUT=""
REPEAT_PROMPT=false
USE_CODEX=false

# Parse optional flags
shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --retry) RETRY_MODEL="$2"; shift 2 ;;
    --read-only) READ_ONLY=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --repeat-prompt) REPEAT_PROMPT=true; shift ;;
    --codex) USE_CODEX=true; shift ;;
    --engine) [ "$2" = "codex" ] && USE_CODEX=true; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Tier 1b/6: Route to Codex CLI if --codex or --engine codex
if [ "$USE_CODEX" = true ]; then
  CODEX_FLAGS=("$TASK" --model "$MODEL")
  [ "$READ_ONLY" = true ] && CODEX_FLAGS+=(--read-only)
  [ -n "$TIMEOUT" ] && CODEX_FLAGS+=(--timeout "$TIMEOUT")
  exec "$(dirname "${BASH_SOURCE[0]}")/codex-worker.sh" "${CODEX_FLAGS[@]}"
fi

# Prompt repetition (Leviathan et al. 2025): improves non-reasoning model accuracy
if [ "$REPEAT_PROMPT" = true ]; then
  TASK="${TASK}

Let me repeat that:

${TASK}"
fi

# Pre-flight: check Ollama — fallback to Codex CLI if unreachable
if ! curl -s --max-time 3 "$OLLAMA_HOST/" >/dev/null 2>&1; then
  if command -v codex &>/dev/null && [[ -n "${OLLAMA_API_KEY:-}" ]]; then
    echo "--- Ollama unreachable, falling back to Codex CLI (Tier 6) ---" >&2
    exec "$(dirname "${BASH_SOURCE[0]}")/codex-worker.sh" "$TASK" --model "$MODEL" \
      ${TIMEOUT:+--timeout "$TIMEOUT"} ${READ_ONLY:+--read-only}
  fi
  echo "ERROR: Ollama not reachable at $OLLAMA_HOST (no Codex fallback available)"
  exit 1
fi

# Worker system prompt — load from centralized role templates, fallback to inline
ROLE_LOADER="$(dirname "${BASH_SOURCE[0]}")/load-prompt-role.sh"
if [[ -x "$ROLE_LOADER" ]]; then
  WORKER_PROMPT="$(bash "$ROLE_LOADER" worker)"
else
  WORKER_PROMPT="You are a coding worker agent. Complete the assigned task precisely. Follow existing code patterns. Read files before writing. Do NOT communicate with users. Do NOT create git commits."
fi

# Build claude flags
CLAUDE_FLAGS=(
  -p "$TASK"
  --model "$MODEL"
  --permission-mode bypassPermissions
  --system-prompt "$WORKER_PROMPT"
  --output-format text
)
if [ "$READ_ONLY" = true ]; then
  CLAUDE_FLAGS+=(--disallowed-tools "Write,Edit")
fi
[ -n "$MAX_TURNS" ] && CLAUDE_FLAGS+=(--max-turns "$MAX_TURNS")

# --- Performance logging ---
LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/worker-performance.log"
START_TIME=$(date +%s)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_BEFORE=$(git diff --stat 2>/dev/null | tail -1)

# Build timeout command prefix
TIMEOUT_CMD=""
[ -n "$TIMEOUT" ] && TIMEOUT_CMD="timeout $TIMEOUT"

# Output capture — tee to temp file for Opus to review
OUTPUT_FILE="/tmp/claude-worker-$(date +%s)-$$.log"

# Spawn the worker (CLAUDECODE= unsets nesting guard)
# Disable set -e for the pipeline so a failing worker exit propagates
# through to EXIT_CODE capture instead of aborting the script mid-run.
# Under `set -euo pipefail`, a non-zero pipe component would otherwise
# take down the whole script here — killing the perf logger, retry
# logic, and the quota-cap detector below. Pre-existing silent hazard;
# any failed worker simply vanished without a trace in the perf log.
set +e
$TIMEOUT_CMD env \
  CLAUDECODE= \
  ANTHROPIC_BASE_URL="${OLLAMA_HOST}" \
  ANTHROPIC_AUTH_TOKEN="${OLLAMA_AUTH_TOKEN:-ollama}" \
  LAUNCH_MODE="ollama" \
  MCP_CONNECTION_NONBLOCKING=true \
  CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 \
  claude "${CLAUDE_FLAGS[@]}" 2>/dev/null | tee "$OUTPUT_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

# Handle timeout (exit code 124)
if [ $EXIT_CODE -eq 124 ]; then
    echo "WARNING: Worker timed out after ${TIMEOUT}s"
fi

# Quota-cap detection: Ollama cloud emits "experiencing high volume",
# "subscription is required", and an ollama.com/upgrade link as a 403
# permission_error when the weekly quota is hit. The error lands on
# stdout (already captured in $OUTPUT_FILE via tee) and exit code 1.
# Flip .worker-status=capped so delegation-reminder.sh downgrades BLOCK
# tier to allow-with-warning — the brain writes code directly instead
# of deadlocking against a reachable-but-unusable worker pool.
CAPPED=0
if declare -f check_ollama_quota >/dev/null 2>&1 && [ -s "$OUTPUT_FILE" ]; then
  if check_ollama_quota "$OUTPUT_FILE" "spawn-worker"; then
    CAPPED=1
  fi
fi

# Log Tier 1 worker performance
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
GIT_AFTER=$(git diff --stat 2>/dev/null | tail -1)

if [ -d "$(dirname "$LOG_FILE")" ] && command -v jq &>/dev/null; then
  jq -n -c \
    --arg ts "$TIMESTAMP" \
    --arg model "$MODEL" \
    --arg task "${TASK:0:200}" \
    --arg status "$([ $EXIT_CODE -eq 0 ] && echo 'success' || echo 'fail')" \
    --arg tier "tier1" \
    --argjson exit_code "$EXIT_CODE" \
    --argjson elapsed "$ELAPSED" \
    --arg git_diff "${GIT_AFTER:-no changes}" \
    --arg output_file "$OUTPUT_FILE" \
    --argjson repeat_prompt "$([ "$REPEAT_PROMPT" = true ] && echo true || echo false)" \
    '{"ts":$ts,"model":$model,"task":$task,"status":$status,"tier":$tier,"exit_code":$exit_code,"elapsed_s":$elapsed,"git_diff":$git_diff,"output_file":$output_file,"repeat_prompt":$repeat_prompt}' \
    >> "$LOG_FILE" 2>/dev/null
fi

echo "--- Output saved to: $OUTPUT_FILE ---" >&2

# --- Retry on failure ---
# When CAPPED=1, every cloud model shares the same quota pool — retrying
# against another :cloud model would just hit the same 403. But a LOCAL
# Ollama model bypasses the quota entirely, so try that first. If no
# local model is downloaded, fall back to the original "skip retry"
# behaviour so we don't loop on a guaranteed-fail cloud retry.
if [ "$CAPPED" = 1 ] && [ $EXIT_CODE -ne 0 ]; then
  LOCAL_FALLBACK=""
  if declare -f get_local_fallback_model >/dev/null 2>&1; then
    LOCAL_FALLBACK=$(get_local_fallback_model 2>/dev/null || true)
  fi
  if [ -n "$LOCAL_FALLBACK" ]; then
    echo "--- Ollama quota capped; retrying with local model: $LOCAL_FALLBACK ---" >&2
    RETRY_MODEL="$LOCAL_FALLBACK"
    CAPPED=0  # Local bypass — gate below should allow the retry.
  elif [ -n "${RETRY_MODEL:-}" ]; then
    echo "--- Ollama quota capped + no local model available, skipping retry ---" >&2
  fi
fi
if [ $EXIT_CODE -ne 0 ] && [ -n "${RETRY_MODEL:-}" ] && [ "$CAPPED" != 1 ]; then
  # Smart retry: if --retry is "auto", pick best alternative from performance log
  if [ "$RETRY_MODEL" = "auto" ] && [ -f "$LOG_FILE" ] && command -v jq &>/dev/null; then
    # Filter valid JSON lines only (malformed entries from crashes are skipped)
    AUTO_MODEL=$(grep -E '^\{' "$LOG_FILE" | jq -s --arg model "$MODEL" '
      [.[] | select(.model != $model and .status == "success" and (.tier == "tier1" or .tier == "tier2"))]
      | group_by(.model) | sort_by(-length) | .[0][0].model // empty
    ' 2>/dev/null)
    if [ -n "$AUTO_MODEL" ]; then
      RETRY_MODEL="$AUTO_MODEL"
      echo "--- Auto-selected retry model: $RETRY_MODEL (from performance log) ---"
    else
      # Fallback chain if no performance data
      RETRY_MODEL="${MODEL_WORKER_PRIMARY:-glm-5.1:cloud}"
      echo "--- No performance data, falling back to: $RETRY_MODEL ---"
    fi
  fi
  echo "--- Worker failed (exit $EXIT_CODE). Retrying with $RETRY_MODEL ---"
  CLAUDE_FLAGS=( -p "$TASK" --model "$RETRY_MODEL" --permission-mode bypassPermissions --system-prompt "$WORKER_PROMPT" --output-format text )
  [ -n "$MAX_TURNS" ] && CLAUDE_FLAGS+=(--max-turns "$MAX_TURNS")

  START_TIME=$(date +%s)
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  RETRY_OUTPUT_FILE="${OUTPUT_FILE%.log}.retry.log"
  set +e
  CLAUDECODE= \
  ANTHROPIC_BASE_URL="${OLLAMA_HOST}" \
  ANTHROPIC_AUTH_TOKEN="${OLLAMA_AUTH_TOKEN:-ollama}" \
  LAUNCH_MODE="ollama" \
  claude "${CLAUDE_FLAGS[@]}" 2>/dev/null | tee "$RETRY_OUTPUT_FILE"
  EXIT_CODE=${PIPESTATUS[0]}
  set -e
  # Cap-check the retry output too — in case the first attempt was a
  # transient error and the retry is what actually hits the quota.
  if declare -f check_ollama_quota >/dev/null 2>&1 && [ -s "$RETRY_OUTPUT_FILE" ]; then
    check_ollama_quota "$RETRY_OUTPUT_FILE" "spawn-worker-retry" || true
  fi

  END_TIME=$(date +%s)
  ELAPSED=$(( END_TIME - START_TIME ))
  GIT_AFTER=$(git diff --stat 2>/dev/null | tail -1)

  if [ -d "$(dirname "$LOG_FILE")" ] && command -v jq &>/dev/null; then
    jq -n -c \
      --arg ts "$TIMESTAMP" \
      --arg model "$RETRY_MODEL" \
      --arg task "${TASK:0:200}" \
      --arg status "$([ $EXIT_CODE -eq 0 ] && echo 'success' || echo 'fail')" \
      --arg tier "tier1_retry" \
      --argjson exit_code "$EXIT_CODE" \
      --argjson elapsed "$ELAPSED" \
      --arg git_diff "${GIT_AFTER:-no changes}" \
      '{"ts":$ts,"model":$model,"task":$task,"status":$status,"tier":$tier,"exit_code":$exit_code,"elapsed_s":$elapsed,"git_diff":$git_diff}' \
      >> "$LOG_FILE" 2>/dev/null
  fi
fi

exit $EXIT_CODE
