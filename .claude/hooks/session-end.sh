#!/bin/bash
# Hook: SessionEnd — log session stats + reverse-sync staging
# Event: SessionEnd
# Purpose: (1) Track session activity in a persistent log file
#          (2) Package kit-universal file changes for reverse-sync
#
# NOTE: SessionEnd has NO additionalContext support (silently ignored).
# This hook only does side-effects: file logging + staging.

source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || true
source "${BASH_SOURCE[0]%/*}/../lib/state-manager.sh" 2>/dev/null || true
source "${BASH_SOURCE[0]%/*}/../lib/event-bus.sh" 2>/dev/null || true
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# Plugin-compatible script resolution
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/.claude/scripts}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${KIT_ROOT:+${KIT_ROOT}/.claude/scripts}}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/.claude/scripts}"
LOG_DIR="$PROJECT_DIR/.claude"
mkdir -p "$LOG_DIR"

# Git stats
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git")
COMMITS=$(git -C "$PROJECT_DIR" rev-list --since="2 hours ago" --count HEAD 2>/dev/null || echo "0")
CHANGES=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Log session end via state-manager + event-bus (with fallbacks)
ENTRY="{\"ts\":\"$(date -Iseconds)\",\"event\":\"session_end\",\"branch\":\"$BRANCH\",\"commits\":$COMMITS,\"uncommitted\":$CHANGES}"
if type -t state_append &>/dev/null; then
  state_append audit "$ENTRY"
else
  echo "[$(date -Iseconds)] End | Branch: $BRANCH | Commits(2h): $COMMITS | Uncommitted: $CHANGES" >> "$LOG_DIR/session-log.txt"
fi
if type -t event_publish &>/dev/null; then
  event_publish "session" "$ENTRY" 2>/dev/null
else
  bash "$SCRIPTS_DIR/event-log.sh" emit "session_end" "session-end.sh" \
    "{\"branch\":\"$BRANCH\",\"commits\":$COMMITS,\"uncommitted\":$CHANGES}" 2>/dev/null &
fi

# Clean expired tokens
bash "$SCRIPTS_DIR/cleanup-tokens.sh" sweep 2>/dev/null &

# Capture session to _sessions branch (async, fire-and-forget)
bash "$SCRIPTS_DIR/session-capture.sh" --end >/dev/null 2>&1 &

# ── Reverse-sync enrichment ───────────────────────────────────────────
# Files are already staged eagerly by reverse-sync-detect.sh (PostToolUse).
# Here we just enrich the manifest with git diffs and clean up the tracking file.

TRACK_FILE="$PROJECT_DIR/.claude/.reverse-sync-session.jsonl"
PROJECT_NAME=$(basename "$PROJECT_DIR")
SESSION_DATE=$(date +%Y-%m-%d)
MANIFEST="$HOME/.claude/reverse-sync/$PROJECT_NAME/$SESSION_DATE/MANIFEST.json"

if [ -f "$MANIFEST" ]; then
  # Enrich each file entry with lines_changed from git diff
  FILE_COUNT=$(jq '.files | length' "$MANIFEST" 2>/dev/null || echo "0")
  idx=0
  while [ "$idx" -lt "${FILE_COUNT:-0}" ]; do
    REL_PATH=$(jq -r ".files[$idx].path" "$MANIFEST" 2>/dev/null)
    if [ -n "$REL_PATH" ] && [ "$REL_PATH" != "null" ]; then
      DIFF_TEXT=""
      if git -C "$PROJECT_DIR" ls-files --error-unmatch "$REL_PATH" >/dev/null 2>&1; then
        DIFF_TEXT=$(git -C "$PROJECT_DIR" diff HEAD -- "$REL_PATH" 2>/dev/null || true)
        [ -z "$DIFF_TEXT" ] && DIFF_TEXT=$(git -C "$PROJECT_DIR" diff --cached -- "$REL_PATH" 2>/dev/null || true)
      fi
      LINES_CHANGED=0
      [ -n "$DIFF_TEXT" ] && LINES_CHANGED=$(echo "$DIFF_TEXT" | wc -l | tr -d ' ')
      jq --argjson idx "$idx" --argjson lc "$LINES_CHANGED" \
        '.files[$idx].lines_changed = $lc' \
        "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
    fi
    idx=$((idx + 1))
  done
fi

# Cleanup tracking file
rm -f "$TRACK_FILE"

exit 0
