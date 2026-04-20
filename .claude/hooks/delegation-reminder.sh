#!/bin/bash
# Hook: Graduated delegation enforcement for Write and Edit tools
# PreToolUse hook (matcher: Write, Edit)
#
# GRADUATED ENFORCEMENT (ADR-007, hardened per harness-design research):
# - ≤THRESHOLD lines: Silent allow
# - THRESHOLD < lines ≤ BLOCK_THRESHOLD: Advisory on first, BLOCK on second
# - >BLOCK_THRESHOLD lines: BLOCK unless delegation token exists

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
source "$_LIB_DIR/env-defaults.sh" 2>/dev/null || true
# shellcheck source=../lib/skill-routes.sh
source "$_LIB_DIR/skill-routes.sh" 2>/dev/null || true

DELEGATION_MODE="${DELEGATION_MODE:-graduated}"
# Track where the effective thresholds come from so block messages can
# explain "why" without the user having to diff settings.json against the
# live environment. Resolution order (last write wins): defaults -> env
# (settings.json) -> budget-override file.
if [ -n "${DELEGATION_THRESHOLD:-}" ] || [ -n "${DELEGATION_BLOCK_THRESHOLD:-}" ]; then
  THRESHOLD_SOURCE="settings.json (env)"
else
  THRESHOLD_SOURCE="defaults"
fi
DELEGATION_THRESHOLD="${DELEGATION_THRESHOLD:-10}"
DELEGATION_BLOCK_THRESHOLD="${DELEGATION_BLOCK_THRESHOLD:-50}"

# Budget-aware threshold override — silently overrides settings.json.
# This is deliberate (usage-aware enforcement per check-usage.sh) but it's
# the #1 source of "why did this block, my settings say 200?" confusion.
BUDGET_THRESHOLDS="${CLAUDE_PROJECT_DIR:-.}/.claude/.budget-thresholds.env"
if [ -f "$BUDGET_THRESHOLDS" ]; then
  source "$BUDGET_THRESHOLDS"
  THRESHOLD_SOURCE="budget-override (.claude/.budget-thresholds.env)"
fi

# Skip in ollama-primary mode (shared detection)
is_ollama_launch_mode && exit 0
if echo "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" | grep -qE '^[a-z0-9-]+:(cloud|local|[0-9]+b)$'; then
  exit 0
fi

if [ "$DELEGATION_MODE" = "advisory-only" ]; then
  DELEGATION_BLOCK_THRESHOLD=999999
fi

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)

# Detect tool: Write uses 'content', Edit uses 'new_string'
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ "$TOOL_NAME" = "Edit" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
  VERB="Editing"
  VERB_UC="EDIT"
else
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
  VERB="Writing"
  VERB_UC="WRITE"
fi

[ -z "$FILE_PATH" ] || [ -z "$CONTENT" ] && exit 0

# Skip non-code files (shared extension check)
EXT="${FILE_PATH##*.}"
if is_noncode_extension "$EXT"; then
  exit 0
