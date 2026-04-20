#!/bin/bash
# Hook: StopFailure — fires when turn ends due to API error
# Logs the failure, updates workstream state, provides recovery guidance.
# v2.1.78+ event. Distinct from Stop (which fires on normal completion).

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Extract error details from the event
ERROR_TYPE=$(echo "$INPUT" | jq -r '.error.type // "unknown"' 2>/dev/null || echo "unknown")
ERROR_MSG=$(echo "$INPUT" | jq -r '.error.message // "No details"' 2>/dev/null || echo "No details")

# Log to observations via state-manager
mkdir -p "$PROJECT_DIR/.claude"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ENTRY="{\"ts\":\"$TS\",\"event\":\"stop_failure\",\"error_type\":\"$ERROR_TYPE\",\"ok\":false}"
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null
if type -t state_append &>/dev/null; then
  state_append observation "$ENTRY"
else
  echo "$ENTRY" >> "$PROJECT_DIR/.claude/observations.jsonl" 2>/dev/null
fi

# Update workstream state if tracker exists
STATE_FILE="$PROJECT_DIR/.claude/.workstream-state"
if [ -f "$STATE_FILE" ]; then
  echo "error" > "$STATE_FILE" 2>/dev/null
fi

# Build recovery guidance based on error type
case "$ERROR_TYPE" in
  rate_limit|overloaded)
    GUIDANCE="Rate limited. Wait 30-60s before retrying. Check /check-usage for quota status. Consider switching to budget mode or lower effort."
    ;;
  authentication|auth*)
    GUIDANCE="Auth failure. Run 'claude auth login' to refresh credentials. If using API key, verify ANTHROPIC_API_KEY is set."
    ;;
  invalid_request*)
    GUIDANCE="Invalid request — possibly context too large or malformed tool call. Try /compact to reduce context, then retry."
    ;;
  *)
    GUIDANCE="Turn ended due to API error ($ERROR_TYPE). Retry the last action. If persistent, check API status."
    ;;
esac

jq -n --arg ctx "$GUIDANCE" '{systemMessage: ("API Error Recovery: " + $ctx)}'
