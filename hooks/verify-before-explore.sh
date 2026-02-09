#!/bin/bash
# Hook: Suggest verifying repo structure before fetching
# PreToolUse hook for WebFetch

# Read JSON input from stdin
INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')

# Exit if no URL or not a GitHub URL
if [ -z "$URL" ]; then
  exit 0
fi

if ! echo "$URL" | grep -qE "(github\.com|raw\.githubusercontent\.com)"; then
  exit 0
fi

# Check if URL has deep path (more than 4 segments after domain)
PATH_DEPTH=$(echo "$URL" | sed 's|.*://[^/]*/||' | tr '/' '\n' | wc -l)

if [ "$PATH_DEPTH" -gt 4 ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "Deep GitHub path detected. Consider using gh api repos/owner/repo/contents to verify the structure before fetching."
    }
  }'
fi

exit 0
