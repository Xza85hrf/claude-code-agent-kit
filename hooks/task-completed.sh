#!/bin/bash
# Hook: Check for merge conflicts before allowing task completion
# TaskCompleted hook — exit 0 = allow completion, exit 2 = block (stderr feedback)
#
# Reads task_id, task_subject from stdin JSON.
# Checks for unresolved merge conflicts in the working tree.
# Fails open: git errors = allow completion.

INPUT=$(cat)

TASK_ID=$(echo "$INPUT" | jq -r '.task_id // empty' 2>/dev/null)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty' 2>/dev/null)

# Check for files with merge conflicts (unmerged paths)
UNMERGED=$(git diff --name-only --diff-filter=U 2>/dev/null)

if [ -n "$UNMERGED" ]; then
  echo "Task '$TASK_SUBJECT' (id: $TASK_ID) cannot complete — unresolved merge conflicts:" >&2
  echo "$UNMERGED" >&2
  echo "Resolve conflicts before marking this task complete." >&2
  exit 2
fi

# Check staged files for leftover conflict markers
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

if [ -n "$STAGED_FILES" ]; then
  MARKERS=$(echo "$STAGED_FILES" | xargs grep -l '<<<<<<<\|>>>>>>>' 2>/dev/null)
  if [ -n "$MARKERS" ]; then
    echo "Task '$TASK_SUBJECT' (id: $TASK_ID) cannot complete — conflict markers found in staged files:" >&2
    echo "$MARKERS" >&2
    echo "Remove conflict markers before marking this task complete." >&2
    exit 2
  fi
fi

# Clean state → allow completion
exit 0
