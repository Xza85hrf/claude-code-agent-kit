#!/bin/bash
# Hook: Delegation enforcement for Serena MCP tools
# PreToolUse hook (matcher: mcp__plugin_serena_serena__create_text_file and siblings)
#
# Prevents Serena tools from bypassing Write/Edit delegation enforcement.
# Same three-tier logic as delegation-reminder-write.sh:
# 1. Valid delegation token → allow (worker output integration)
# 2. No token + Ollama up → BLOCK
# 3. No token + Ollama down → warn but allow (graceful fallback)

INPUT=$(cat)

# Get tool name to determine which field has the content
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Extract content based on tool type
case "$TOOL_NAME" in
  *create_text_file)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    ;;
  *replace_content)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.repl // empty')
    ;;
  *)
    # replace_symbol_body, insert_after_symbol, insert_before_symbol
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.body // empty')
    ;;
esac

RELATIVE_PATH=$(echo "$INPUT" | jq -r '.tool_input.relative_path // empty')

# Skip if no content or path
if [ -z "$CONTENT" ] || [ -z "$RELATIVE_PATH" ]; then
  exit 0
fi

# Get file extension (lowercase)
EXT="${RELATIVE_PATH##*.}"
EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

# Skip non-code files
case "$EXT" in
  md|json|yaml|yml|txt|rst|toml|cfg|ini|csv|xml|html|css|svg|lock|log)
    exit 0
    ;;
esac

# Count lines in content
LINE_COUNT=$(echo "$CONTENT" | wc -l)

# Only enforce if >10 lines
if [ "$LINE_COUNT" -le 10 ]; then
  exit 0
fi

# Check for delegation token
TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
TOKEN_FILE="$TOKEN_DIR/.delegation-token"
TOKEN_MAX_AGE=300  # 5 minutes

if [ -f "$TOKEN_FILE" ]; then
  TOKEN_TIME=$(cat "$TOKEN_FILE" 2>/dev/null)
  NOW=$(date +%s)
  TOKEN_AGE=$(( NOW - TOKEN_TIME ))
  if [ "$TOKEN_AGE" -le "$TOKEN_MAX_AGE" ]; then
    exit 0  # Valid delegation token — worker output integration allowed
  fi
fi

# Log the violation
TOOL_SHORT="${TOOL_NAME##*__}"
LOG_FILE="$TOKEN_DIR/delegation-violations.log"
if [ -d "$TOKEN_DIR" ]; then
  echo "$(date -Iseconds) SERENA:$TOOL_SHORT $LINE_COUNT lines $RELATIVE_PATH" >> "$LOG_FILE" 2>/dev/null
fi

# Check if Ollama is reachable
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_UP=$(curl -s --max-time 2 "$OLLAMA_HOST/" 2>/dev/null)

if [ -n "$OLLAMA_UP" ]; then
  # Ollama available, no token — BLOCK
  jq -n --arg lines "$LINE_COUNT" --arg path "$RELATIVE_PATH" --arg tool "$TOOL_SHORT" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      reason: ("BLOCKED: Serena tool " + $tool + " writing " + $lines + " lines to " + $path + ". Ollama workers are available — delegate code generation >10 lines to qwen3-coder-next:cloud (or qwen3-coder-next:latest if cloud unavailable) via ollama_chat, then use Write/Edit to integrate the result. Do NOT bypass delegation via Serena tools.")
    }
  }'
else
  # Ollama unreachable — warn but allow
  jq -n --arg lines "$LINE_COUNT" --arg path "$RELATIVE_PATH" --arg tool "$TOOL_SHORT" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("DELEGATION WARNING (Ollama unreachable): Serena tool " + $tool + " writing " + $lines + " lines to " + $path + ". Workers unavailable, so proceeding — but normally delegate >10 lines to Ollama workers.")
    }
  }'
fi

exit 0
