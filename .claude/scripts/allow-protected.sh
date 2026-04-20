#!/usr/bin/env bash
# allow-protected.sh — Run a single command with damage-control bypass
#
# Usage:
#   bash .claude/scripts/allow-protected.sh rm .claude/scripts/foo.sh
#   bash .claude/scripts/allow-protected.sh mv .claude/hooks/a.sh .claude/hooks/b.sh
#
# Writes .claude/.damage-control-bypass (5-min TTL) before invoking the
# command so readOnly/noDelete paths under .claude/ can be touched in a
# single turn. zeroAccess paths remain absolute — this script cannot
# override them.
#
# The bypass file is removed on exit regardless of the command's outcome.

set -euo pipefail

if [ $# -eq 0 ]; then
  cat <<'EOF' >&2
Usage: bash allow-protected.sh CMD [ARGS...]
Run CMD with the damage-control bypass token active for this turn.
Example: bash allow-protected.sh rm .claude/scripts/old-script.sh
EOF
  exit 2
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BYPASS_FILE="$PROJECT_DIR/.claude/.damage-control-bypass"

mkdir -p "$(dirname "$BYPASS_FILE")"
date +%s > "$BYPASS_FILE"

cleanup() { rm -f "$BYPASS_FILE" 2>/dev/null || true; }
trap cleanup EXIT

"$@"
