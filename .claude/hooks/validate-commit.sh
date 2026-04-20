#!/bin/bash
# Hook: Validate commit message format
# PreToolUse hook for Bash - Enforces conventional commit format

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

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
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:"[HOOK:commit] Parse failed | DO: Quote message correctly with -m \"type(scope): desc\""}}'
  exit 0
fi

# If no -m flag at all, it is using editor - allow
if [ -z "$MSG" ]; then
  exit 0
fi

# Validate conventional commit format
VALID_TYPES="feat|fix|refactor|docs|test|chore|style|perf|ci|build|revert"

if ! echo "$MSG" | grep -qE "^($VALID_TYPES)(\(.+\))?: .+"; then
  jq -n --arg t "$VALID_TYPES" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:commit] Invalid format | DO: Use type(scope): desc. Types: " + $t)}}'
fi

exit 0
