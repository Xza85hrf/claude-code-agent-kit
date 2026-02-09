#!/bin/bash
# Hook: Handle WebFetch errors and provide guidance
# PostToolUse hook for WebFetch

# Read JSON input from stdin
INPUT=$(cat)
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')

# Check if result contains error indicators
if echo "$TOOL_RESPONSE" | grep -qiE "(404|not found|error|failed)"; then

  GUIDANCE=""

  # GitHub-specific guidance
  if echo "$URL" | grep -qE "github\.com|raw\.githubusercontent\.com"; then
    GUIDANCE="GitHub fetch failed. Common fixes: 1. Check if path exists - browse repo manually first 2. Try different paths: /skills/ vs /prompts/skills/ 3. Verify branch name (main vs master) 4. Use GitHub API: gh api repos/owner/repo/contents/path 5. Search the repo structure first before fetching specific files"
  fi

  # Generic guidance
  if [ -z "$GUIDANCE" ]; then
    GUIDANCE="URL fetch failed. Verify the URL is accessible and path is correct."
  fi

  jq -n --arg guidance "$GUIDANCE" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("Fetch Error Recovery: " + $guidance)
    }
  }'
fi

exit 0
