#!/bin/bash
#
# session-capture.sh - Captures session summaries to a _sessions orphan git branch
# Usage: session-capture.sh [--checkpoint|--end|--list|--resume SESSION_ID]
#
# Writes to _sessions branch via git worktree without affecting working branch.
#

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSIONS_BRANCH="_sessions"
WORKTREE_DIR=""

cd "$PROJECT_DIR" || exit 1

# Check git repo
git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo"; exit 1; }

generate_session_id() {
    echo "${CLAUDE_SESSION_ID:-session-$(date +%Y%m%d-%H%M%S)-$$}"
}

cleanup_worktree() {
    if [ -n "$WORKTREE_DIR" ] && [ -d "$WORKTREE_DIR" ]; then
        git worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
        git worktree prune 2>/dev/null || true
    fi
}
trap cleanup_worktree EXIT

ensure_sessions_branch() {
    if git rev-parse --verify "$SESSIONS_BRANCH" >/dev/null 2>&1; then
        return 0
    fi
    # Save current ref
    local current_ref
    current_ref=$(git rev-parse HEAD 2>/dev/null)
    # Create orphan branch
    git checkout --orphan "$SESSIONS_BRANCH" 2>/dev/null
    git rm -rf . >/dev/null 2>&1 || true
    git commit --allow-empty -m "Initialize _sessions branch" 2>/dev/null
    # Return to original
    git checkout "${current_ref}" 2>/dev/null || git checkout - 2>/dev/null || true
}

create_worktree() {
    ensure_sessions_branch
    WORKTREE_DIR="/tmp/mc-sessions-$$"
    rm -rf "$WORKTREE_DIR"
    git worktree add "$WORKTREE_DIR" "$SESSIONS_BRANCH" 2>/dev/null || return 1
}

do_checkpoint() {
    local session_id timestamp date_dir branch uncommitted_count recent_commits
    session_id=$(generate_session_id)
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    date_dir=$(date +%Y-%m-%d)
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    uncommitted_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    recent_commits=$(git log --oneline -5 2>/dev/null || echo "No commits")

    create_worktree || { echo "Worktree failed, skipping"; exit 0; }

    local session_dir="$WORKTREE_DIR/sessions/$date_dir"
    mkdir -p "$session_dir"

    cat > "$session_dir/${session_id}.md" <<EOF
---
type: checkpoint
branch: $branch
timestamp: $timestamp
session_id: $session_id
uncommitted_files: $uncommitted_count
---

## Checkpoint
Branch: $branch
Uncommitted: $uncommitted_count files

### Recent commits
$recent_commits
EOF

    git -C "$WORKTREE_DIR" add -A
    git -C "$WORKTREE_DIR" commit -m "Checkpoint: $session_id" 2>/dev/null || true
    echo "Checkpoint saved: $session_id"
}

do_end() {
    local session_id timestamp date_dir branch commit_count
    session_id=$(generate_session_id)
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    date_dir=$(date +%Y-%m-%d)
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")

    local pre_compact="" session_log=""
    [ -f ".claude/pre-compact-state.md" ] && pre_compact=$(cat ".claude/pre-compact-state.md")
    [ -f ".claude/session-log.txt" ] && session_log=$(tail -50 ".claude/session-log.txt")

    create_worktree || { echo "Worktree failed, skipping"; exit 0; }

    local session_dir="$WORKTREE_DIR/sessions/$date_dir"
    mkdir -p "$session_dir"

    cat > "$session_dir/${session_id}.md" <<EOF
---
type: session_end
timestamp: $timestamp
session_id: $session_id
branch: $branch
commit_count: $commit_count
---

## Session Summary

$pre_compact

## Session Log (last 50 lines)

\`\`\`
$session_log
\`\`\`
EOF

    git -C "$WORKTREE_DIR" add -A
    git -C "$WORKTREE_DIR" commit -m "Session end: $session_id" 2>/dev/null || true
    echo "Session end saved: $session_id"
}

do_list() {
    if ! git rev-parse --verify "$SESSIONS_BRANCH" >/dev/null 2>&1; then
        echo "No sessions (branch does not exist)"
        return 0
    fi
    echo "Recent sessions:"
    git log "$SESSIONS_BRANCH" --oneline -20 2>/dev/null || true
    echo ""
    echo "Session files:"
    git ls-tree -r --name-only "$SESSIONS_BRANCH" 2>/dev/null | grep '\.md$' | head -20 || true
}

do_resume() {
    local session_id="${1:-}"
    [ -z "$session_id" ] && { echo "Usage: $0 --resume SESSION_ID"; exit 1; }

    git rev-parse --verify "$SESSIONS_BRANCH" >/dev/null 2>&1 || { echo "No sessions"; exit 1; }

    local path
    path=$(git ls-tree -r --name-only "$SESSIONS_BRANCH" 2>/dev/null | grep "${session_id}.md" | head -1)
    [ -z "$path" ] && { echo "Session not found: $session_id"; exit 1; }

    git show "$SESSIONS_BRANCH:$path"
}

case "${1:-}" in
    --checkpoint) do_checkpoint ;;
    --end)        do_end ;;
    --list)       do_list ;;
    --resume)     do_resume "${2:-}" ;;
    *)            echo "Usage: $0 --checkpoint|--end|--list|--resume SESSION_ID"; exit 1 ;;
esac
