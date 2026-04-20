#!/usr/bin/env bash
set -euo pipefail

# version-check.sh — Detect Claude Code version changes and alert for changelog review
#
# Usage:
#   bash .claude/scripts/version-check.sh           # Check and alert if version changed
#   bash .claude/scripts/version-check.sh --show    # Show current version info
#   bash .claude/scripts/version-check.sh --update  # Force update cached version (no alert)
#
# Cached version stored in .claude/.claude-code-version
# Knowledge cache entry: claude-code-changelog

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VERSION_FILE="$PROJECT_ROOT/.claude/.claude-code-version"
CHANGELOG_CACHE="$PROJECT_ROOT/.claude/.knowledge/topics/claude-code-changelog.md"

MODE="${1:---check}"

CURRENT_VERSION="$(claude --version 2>/dev/null | head -1 | grep -oP '[\d.]+' || echo unknown)"

show_mode() {
    echo "Current version: $CURRENT_VERSION"

    if [[ -f "$VERSION_FILE" ]]; then
        CACHED_VERSION="$(cat "$VERSION_FILE")"
        echo "Cached version:  $CACHED_VERSION"

        if [[ "$CURRENT_VERSION" != "$CACHED_VERSION" ]]; then
            echo "Status:  VERSION CHANGED"
        else
            echo "Status:  Up to date"
        fi
    else
        echo "Cached version:  (none)"
        echo "Status:  No cache"
    fi

    if [[ -f "$CHANGELOG_CACHE" ]]; then
        CACHE_SECONDS=$(($(date +%s) - $(stat -c %Y "$CHANGELOG_CACHE" 2>/dev/null || echo "0")))
        CACHE_AGE_DAYS=$((CACHE_SECONDS / 86400))
        echo "Changelog cache: ${CACHE_AGE_DAYS}d old"
    else
        echo "Changelog cache: not found"
    fi
}

update_mode() {
    echo "$CURRENT_VERSION" > "$VERSION_FILE"
    echo "Cached version updated to $CURRENT_VERSION"
}

check_mode() {
    if [[ "$CURRENT_VERSION" == "unknown" ]]; then
        exit 0
    fi

    if [[ ! -f "$VERSION_FILE" ]]; then
        # First run — cache current version silently
        echo "$CURRENT_VERSION" > "$VERSION_FILE"
        exit 0
    fi

    CACHED_VERSION="$(cat "$VERSION_FILE")"

    if [[ "$CURRENT_VERSION" != "$CACHED_VERSION" ]]; then
        echo "Claude Code updated: $CACHED_VERSION → $CURRENT_VERSION"
        echo "ACTION: Review changelog for native feature overlap before using kit features."
        echo "  Changelog: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md"
        echo "  Knowledge cache: bash .claude/scripts/knowledge-cache.sh --get claude-code-changelog"

        # Update cached version
        echo "$CURRENT_VERSION" > "$VERSION_FILE"

        # Auto-check docs for content changes on version update
        DOCS_CHECK="$SCRIPT_DIR/check-claude-docs.sh"
        if [[ -x "$DOCS_CHECK" ]]; then
            echo ""
            bash "$DOCS_CHECK" --check
        fi

        # Also check Ollama docs for changes
        OLLAMA_DOCS_CHECK="$SCRIPT_DIR/check-ollama-docs.sh"
        if [[ -x "$OLLAMA_DOCS_CHECK" ]]; then
            echo ""
            bash "$OLLAMA_DOCS_CHECK" --check
        fi

        # Auto-run RE changelog analysis on version change
        RE_CHANGELOG="$SCRIPT_DIR/re-changelog.sh"
        if [[ -x "$RE_CHANGELOG" ]]; then
            echo ""
            echo "Running changelog analysis for kit improvement opportunities..."
            bash "$RE_CHANGELOG" --full 2>/dev/null || true
        fi
    fi
}

case "$MODE" in
    --show)   show_mode ;;
    --update) update_mode ;;
    --check)  check_mode ;;
    *)        check_mode ;;
esac

exit 0
