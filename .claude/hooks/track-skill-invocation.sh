#!/bin/bash
# Hook: Track Skill() invocations for session compliance auditing
# Event: PostToolUse:Skill
# Logs each skill invocation to .claude/.session-skill-log
# Read by stop-skill-check.sh at session end to verify skill compliance.

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)

# Extract skill name from tool input
SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
[ -z "$SKILL_NAME" ] && exit 0

LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.session-skill-log"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Source state-manager
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null

# Log to state-manager + session skill log (stop-skill-check reads the log file)
if type -t state_append &>/dev/null; then
  state_append observation "{\"ts\":\"$TIMESTAMP\",\"event\":\"skill_invocation\",\"skill\":\"$SKILL_NAME\"}"
fi
# Always write to session log too (read by stop-skill-check.sh)
echo "${TIMESTAMP}|${SKILL_NAME}" >> "$LOG_FILE" 2>/dev/null

exit 0
