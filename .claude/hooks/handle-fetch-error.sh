#!/bin/bash
# Hook: Handle WebFetch errors and provide guidance
# PostToolUse hook for WebFetch

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty' 2>/dev/null)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null)

# Check for structural fetch failures (not content mentioning "error")
# Only trigger on short responses that look like error messages, not page content
RESP_LEN=${#TOOL_RESPONSE}
if [ "$RESP_LEN" -lt 500 ] && echo "$TOOL_RESPONSE" | grep -qiE "(404|not found|could not fetch|connection refused|timed out|403 forbidden)"; then

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
