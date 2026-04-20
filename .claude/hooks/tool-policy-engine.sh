#!/bin/bash
set -euo pipefail
# Hook: Tool Policy Engine — YAML-driven tool access control
# PreToolUse hook (all tools)
# Inspired by Turnstone's tool policies (glob patterns: allow/deny/ask/warn)

KIT_LIB_DIR="${BASH_SOURCE[0]%/*}/../lib"
if [ -f "$KIT_LIB_DIR/hook-protocol.sh" ]; then
  source "$KIT_LIB_DIR/hook-protocol.sh"
fi
source "$KIT_LIB_DIR/env-defaults.sh" 2>/dev/null || true

SCRIPTS_LIB="${BASH_SOURCE[0]%/*}/../scripts/lib"
[ -f "$SCRIPTS_LIB/hook-profile-gate.sh" ] && source "$SCRIPTS_LIB/hook-profile-gate.sh"
if declare -f hook_profile_check >/dev/null 2>&1; then
  hook_profile_check "standard" "tool-policy-engine" || exit 0
fi

INPUT=$(if [ -t 0 ]; then echo '{}'; else cat; fi)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)

[ -z "$TOOL_NAME" ] && exit 0

POLICY_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/config/tool-policies.yaml"
[ -f "$POLICY_FILE" ] || exit 0

CACHE_FILE="/tmp/tool-policies-$(echo "${CLAUDE_PROJECT_DIR:-.}" | md5sum | cut -d' ' -f1).cache"

# Parse YAML policies into cache (format: priority|pattern|action|condition|reason)
parse_policies() {
  local policy_mtime cache_mtime
  policy_mtime=$(stat -c %Y "$POLICY_FILE" 2>/dev/null || stat -f %m "$POLICY_FILE" 2>/dev/null || echo 0)
  cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)

  if [ -f "$CACHE_FILE" ] && [ "$cache_mtime" -ge "$policy_mtime" ]; then
    cat "$CACHE_FILE"; return
  fi

  awk '
    BEGIN { pat=""; act=""; cond=""; reas=""; pri=0 }
    /^[[:space:]]*-[[:space:]]/ {
      if (pat != "") printf "%010d|%s|%s|%s|%s\n", pri, pat, act, cond, reas
      pat=""; act=""; cond=""; reas=""; pri=0
    }
    /pattern:/ { sub(/^[^:]*:[[:space:]]*"?/, ""); sub(/"[[:space:]]*$/, ""); pat=$0 }
    /action:/ { sub(/^[^:]*:[[:space:]]*"?/, ""); sub(/"[[:space:]]*$/, ""); act=$0 }
    /priority:/ { sub(/^[^:]*:[[:space:]]*/, ""); pri=$0+0 }
    /condition:/ { sub(/^[^:]*:[[:space:]]*"?/, ""); sub(/"[[:space:]]*$/, ""); cond=$0 }
    /reason:/ { sub(/^[^:]*:[[:space:]]*"?/, ""); sub(/"[[:space:]]*$/, ""); reas=$0 }
    END { if (pat != "") printf "%010d|%s|%s|%s|%s\n", pri, pat, act, cond, reas }
  ' "$POLICY_FILE" | sort -t'|' -k1 -rn > "$CACHE_FILE" 2>/dev/null || true
  cat "$CACHE_FILE"
}

# Check if tool name matches pattern (| separated OR)
match_tool() {
  local tool="$1" pattern="$2"
  local IFS='|'
  for p in $pattern; do
    # Support wildcard: mcp__* matches mcp__anything
    if [[ "$p" == *"*" ]]; then
      local prefix="${p%\*}"
      [[ "$tool" == "$prefix"* ]] && return 0
    else
      [ "$tool" = "$p" ] && return 0
    fi
  done
  return 1
}

# Check condition against tool input
check_condition() {
  local cond="$1"
  [ -z "$cond" ] && return 0

  local file_path
  file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // .url // empty' 2>/dev/null)
  [ -z "$file_path" ] && return 1

  if [[ "$cond" =~ ^path[[:space:]]+matches[[:space:]]+(.+)$ ]]; then
    local globs="${BASH_REMATCH[1]}"
    local IFS='|'
    for g in $globs; do
      case "$file_path" in *${g}) return 0;; esac
    done
  fi
  return 1
}

# Process policies (sorted by priority descending)
while IFS='|' read -r pri pattern action condition reason; do
  [ -z "$pattern" ] && continue
  match_tool "$TOOL_NAME" "$pattern" || continue
  check_condition "$condition" || continue

  case "$action" in
    allow) exit 0 ;;
    deny)
      jq -n --arg r "${reason:-Policy denied}" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("[HOOK:tool-policy] DENIED: " + $r)}}'
      exit 2 ;;
    warn)
      jq -n --arg r "${reason:-Policy warning}" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:tool-policy] WARNING: " + $r + " | DO: Verify this action is intentional")}}'
      exit 0 ;;
    ask)
      jq -n --arg r "${reason:-Policy requires approval}" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("[HOOK:tool-policy] ASK: " + $r)}}'
      exit 2 ;;
  esac
done < <(parse_policies)

# Default: allow
exit 0
