#!/bin/bash
set -euo pipefail
# Hook: YAML-driven damage control — security pattern matching
# Event: PreToolUse:Bash
#
# Reads patterns from .claude/config/damage-control-patterns.yaml
# Enforces BLOCK (deny), ASK (deny + bypass token), and ALLOW (log) rules
#
# Bypass: create .claude/.damage-control-bypass with timestamp (5-min TTL)

# strip_heredocs() comes from command-security.sh — one copy used by
# every pattern-matching hook so the delimiter regex stays in sync.
# Source directly (can't defer to the later source block below because
# we need the function BEFORE the first COMMAND_FOR_PATTERNS strip).
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/command-security.sh" 2>/dev/null || true

# Read JSON input from stdin
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Exit if no command
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Strip embedded language content (heredocs, python -c, etc.) to prevent
# false positives from comparison operators like > in Python code
COMMAND_FOR_PATTERNS="$COMMAND"
# Remove heredoc bodies — any delimiter, including user-chosen ones like
# COMMIT_MSG, SCRIPT, etc. Previously hardcoded EOF/PYEOF/END only.
# Skip if the lib didn't load (defensive — lets us fail-open to the
# old unstripped behavior rather than crashing the hook).
if declare -f strip_heredocs >/dev/null 2>&1; then
  COMMAND_FOR_PATTERNS=$(strip_heredocs "$COMMAND_FOR_PATTERNS")
