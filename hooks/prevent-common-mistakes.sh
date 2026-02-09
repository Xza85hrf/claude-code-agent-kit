#!/bin/bash
# Hook: Prevent common agent mistakes
# PreToolUse hook for WebFetch, Edit, Write

# Read JSON input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  "WebFetch")
    URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')

    # Warn about guessing GitHub paths without verification
    if echo "$URL" | grep -qE "raw\.githubusercontent\.com.*/(prompts|templates|examples|assets)/" ; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: "Path contains common assumption folder (prompts/templates/examples). Verify this path exists first using gh api or web search."
        }
      }'
      exit 0
    fi

    # Warn about very deep paths that are likely guessed
    DEPTH=$(echo "$URL" | tr '/' '\n' | wc -l)
    if [ "$DEPTH" -gt 10 ]; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: "Deep URL path detected - likely guessed. Verify repo structure before fetching."
        }
      }'
      exit 0
    fi
    ;;

  "Edit")
    OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty')

    # Check if old_string is very short (risky replacement)
    if [ "${#OLD_STRING}" -lt 10 ]; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: "Short old_string in Edit - may match multiple locations. Consider using more context for unique match."
        }
      }'
      exit 0
    fi
    ;;

  "Write")
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

    # Warn when overwriting important files
    IMPORTANT_FILES="package.json|Cargo.toml|requirements.txt|go.mod|Gemfile|.env|docker-compose|Dockerfile|Makefile"
    if echo "$FILE_PATH" | grep -qE "($IMPORTANT_FILES)$"; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: "Writing to important config/build file. Ensure Read was done first and changes are intentional."
        }
      }'
      exit 0
    fi
    ;;
esac

exit 0
