#!/bin/bash
# Hook: Prevent common agent mistakes
# PreToolUse hook for WebFetch, Edit, Write

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

case "$TOOL_NAME" in
  "WebFetch")
    URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null)

    # Warn about guessing GitHub paths without verification
    if echo "$URL" | grep -qE "raw\.githubusercontent\.com.*/(prompts|templates|examples|assets)/" ; then
      jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:"[HOOK:mistake] Guessed GitHub path (prompts/templates/examples) | DO: Verify with gh api or web search first"}}'
      exit 0
    fi

    # Warn about very deep paths that are likely guessed
    DEPTH=$(echo "$URL" | tr '/' '\n' | wc -l)
    if [ "$DEPTH" -gt 10 ]; then
      jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:"[HOOK:mistake] Deep URL path (likely guessed) | DO: Verify repo structure before fetching"}}'
      exit 0
    fi
    ;;

  "Edit")
    OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)

    # Check if old_string is very short (risky replacement)
    if [ "${#OLD_STRING}" -lt 10 ]; then
      jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:"[HOOK:mistake] Short old_string (<10 chars) | DO: Add more surrounding context for unique match"}}'
      exit 0
    fi
    ;;

  "Write")
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

    # Warn when overwriting important files
    IMPORTANT_FILES="package.json|Cargo.toml|requirements.txt|go.mod|Gemfile|.env|docker-compose|Dockerfile|Makefile"
    if echo "$FILE_PATH" | grep -qE "($IMPORTANT_FILES)$"; then
      FNAME=$(basename "$FILE_PATH")
      jq -n --arg f "$FNAME" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:mistake] Writing config file " + $f + " | DO: Read file first, verify changes are intentional")}}'
      exit 0
    fi

    # Warn about creating files that may duplicate existing ones
    if [ -n "$FILE_PATH" ] && echo "$FILE_PATH" | grep -qE "\.(ts|tsx|js|jsx|py)$"; then
      FILE_BASE=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
      FILE_DIR=$(dirname "$FILE_PATH")
      if [ -d "$FILE_DIR" ]; then
        # Check for similarly named files in the same directory
        SIMILAR=$(find "$FILE_DIR" -maxdepth 1 -name "${FILE_BASE}*" -not -name "$(basename "$FILE_PATH")" 2>/dev/null | head -3)
        if [ -n "$SIMILAR" ]; then
          SIMILAR_SHORT=$(echo "$SIMILAR" | tr '\n' ', ' | head -c 100)
          jq -n --arg s "$SIMILAR_SHORT" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:mistake] Similar files exist: " + $s + " | DO: Verify not a duplicate")}}'
          exit 0
        fi
      fi
    fi
    ;;
esac

exit 0
