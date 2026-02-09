#!/bin/bash
# Hook: Recovery guidance for tool failures
# PostToolUseFailure - Fires when any tool execution fails.
# Provides contextual recovery advice and notes sibling cancellation risk.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')

case "$TOOL_NAME" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    if echo "$CMD" | grep -qE '^diff '; then
      GUIDANCE="diff returns exit 1 when files differ (not an error). Use 'diff ... || true' in parallel batches to prevent sibling cancellation."
    else
      GUIDANCE="Bash command failed. Sibling parallel calls may have been cancelled. Check the command and retry."
    fi
    ;;
  mcp__ollama__ollama_chat|mcp__ollama__ollama_generate)
    GUIDANCE="Ollama worker call failed. Delegation token was NOT created. Retry the delegation or check Ollama availability (curl http://localhost:11434/api/tags)."
    ;;
  WebFetch)
    GUIDANCE="URL fetch failed. For GitHub URLs, use 'gh api repos/owner/repo/contents/path' instead. Sibling calls may have been cancelled."
    ;;
  *)
    GUIDANCE="Tool '$TOOL_NAME' failed. Sibling parallel calls may have been cancelled. Retry the failed operation independently."
    ;;
esac

jq -n --arg ctx "$GUIDANCE" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUseFailure",
    additionalContext: ("Tool Failure Recovery: " + $ctx)
  }
}'

exit 0
