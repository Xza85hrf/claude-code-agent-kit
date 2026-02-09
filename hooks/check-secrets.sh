#!/bin/bash
# Hook: Check for potential secrets in written/edited files
# PostToolUse hook for Write and Edit

# Read JSON input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Fallback: Serena tools use relative_path instead of file_path
if [ -z "$FILE_PATH" ]; then
  REL_PATH=$(echo "$INPUT" | jq -r '.tool_input.relative_path // empty')
  if [ -n "$REL_PATH" ]; then
    FILE_PATH="${CLAUDE_PROJECT_DIR:-.}/$REL_PATH"
  fi
fi

# Exit if no file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip if file doesn't exist or is binary
if [ ! -f "$FILE_PATH" ] || file "$FILE_PATH" | grep -q "binary"; then
  exit 0
fi

# Secret patterns to check
WARNINGS=""

# API keys, tokens, passwords
if grep -qEi "(api[_-]?key|api[_-]?secret|auth[_-]?token|access[_-]?token|bearer|password|passwd|pwd|secret[_-]?key|private[_-]?key|encryption[_-]?key)\s*[:=]\s*['\"][^'\"]{8,}['\"]" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="Potential API key/secret/password detected."
fi

# AWS credentials
if grep -qEi "(aws[_-]?access[_-]?key|aws[_-]?secret|AKIA[0-9A-Z]{16})" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Potential AWS credential detected."
fi

# Private keys
if grep -q "-----BEGIN.*PRIVATE KEY-----" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Private key detected!"
fi

# Database connection strings
if grep -qEi "(mongodb|postgres|mysql|redis)://[^[:space:]]+:[^[:space:]]+@" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Database connection string with credentials detected."
fi

# JWT tokens (long base64 strings with dots)
if grep -qE "eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} JWT token detected."
fi

if [ -n "$WARNINGS" ]; then
  WARNINGS=$(echo "$WARNINGS" | sed 's/^ *//')
  jq -n --arg warnings "$WARNINGS" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("SECRET WARNING: " + $warnings + " Ensure no actual credentials are committed. Use environment variables instead.")
    }
  }'
fi

exit 0
