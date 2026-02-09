#!/bin/bash
# Hook: Check for common security issues in code
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

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Skip for markdown/docs
if echo "$FILE_PATH" | grep -qE "\.(md|txt|rst)$"; then
  exit 0
fi

WARNINGS=""

# Check for potential SQL injection (unparameterized queries)
if grep -qE "(SELECT|INSERT|UPDATE|DELETE).*\+.*(\$|req\.|request\.|params\.)" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="Potential SQL injection: string concatenation in SQL query. Use parameterized queries."
fi

# Check for potential command injection
if grep -qEi "(child_process|subprocess|os\.system|shell_exec|passthru)\s*\(" "$FILE_PATH" 2>/dev/null; then
  if grep -qE "\$\{|\+.*\$|request\.|req\.|params\." "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS} Potential command injection: user input may reach shell execution."
  fi
fi

# Check for disabled security features
if grep -qE "(verify\s*=\s*False|verify_ssl\s*=\s*False|rejectUnauthorized\s*:\s*false)" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} SSL verification disabled - security risk in production."
fi

# Check for hardcoded localhost that might leak to prod
if grep -qE "(localhost|127\.0\.0\.1):?[0-9]+" "$FILE_PATH" 2>/dev/null; then
  if ! echo "$FILE_PATH" | grep -qE "(test|spec|config|\.env)"; then
    WARNINGS="${WARNINGS} Hardcoded localhost found - ensure this doesn't reach production."
  fi
fi

# Check for debug mode enabled
if grep -qE "(DEBUG\s*=\s*True|debug:\s*true|\"debug\":\s*true)" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Debug mode enabled - disable before production deployment."
fi

if [ -n "$WARNINGS" ]; then
  WARNINGS=$(echo "$WARNINGS" | sed 's/^ *//')
  jq -n --arg warnings "$WARNINGS" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("SECURITY CHECK: " + $warnings)
    }
  }'
fi

exit 0
