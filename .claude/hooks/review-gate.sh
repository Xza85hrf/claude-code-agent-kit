#!/bin/bash
set -euo pipefail
#
# review-gate.sh - Claude Code PreToolUse Hook
# Blocks git push for branches with >100 lines changed vs base branch
# unless an audit-pass token exists.
#

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Read JSON from stdin and extract the command
INPUT_JSON=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT_JSON" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# If no command, allow
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Skip if SKIP_REVIEW_GATE is set
if [ "${SKIP_REVIEW_GATE:-}" = "1" ]; then
  exit 0
fi

# Only trigger on git push commands
if ! echo "$COMMAND" | grep -qE 'git\s+push\b'; then
  exit 0
fi

# Skip dry-run and help
if echo "$COMMAND" | grep -qE '(--dry-run|-n|--help)'; then
  exit 0
fi

# Get current branch
CURRENT_BRANCH=$(cd "$PROJECT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ]; then
  exit 0
fi

# Determine base branch (try main, fallback to master)
if cd "$PROJECT_DIR" && git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
  BASE_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
  BASE_BRANCH="master"
else
  exit 0
fi

# Skip if pushing main/master itself
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  exit 0
fi

# Get the base commit for comparison
BASE_COMMIT=$(cd "$PROJECT_DIR" && git merge-base "$BASE_BRANCH" "$CURRENT_BRANCH" 2>/dev/null || echo "")
if [ -z "$BASE_COMMIT" ]; then
  exit 0
fi

# Count lines changed
DIFF_STAT=$(cd "$PROJECT_DIR" && git diff --stat "$BASE_COMMIT".."$CURRENT_BRANCH" 2>/dev/null | tail -1 || echo "")
if [ -z "$DIFF_STAT" ]; then
  exit 0
fi

INSERTIONS=$(echo "$DIFF_STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DELETIONS=$(echo "$DIFF_STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
TOTAL_CHANGED=$(echo "${INSERTIONS:-0} + ${DELETIONS:-0}" | bc 2>/dev/null || echo "0")

# If less than 100 lines, allow silently
if [ "${TOTAL_CHANGED:-0}" -lt 100 ] 2>/dev/null; then
  exit 0
fi

# Check for token file (new location first, then legacy)
BRANCH_TOKEN_NAME=$(echo "$CURRENT_BRANCH" | tr '/' '-')
TOKEN_FOUND=false

for TOKEN_FILE in "$PROJECT_DIR/.claude/.tokens/audit-pass-${BRANCH_TOKEN_NAME}.token" "$PROJECT_DIR/.claude/.audit-pass-${BRANCH_TOKEN_NAME}"; do
  if [ -f "$TOKEN_FILE" ]; then
    TOKEN_AGE=$(($(date +%s) - $(stat -c %Y "$TOKEN_FILE" 2>/dev/null || echo "0")))
    if [ "$TOKEN_AGE" -lt 14400 ]; then
      jq -n --arg b "$CURRENT_BRANCH" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:review-gate] Audit token valid for " + $b)}}'
      exit 0
    fi
    rm -f "$TOKEN_FILE"
  fi
done

# No valid token — block push
jq -n --arg b "$CURRENT_BRANCH" --arg l "$TOTAL_CHANGED" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("BLOCKED[review-gate]: " + $b + " ~" + $l + "L changed (>100) | DO: Run /audit --diff " + $b)}}'

exit 0
