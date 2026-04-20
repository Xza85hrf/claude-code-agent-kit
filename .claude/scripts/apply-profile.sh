#!/usr/bin/env bash
# apply-profile.sh — Generate .claude/settings.local.json from a profile.
# Usage: apply-profile.sh [minimal|standard]
set -euo pipefail

PROFILE="${1:-standard}"
# Resolve project dir from script location (script lives at .claude/scripts/apply-profile.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILE_FILE="$PROJECT_DIR/.claude/profiles/${PROFILE}.json"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "Profile not found: $PROFILE_FILE" >&2
  echo "Available: $(ls "$PROJECT_DIR/.claude/profiles/" | sed 's/\.json$//' | tr '\n' ' ')" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required. Install: https://jqlang.github.io/jq/" >&2
  exit 1
fi

# Merge profile env + hooks into settings.local.json, preserve permissions.deny/allow
TMP=$(mktemp)
if [ -f "$SETTINGS_FILE" ]; then
  EXISTING_PERMS=$(jq '.permissions // {}' "$SETTINGS_FILE")
else
  EXISTING_PERMS='{}'
fi

jq --argjson perms "$EXISTING_PERMS" '
  {
    "_comment": ("Generated from profiles/" + .name + ".json by apply-profile.sh"),
    env: .env,
    hooks: .hooks,
    permissions: (if $perms == {} then {
      deny: [
        "Bash(rm -rf /*)",
        "Bash(rm -rf ~*)",
        "Bash(sudo *)",
        "Bash(curl * | sh)",
        "Bash(curl * | bash)",
        "Write(**/.env)",
        "Read(**/.env)"
      ],
      allow: []
    } else $perms end)
  }
' "$PROFILE_FILE" > "$TMP"

mv "$TMP" "$SETTINGS_FILE"
echo "Applied profile: $PROFILE"
echo "Settings: $SETTINGS_FILE"
echo "Hook count: $(jq '[.hooks[][]?] | length' "$SETTINGS_FILE")"
