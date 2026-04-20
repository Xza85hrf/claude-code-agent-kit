#!/bin/bash
set -euo pipefail
# Hook: Check for potential secrets in written/edited files
# PostToolUse hook for Write and Edit

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Fallback: Serena tools use relative_path instead of file_path
if [ -z "$FILE_PATH" ]; then
  REL_PATH=$(echo "$INPUT" | jq -r '.tool_input.relative_path // empty' 2>/dev/null)
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

# Skip shell scripts and kit infrastructure (contain variable refs like $API_KEY, not actual secrets)
if echo "$FILE_PATH" | grep -qE "\.(sh|bash|zsh)$"; then
  exit 0
fi
if echo "$FILE_PATH" | grep -qE "(\.claude/|hooks/|scripts/)"; then
  exit 0
fi

# Secret patterns to check
WARNINGS=""

# API keys, tokens, passwords — exclude comment lines (# or //)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qEi "(api[_-]?key|api[_-]?secret|auth[_-]?token|access[_-]?token|bearer|password|passwd|pwd|secret[_-]?key|private[_-]?key|encryption[_-]?key)\s*[:=]\s*['\"][^'\"]{8,}['\"]"; then
  WARNINGS="Potential API key/secret/password detected."
fi

# AWS credentials
if grep -qEi "(aws[_-]?access[_-]?key|aws[_-]?secret|AKIA[0-9A-Z]{16})" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Potential AWS credential detected."
fi

# Private keys (catch evasion variants: missing/partial dashes, PEM headers)
if grep -qE "(----)?BEGIN.*(PRIVATE|RSA|EC|DSA|OPENSSH) KEY" "$FILE_PATH" 2>/dev/null; then
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

# GitHub personal access tokens (ghp_, gho_, ghu_, ghs_, ghr_ prefixes followed by 30+ alphanumeric)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qEi "(ghp_|gho_|ghu_|ghs_|ghr_)[a-z0-9]{30,}"; then
  WARNINGS="${WARNINGS} GitHub personal access token pattern detected."
fi

# Base64-obfuscated credentials (common obfuscation patterns with 20+ base64 chars)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qEi "(Buffer\.from|atob|b64decode|base64\.decode)\s*\(\s*['\"][A-Za-z0-9+/]{20,}['\"]"; then
  WARNINGS="${WARNINGS} Base64-encoded secret pattern detected."
fi

# Split-string secret patterns (concatenation to evade detection)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qE "['\"]*(sk-|ghp_|gho_|ghu_|ghs_|ghr_|AKIA|xoxb-|xoxp-|xoxs-)['\"]?\s*\+\s*['\"][a-zA-Z0-9_-]+['\"]"; then
  WARNINGS="${WARNINGS} Split-string secret pattern detected (possible credential obfuscation)."
fi

# Slack tokens (xoxb-, xoxp-, xoxs- prefixes followed by alphanumeric+hyphens)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qEi "(xoxb-|xoxp-|xoxs-|xoxa-)[a-z0-9-]{10,}"; then
  WARNINGS="${WARNINGS} Slack token pattern detected."
fi

# GitLab personal access tokens (glpat-)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qEi "glpat-[a-z0-9_-]{10,}"; then
  WARNINGS="${WARNINGS} GitLab personal access token detected."
fi

# Generic high-entropy secrets (variable assignment of 32+ alphanumeric chars)
if grep -vE '^\s*(#|//)' "$FILE_PATH" 2>/dev/null | grep -qEi "(secret|token|apikey|api_key|credential|private_key|auth_key|access_key)\s*[:=]\s*['\"]?[a-z0-9]{32,}['\"]?"; then
  WARNINGS="${WARNINGS} High-entropy secret pattern detected."
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
