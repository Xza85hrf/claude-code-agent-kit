#!/bin/bash
# hook-profile-gate.sh — Runtime hook profile switching library
#
# Enables runtime profile selection via environment variables, replacing the need
# to re-run setup-profile.sh for profile changes. Hooks source this file and call
# `hook_profile_check` to self-disable based on the current profile.
#
# Environment Variables:
#   KIT_HOOK_PROFILE — minimal|standard|full (default: standard)
#   KIT_DISABLED_HOOKS — comma-separated hook names to skip (e.g. "review-gate,delegation-check")
#
# Profile Tiers (cumulative):
#   minimal (level 1) — Only critical safety hooks
#   standard (level 2) — Safety + quality + delegation + observability
#   full (level 3) — Everything including experimental and learning hooks
#
# Usage:
#   source "${BASH_SOURCE[0]%/*}/hook-profile-gate.sh"
#
#   # Check if hook should run (returns 0=run, 1=skip):
#   hook_profile_check "standard" "hook-name" || exit 0
#
#   # Check exact profile:
#   hook_is_profile "minimal"

# Guard against double-sourcing
[[ -n "${_HOOK_PROFILE_GATE_LOADED:-}" ]] && return 0
_HOOK_PROFILE_GATE_LOADED=1

# Profile tier levels
declare -gA _PROFILE_LEVELS=(
  [minimal]=1
  [standard]=2
  [full]=3
)

# Get current profile from KIT_HOOK_PROFILE env var
_get_current_profile() {
  local profile="${KIT_HOOK_PROFILE:-standard}"
  # Normalize to lowercase
  echo "$profile" | tr '[:upper:]' '[:lower:]'
}

# Get numeric tier for a profile
_get_profile_level() {
  local profile="$1"
  echo "${_PROFILE_LEVELS[$profile]:-2}"  # Default to standard (2) if invalid
}

# Check if hook should run based on minimum required tier and disabled list
# Returns 0 (run), 1 (skip)
hook_profile_check() {
  local min_tier="$1"
  local hook_name="$2"

  # Check disabled hooks list first (comma-separated)
  if [[ -n "${KIT_DISABLED_HOOKS:-}" ]]; then
    # Normalize hook name (remove .sh suffix)
    local hook_base="${hook_name%.sh}"

    # Build disabled list with normalized format for matching
    local normalized_disabled
    normalized_disabled=$(echo "$KIT_DISABLED_HOOKS" | sed 's/[[:space:]]*//g; s/\.sh//g')

    # Check if hook is in disabled list (use commas as delimiters)
    if echo ",$normalized_disabled," | grep -q ",$hook_base,"; then
      return 1  # Skip this hook
    fi
  fi

  # Get current profile and its level
  local current_profile
  current_profile=$(_get_current_profile)
  local current_level
  current_level=$(_get_profile_level "$current_profile")

  # Get required tier level (default to standard=2 if invalid)
  local required_level
  required_level=$(_get_profile_level "$min_tier")

  # Run if current >= required
  if (( current_level >= required_level )); then
    return 0  # Run
  else
    return 1  # Skip
  fi
}

# Check if we're running the exact specified profile
# Returns 0 (match), 1 (no match)
hook_is_profile() {
  local target_profile="$1"
  local current_profile
  current_profile=$(_get_current_profile)

  if [[ "$current_profile" == "$target_profile" ]]; then
    return 0
  else
    return 1
  fi
}

# Check if we're running the specified profile or higher
# Returns 0 (match), 1 (no match)
hook_is_profile_or_higher() {
  local min_profile="$1"
  local current_profile
  current_profile=$(_get_current_profile)
  local current_level
  current_level=$(_get_profile_level "$current_profile")
  local required_level
  required_level=$(_get_profile_level "$min_profile")

  if (( current_level >= required_level )); then
    return 0
  else
    return 1
  fi
}

# Get list of hooks enabled in a specific profile
# Useful for debugging which hooks are active
hook_get_enabled_hooks() {
  local target_profile="${1:-standard}"
  local profile_file="${CLAUDE_PROJECT_DIR:-.}/.claude/profiles/${target_profile}.json"

  if [[ ! -f "$profile_file" ]]; then
    echo "Error: Profile file not found: $profile_file" >&2
    return 1
  fi

  jq -r '.hooks | to_entries | .[] | .value | .[] | .script' "$profile_file" 2>/dev/null | sort -u
}

# Get all hooks that should run based on current profile and disabled list
hook_get_active_hooks() {
  local current_profile
  current_profile=$(_get_current_profile)

  # Get hooks for current profile
  local all_hooks
  all_hooks=$(hook_get_enabled_hooks "$current_profile" 2>/dev/null)

  # Filter out disabled hooks
  if [[ -n "${KIT_DISABLED_HOOKS:-}" ]]; then
    # Normalize disabled list (remove spaces, .sh suffixes)
    local normalized_disabled
    normalized_disabled=$(echo "$KIT_DISABLED_HOOKS" | sed 's/[[:space:]]*//g; s/\.sh//g')

    echo "$all_hooks" | while IFS= read -r hook; do
      # Remove .sh suffix for comparison
      local hook_base="${hook%.sh}"
      # Check if hook is in disabled list
      if ! echo ",$normalized_disabled," | grep -q ",$hook_base,"; then
        echo "$hook"
      fi
    done
  else
    echo "$all_hooks"
  fi
}
