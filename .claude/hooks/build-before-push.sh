#!/bin/bash
# Hook: Suggest running build before pushing
# PreToolUse hook (matcher: Bash)
#
# Advisory only — never blocks. Reminds to run build before git push
# when a package.json with a build script exists in the project root.

source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || true
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check commands containing git push
if ! echo "$COMMAND" | grep -qE 'git\s+push\b'; then
  exit 0
fi

# Exclude dry-run and help
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--(dry-run|help)'; then
  exit 0
fi

# Look for package.json in project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# Plugin-compatible script resolution
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/.claude/scripts}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${KIT_ROOT:+${KIT_ROOT}/.claude/scripts}}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/.claude/scripts}"
PKG_FILE="${PROJECT_DIR}/package.json"

# Exit silently if not a Node project
if [ ! -f "$PKG_FILE" ]; then
  exit 0
fi

# Check if package.json contains a "build" script
if ! jq -e '.scripts.build' "$PKG_FILE" >/dev/null 2>&1; then
  exit 0
fi

# Build signal
BUILD_ACTION="Run: npm run build (or equivalent) before push"

# Multi-model security scan (opt-in via MULTI_MODEL_PRE_PUSH=true)
if [ "${MULTI_MODEL_PRE_PUSH:-false}" = "true" ]; then
  AUDIT_SCRIPT="$SCRIPTS_DIR/multi-model-audit.sh"
  if [ -f "$AUDIT_SCRIPT" ]; then
    BUILD_ACTION="${BUILD_ACTION} + /audit --diff HEAD~1 --focus security"
  fi
fi

jq -n --arg a "$BUILD_ACTION" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",additionalContext:("[HOOK:build] Pushing without build check | DO: " + $a)}}'

exit 0