fi
# Allow skill/template markdown through, skip other markdown
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
if [ "$EXT_LOWER" = "md" ]; then
  case "$FILE_PATH" in
    */skills/*|*/templates/*) ;;
    *) exit 0 ;;
  esac
fi

LINE_COUNT=$(echo "$CONTENT" | wc -l)
[ "$LINE_COUNT" -le "$DELEGATION_THRESHOLD" ] && exit 0

# Session violation tracking (state-manager with fallback)
TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
LOG_FILE="$TOKEN_DIR/delegation-violations.log"
mkdir -p "$TOKEN_DIR" 2>/dev/null

# _LIB_DIR already set at top of file
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null

if type -t state_get &>/dev/null; then
  COUNT=$(state_get session delegation-count 2>/dev/null || echo "0")
  COUNT=$((COUNT + 1))
  state_set session delegation-count "$COUNT"
else
  COUNTER_FILE="$TOKEN_DIR/.session-delegation-count"
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
  COUNT=$((COUNT + 1))
  echo "$COUNT" > "$COUNTER_FILE"
fi

# Log violation
if [ -d "$TOKEN_DIR" ]; then
  SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/.claude/scripts}"
  SCRIPTS_DIR="${SCRIPTS_DIR:-${KIT_ROOT:+${KIT_ROOT}/.claude/scripts}}"
  SCRIPTS_DIR="${SCRIPTS_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/scripts}"
  echo "$(date -Iseconds) ${VERB_UC}[graduated] ${LINE_COUNT}lines $FILE_PATH (violation #$COUNT)" >> "$LOG_FILE" 2>/dev/null
  bash "$SCRIPTS_DIR/event-log.sh" emit "delegation_violation" "delegation-reminder.sh" \
    "{\"lines\":$LINE_COUNT,\"file\":\"$(basename "$FILE_PATH")\",\"count\":$COUNT,\"tool\":\"$TOOL_NAME\",\"tier\":\"$([ $LINE_COUNT -gt $DELEGATION_BLOCK_THRESHOLD ] && echo block || echo advisory)\"}" 2>/dev/null &
fi

# Helper: check delegation token
check_token() {
  if type -t state_exists &>/dev/null; then
    state_exists token delegation && return 0
  else
    for TOKEN_FILE in "$TOKEN_DIR/.tokens/delegation.token" "$TOKEN_DIR/.delegation-token"; do
      if [ -f "$TOKEN_FILE" ]; then
        TOKEN_TIME=$(cat "$TOKEN_FILE" 2>/dev/null)
        NOW=$(date +%s)
        TOKEN_AGE=$(( NOW - TOKEN_TIME ))
        [ "$TOKEN_AGE" -le 300 ] && return 0
      fi
    done
  fi
  return 1
}

# BLOCK TIER: >BLOCK_THRESHOLD lines
if [ "$LINE_COUNT" -gt "$DELEGATION_BLOCK_THRESHOLD" ]; then
  check_token && exit 0

  # OLLAMA_HOST resolved by env-defaults.sh at the top.
  # A `capped` status is set by mcp-cli.sh when Ollama returns a weekly-
  # usage-limit or high-volume error. Workers are technically reachable
  # (/api/tags still 200s) but cannot actually chat, so we treat capped
  # identically to offline — downgrade BLOCK tier to allow-with-warning
  # instead of deadlocking the brain against a worker pool that can't help.
  _CACHED_STATUS=$(cat "${CLAUDE_PROJECT_DIR:-.}/.claude/.worker-status" 2>/dev/null || echo "unknown")
  if [ "$_CACHED_STATUS" = "offline" ] || [ "$_CACHED_STATUS" = "capped" ]; then
    OLLAMA_UP=""
  else
    OLLAMA_UP=$(curl -s --connect-timeout 3 --max-time 3 "$OLLAMA_HOST/" 2>/dev/null)
  fi

  if [ -n "$OLLAMA_UP" ]; then
    BASENAME=$(basename "$FILE_PATH")
    jq -n --arg lines "$LINE_COUNT" --arg path "$FILE_PATH" --arg name "$BASENAME" \
      --arg count "$COUNT" --arg thresh "$DELEGATION_BLOCK_THRESHOLD" \
      --arg spawn "$SCRIPTS_DIR/spawn-worker.sh" --arg verb "$VERB" \
      --arg source "$THRESHOLD_SOURCE" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ BLOCKED — " + $verb + " " + $lines + " lines to " + $path + " (violation #" + $count + ")\n\nCode >" + $thresh + " lines MUST be delegated. You are the BRAIN, not the typist.\n\nThreshold source: " + $source + "\n\nDO THIS INSTEAD:\n  Tier 1a: Agent tool (subagent_type=worker) — auto-creates delegation token\n  Tier 1b: bash " + $spawn + " \"glm-5.1:cloud\" \"task\" --engine codex (shell/DevOps)\n  Tier 2:  mcp-cli.sh ollama chat glm-5.1:cloud\n\nAfter delegation, your " + $verb + " will be auto-allowed via delegation token.")
      }
    }'
    exit 0
  else
    # No `local` — this block runs at script scope, not in a function.
    if [ "$_CACHED_STATUS" = "capped" ]; then
      _REASON="Ollama quota capped"
    else
      _REASON="Ollama unreachable"
    fi
    jq -n --arg lines "$LINE_COUNT" --arg path "$FILE_PATH" --arg count "$COUNT" --arg verb "$VERB" \
      --arg source "$THRESHOLD_SOURCE" --arg reason "$_REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        additionalContext: ("⚠️ DELEGATION OVERRIDE (" + $reason + "): " + $verb + " " + $lines + " lines to " + $path + " (violation #" + $count + "). Threshold source: " + $source + ". Workers unavailable — allowing, but this MUST be delegated when workers are online.")
      }
    }'
    exit 0
  fi
fi

# ADVISORY TIER: THRESHOLD < lines ≤ BLOCK_THRESHOLD
check_token && exit 0
BASENAME=$(basename "$FILE_PATH")

if [ "$COUNT" -le 1 ]; then
  jq -n --arg lines "$LINE_COUNT" --arg path "$FILE_PATH" --arg name "$BASENAME" \
    --arg count "$COUNT" --arg thresh "$DELEGATION_THRESHOLD" --arg verb "$VERB" \
    --arg source "$THRESHOLD_SOURCE" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("┌─ ACTION REQUIRED ─────────────────────────────\n│ WHAT: " + $verb + " " + $lines + " lines to " + $name + " (violation " + $count + "/1)\n│ DO:   Delegate via: Agent tool (worker) OR ollama_chat model=glm-5.1:cloud\n│       Shell/DevOps? → spawn-worker --engine codex (Tier 1b)\n│ WHY:  Code >" + $thresh + " lines must be delegated. NEXT violation = BLOCK.\n│ SRC:  threshold from " + $source + "\n└───────────────────────────────────────────────")
    }
  }'
else
  jq -n --arg lines "$LINE_COUNT" --arg path "$FILE_PATH" --arg name "$BASENAME" \
    --arg count "$COUNT" --arg thresh "$DELEGATION_THRESHOLD" --arg spawn "$SCRIPTS_DIR/spawn-worker.sh" --arg verb "$VERB" \
    --arg source "$THRESHOLD_SOURCE" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("⛔ BLOCKED — " + $verb + " " + $lines + " lines to " + $path + " (violation #" + $count + ")\n\nAdvisory limit reached. Code >" + $thresh + " lines MUST be delegated.\n\nThreshold source: " + $source + "\n\nDO INSTEAD:\n  Tier 1a: Agent tool (subagent_type=worker) — auto-creates delegation token\n  Tier 1b: bash " + $spawn + " \"glm-5.1:cloud\" \"task\" --engine codex (shell/DevOps)\n  Tier 2:  mcp-cli.sh ollama chat glm-5.1:cloud\n\nAfter delegation, your " + $verb + " will be auto-allowed via delegation token.")
    }
  }'
fi

exit 0
