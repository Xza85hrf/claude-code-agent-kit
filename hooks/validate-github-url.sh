#!/bin/bash
# Hook: Validate GitHub URL patterns
# PreToolUse hook for WebFetch - Warns about potentially incorrect GitHub paths

# Read JSON input from stdin
INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')

# Exit if no URL or not a GitHub/raw.githubusercontent URL
if [ -z "$URL" ]; then
  exit 0
fi

if ! echo "$URL" | grep -qE "(github\.com|raw\.githubusercontent\.com)"; then
  exit 0
fi

# Check for suspicious patterns
WARNING=""

# Check for common wrong path patterns
if echo "$URL" | grep -qE "/prompts/|/templates/|/examples/"; then
  WARNING="GitHub repos often don't have these directories at the expected paths. Consider using 'gh api repos/owner/repo/contents' to verify the structure first."
fi

# Check for non-standard branch names in raw URLs
if echo "$URL" | grep -qE "raw\.githubusercontent\.com.*/(feature|develop|dev|fix)/"; then
  WARNING="Using non-standard branch name in URL. Verify the branch exists: 'gh api repos/owner/repo/branches'"
fi

# Check for github.com/blob URLs (should use raw.githubusercontent.com)
if echo "$URL" | grep -qE "github\.com/.*/blob/"; then
  WARNING="Using github.com/blob URL - consider using raw.githubusercontent.com for raw file content."
fi

if [ -n "$WARNING" ]; then
  jq -n --arg warning "$WARNING" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: $warning
    }
  }'
fi

exit 0
