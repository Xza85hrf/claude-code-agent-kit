#!/bin/bash
# Hook: Structural skill enforcement gate
# PreToolUse hook (matcher: Write|Edit)
#
# DESIGN: Blocks writes to domain-specific files unless the matching skill
# was loaded this session. Prevents the model from skipping the pipeline.
#
# Based on Anthropic's harness design research: "Separating evaluation from
# generation is far more tractable than making a generator critical of its own work."
# This hook makes skill-loading structural, not advisory.
#
# Token files: .claude/.tokens/skill-{name}.token (created by skill-token.sh)

SKILL_GATE="${SKILL_GATE:-enforced}"
[ "$SKILL_GATE" = "off" ] && exit 0

# Source shared lookup table
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
# shellcheck source=../lib/skill-routes.sh
source "$_LIB_DIR/skill-routes.sh" 2>/dev/null || { echo "skill-routes.sh not found" >&2; exit 0; }

# Skip in ollama-primary mode
is_ollama_launch_mode && exit 0

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

FILEPATH_LOWER=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

# ─── BYPASS: small edits, kit files, config, tests, types ───

# Small edits don't need skill loading (Edit tool only)
if [ "$TOOL_NAME" = "Edit" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
  LINE_COUNT=$(echo "$CONTENT" | wc -l)
  [ "$LINE_COUNT" -le 10 ] && exit 0
fi

# Shared bypass check (kit infra, config, docs, tests, types)
is_hook_bypass_path "$FILEPATH_LOWER" && exit 0

# ─── DOMAIN DETECTION: map file patterns to required skills ───
REQUIRED_SKILL=$(classify_gate_skill "$FILEPATH_LOWER")
[ -z "$REQUIRED_SKILL" ] && exit 0

# ─── TOKEN CHECK: was the required skill loaded? ───
# Uses state-manager for TTL-validated token checks
# shellcheck source=../lib/state-manager.sh
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null

if type -t state_exists &>/dev/null; then
  # State-manager path: TTL-validated checks
  state_exists token "skill-${REQUIRED_SKILL}" && exit 0

  # Accept related skills
  case "$REQUIRED_SKILL" in
    frontend-engineering) state_exists token "skill-frontend-design-pro" && exit 0 ;;
    frontend-design-pro)  state_exists token "skill-frontend-engineering" && exit 0 ;;
  esac

  # Delegation token as escape hatch
  state_exists token delegation && exit 0
else
  # Fallback: direct file checks (state-manager unavailable)
  TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.tokens"
  NOW=$(date +%s)
  for token_name in "skill-${REQUIRED_SKILL}" delegation; do
    local_file="$TOKEN_DIR/${token_name}.token"
    if [ -f "$local_file" ]; then
      TOKEN_TIME=$(cat "$local_file" 2>/dev/null)
      case "$token_name" in
        skill-*) ttl=1800 ;; delegation) ttl=300 ;; *) ttl=300 ;;
      esac
      [ $((NOW - TOKEN_TIME)) -le "$ttl" ] 2>/dev/null && exit 0
    fi
  done
  # Related skill fallback
  case "$REQUIRED_SKILL" in
    frontend-engineering)
      [ -f "$TOKEN_DIR/skill-frontend-design-pro.token" ] && {
        TOKEN_TIME=$(cat "$TOKEN_DIR/skill-frontend-design-pro.token" 2>/dev/null)
        [ $((NOW - TOKEN_TIME)) -le 1800 ] 2>/dev/null && exit 0
      } ;;
    frontend-design-pro)
      [ -f "$TOKEN_DIR/skill-frontend-engineering.token" ] && {
        TOKEN_TIME=$(cat "$TOKEN_DIR/skill-frontend-engineering.token" 2>/dev/null)
        [ $((NOW - TOKEN_TIME)) -le 1800 ] 2>/dev/null && exit 0
      } ;;
  esac
fi

# ─── ENFORCE OR ADVISE ───
FILE_NAME=$(basename "$FILE_PATH")
if [ "$SKILL_GATE" = "enforced" ]; then
  jq -n --arg f "$FILE_NAME" --arg skill "$REQUIRED_SKILL" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("BLOCKED[skill-gate]: " + $f + " requires Skill(\"" + $skill + "\") — load the skill FIRST, then write code.\n\nThe skill provides domain-specific patterns, quality criteria, and pipeline context.\nAfter loading, your writes will be auto-allowed for 30 minutes.\n\nDO: Skill(\"" + $skill + "\")")
    }
  }'
else
  jq -n --arg f "$FILE_NAME" --arg skill "$REQUIRED_SKILL" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("[HOOK:skill-gate] " + $f + " → Skill(\"" + $skill + "\") recommended | DO: Load skill for domain-specific patterns")
    }
  }'
fi

exit 0
