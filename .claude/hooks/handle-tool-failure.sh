#!/bin/bash
# Hook: Recovery guidance for tool failures
# PostToolUseFailure - Fires when any tool execution fails.
# Provides contextual recovery advice and notes sibling cancellation risk.

source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || true
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")

case "$TOOL_NAME" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    if echo "$CMD" | grep -qE '^diff '; then
      GUIDANCE="diff returns exit 1 when files differ (not an error). Use 'diff ... || true' in parallel batches to prevent sibling cancellation."
    elif echo "$CMD" | grep -q 'mcp-cli.sh ollama'; then
      GUIDANCE="Ollama worker call failed (via mcp-cli.sh). Delegation token was NOT created. Retry the delegation or check Ollama availability (curl \$OLLAMA_HOST/api/tags)."
    else
      GUIDANCE="Bash command failed. Sibling parallel calls may have been cancelled. Check the command and retry."
    fi
    ;;
  WebFetch)
    GUIDANCE="URL fetch failed. For GitHub URLs, use 'gh api repos/owner/repo/contents/path' instead. Sibling calls may have been cancelled."
    ;;
  *)
    GUIDANCE="Tool '$TOOL_NAME' failed. Sibling parallel calls may have been cancelled. Retry the failed operation independently."
    ;;
esac

# Log failure to observations
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
mkdir -p "$PROJECT_DIR/.claude"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // empty' 2>/dev/null)
ENTRY="{\"ts\":\"$TS\",\"tool\":\"$TOOL_NAME\",\"file\":\"$FILE_PATH\",\"ok\":false,\"event\":\"failure\"}"
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null
if type -t state_append &>/dev/null; then
  state_append observation "$ENTRY"
else
  echo "$ENTRY" >> "$PROJECT_DIR/.claude/observations.jsonl" 2>/dev/null
fi

jq -n --arg c "Tool Failure Recovery: $GUIDANCE" '{systemMessage:$c}'

exit 0
