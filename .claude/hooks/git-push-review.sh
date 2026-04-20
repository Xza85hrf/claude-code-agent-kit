#!/bin/bash
# Hook: Advisory reminder before git push
# Event: PreToolUse:Bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-protocol.sh" 2>/dev/null || true

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only match git push commands
[[ "$COMMAND" =~ ^git[[:space:]]+push($|[[:space:]]) ]] || exit 0

# Skip dry-run (already safe)
[[ "$COMMAND" =~ --dry-run ]] && exit 0

if type hook_signal >/dev/null 2>&1; then
  if [[ "$COMMAND" =~ (main|master) ]]; then
    hook_signal PreToolUse allow git-push-review \
      "Pushing to main/master" \
      "Confirm intentional — consider a PR instead" \
      "DENY on force-push to main"
  else
    hook_signal PreToolUse allow git-push-review \
      "Pushing to remote" \
      "Verify changes are committed and tested"
  fi
fi
exit 0
