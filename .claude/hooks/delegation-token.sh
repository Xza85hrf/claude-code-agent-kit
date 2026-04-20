#!/bin/bash
# Hook: Delegation token creator
# PostToolUse hook (matcher: Bash, if: Bash(*mcp-cli.sh ollama*))
#
# After a successful mcp-cli.sh ollama chat/generate call, creates a time-limited
# delegation token. The Write/Edit enforcement hooks check for this token and
# allow writes when it exists (worker output integration).
#
# Token validity: 300 seconds (5 minutes) — generous for swarm patterns.
# Token is time-based, not single-use, so multiple writes after parallel
# ollama calls all succeed.

# Skip in ollama-primary mode (no delegation system)
source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || true
if [ -z "${LAUNCH_MODE:-}" ]; then
  for _lm_dir in "${CLAUDE_PROJECT_DIR:-.}" "$(git rev-parse --show-toplevel 2>/dev/null)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" "$HOME"; do
    [ -n "$_lm_dir" ] && [ -f "$_lm_dir/.claude/.launch-mode" ] && { LAUNCH_MODE=$(cat "$_lm_dir/.claude/.launch-mode" 2>/dev/null); break; }
  done
fi
[ "${LAUNCH_MODE:-opus}" = "ollama" ] && exit 0

TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.tokens"
TOKEN_FILE="$TOKEN_DIR/delegation.token"
LEGACY_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.delegation-token"

# Create token with current timestamp (both locations for backward compat)
mkdir -p "$TOKEN_DIR" 2>/dev/null
date +%s > "$TOKEN_FILE" 2>/dev/null
echo "300" > "$TOKEN_DIR/delegation.ttl" 2>/dev/null
date +%s > "$LEGACY_FILE" 2>/dev/null

# Plugin-compatible script resolution
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/.claude/scripts}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${KIT_ROOT:+${KIT_ROOT}/.claude/scripts}}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/scripts}"
# Emit event
bash "$SCRIPTS_DIR/event-log.sh" emit "delegation_token" "delegation-token.sh" '{}' 2>/dev/null &

exit 0
