#!/usr/bin/env bash
# Claude Code Agent Kit — one-command installer.
#
# Usage:
#   ./install.sh [target-dir] [--profile minimal|standard] [--force]
#
# If target-dir is omitted, installs into the current directory.
# Safe to re-run (idempotent): backs up existing .claude/settings.local.json.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$PWD}"
PROFILE="standard"
FORCE=0

# Parse args
shift 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [ "$TARGET" = "--profile" ] || [ "$TARGET" = "--force" ]; then
  echo "Missing target directory before flags." >&2
  exit 1
fi

TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

c_red()   { printf "\033[31m%s\033[0m" "$*"; }
c_green() { printf "\033[32m%s\033[0m" "$*"; }
c_yellow(){ printf "\033[33m%s\033[0m" "$*"; }
c_bold()  { printf "\033[1m%s\033[0m" "$*"; }

info() { printf "  %s\n" "$*"; }
ok()   { printf "  $(c_green ✓) %s\n" "$*"; }
warn() { printf "  $(c_yellow !) %s\n" "$*"; }
fail() { printf "  $(c_red ✗) %s\n" "$*" >&2; exit 1; }

echo
echo "$(c_bold 'Claude Code Agent Kit') — installer"
echo "  Kit:     $KIT_DIR"
echo "  Target:  $TARGET"
echo "  Profile: $PROFILE"
echo

# ── 1. Prerequisites ───────────────────────────────────────────────
echo "$(c_bold 'Checking prerequisites')"

case "$(uname -s)" in
  Linux*)  OS=linux ;;
  Darwin*) OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  *) OS=unknown ;;
esac

if grep -qi microsoft /proc/version 2>/dev/null; then OS=wsl; fi
info "Platform: $OS"

for cmd in bash jq git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd: $(command -v "$cmd")"
  else
    fail "$cmd is required. Install it and rerun."
  fi
done

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI: $(claude --version 2>/dev/null | head -1 || echo detected)"
else
  warn "claude CLI not found — kit will install but Claude Code won't run."
  warn "Install: https://docs.anthropic.com/en/docs/claude-code"
fi

if [ ! -d "$TARGET" ]; then
  info "Target doesn't exist — creating: $TARGET"
  mkdir -p "$TARGET"
fi

if [ ! -f "$KIT_DIR/.claude/profiles/${PROFILE}.json" ]; then
  fail "Unknown profile: $PROFILE (available: $(ls "$KIT_DIR/.claude/profiles/" | sed 's/\.json$//' | tr '\n' ' '))"
fi

echo

# ── 2. Back up any existing install ────────────────────────────────
echo "$(c_bold 'Preparing target')"

BACKUP_DIR=""
if [ -d "$TARGET/.claude" ] && [ "$FORCE" -eq 0 ]; then
  BACKUP_DIR="$TARGET/.claude.backup.$(date +%Y%m%d-%H%M%S)"
  info "Existing .claude/ found — backing up to ${BACKUP_DIR##*/}"
  mv "$TARGET/.claude" "$BACKUP_DIR"
fi

if [ -f "$TARGET/CLAUDE.md" ] && [ "$FORCE" -eq 0 ]; then
  info "Existing CLAUDE.md → CLAUDE.md.bak"
  mv "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.md.bak"
fi

echo

# ── 3. Install kit files ───────────────────────────────────────────
echo "$(c_bold 'Installing kit files')"

mkdir -p "$TARGET/.claude"

# Copy kit bones. Use rsync if available (excludes dotfiles/state), else cp.
if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '.git' --exclude '.DS_Store' --exclude '*.backup' \
    --exclude 'install.sh' \
    "$KIT_DIR/.claude/" "$TARGET/.claude/"
else
  cp -R "$KIT_DIR/.claude/." "$TARGET/.claude/"
fi

for f in CLAUDE.md AGENTS.md; do
  if [ -f "$KIT_DIR/$f" ]; then
    cp "$KIT_DIR/$f" "$TARGET/$f"
  fi
done

# Ensure every hook is executable.
find "$TARGET/.claude/hooks" -name '*.sh' -exec chmod +x {} \;
find "$TARGET/.claude/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null
find "$TARGET/.claude/scripts/lib" -name '*.sh' -exec chmod +x {} \; 2>/dev/null

ok "Files copied ($(find "$TARGET/.claude" -type f | wc -l) files)"

echo

# ── 4. Apply selected profile ──────────────────────────────────────
echo "$(c_bold 'Applying profile: ')$PROFILE"

bash "$TARGET/.claude/scripts/apply-profile.sh" "$PROFILE"

echo

# ── 5. Optional: secrets file ──────────────────────────────────────
SECRETS_FILE="$HOME/.claude-secrets"
if [ ! -f "$SECRETS_FILE" ]; then
  info "No ~/.claude-secrets found. Creating template (optional)."
  cat > "$SECRETS_FILE" <<'EOF'
# ~/.claude-secrets — sourced by session hooks.
# Any keys that are set activate the matching tier/feature.
# export ANTHROPIC_API_KEY=""
# export OPENAI_API_KEY=""
# export GEMINI_API_KEY=""
# export DEEPSEEK_API_KEY=""
# export OLLAMA_API_KEY=""       # Ollama Cloud ($0/$20/$100 tiers)
# export GITHUB_TOKEN=""
EOF
  chmod 600 "$SECRETS_FILE"
  ok "Created: $SECRETS_FILE"
else
  ok "Secrets file exists: $SECRETS_FILE"
fi

echo

# ── 6. Final output ────────────────────────────────────────────────
echo "$(c_bold 'Installation complete')"
echo
echo "  Next steps:"
echo "    1. cd $TARGET"
echo "    2. (optional) edit ~/.claude-secrets to enable worker tiers"
echo "    3. Run: claude"
echo
echo "  Change profile later: bash .claude/scripts/apply-profile.sh minimal"
if [ -n "$BACKUP_DIR" ]; then
  echo "  Your previous .claude/ is at: ${BACKUP_DIR##*/}"
fi
echo
