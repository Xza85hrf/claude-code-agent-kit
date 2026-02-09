#!/bin/bash
# Hook: Check for unclaimed tasks before allowing teammate to idle
# TeammateIdle hook — exit 0 = allow idle, exit 2 = keep working (stderr feedback)
#
# Reads team_name from stdin JSON. If unclaimed, unblocked tasks exist,
# prevents idle so the teammate picks up remaining work.
# Fails open: missing team context = allow idle.

INPUT=$(cat)

TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty' 2>/dev/null)

# No team name → not in a team context → allow idle
if [ -z "$TEAM_NAME" ]; then
  exit 0
fi

TASKS_DIR="$HOME/.claude/teams/$TEAM_NAME/tasks"

# No tasks directory → nothing to check → allow idle
if [ ! -d "$TASKS_DIR" ]; then
  exit 0
fi

# Check for pending, unclaimed, unblocked tasks via TaskList-compatible files
# Task files are JSON with status, owner, blockedBy fields
UNCLAIMED=0
for task_file in "$TASKS_DIR"/*.json; do
  [ -f "$task_file" ] || continue

  STATUS=$(jq -r '.status // empty' "$task_file" 2>/dev/null)
  OWNER=$(jq -r '.owner // empty' "$task_file" 2>/dev/null)
  BLOCKED_COUNT=$(jq -r '.blockedBy | length // 0' "$task_file" 2>/dev/null)

  # Pending + no owner + not blocked = unclaimed work
  if [ "$STATUS" = "pending" ] && [ -z "$OWNER" ] && [ "$BLOCKED_COUNT" = "0" ]; then
    UNCLAIMED=$((UNCLAIMED + 1))
  fi
done

if [ "$UNCLAIMED" -gt 0 ]; then
  echo "There are $UNCLAIMED unclaimed, unblocked task(s) remaining. Check TaskList and claim one before going idle." >&2
  exit 2
fi

# All tasks claimed or completed → allow idle
exit 0
