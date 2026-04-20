#!/bin/bash
# Hook: Create skill token when a skill is loaded
# PostToolUse hook (matcher: Skill)
#
# Creates .claude/.tokens/skill-{name}.token so skill-gate.sh can verify
# that the required skill was loaded before allowing domain file writes.
#
# Token TTL: 30 minutes (checked by skill-gate.sh)

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)

SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
[ -z "$SKILL_NAME" ] && exit 0

# Normalize skill name: strip plugin prefix (e.g., "agent-enhancement-kit:frontend-design-pro" → "frontend-design-pro")
SKILL_NAME=$(echo "$SKILL_NAME" | sed 's/.*://')

# Write timestamp token via state-manager (with file fallback)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null

if type -t state_set &>/dev/null; then
  state_set token "skill-${SKILL_NAME}" "$(date +%s)"
else
  TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.tokens"
  mkdir -p "$TOKEN_DIR" 2>/dev/null
  date +%s > "$TOKEN_DIR/skill-${SKILL_NAME}.token" 2>/dev/null
fi

# Publish skill-loaded event for subscribers
[[ -f "$_LIB_DIR/event-bus.sh" ]] && source "$_LIB_DIR/event-bus.sh" 2>/dev/null
if type -t event_publish &>/dev/null; then
  event_publish "skill" "{\"name\":\"${SKILL_NAME}\",\"action\":\"loaded\",\"ts\":$(date +%s)}" 2>/dev/null
fi

exit 0
