#!/bin/bash
set -euo pipefail
# Hook: Check for common security issues in code (enhanced with Veracode 2025 patterns)
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

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Skip for markdown/docs/shell scripts/kit infrastructure
if echo "$FILE_PATH" | grep -qE "\.(md|txt|rst|sh|bash|zsh)$"; then
  exit 0
fi
if echo "$FILE_PATH" | grep -qE "(\.claude/|hooks/|scripts/)"; then
  exit 0
fi

# Load review suppressions
_load_suppressions() {
  local suppression_file="${CLAUDE_PROJECT_DIR:-.}/.claude/config/review-suppressions.yml"
  if [ ! -f "$suppression_file" ]; then
    return 1  # No suppressions file, continue normally
  fi

  # Check if file matches exclusion patterns
  local exclusions
  exclusions=$(grep -A100 'file_exclusions:' "$suppression_file" 2>/dev/null | grep '^\s*-\s*"' | sed 's/.*"\(.*\)".*/\1/')

  if [ -n "$exclusions" ]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      # Convert glob-style pattern to regex
      local regex="${pattern//\*/.*}"
      regex="${regex//\?/.}"
      if echo "$FILE_PATH" | grep -qE "$regex$"; then
        return 0  # File is suppressed
      fi
    done <<< "$exclusions"
  fi

  return 1  # File not in exclusion list
}

# Skip if file matches suppression exclusions
if _load_suppressions; then
  exit 0
fi

WARNINGS=""

# Check for potential SQL injection (unparameterized queries)
# Matches both + concatenation and template literal interpolation ${...}
if grep -qE "(SELECT|INSERT|UPDATE|DELETE).*(\+.*(\$|req\.|request\.|params\.)|\\\$\{)" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="Potential SQL injection: user input interpolated into SQL query. Use parameterized queries."
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
  if ! echo "$FILE_PATH" | grep -qE "(test|spec|config|\.env|monitor|dev\.|local\.|docker|compose)"; then
    WARNINGS="${WARNINGS} Hardcoded localhost found - ensure this doesn't reach production."
  fi
fi

# Check for debug mode enabled
if grep -qE "(DEBUG\s*=\s*True|debug:\s*true|\"debug\":\s*true)" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Debug mode enabled - disable before production deployment."
fi

# --- Veracode 2025 patterns (AI-generated code vulnerabilities) ---

# XSS: direct HTML insertion and event handler injection (86% failure rate in AI code)
if grep -qE 'innerHTML|dangerouslySetInnerHTML|document\.write\(|v-html|outerHTML\s*=' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Potential XSS: direct HTML insertion. Use textContent or sanitization."
fi
# XSS: event handler attributes with dynamic content
if grep -qE 'on(error|load|click|mouseover|focus|input)\s*=\s*[`"'"'"'].*\$' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Potential XSS: event handler with dynamic content. Sanitize user input."
fi

# Insecure deserialization
if grep -qE 'pickle\.loads|yaml\.load\(|unserialize\(|Marshal\.load' "$FILE_PATH" 2>/dev/null; then
  if ! grep -qE 'SafeLoader|yaml\.safe_load' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS} Insecure deserialization: untrusted data may run code. Use safe loaders."
  fi
fi

# Weak password hashing (md5/sha1)
if grep -qE '(password|passwd|pwd)' "$FILE_PATH" 2>/dev/null; then
  if grep -qEi '(md5|sha1)\(' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS} Weak password hashing (md5/sha1). Use bcrypt, argon2, or scrypt."
  fi
fi

# Missing input validation
if grep -qE 'req\.(body|params|query)\.' "$FILE_PATH" 2>/dev/null; then
  if ! grep -qE '(validate|sanitize|escape|Joi\.|zod\.|yup\.|check\(|body\(|param\()' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS} User input without validation. Sanitize req.body/params/query."
  fi
fi

# Hardcoded secrets (skip .env/.config/.example files)
if ! echo "$FILE_PATH" | grep -qE '\.(env|config|example|sample)'; then
  if grep -qiE '(password|api_key|apiKey|secret|token)\s*[=:]\s*['"'"'"][^'"'"'"]{8,}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS} Hardcoded secret detected. Use environment variables."
  fi
fi

# Insecure randomness in security context
if grep -qE '(token|session|secret|auth|password)' "$FILE_PATH" 2>/dev/null; then
  if grep -qE 'Math\.random()|random\.random()' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS} Insecure randomness for security. Use crypto.randomBytes or secrets."
  fi
fi

# Connection strings with embedded credentials
if grep -qE '(mongodb|postgres|mysql|redis|amqp|mssql)://[^[:space:]/]+:[^[:space:]@]+@' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Connection string with embedded credentials. Use environment variables."
fi

# Eval/exec with user input (direct code injection)
if grep -qE '(eval|exec|Function)\s*\(\s*(req\.|request\.|params\.|body\.|query\.|user[Ii]nput|untrusted)' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS} Dynamic code execution with user input — critical injection risk."
fi

# Shell-escape detection in non-shell code (ported from context-mode security.ts)
# Detects subprocess.run(), child_process calls, etc. with dangerous arguments
_SEC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SEC_SCRIPT_DIR/../lib/command-security.sh" 2>/dev/null || true
if declare -f detect_shell_escapes >/dev/null 2>&1; then
  SHELL_CMDS=$(detect_shell_escapes "$FILE_PATH" 2>/dev/null || true)
  if [ -n "$SHELL_CMDS" ]; then
    _DENY_RE='(rm\s+-rf|sudo|chmod\s+777|curl.*(-d|--data)|wget.*\||dd\s+if=|mkfs|kill\s+-9)'
    while IFS= read -r _shell_cmd; do
      if echo "$_shell_cmd" | grep -qE "$_DENY_RE"; then
        WARNINGS="${WARNINGS} Shell escape with dangerous command: ${_shell_cmd}. Verify this is intentional."
      fi
    done <<< "$SHELL_CMDS"
  fi
fi

# Elevated scrutiny for AI-generated code
if [ -n "$WARNINGS" ]; then
  TOKEN_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.tokens/delegation.token"
  if [ -f "$TOKEN_FILE" ]; then
    TOKEN_TS=$(cat "$TOKEN_FILE" 2>/dev/null)
    ELAPSED=$(( $(date +%s) - ${TOKEN_TS:-0} ))
    if [ "$ELAPSED" -lt 300 ]; then
      WARNINGS="${WARNINGS} [AI CODE] 2.74x more vulns in AI code (Veracode 2025). Review carefully."
    fi
  fi
fi

if [ -n "$WARNINGS" ]; then
  WARNINGS=$(echo "$WARNINGS" | sed 's/^ *//')
  # Source protocol library
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "$SCRIPT_DIR/../lib/hook-protocol.sh" 2>/dev/null || source "${CLAUDE_PLUGIN_ROOT:-.}/.claude/lib/hook-protocol.sh" 2>/dev/null
  if declare -f hook_signal >/dev/null 2>&1; then
    FILE_NAME=$(basename "$FILE_PATH")
    hook_signal PostToolUse allow security "Vuln in ${FILE_NAME}: ${WARNINGS}" "Fix each issue before committing"
  else
    jq -n --arg w "$WARNINGS" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("[HOOK:security] " + $w + " | DO: Fix before committing")}}'
  fi
fi

exit 0
