#!/usr/bin/env bash
# proactive-skill-trigger.sh — PostToolUse hook for Write|Edit
# Auto-triggers relevant skills based on file patterns being edited.
# Outputs JSON additionalContext so directives reach the agent's context.
# Deduplicates within session (each skill suggested at most once).
#
# Pattern matching delegated to shared lib: .claude/lib/skill-routes.sh

# Source shared lookup table
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
# shellcheck source=../lib/skill-routes.sh
source "$_LIB_DIR/skill-routes.sh" 2>/dev/null || exit 0

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)

# Extract file_path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.relative_path // empty' 2>/dev/null || echo "")
[[ -z "$FILE_PATH" ]] && exit 0

FILENAME=$(basename "$FILE_PATH")
FILEPATH_LOWER=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

# Skip test files — they don't need skill suggestions
is_hook_bypass_path "$FILEPATH_LOWER" && exit 0

# Session dedup — each skill fires at most once per session
PROJECT_KEY="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER_HASH=$(echo "$PROJECT_KEY" | md5sum | cut -c1-8)
MARKER_FILE="/tmp/claude-skill-triggers-${MARKER_HASH}"
touch "$MARKER_FILE"

# Collect matched skills via shared lookup
declare -a MATCHED_SKILLS=()
declare -a MATCHED_MSGS=()

# Get all matching skills from shared table
while IFS=$'\t' read -r skill msg; do
  [[ -z "$skill" ]] && continue
  if ! grep -qF "$skill" "$MARKER_FILE" 2>/dev/null; then
    echo "$skill" >> "$MARKER_FILE"
    MATCHED_SKILLS+=("$skill")
    MATCHED_MSGS+=("$msg")
  fi
done < <(classify_all_skills "$FILEPATH_LOWER" "$FILENAME")

# PTC check (requires file content inspection — stays inline)
FILENAME_LOWER=$(echo "$FILENAME" | tr '[:upper:]' '[:lower:]')
if [[ "$FILENAME_LOWER" == *agent*.py || "$FILENAME_LOWER" == *ptc* || \
      "$FILEPATH_LOWER" == */agents/*.py || "$FILEPATH_LOWER" == */tools/*.py ]]; then
  if [[ -f "$FILE_PATH" ]] && grep -qE 'allowed_callers|code_execution_202[56]' "$FILE_PATH" 2>/dev/null; then
    if ! grep -qF "programmatic-tool-calling" "$MARKER_FILE" 2>/dev/null; then
      echo "programmatic-tool-calling" >> "$MARKER_FILE"
      MATCHED_SKILLS+=("programmatic-tool-calling")
      MATCHED_MSGS+=("PTC agent code ($FILENAME) — use async tool orchestration patterns")
    fi
  fi
fi

# ─── OUTPUT (JSON additionalContext, or silent exit) ───

if [ ${#MATCHED_SKILLS[@]} -eq 0 ]; then
    exit 0
fi

MSG="[HOOK:skill-route] REQUIRED — Load before writing code:"
for i in "${!MATCHED_SKILLS[@]}"; do
    MSG="${MSG}\n  DO: Skill(\"${MATCHED_SKILLS[$i]}\") — ${MATCHED_MSGS[$i]}"
done
MSG="${MSG}\n  NEXT: Invoke ALL matched skills, then proceed with implementation"

jq -n --arg msg "$MSG" '{
    hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $msg
    }
}'

exit 0
