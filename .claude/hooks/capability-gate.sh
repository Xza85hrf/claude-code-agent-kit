#!/bin/bash
# Hook: Capability pipeline enforcement gate
# PreToolUse hook (matcher: Write|Edit)
#
# DESIGN: Prevents the agent from bypassing the multi-model pipeline
# for design-heavy files. Checks for .capability-pipeline-token
# (created by capability-tracker.sh after MCP tool usage).
#
# Design-heavy = pages, layouts, heroes, CSS, HTML, animations
# Functional = tests, hooks, utils, API, services, schemas, types
#
# Modes:
#   enforced (default) — BLOCKs design writes without token
#   advisory — warns but allows
#   off — disabled entirely

CAPABILITY_GATE="${CAPABILITY_GATE:-enforced}"
CAPABILITY_TOKEN_TTL="${CAPABILITY_TOKEN_TTL:-3600}"

[ "$CAPABILITY_GATE" = "off" ] && exit 0
if [ -z "${LAUNCH_MODE:-}" ]; then
  for _lm_dir in "${CLAUDE_PROJECT_DIR:-.}" "$(git rev-parse --show-toplevel 2>/dev/null)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" "$HOME"; do
    [ -n "$_lm_dir" ] && [ -f "$_lm_dir/.claude/.launch-mode" ] && { LAUNCH_MODE=$(cat "$_lm_dir/.claude/.launch-mode" 2>/dev/null); break; }
  done
fi
[ "${LAUNCH_MODE:-opus}" = "ollama" ] && exit 0

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

FILENAME=$(basename "$FILE_PATH")
FILEPATH_LOWER=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')
FILENAME_LOWER=$(echo "$FILENAME" | tr '[:upper:]' '[:lower:]')
EXT="${FILENAME_LOWER##*.}"

# ─── BYPASS: functional files, tests, config, docs, scripts ───
case "$FILENAME_LOWER" in
  *.test.*|*.spec.*|test_*) exit 0 ;;
  *hook*|*util*|*helper*|*lib*) exit 0 ;;
  *service*|*api*|*handler*|*middleware*) exit 0 ;;
  *schema*|*model*|*type*|*interface*) exit 0 ;;
  *config*|*env*|*.json|*.yaml|*.yml|*.toml) exit 0 ;;
  *.md|*.txt|*.log|*.sh) exit 0 ;;
  *store*|*reducer*|*context*|*provider*) exit 0 ;;
  *route*|*router*) exit 0 ;;
esac

case "$FILEPATH_LOWER" in
  */hooks/*|*/utils/*|*/lib/*|*/helpers/*) exit 0 ;;
  */api/*|*/routes/*|*/services/*|*/middleware/*) exit 0 ;;
  */tests/*|*__tests__*|*/e2e/*) exit 0 ;;
  */types/*|*/schemas/*|*/models/*) exit 0 ;;
  */.claude/*|*/.github/*|*/node_modules/*) exit 0 ;;
  */server/*|*/scripts/*) exit 0 ;;
esac

# ─── DETECT: design-heavy files ───
IS_DESIGN=false

case "$FILENAME_LOWER" in
  *page*.*sx|*page*.*ue|*page*.*velte) IS_DESIGN=true ;;
  *layout*.*sx|*layout*.*ue) IS_DESIGN=true ;;
  *hero*|*landing*|*home*.*sx|*home*.*ue) IS_DESIGN=true ;;
  *animation*|*motion*|*transition*) IS_DESIGN=true ;;
  *theme*|*global*.css|*app*.css|*index*.css) IS_DESIGN=true ;;
  *section*.*sx|*section*.*ue) IS_DESIGN=true ;;
  *footer*.*sx|*nav*.*sx|*header*.*sx) IS_DESIGN=true ;;
esac

case "$EXT" in
  css|scss|sass|less) IS_DESIGN=true ;;
  html) IS_DESIGN=true ;;
esac

case "$FILEPATH_LOWER" in
  */pages/*|*/views/*|*/layouts/*|*/sections/*) IS_DESIGN=true ;;
  */components/*hero*|*/components/*nav*|*/components/*footer*) IS_DESIGN=true ;;
  */components/*header*|*/components/*banner*) IS_DESIGN=true ;;
esac

[ "$IS_DESIGN" = false ] && exit 0

# ─── TOKEN CHECK ───
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
[[ -f "$_LIB_DIR/state-manager.sh" ]] && source "$_LIB_DIR/state-manager.sh" 2>/dev/null

if type -t state_exists &>/dev/null; then
  # State-manager path: TTL-validated checks (priority order)
  state_exists token "skill-frontend-design-pro" && exit 0
  state_exists token "skill-frontend-engineering" && exit 0
  state_exists token "capability-pipeline" && exit 0
  state_exists token delegation && exit 0
else
  # Fallback: direct file checks
  TOKEN_BASE="${CLAUDE_PROJECT_DIR:-.}/.claude"
  NOW=$(date +%s)
  for skill_token in "$TOKEN_BASE/.tokens/skill-frontend-design-pro.token" "$TOKEN_BASE/.tokens/skill-frontend-engineering.token"; do
    [ -f "$skill_token" ] && { TOKEN_TIME=$(cat "$skill_token" 2>/dev/null); [ $((NOW - TOKEN_TIME)) -le 1800 ] 2>/dev/null && exit 0; }
  done
  for tf in "$TOKEN_BASE/.tokens/capability-pipeline.token" "$TOKEN_BASE/.capability-pipeline-token"; do
    [ -f "$tf" ] && { TOKEN_TIME=$(cat "$tf" 2>/dev/null); [ $((NOW - TOKEN_TIME)) -le "$CAPABILITY_TOKEN_TTL" ] 2>/dev/null && exit 0; }
  done
  for tf in "$TOKEN_BASE/.tokens/delegation.token" "$TOKEN_BASE/.delegation-token"; do
    [ -f "$tf" ] && { TOKEN_TIME=$(cat "$tf" 2>/dev/null); [ $((NOW - TOKEN_TIME)) -le 300 ] 2>/dev/null && exit 0; }
  done
fi

# ─── ENFORCE OR ADVISE ───
FILE_NAME=$(basename "$FILE_PATH")
if [ "$CAPABILITY_GATE" = "enforced" ]; then
  jq -n --arg f "$FILE_NAME" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("BLOCKED[capability]: Design file " + $f + " without pipeline token | DO: Skill(\"frontend-design-pro\") or spawn-worker.sh")}}'
else
  jq -n --arg f "$FILE_NAME" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:capability] Design file " + $f + " | DO: Use Skill(\"frontend-design-pro\") for design thinking")}}'
fi

exit 0
