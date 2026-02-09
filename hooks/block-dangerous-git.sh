#!/bin/bash
# Hook: Block dangerous git commands
# PreToolUse hook for Bash - Prevents destructive operations without explicit approval

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Exit if no command or not a git command
if [ -z "$COMMAND" ] || ! echo "$COMMAND" | grep -q "^git "; then
  exit 0
fi

# Dangerous patterns that require explicit approval
DANGEROUS_PATTERNS=(
  "git push.*--force"
  "git push.*-f[^a-z]"
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

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
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
