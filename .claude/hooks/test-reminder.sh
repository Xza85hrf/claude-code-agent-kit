#!/bin/bash
# Hook: Remind to run tests after code changes
# PostToolUse hook for Edit

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Fallback: Serena tools use relative_path instead of file_path
if [ -z "$FILE_PATH" ]; then
  REL_PATH=$(echo "$INPUT" | jq -r '.tool_input.relative_path // empty' 2>/dev/null)
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

# Skip for test files themselves. The /test_X.py/ half of this regex must match
# test_X.py in any directory (e.g. .claude/scripts/test_synthesize_briefs.py),
# not only at the literal start of the path — otherwise we false-positive on
# every edit to an already-existing pytest test file that lives outside a
# tests/ directory.
if echo "$FILE_PATH" | grep -qE "\.(test|spec)\.(ts|tsx|js|jsx)$|_test\.(py|go)$|Test\.(java|kt)$|(^|/)test_[^/]+\.py$"; then
  exit 0
fi

# Skip for config files
if echo "$FILE_PATH" | grep -qE "(config|\.config)\.(ts|js)$|settings\.(py)$"; then
  exit 0
fi

# Determine test file patterns
BASE_NAME="${FILE_PATH%.*}"
EXT="${FILE_PATH##*.}"

# Check if test file exists (sibling or __tests__/ directory)
TEST_EXISTS=false
DIR_NAME=$(dirname "$FILE_PATH")
FILE_STEM=$(basename "$BASE_NAME")

case "$EXT" in
  ts|tsx|js|jsx)
    # Sibling test files
    [ -f "${BASE_NAME}.test.${EXT}" ] && TEST_EXISTS=true
    [ -f "${BASE_NAME}.spec.${EXT}" ] && TEST_EXISTS=true
    # __tests__/ directory (React/Jest convention)
    [ -f "${DIR_NAME}/__tests__/${FILE_STEM}.test.${EXT}" ] && TEST_EXISTS=true
    [ -f "${DIR_NAME}/__tests__/${FILE_STEM}.spec.${EXT}" ] && TEST_EXISTS=true
    # Also check parent __tests__/ (common for nested components)
    [ -f "$(dirname "$DIR_NAME")/__tests__/${FILE_STEM}.test.${EXT}" ] && TEST_EXISTS=true
    ;;
  py)
    # Sibling test files. Note the directory prefix — without it the -f check
    # runs against CWD, which was a latent bug that only happened to work when
    # the brain was cd'd into the same dir as the source file.
    [ -f "${BASE_NAME}_test.py" ] && TEST_EXISTS=true
    [ -f "${DIR_NAME}/test_${FILE_STEM}.py" ] && TEST_EXISTS=true
    # Stem normalization: module names can't contain '-', so foo-bar.py is
    # typically tested by test_foo_bar.py.
    _PY_NORM_STEM="${FILE_STEM//-/_}"
    [ -f "${DIR_NAME}/test_${_PY_NORM_STEM}.py" ] && TEST_EXISTS=true
    [ -f "${DIR_NAME}/${_PY_NORM_STEM}_test.py" ] && TEST_EXISTS=true
    # tests/ directory (both raw and normalized stems)
    [ -f "${DIR_NAME}/tests/test_${FILE_STEM}.py" ] && TEST_EXISTS=true
    [ -f "${DIR_NAME}/tests/test_${_PY_NORM_STEM}.py" ] && TEST_EXISTS=true
    [ -f "${DIR_NAME}/tests/${FILE_STEM}_test.py" ] && TEST_EXISTS=true
    [ -f "${DIR_NAME}/tests/${_PY_NORM_STEM}_test.py" ] && TEST_EXISTS=true
    unset _PY_NORM_STEM
    ;;
  go)
    [ -f "${BASE_NAME}_test.go" ] && TEST_EXISTS=true
    ;;
esac

if [ "$TEST_EXISTS" = true ]; then
  jq -n --arg file "$(basename "$FILE_PATH")" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("┌─ ACTION REQUIRED ─────────────────────────────\n│ WHAT: Code modified in " + $file + "\n│ DO:   Run related tests NOW to verify no regressions\n│ WHY:  Quality gate — changes without test verification risk silent breakage\n└───────────────────────────────────────────────")
    }
  }'
else
  jq -n --arg file "$(basename "$FILE_PATH")" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("┌─ ACTION REQUIRED ─────────────────────────────\n│ WHAT: No test file found for " + $file + "\n│ DO:   Create tests for this file before moving to next task\n│ WHY:  Quality gate — untested code is incomplete code\n└───────────────────────────────────────────────")
    }
  }'
fi

exit 0
