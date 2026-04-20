#!/bin/bash
# hook-protocol.sh — Compact structured output for hook signals
#
# Replaces English prose with machine-parseable key-value signals.
# Models attend to structured key-value format >> natural language prose.
# Token savings: ~65% vs ACTION REQUIRED boxes, ~80% vs free-form prose.
#
# Signal format (inside JSON additionalContext/permissionDecisionReason):
#   allow:  [HOOK:name] context | DO: action | NEXT: escalation
#   deny:   BLOCKED[name]: context | DO: alternative
#
# Usage:
#   source .claude/lib/hook-protocol.sh
#   hook_signal PostToolUse allow test-reminder "Modified auth.ts" "Run: npm test -- auth"
#   hook_signal PreToolUse deny review-gate "87L changed, no audit" "Run: multi-model-audit.sh --diff main"
#   hook_signal PreToolUse allow security "SQL concat in query.ts" "Use parameterized queries" "DENY on repeat"

[[ -n "${_HOOK_PROTOCOL_LOADED:-}" ]] && return 0
_HOOK_PROTOCOL_LOADED=1

# hook_signal EVENT DECISION HOOK_NAME CONTEXT ACTION [ESCALATION]
hook_signal() {
  local event="$1" decision="$2" hook="$3" context="$4" action="${5:-}" escalation="${6:-}"
  local signal=""

  case "$decision" in
    deny|block)
      signal="BLOCKED[${hook}]: ${context}"
      [[ -n "$action" ]] && signal="${signal} | DO: ${action}"
      ;;
    allow)
      signal="[HOOK:${hook}] ${context}"
      [[ -n "$action" ]] && signal="${signal} | DO: ${action}"
      [[ -n "$escalation" ]] && signal="${signal} | NEXT: ${escalation}"
      ;;
  esac

  _hook_emit_json "$event" "$decision" "$signal"
}

# hook_signal_multi EVENT DECISION HOOK_NAME CONTEXT ITEMS_STRING [ESCALATION]
# ITEMS_STRING: newline-separated lines appended after context
hook_signal_multi() {
  local event="$1" decision="$2" hook="$3" context="$4" items="$5" escalation="${6:-}"
  local signal=""

  case "$decision" in
    deny|block)
      signal="BLOCKED[${hook}]: ${context}"
      ;;
    allow)
      signal="[HOOK:${hook}] ${context}"
      ;;
  esac

  [[ -n "$items" ]] && signal="${signal}
${items}"
  [[ -n "$escalation" ]] && signal="${signal}
NEXT: ${escalation}"

  _hook_emit_json "$event" "$decision" "$signal"
}

# Internal: emit correct JSON schema for event type
_hook_emit_json() {
  local event="$1" decision="$2" signal="$3"

  case "$event" in
    PreToolUse)
      if [[ "$decision" == "deny" ]]; then
        jq -n --arg e "$event" --arg r "$signal" \
          '{hookSpecificOutput:{hookEventName:$e,permissionDecision:"deny",permissionDecisionReason:$r}}'
      else
        jq -n --arg e "$event" --arg c "$signal" \
          '{hookSpecificOutput:{hookEventName:$e,permissionDecision:"allow",additionalContext:$c}}'
      fi
      ;;
    PostToolUse)
      jq -n --arg e "$event" --arg c "$signal" \
        '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
      ;;
    UserPromptSubmit)
      if [[ "$decision" == "block" ]]; then
        jq -n --arg c "$signal" \
          '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c},decision:"block"}'
      else
        jq -n --arg c "$signal" \
          '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
      fi
      ;;
    PermissionRequest)
      if [[ "$decision" == "deny" ]]; then
        jq -n --arg m "$signal" \
          '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"deny",message:$m}}}'
      else
        jq -n '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"allow"}}}'
      fi
      ;;
    Stop|SubagentStop)
      # Stop/SubagentStop: block uses top-level decision/reason; advisory uses systemMessage
      # hookSpecificOutput is NOT supported for Stop events
      if [[ "$decision" == "block" ]]; then
        jq -n --arg r "$signal" '{decision:"block",reason:$r}'
      elif [[ -n "$signal" ]]; then
        jq -n --arg c "$signal" '{systemMessage:$c}'
      fi
      ;;
    *)
      # All other events (SessionStart, PreCompact, SubagentStart, Notification, etc.)
      # These do NOT support hookSpecificOutput — use top-level systemMessage instead.
      # Only PreToolUse, PostToolUse, UserPromptSubmit support hookSpecificOutput.
      if [[ -n "$signal" ]]; then
        jq -n --arg c "$signal" '{systemMessage:$c}'
      fi
      ;;
  esac
}
