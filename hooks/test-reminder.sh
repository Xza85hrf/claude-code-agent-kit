#!/bin/bash
# Hook: Remind to run tests after code changes
# PostToolUse hook for Edit

# Read JSON input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Fallback: Serena tools use relative_path instead of file_path
if [ -z "$FILE_PATH" ]; then
  REL_PATH=$(echo "$INPUT" | jq -r '.tool_input.relative_path // empty')
  if [ -n "$REL_PATH" ]; then
    FILE_PATH="${CLAUDE_PROJECT_DIR:-.}/$REL_PATH"
  fi
fi

# Exit if no file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip for non-code files
if ! echo "$FILE_PATH" | grep -qE "\.(ts|tsx|js|jsx|py|rb|go|rs|java|kt|swift)$"; then
  exit 0
fi

# Skip for test files themselves
if echo "$FILE_PATH" | grep -qE "\.(test|spec)\.(ts|tsx|js|jsx)$|_test\.(py|go)$|Test\.(java|kt)$"; then
  exit 0
fi

# Skip for config files
if echo "$FILE_PATH" | grep -qE "(config|\.config)\.(ts|js)$|settings\.(py)$"; then
  exit 0
fi

# Determine test file patterns
BASE_NAME="${FILE_PATH%.*}"
EXT="${FILE_PATH##*.}"

# Check if test file exists
TEST_EXISTS=false
case "$EXT" in
  ts|tsx|js|jsx)
    [ -f "${BASE_NAME}.test.${EXT}" ] && TEST_EXISTS=true
    [ -f "${BASE_NAME}.spec.${EXT}" ] && TEST_EXISTS=true
    ;;
  py)
    [ -f "${BASE_NAME}_test.py" ] && TEST_EXISTS=true
    [ -f "test_${BASE_NAME##*/}.py" ] && TEST_EXISTS=true
    ;;
  go)
    [ -f "${BASE_NAME}_test.go" ] && TEST_EXISTS=true
    ;;
esac

if [ "$TEST_EXISTS" = true ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: "Code modified. Remember to run related tests to verify changes."
    }
  }'
else
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: "No test file found for this code file. Consider adding tests for coverage."
    }
  }'
fi

exit 0
