#!/bin/bash
# generate-hooks-json.sh — Generate hooks.json for Claude Code plugin distribution
#
# Usage: bash .claude/scripts/generate-hooks-json.sh [--profile NAME] [--output PATH]
#
# The profile and output files now use the same Claude Code plugin hook schema
# (nested { matcher?, hooks: [{ type, command, timeout?, ... }] }), so this
# script just strips comments/metadata and copies the .hooks tree through.
# Historical note: an older profile format used flat { script, matcher, timeout }
# entries and this script transformed them into the plugin schema. That format
# is dead; the profile schema was unified with hooks.json. The old transform
# destroyed every command field when run against the new format.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROFILE_NAME="full"
OUTPUT_PATH="$SOURCE_DIR/hooks/hooks.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE_NAME="$2"; shift 2 ;;
    --output)  OUTPUT_PATH="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--profile NAME] [--output PATH]"; exit 0 ;;
    *)         echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PROFILE_FILE="$SOURCE_DIR/.claude/profiles/${PROFILE_NAME}.json"

command -v jq &>/dev/null || { echo "Error: jq required" >&2; exit 1; }
[ -f "$PROFILE_FILE" ] || { echo "Error: Profile not found: $PROFILE_FILE" >&2; exit 1; }
jq -e '.hooks' "$PROFILE_FILE" &>/dev/null || { echo "Error: No hooks in profile" >&2; exit 1; }

mkdir -p "$(dirname "$OUTPUT_PATH")"

# Profile and plugin hooks.json share the same schema — emit just the .hooks
# subtree, stripping any profile-only metadata that might sit alongside it.
jq '{hooks: .hooks}' "$PROFILE_FILE" > "$OUTPUT_PATH"

# Validate
if ! jq empty "$OUTPUT_PATH" 2>/dev/null; then
  echo "Error: Generated hooks.json is invalid" >&2
  exit 1
fi

EVENT_COUNT=$(jq '.hooks | keys | length' "$OUTPUT_PATH")
HOOK_COUNT=$(jq '[.hooks[][] | .hooks | length] | add' "$OUTPUT_PATH")

echo "Generated: $OUTPUT_PATH"
echo "Profile:   $PROFILE_NAME"
echo "Events:    $EVENT_COUNT"
echo "Hooks:     $HOOK_COUNT"
