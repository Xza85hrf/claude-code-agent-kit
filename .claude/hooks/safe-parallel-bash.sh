#!/bin/bash
# Hook: Prevent false failures from diff commands in parallel batches
# PreToolUse:Bash - Detects standalone diff commands without error handling
# and appends "|| true" via updatedInput to prevent sibling cancellation.
#
# Why: diff returns exit code 1 when files differ (not an error).
# In parallel tool calls, this cancels unrelated sibling commands.

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only target commands starting with "diff " (not git diff, not in pipelines)
if echo "$CMD" | grep -qE '^diff '; then
  # Skip if already has error handling
  if ! echo "$CMD" | grep -qE '\|\| true|\|\| echo|\|\| exit|; true|; echo'; then
    NEW_CMD="${CMD} || true"
    jq -n --arg cmd "$NEW_CMD" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        updatedInput: { command: $cmd },
        additionalContext: "Auto-appended || true to diff command to prevent false failure (exit 1 = files differ, not error). This prevents sibling tool call cancellation in parallel batches."
      }
    }'
    exit 0
  fi
fi

exit 0
