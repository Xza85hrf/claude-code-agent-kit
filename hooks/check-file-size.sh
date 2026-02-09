#!/bin/bash
# Hook: Check file size before writing
# PreToolUse hook for Write - Warns when creating large files

# Read JSON input from stdin
INPUT=$(cat)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit if no content
if [ -z "$CONTENT" ]; then
  exit 0
fi

# Count lines
LINE_COUNT=$(echo "$CONTENT" | wc -l)

# Set limits based on file type
if echo "$FILE_PATH" | grep -qE "\.(md|markdown|txt|rst)$"; then
  LIMIT=1000
  TYPE="documentation"
elif echo "$FILE_PATH" | grep -qE "\.(test|spec)\.(js|ts|jsx|tsx|py)$"; then
  LIMIT=800
  TYPE="test"
else
  LIMIT=500
  TYPE="code"
fi

if [ "$LINE_COUNT" -gt "$LIMIT" ]; then
  jq -n --arg lines "$LINE_COUNT" --arg limit "$LIMIT" --arg type "$TYPE" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: ("Warning: Creating a " + $type + " file with " + $lines + " lines (limit: " + $limit + "). Consider splitting into smaller files for better maintainability.")
    }
  }'
fi

exit 0