fi
# Remove python -c "..." or python3 -c "..." inline code (single-line)
COMMAND_FOR_PATTERNS=$(echo "$COMMAND_FOR_PATTERNS" | sed 's/python[3]\? -c "[^"]*"//g; s/python[3]\? -c '\''[^'\'']*'\''//g')

# Source shared libraries
KIT_LIB_DIR="${BASH_SOURCE[0]%/*}/../lib"
if [ ! -f "$KIT_LIB_DIR/hook-protocol.sh" ]; then
  exit 0
fi
source "$KIT_LIB_DIR/hook-protocol.sh"
source "$KIT_LIB_DIR/env-defaults.sh"

# Profile gate — damage-control is "minimal" tier (always runs)
SCRIPTS_LIB="${BASH_SOURCE[0]%/*}/../scripts/lib"
[ -f "$SCRIPTS_LIB/hook-profile-gate.sh" ] && source "$SCRIPTS_LIB/hook-profile-gate.sh"
if declare -f hook_profile_check >/dev/null 2>&1; then
  hook_profile_check "minimal" "damage-control" || exit 0
fi

# Locate YAML config
CONFIG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/config/damage-control-patterns.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

# =============================================================================
# Path-level protection helper functions
# =============================================================================

# expand_tilde PATH
# Expands ~ to $HOME in a path
expand_tilde() {
  local path="$1"
  [[ "$path" == "~"* ]] && path="${path/#\~/$HOME}" || true
  echo "$path"
}

# path_matches TARGET PATTERN
# Checks if target path matches protection pattern relative to project dir
# Only matches paths within the project directory (not global ~/.claude/ etc.)
path_matches() {
  local target="$1" pattern="$2"
  pattern=$(expand_tilde "$pattern")
  target=$(expand_tilde "$target")

  local project_dir
  project_dir=$(expand_tilde "${CLAUDE_PROJECT_DIR:-.}")

  # Resolve relative targets to project directory
  if [[ "$target" != /* ]]; then
    target="${project_dir}/${target}"
  fi

  # If pattern is relative (no leading /), scope it to the project directory
  if [[ "$pattern" != /* ]]; then
    local full_pattern="${project_dir}/${pattern}"
    # Only match if the target is within the project directory AND matches the pattern
    [[ "$target" == "${project_dir}"* ]] && [[ "$target" == "${full_pattern}"* ]]
  else
    # Absolute pattern — match prefix exactly
    [[ "$target" == "${pattern}"* ]]
  fi
}

# parse_path_list YAML_FILE SECTION
# Extracts path list from paths section (e.g., zeroAccess, readOnly, noDelete)
# Output: newline-separated paths
parse_path_list() {
  local yaml_file="$1" section="$2"

  awk -v section="$section:" '
    /^  '"$section"'/ { in_section=1; next }
    /^  [a-zA-Z]/ && in_section { in_section=0 }
    in_section && /^    - / {
      gsub(/^    - "?/, "");
      gsub(/"$/, "");
      if (length($0) > 0) print $0;
    }
  ' "$yaml_file"
}

# extract_paths_from_command COMMAND
# Extracts file paths from a bash command
# Handles: rm, mv, cat, vi, nano, sed, chmod, chown, touch, cp, etc.
extract_paths_from_command() {
  local cmd="$1"
  local paths=()

  # Simple extraction: split on whitespace, capture tokens that look like paths
  # or follow known flags
  local tokens=($cmd)
  local skip_next=false

  for i in "${!tokens[@]}"; do
    local token="${tokens[$i]}"

    # Skip option flags
    if [[ "$token" == -* ]]; then
      # Some flags take arguments (e.g., -o file, -d delimiter)
      if [[ "$token" == -[od] ]]; then
        skip_next=true
      fi
      continue
    fi

    if $skip_next; then
      skip_next=false
      continue
    fi

    # Capture tokens that look like paths or filenames
    # Skip pipes, redirects, and common non-path tokens
    if [[ "$token" == ">" ]] || [[ "$token" == ">>" ]] || [[ "$token" == "|" ]] || [[ "$token" == "&&" ]] || [[ "$token" == "||" ]] || [[ "$token" == ";" ]]; then
      continue
    fi
    # Strip surrounding quotes (single, double) — tokens get passed through
    # bash word-splitting with quotes attached, and a quoted filename should
    # count identically to an unquoted one.
    token="${token#\"}"; token="${token%\"}"
    token="${token#\'}"; token="${token%\'}"
    [ -z "$token" ] && continue
    # Accept as a path IFF it looks like a real filesystem reference:
    #   1. Starts with /, ./, ../, or ~  — absolute or explicit relative
    #   2. Contains at least one /       — relative path (foo/bar)
    #   3. Bare filename with a known extension suffix
    # REJECT dotted-identifier style tokens like .env.DISABLE_AUTOUPDATER
    # (jq filter), package.json (jq path expression), or obj.attr.method
    # — which are NOT filesystem paths, just shell/jq/JS syntax that
    # happens to contain dots. Before this fix, anything with a dot was
    # matched, which caused zeroAccess false positives on every command
    # mentioning `.env.*` in any context (including JSON filter expressions).
    _is_path=false
    case "$token" in
      /*|./*|../*|~/*|~)       _is_path=true ;;
      */*)                      _is_path=true ;;
      *.sh|*.py|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.jsx|*.json|*.yaml|*.yml|*.toml|*.md|*.txt|*.log|*.lock|*.env|*.cfg|*.conf|*.ini|*.xml|*.html|*.css|*.scss|*.rs|*.go|*.c|*.cpp|*.h|*.hpp|*.java|*.kt|*.rb|*.php|*.sql|*.csv|*.tsv|*.pdf|*.png|*.jpg|*.svg) _is_path=true ;;
    esac
    if $_is_path; then
      paths+=("$token")
    fi
  done

  printf '%s\n' "${paths[@]}"
}

# detect_operation COMMAND TARGET
# Determines if command is a read, write, or delete operation
detect_operation() {
  local cmd="$1"

  # Check for delete operations
  if echo "$cmd" | grep -qE "^(rm|unlink|truncate)\s"; then
    echo "delete"
    return
  fi

  # Check for write operations
  if echo "$cmd" | grep -qE "^(mv|sed\s+.*-i|chmod|chown|tee|touch|dd)\s"; then
    echo "write"
    return
  fi

  # Check for read operations
  if echo "$cmd" | grep -qE "^(cat|head|tail|less|more|file|stat|wc|grep|ls|echo|printf|find|test|diff|du|df|readlink|realpath|basename|dirname)\s"; then
    echo "read"
    return
  fi

  # Git staging/inspection ops — don't modify files, safe for readOnly paths
  if echo "$cmd" | grep -qE "^git\s+(add|status|diff|log|show|blame|stash|fetch|branch|commit|reset)\b"; then
    echo "read"
    return
  fi

  # Check for pipe/redirect operations
  if echo "$cmd" | grep -qE "[>|]"; then
    echo "write"
    return
  fi

  # Default to write (most restrictive for unknown commands)
  echo "write"
}

# has_bypass_token — returns 0 (bypass active) or 1 (no bypass)
# A bypass token is .claude/.damage-control-bypass containing a UNIX
# timestamp. Valid for 5 min, then self-expires.
has_bypass_token() {
  local bypass_file="${CLAUDE_PROJECT_DIR:-.}/.claude/.damage-control-bypass"
  [ -f "$bypass_file" ] || return 1
  local ts age
  ts=$(cat "$bypass_file" 2>/dev/null)
  age=$(( $(date +%s) - ${ts:-0} ))
  if [ "$age" -lt 300 ]; then
    return 0
  fi
  rm -f "$bypass_file" 2>/dev/null
  return 1
}

# check_path_protection TARGET OPERATION YAML_FILE
# Checks if target path violates any protection rules
# Returns 0 (allowed), 1 (blocked)
#
# Bypass: a valid .claude/.damage-control-bypass token overrides readOnly
# and noDelete checks (not zeroAccess — those stay absolute). Lets the
# agent delete a protected file in one turn instead of the three-step
# edit-yaml / rm / restore-yaml dance.
check_path_protection() {
  local target="$1" operation="$2" yaml_file="$3"

  target=$(expand_tilde "$target")

  # Check zeroAccess — block ANY access (read or write). No bypass.
  local zero_paths
  zero_paths=$(parse_path_list "$yaml_file" "zeroAccess")
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    if path_matches "$target" "$pattern"; then
      hook_signal PreToolUse deny damage-control \
        "BLOCKED: Access to protected path '$target' (zeroAccess: $pattern)" \
        "This path is fully protected by security policy. No read or write access allowed."
      return 1
    fi
  done <<< "$zero_paths"

  local has_bypass=false
  has_bypass_token && has_bypass=true

  # Check readOnly — block writes/deletes but allow reads
  if [[ "$operation" == "write" ]] || [[ "$operation" == "delete" ]]; then
    local ro_paths
    ro_paths=$(parse_path_list "$yaml_file" "readOnly")
    while IFS= read -r pattern; do
      [ -z "$pattern" ] && continue
      if path_matches "$target" "$pattern"; then
        if $has_bypass; then
          # Exit immediately — one JSON per hook invocation, matches the
          # ASK-pattern bypass at the end of this file.
          hook_signal PreToolUse allow damage-control \
            "Bypass token accepted: write to '$target' (readOnly: $pattern)" \
            "Monitor execution closely — protected path temporarily unlocked"
          exit 0
        fi
        hook_signal PreToolUse deny damage-control \
          "BLOCKED: Write to read-only path '$target' (readOnly: $pattern)" \
          "Create .claude/.damage-control-bypass with timestamp to override (5-min TTL)"
        return 1
      fi
    done <<< "$ro_paths"
  fi

  # Check noDelete — block deletes but allow reads/writes
  if [[ "$operation" == "delete" ]]; then
    local nd_paths
    nd_paths=$(parse_path_list "$yaml_file" "noDelete")
    while IFS= read -r pattern; do
      [ -z "$pattern" ] && continue
      if path_matches "$target" "$pattern"; then
        if $has_bypass; then
          hook_signal PreToolUse allow damage-control \
            "Bypass token accepted: delete '$target' (noDelete: $pattern)" \
            "Monitor execution closely — protected path temporarily unlocked"
          exit 0
        fi
        hook_signal PreToolUse deny damage-control \
          "BLOCKED: Cannot delete protected path '$target' (noDelete: $pattern)" \
          "Create .claude/.damage-control-bypass with timestamp to override (5-min TTL)"
        return 1
      fi
    done <<< "$nd_paths"
  fi

  return 0
}

# =============================================================================
# Parse YAML patterns helper functions
# =============================================================================

# parse_patterns_with_desc YAML_FILE CATEGORY LEVEL
# Extracts patterns and descriptions under a specific category/level
# Output: newline-separated "pattern|||description" pairs
parse_patterns_with_desc() {
  local yaml_file="$1" category="$2" level="$3"

  awk -v cat="^${category}:" -v lvl="^  ${level}:" '
    BEGIN { in_category = 0; in_level = 0; pattern = "" }

    # Enter category
    $0 ~ cat { in_category = 1; next }

    # Enter level within category
    in_category && $0 ~ lvl { in_level = 1; next }

    # Exit category if we see another top-level key
    in_category && /^[a-zA-Z]/ && !($0 ~ cat) && !($0 ~ lvl) {
      in_category = 0; in_level = 0; pattern = ""
    }

    # Exit level if we see another level marker
    in_level && /^  [A-Z]/ { in_level = 0; pattern = ""; next }

    # Extract pattern line
    in_level && /pattern:/ {
      gsub(/^[[:space:]]*- pattern:[[:space:]]*'\''/, "");
      gsub(/'\''[[:space:]]*$/, "");
      pattern = $0;
    }

    # Extract description following pattern
    in_level && /description:/ && pattern != "" {
      gsub(/^[[:space:]]*description:[[:space:]]*"/, "");
      gsub(/"[[:space:]]*$/, "");
      desc = $0;
      print pattern "|||" desc;
      pattern = "";
    }
  ' "$yaml_file"
}

# check_and_get_match COMMAND PATTERNS_WITH_DESC
# Find first matching pattern and return "pattern|||description".
#
# Patterns starting with `(?i)` are treated as case-insensitive
# (grep -i). POSIX ERE has no inline case flag, so `(?i)drop` in a
# raw `grep -E` invocation matches literally and silently never
# fires — that's how the database category's DROP/TRUNCATE/DELETE
# rules became dead code even after the enclosing loop was
# eventually wired up. Strip the prefix and use grep -iE instead.
check_and_get_match() {
  local command="$1" patterns_str="$2"
  local line pattern desc grep_flags

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    pattern="${line%|||*}"
    desc="${line#*|||}"
    grep_flags="-qE"

    if [[ "$pattern" == '(?i)'* ]]; then
      pattern="${pattern#(\?i)}"
      grep_flags="-qiE"
    fi

    if echo "$COMMAND_FOR_PATTERNS" | grep $grep_flags "$pattern" 2>/dev/null; then
      echo "$pattern|||$desc"
      return 0
    fi
  done <<< "$patterns_str"

  return 1
}

# =============================================================================
# Main logic: Path protection first, then pattern matching
# =============================================================================

# Path-level protection check (highest priority)
# Split compound commands on && || ; | and check each subcommand independently.
# CRITICAL: split on $COMMAND_FOR_PATTERNS (heredocs + python -c stripped),
# not $COMMAND. Tokenizing the raw command pulls every quoted string literal
# inside `python3 -c "..."` into the path-extraction pass, which then treats
# anything with a dot as a path — so `python3 -c 'print("package-lock.json")'`
# was matching readOnly and getting blocked. The patterns section already uses
# COMMAND_FOR_PATTERNS for the same reason.
IFS=$'\n' read -r -d '' -a SUBCMDS < <(
  echo "$COMMAND_FOR_PATTERNS" | sed 's/\s*&&\s*/\n/g; s/\s*||\s*/\n/g; s/\s*;\s*/\n/g' | sed 's/^\s*//'
  printf '\0'
) || true

for subcmd in "${SUBCMDS[@]}"; do
  [ -z "$subcmd" ] && continue
  PATHS=$(extract_paths_from_command "$subcmd")
  if [ -n "$PATHS" ]; then
    OPERATION=$(detect_operation "$subcmd")

    while IFS= read -r target_path; do
      [ -z "$target_path" ] && continue
      check_path_protection "$target_path" "$OPERATION" "$CONFIG_FILE" || exit 0
    done <<< "$PATHS"
  fi
done

# Pattern-based checks: ALLOW, BLOCK, ASK (in priority order)
#
# Category list — single source of truth for all three loops below.
# Historical: only the first six categories were evaluated until the
# v2.1.109 audit, which left the Turnstone-inspired `supply_chain`,
# `browser_data`, `container_escape`, `credential_harvest`,
# `network_exfil`, and `database` rules defined in the YAML but
# never matched against. They all became dead code. Enabling them
# required an FP-tightening pass on the patterns themselves (see
# damage-control-patterns.yaml history) so they don't block e.g.
# `cat chrome-cookies-notes.md` or `grep 'DROP TABLE' migration.sql`.
PATTERN_CATEGORIES=(
  filesystem git system cloud process network
  supply_chain browser_data container_escape
  credential_harvest network_exfil database
)

# First, check ALLOW patterns (whitelist) — these pass silently
for CATEGORY in "${PATTERN_CATEGORIES[@]}"; do
  ALLOW_DATA=$(parse_patterns_with_desc "$CONFIG_FILE" "$CATEGORY" "ALLOW")
  if [ -n "$ALLOW_DATA" ]; then
    if MATCH=$(check_and_get_match "$COMMAND" "$ALLOW_DATA"); then
      # Pattern matched in ALLOW list — pass through silently
      exit 0
    fi
  fi
done

# Check BLOCK patterns (hard deny, no bypass)
for CATEGORY in "${PATTERN_CATEGORIES[@]}"; do
  BLOCK_DATA=$(parse_patterns_with_desc "$CONFIG_FILE" "$CATEGORY" "BLOCK")
  if [ -n "$BLOCK_DATA" ]; then
    if MATCH=$(check_and_get_match "$COMMAND" "$BLOCK_DATA"); then
      PATTERN="${MATCH%|||*}"
      DESCRIPTION="${MATCH#*|||}"

      hook_signal PreToolUse deny damage-control \
        "BLOCKED: $DESCRIPTION (pattern: $PATTERN)" \
        "This command is prohibited by security policy"
      exit 0
    fi
  fi
done

# Check ASK patterns (deny unless bypass token exists)
BYPASS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.damage-control-bypass"
HAS_BYPASS=false

if [ -f "$BYPASS_FILE" ]; then
  TOKEN_TS=$(cat "$BYPASS_FILE" 2>/dev/null)
  NOW=$(date +%s)
  AGE=$(( NOW - ${TOKEN_TS:-0} ))
  if [ "$AGE" -lt 300 ]; then
    HAS_BYPASS=true
  else
    rm -f "$BYPASS_FILE"
  fi
fi

for CATEGORY in "${PATTERN_CATEGORIES[@]}"; do
  ASK_DATA=$(parse_patterns_with_desc "$CONFIG_FILE" "$CATEGORY" "ASK")
  if [ -n "$ASK_DATA" ]; then
    if MATCH=$(check_and_get_match "$COMMAND" "$ASK_DATA"); then
      PATTERN="${MATCH%|||*}"
      DESCRIPTION="${MATCH#*|||}"

      if $HAS_BYPASS; then
        # User explicitly approved — allow through with advisory
        hook_signal PreToolUse allow damage-control \
          "Dangerous command allowed via bypass token (pattern: $PATTERN)" \
          "Monitor execution closely"
        exit 0
      fi

      # Deny with advisory message
      hook_signal PreToolUse deny damage-control \
        "Dangerous: $DESCRIPTION (pattern: $PATTERN)" \
        "Create .claude/.damage-control-bypass with timestamp to override (5-min TTL)"
      exit 0
    fi
  fi
done

exit 0
