#!/bin/bash
# Hook: Delegation enforcement for Edit tool
# PreToolUse hook (matcher: Edit)
#
# When inserting >10 lines via new_string in a code file, BLOCKS the edit unless:
# 1. A valid delegation token exists (worker output integration), or
# 2. Ollama is unreachable (graceful fallback to advisory mode).
# Skips non-code files and short edits.

INPUT=$(cat)

# Extract file path and new_string
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')

# Skip if no file path or new_string
if [ -z "$FILE_PATH" ] || [ -z "$NEW_STRING" ]; then
  exit 0
fi

# Get file extension (lowercase)
EXT="${FILE_PATH##*.}"
EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

# Skip non-code files
case "$EXT" in
  md|json|yaml|yml|txt|rst|toml|cfg|ini|csv|xml|html|css|svg|lock|log)
    exit 0
    ;;
esac

# Count lines in new_string
LINE_COUNT=$(echo "$NEW_STRING" | wc -l)

# Only enforce if >10 lines
if [ "$LINE_COUNT" -le 10 ]; then
  exit 0
fi

# Check for delegation token (created by PostToolUse hook on ollama_chat/generate)
TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
TOKEN_FILE="$TOKEN_DIR/.delegation-token"
TOKEN_MAX_AGE=300  # 5 minutes

if [ -f "$TOKEN_FILE" ]; then
  TOKEN_TIME=$(cat "$TOKEN_FILE" 2>/dev/null)
  NOW=$(date +%s)
  TOKEN_AGE=$(( NOW - TOKEN_TIME ))
  if [ "$TOKEN_AGE" -le "$TOKEN_MAX_AGE" ]; then
    # Valid delegation token — worker output integration allowed
    exit 0
  fi
fi

# Log the violation
LOG_FILE="$TOKEN_DIR/delegation-violations.log"
if [ -d "$TOKEN_DIR" ]; then
  echo "$(date -Iseconds) EDIT $LINE_COUNT lines $FILE_PATH" >> "$LOG_FILE" 2>/dev/null
fi

# Check if Ollama is reachable (determines block vs warn)
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_UP=$(curl -s --max-time 2 "$OLLAMA_HOST/" 2>/dev/null)

if [ -n "$OLLAMA_UP" ]; then
  # Ollama is available but no delegation token — BLOCK the edit
  jq -n --arg lines "$LINE_COUNT" --arg path "$FILE_PATH" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      reason: ("BLOCKED: Inserting " + $lines + " lines of code into " + $path + " via Edit. Ollama workers are available — delegate code generation >10 lines to qwen3-coder-next:cloud (or qwen3-coder-next:latest if cloud unavailable) via ollama_chat, then integrate the result. The edit will be allowed automatically after delegation.")
    }
  }'
else
  # Ollama unreachable — fall back to advisory (allow with warning)
  jq -n --arg lines "$LINE_COUNT" --arg path "$FILE_PATH" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("DELEGATION WARNING (Ollama unreachable): Inserting " + $lines + " lines of code into " + $path + " via Edit. Workers unavailable, so proceeding — but normally this should be delegated to an Ollama worker.")
    }
  }'
fi

exit 0
