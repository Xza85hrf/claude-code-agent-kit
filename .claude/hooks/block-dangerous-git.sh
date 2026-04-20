#!/bin/bash
set -euo pipefail
# Hook: Block dangerous git commands
# PreToolUse hook for Bash - Prevents destructive operations without explicit approval
# Bypass: create .claude/.git-destructive-bypass with timestamp (5-min TTL)

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Exit if no command
[ -z "$COMMAND" ] && exit 0

# Strip leading env var assignments (e.g., GIT_DIR=. git push)
CLEAN_CMD=$(echo "$COMMAND" | sed 's/^[A-Z_][A-Z_0-9]*=[^ ]* *//')

# Exit if not a git command
if ! echo "$CLEAN_CMD" | grep -q "^git "; then
  exit 0
fi
COMMAND="$CLEAN_CMD"

# Dangerous patterns that require explicit approval
DANGEROUS_PATTERNS=(
  "git push.*--force"
  "git push.*-f([^a-z]|$)"
  "git reset --hard"
  "git checkout \."
  "git checkout -- \."
  "git restore \."
  "git restore --staged \."
  "git clean -f"
  "git clean -fd"
  "git branch -D"
  "git stash drop"
  "git stash clear"
  "git rebase.*--force"
  "git push origin :main"
  "git push origin :master"
  "git push --delete.*main"
  "git push --delete.*master"
)

# Check for user-approved bypass token (5-min TTL)
BYPASS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.git-destructive-bypass"
has_bypass=false
if [ -f "$BYPASS_FILE" ]; then
  token_ts=$(cat "$BYPASS_FILE" 2>/dev/null)
  now=$(date +%s)
  age=$(( now - ${token_ts:-0} ))
  if [ "$age" -lt 300 ]; then
    has_bypass=true
  else
    rm -f "$BYPASS_FILE"
  fi
fi

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    if $has_bypass; then
      # User explicitly approved — allow through with advisory
      jq -n --arg reason "Destructive git command allowed via bypass token (pattern: $pattern)" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          permissionDecisionReason: $reason
        }
      }'
      exit 0
    fi
    jq -n --arg reason "Blocked: Destructive git command detected. Pattern: $pattern. This requires explicit user approval." '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
done

exit 0
