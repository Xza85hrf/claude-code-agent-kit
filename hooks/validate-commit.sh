#!/bin/bash
# Hook: Validate commit message format
# PreToolUse hook for Bash - Enforces conventional commit format

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Exit if no command or not a git commit command
if [ -z "$COMMAND" ] || ! echo "$COMMAND" | grep -q "git commit"; then
  exit 0
fi

# Skip if --amend without -m (using editor)
if echo "$COMMAND" | grep -q "\-\-amend" && ! echo "$COMMAND" | grep -q "\-m"; then
  exit 0
fi

# Extract commit message - handle both -m "msg" and -m 'msg'
MSG=$(echo "$COMMAND" | grep -oP '(?<=-m ["\x27]).*?(?=["\x27](\s|$))' | head -1)

# If no message found with short form, check for HEREDOC pattern
if [ -z "$MSG" ]; then
  if echo "$COMMAND" | grep -q "cat <<"; then
    # HEREDOC style commit - can't easily validate, allow it
    exit 0
  fi
fi

# If still no message and has -m flag, something is off
if [ -z "$MSG" ] && echo "$COMMAND" | grep -q "\-m"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: "Could not parse commit message. Ensure message is properly quoted."
    }
  }'
  exit 0
fi

# If no -m flag at all, it is using editor - allow
if [ -z "$MSG" ]; then
  exit 0
fi

# Validate conventional commit format
VALID_TYPES="feat|fix|refactor|docs|test|chore|style|perf|ci|build|revert"

if ! echo "$MSG" | grep -qE "^($VALID_TYPES)(\(.+\))?: .+"; then
  jq -n --arg types "$VALID_TYPES" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: ("Commit message should follow conventional commits format: type(scope): description. Valid types: " + $types)
    }
  }'
fi

exit 0
