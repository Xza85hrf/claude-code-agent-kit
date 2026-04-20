#!/bin/bash
#
# blast-radius-check.sh — PreToolUse:Bash advisory hook
# Shows downstream impacts when committing kit files.
# Always allows (advisory only, never blocking).
#
# Read stdin JSON and extract command
INPUT_JSON=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT_JSON" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Early exit: not a git commit
if [[ -z "$COMMAND" ]] || ! echo "$COMMAND" | grep -qE 'git\s+commit\b'; then
  exit 0
fi

SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/.claude/scripts}"
SCRIPT_DIR="${SCRIPT_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/scripts}"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "$LIB_DIR/hook-protocol.sh" 2>/dev/null || true

# Skip amend, help, dry-run
if echo "$COMMAND" | grep -qE '(--amend|--help|--dry-run)'; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Get staged files
STAGED=$(cd "$PROJECT_DIR" && git diff --cached --name-only 2>/dev/null || echo "")
[[ -z "$STAGED" ]] && exit 0

# Filter to kit files only
KIT_FILES=()
while IFS= read -r f; do
  case "$f" in
    .claude/*|CLAUDE.md|AGENTS.md|hooks/*|docs/*|launch-claude.sh|.mcp.json|.claude-plugin/*)
      KIT_FILES+=("$f")
      ;;
  esac
done <<< "$STAGED"

[[ ${#KIT_FILES[@]} -eq 0 ]] && exit 0

# Check for impacts (quiet mode: exit 1 = has impacts)
if ! bash "$SCRIPT_DIR/blast-radius.sh" --quiet "${KIT_FILES[@]}" 2>/dev/null; then
  IMPACT_SUMMARY=$(bash "$SCRIPT_DIR/blast-radius.sh" "${KIT_FILES[@]}" 2>/dev/null | head -40)

  hook_signal_multi PreToolUse allow blast-radius \
    "${#KIT_FILES[@]} kit files have downstream impacts" \
    "$IMPACT_SUMMARY" \
    "Unaddressed impacts may break plugin/synced projects"
fi

exit 0
