#!/bin/bash
# Hook: Skill compliance check + session handoff before stopping
# Stop hook — fires when the agent is about to finish responding
#
# 1. Reads .session-skill-log to check which skills were actually loaded
# 2. Warns if expected skills were skipped based on session activity
# 3. Outputs verification checklist
# 4. Generates session handoff document for cross-session continuity

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Source shared libs (with fallback)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
[[ -f "$_LIB_DIR/hook-protocol.sh" ]] && source "$_LIB_DIR/hook-protocol.sh" 2>/dev/null
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null

# Guard against infinite loops — if this Stop hook triggers another stop, bail out
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

# --- Skill compliance audit ---
SKILL_LOG="$PROJECT_DIR/.claude/.session-skill-log"
LOADED_SKILLS=""
if [ -f "$SKILL_LOG" ]; then
  LOADED_SKILLS=$(awk -F'|' '{print $2}' "$SKILL_LOG" 2>/dev/null | sort -u | tr '\n' ' ')
fi

# Check session activity to determine expected skills
CODE_MODIFIED=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java|rb)$' | head -5)
CODE_LINES_CHANGED=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
HAS_COMMIT=$(git -C "$PROJECT_DIR" log --oneline -1 --since="1 hour ago" 2>/dev/null)

SKILL_WARNINGS=""

# If significant code was written, TDD should have been loaded
if [ "$CODE_LINES_CHANGED" -gt 50 ]; then
  if ! echo "$LOADED_SKILLS" | grep -q "test-driven-development"; then
    SKILL_WARNINGS="${SKILL_WARNINGS}\n  - test-driven-development: ${CODE_LINES_CHANGED} lines changed without TDD skill"
  fi
fi

# If security-related files were touched, security-review should have been loaded
SECURITY_FILES=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -iE '(auth|token|password|session|permission|secret|crypto|security)' | head -3)
if [ -n "$SECURITY_FILES" ]; then
  if ! echo "$LOADED_SKILLS" | grep -q "security-review"; then
    SKILL_WARNINGS="${SKILL_WARNINGS}\n  - security-review: Security-related files modified ($(echo "$SECURITY_FILES" | tr '\n' ', '))"
  fi
fi

# If frontend files were touched, frontend skill should have been loaded
FRONTEND_FILES=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -E '\.(tsx|jsx|css|scss|html)$' | head -3)
if [ -n "$FRONTEND_FILES" ]; then
  if ! echo "$LOADED_SKILLS" | grep -qE "(frontend-engineering|frontend-design-pro)"; then
    SKILL_WARNINGS="${SKILL_WARNINGS}\n  - frontend-engineering: Frontend files modified without frontend skill loaded"
  fi
fi

# If bug-fix related commits, systematic-debugging should have been loaded
BUG_COMMITS=$(git -C "$PROJECT_DIR" log --oneline --since="1 hour ago" 2>/dev/null | grep -iE '(fix|bug|patch|resolve)' | head -3)
if [ -n "$BUG_COMMITS" ]; then
  if ! echo "$LOADED_SKILLS" | grep -q "systematic-debugging"; then
    SKILL_WARNINGS="${SKILL_WARNINGS}\n  - systematic-debugging: Bug-fix commits without debugging skill loaded"
  fi
fi

# Build checklist as string (Stop events require {systemMessage:...} JSON)
CHECKLIST="── COMPLETION CHECKLIST ──"

if [ -n "$LOADED_SKILLS" ]; then
  SKILL_COUNT=$(echo "$LOADED_SKILLS" | wc -w | tr -d ' ')
  CHECKLIST="$CHECKLIST\nSkills loaded this session (${SKILL_COUNT}): ${LOADED_SKILLS}"
fi

if [ -n "$SKILL_WARNINGS" ]; then
  CHECKLIST="$CHECKLIST\nSKILL COMPLIANCE WARNINGS:$(echo -e "$SKILL_WARNINGS")"
fi

if [ -n "$CODE_MODIFIED" ]; then
  CHECKLIST="$CHECKLIST\nCode files modified: $(echo "$CODE_MODIFIED" | tr '\n' ', ') → Did you run tests?"
fi

if [ -n "$HAS_COMMIT" ]; then
  CHECKLIST="$CHECKLIST\nRecent commit: $HAS_COMMIT → Was it verified?"
fi

if type -t state_get &>/dev/null; then
  VIOLATION_COUNT=$(state_get session delegation-count 2>/dev/null || echo "0")
else
  VIOLATION_COUNT=$(cat "${PROJECT_DIR}/.claude/.session-delegation-count" 2>/dev/null || echo "0")
fi
if [ "$VIOLATION_COUNT" -gt 0 ]; then
  CHECKLIST="$CHECKLIST\nDELEGATION COMPLIANCE: $VIOLATION_COUNT violation(s)"
fi

CHECKLIST="$CHECKLIST\n── END CHECKLIST ──"

# Output via hook_signal (with raw jq fallback)
if type -t hook_signal_multi &>/dev/null; then
  hook_signal_multi Stop allow stop-skill-check "Session completion audit" "$(echo -e "$CHECKLIST")"
else
  jq -n --arg c "$(echo -e "$CHECKLIST")" '{systemMessage: $c}'
fi

# --- Session handoff ---
HANDOFF_DIR="$PROJECT_DIR/docs/session-handoffs"
mkdir -p "$HANDOFF_DIR" 2>/dev/null

TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
HANDOFF_FILE="$HANDOFF_DIR/$TIMESTAMP.md"

BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
SESSION_COMMITS=$(git -C "$PROJECT_DIR" log --oneline --since="2 hours ago" 2>/dev/null)
UNSTAGED=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null)
STAGED=$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null)

# Worker performance summary (last 20 entries)
PERF_LOG="$PROJECT_DIR/.claude/worker-performance.log"
WORKER_SUMMARY=""
if [ -f "$PERF_LOG" ] && command -v jq &>/dev/null; then
  WORKER_SUMMARY=$(tail -20 "$PERF_LOG" | jq -s '
    group_by(.model) | map({
      model: .[0].model,
      total: length,
      success: [.[] | select(.status=="success")] | length
    }) | .[] | "\(.model): \(.success)/\(.total) success"
  ' 2>/dev/null | tr -d '"' | sed 's/^/- /')
fi

cat << EOF > "$HANDOFF_FILE"
### Session: $TIMESTAMP
**Branch:** \`$BRANCH\`

**Skills loaded:** ${LOADED_SKILLS:-_None_}

**Commits this session:**
$(if [ -n "$SESSION_COMMITS" ]; then echo "$SESSION_COMMITS" | sed 's/^/- /'; else echo "_None_"; fi)

**Unstaged changes:**
$(if [ -n "$UNSTAGED" ]; then echo "$UNSTAGED" | sed 's/^/- /'; else echo "_None_"; fi)

**Staged (uncommitted):**
$(if [ -n "$STAGED" ]; then echo "$STAGED" | sed 's/^/- /'; else echo "_None_"; fi)

**Worker delegation summary:**
$(if [ -n "$WORKER_SUMMARY" ]; then echo "$WORKER_SUMMARY"; else echo "_No delegations this session_"; fi)
EOF

echo "" >&2
echo "Session handoff saved: $HANDOFF_FILE" >&2

# Clean up session skill log (will be recreated next session)
# Don't delete — leave for debugging. It's cleared on SessionStart by session-start.sh.

exit 0
