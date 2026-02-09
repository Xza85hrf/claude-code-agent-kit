#!/bin/bash
# Hook: Delegation token creator
# PostToolUse hook (matcher: mcp__ollama__ollama_chat|mcp__ollama__ollama_generate)
#
# After a successful ollama_chat or ollama_generate call, creates a time-limited
# delegation token. The Write/Edit enforcement hooks check for this token and
# allow writes when it exists (worker output integration).
#
# Token validity: 300 seconds (5 minutes) — generous for swarm patterns.
# Token is time-based, not single-use, so multiple writes after parallel
# ollama calls all succeed.

TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
TOKEN_FILE="$TOKEN_DIR/.delegation-token"

# Create token with current timestamp
if [ -d "$TOKEN_DIR" ]; then
  date +%s > "$TOKEN_FILE" 2>/dev/null
fi

exit 0
