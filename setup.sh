#!/bin/bash
# Agent Enhancement Kit — Install Script
# Copies hooks, skills, settings, and CLAUDE.md into a target project.
#
# Usage:
#   ./setup.sh                    # Install into current directory
#   ./setup.sh /path/to/project   # Install into specified project
#
# What it does:
#   1. Validates prerequisites (jq)
#   2. Creates .claude/ directory structure
#   3. Copies hooks (with +x permissions)
#   4. Copies skills
#   5. Installs settings.local.json (merges if exists)
#   6. Copies CLAUDE.md to project root
#   7. Copies reference docs to .claude/
#   8. Runs hook self-tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "╔══════════════════════════════════════════════╗"
echo "║     Agent Enhancement Kit — Setup            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Source:  $SCRIPT_DIR"
echo "Target:  $TARGET_DIR"
echo ""

# --- Prerequisites ---
echo "▸ Checking prerequisites..."

if ! command -v jq &> /dev/null; then
  echo "  ✗ jq is required but not installed."
  echo "    Install: sudo apt install jq  (or: brew install jq)"
  exit 1
fi
echo "  ✓ jq found"

if ! command -v bash &> /dev/null; then
  echo "  ✗ bash is required"
  exit 1
fi
echo "  ✓ bash found"
echo ""

# --- Create directory structure ---
echo "▸ Creating directory structure..."
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/skills"
echo "  ✓ .claude/hooks/"
echo "  ✓ .claude/skills/"
echo ""

# --- Copy hooks ---
echo "▸ Installing hooks..."
HOOK_COUNT=0
for hook in "$SCRIPT_DIR"/hooks/*.sh; do
  if [ -f "$hook" ]; then
    cp "$hook" "$TARGET_DIR/.claude/hooks/"
    chmod +x "$TARGET_DIR/.claude/hooks/$(basename "$hook")"
    echo "  ✓ $(basename "$hook")"
    HOOK_COUNT=$((HOOK_COUNT + 1))
  fi
done
echo "  → $HOOK_COUNT hooks installed"
echo ""

# --- Copy skills ---
echo "▸ Installing skills..."
SKILL_COUNT=0
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  if [ -d "$skill_dir" ]; then
    SKILL_NAME="$(basename "$skill_dir")"
    cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/"
    echo "  ✓ $SKILL_NAME"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done
echo "  → $SKILL_COUNT skills installed"
echo ""

# --- Install settings ---
echo "▸ Installing settings..."
if [ -f "$TARGET_DIR/.claude/settings.local.json" ]; then
  echo "  ⚠ settings.local.json already exists — backing up to settings.local.json.bak"
  cp "$TARGET_DIR/.claude/settings.local.json" "$TARGET_DIR/.claude/settings.local.json.bak"
fi
cp "$SCRIPT_DIR/settings.local.json" "$TARGET_DIR/.claude/settings.local.json"
echo "  ✓ settings.local.json installed"
echo ""

# --- Copy CLAUDE.md ---
echo "▸ Installing CLAUDE.md..."
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  echo "  ⚠ CLAUDE.md already exists — backing up to CLAUDE.md.bak"
  cp "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.bak"
fi
cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
echo "  ✓ CLAUDE.md installed at project root"
echo ""

# --- Copy reference docs ---
echo "▸ Installing reference docs..."
DOC_COUNT=0
for doc in "$SCRIPT_DIR"/*.md; do
  BASENAME="$(basename "$doc")"
  # Skip CLAUDE.md (goes to root) and README.md (kit-specific)
  if [ "$BASENAME" = "CLAUDE.md" ] || [ "$BASENAME" = "README.md" ]; then
    continue
  fi
  cp "$doc" "$TARGET_DIR/.claude/"
  echo "  ✓ $BASENAME"
  DOC_COUNT=$((DOC_COUNT + 1))
done
echo "  → $DOC_COUNT docs installed to .claude/"
echo ""

# --- Run self-test if available ---
if [ -f "$TARGET_DIR/.claude/hooks/test-hooks.sh" ]; then
  echo "▸ Running hook self-tests..."
  chmod +x "$TARGET_DIR/.claude/hooks/test-hooks.sh"
  CLAUDE_PROJECT_DIR="$TARGET_DIR" "$TARGET_DIR/.claude/hooks/test-hooks.sh" || true
  echo ""
fi

# --- Summary ---
echo "╔══════════════════════════════════════════════╗"
echo "║     Installation Complete                    ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Installed:"
echo "  • $HOOK_COUNT hooks in .claude/hooks/"
echo "  • $SKILL_COUNT skills in .claude/skills/"
echo "  • settings.local.json in .claude/"
echo "  • CLAUDE.md at project root"
echo "  • $DOC_COUNT reference docs in .claude/"
echo ""
echo "Next steps:"
echo "  1. Review CLAUDE.md and customize the Project-Specific Section"
echo "  2. Review .claude/settings.local.json and adjust permissions"
echo "  3. Start Claude Code in your project: claude"
echo "  4. The agent will operate with enhanced protocols automatically"
echo ""
echo "Optional:"
echo "  • Enable additional MCP plugins in settings.local.json"
echo "  • See .claude/MCP-CATALOG.md for available integrations"
echo "  • Run .claude/hooks/test-hooks.sh to re-verify hooks"
