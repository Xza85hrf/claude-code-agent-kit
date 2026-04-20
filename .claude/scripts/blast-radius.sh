#!/bin/bash
set -euo pipefail

# blast-radius.sh — Dependency impact analyzer for Agent Enhancement Kit
# Shows what's affected when kit files change: deploy scripts, source consumers,
# generated outputs, @-import references, and validation commands.
#
# Usage:
#   bash .claude/scripts/blast-radius.sh FILE [FILE...]
#   bash .claude/scripts/blast-radius.sh --json .claude/skills/skills.yml
#   bash .claude/scripts/blast-radius.sh --quiet .claude/lib/env-defaults.sh
#   git diff --cached --name-only | xargs bash .claude/scripts/blast-radius.sh

# ── Flags ──
JSON_OUTPUT=false
QUIET_MODE=false
FILES=()

for arg in "$@"; do
  case "$arg" in
    --json)  JSON_OUTPUT=true ;;
    --quiet) QUIET_MODE=true ;;
    -h|--help)
      echo "Usage: $0 [--json|--quiet] FILE [FILE...]" >&2
      exit 0
      ;;
    -*)      echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)       FILES+=("$arg") ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: $0 [--json|--quiet] FILE [FILE...]" >&2
  exit 1
fi

# ── Dependency Maps ──

# DEPLOYED_BY: file glob pattern → space-separated deploy script names
declare -A DEPLOYED_BY
DEPLOYED_BY[".claude/hooks/*"]="install-global.sh"
DEPLOYED_BY[".claude/scripts/*"]="install-global.sh"
DEPLOYED_BY[".claude/commands/*"]="install-global.sh"
DEPLOYED_BY[".claude/agents/*"]="install-global.sh setup-globals.sh"
DEPLOYED_BY[".claude/skills/*"]="install-global.sh"
DEPLOYED_BY[".claude/lib/*"]="install-global.sh"
DEPLOYED_BY[".claude/config/*"]="install-global.sh"
DEPLOYED_BY[".claude/profiles/*"]="install-global.sh"
DEPLOYED_BY[".claude/output-styles/*"]="install-global.sh setup-globals.sh"
DEPLOYED_BY[".claude/rules/*"]="install-global.sh setup-globals.sh"
DEPLOYED_BY[".claude/*.md"]="install-global.sh"
DEPLOYED_BY["CLAUDE.md"]="install-global.sh"
DEPLOYED_BY["AGENTS.md"]="install-global.sh"
DEPLOYED_BY["docs/*"]="install-global.sh"
DEPLOYED_BY["hooks/hooks.json"]="install-global.sh"
DEPLOYED_BY[".claude-plugin/plugin.json"]="install-global.sh"

# SOURCED_BY: lib file basename → scripts that source it
declare -A SOURCED_BY
SOURCED_BY["env-defaults.sh"]="spawn-worker.sh select-model.sh model-config.sh ollama-batch.sh multi-model-audit.sh system-health.sh context-save.sh diagnose.sh deepseek-fallback.sh build-skill-index.sh"
SOURCED_BY["model-config.sh"]="list-provider-models.sh multi-model-audit.sh select-model.sh thinktank.sh embed-codebase.sh"
# hook-protocol.sh is sourced by 23+ hooks — tracked via DEPLOYED_BY, not here
# warning-format.sh removed — was dead code (zero actual source calls)

# GENERATES: source file → generated output files
declare -A GENERATES
GENERATES[".claude/skills/skills.yml"]=".claude/skills/SKILL-INDEX.md .claude/skills/skill-routes.json .claude/skills/WORKFLOW-INDEX.md"
GENERATES[".claude/profiles/full.json"]="hooks/hooks.json"
GENERATES[".claude/profiles/standard.json"]="hooks/hooks.json"
GENERATES[".claude/profiles/minimal.json"]="hooks/hooks.json"
GENERATES[".claude/config/workflows.yml"]=".claude/skills/WORKFLOW-INDEX.md"

# AT_IMPORTED_BY: file → files that @-import or reference it
declare -A AT_IMPORTED_BY
AT_IMPORTED_BY["AGENTS.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/execution.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/delegation.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/session-and-context.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/tool-usage.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/quality.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/debugging-escalation.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/rules/ci-workflow-safety.md"]="CLAUDE.md"
AT_IMPORTED_BY[".claude/scripts/model-config.sh"]="AGENTS.md"

# VALIDATES_WITH: file pattern → command template (FILE = placeholder)
declare -A VALIDATES_WITH
VALIDATES_WITH[".claude/profiles/*.json"]="jq empty FILE"
VALIDATES_WITH["hooks/hooks.json"]="jq empty FILE"
VALIDATES_WITH[".claude-plugin/plugin.json"]="jq empty FILE"
# .mcp.json no longer used — servers in ~/.claude.json
VALIDATES_WITH["*.sh"]="bash -n FILE"

# ── Pattern Matching ──

matches_pattern() {
  local file="$1" pattern="$2"
  # shellcheck disable=SC2254
  case "$file" in
    $pattern) return 0 ;;
  esac
  return 1
}

# Convert bash array to JSON array safely (handles empty arrays)
to_json_array() {
  if [[ $# -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "$@" | jq -R . | jq -s .
  fi
}

# ── Analysis ──

HAS_IMPACTS=false
JSON_RESULTS=()

analyze_file() {
  local file="$1"
  local stripped="${file#./}"
  local base="${stripped##*/}"

  local -a deployed=() sourced=() generated=() imported=() validate=()

  # Check DEPLOYED_BY (glob pattern match)
  for pattern in "${!DEPLOYED_BY[@]}"; do
    if matches_pattern "$stripped" "$pattern"; then
      read -ra scripts <<< "${DEPLOYED_BY[$pattern]}"
      deployed+=("${scripts[@]}")
    fi
  done
  # Deduplicate
  if [[ ${#deployed[@]} -gt 0 ]]; then
    mapfile -t deployed < <(printf '%s\n' "${deployed[@]}" | sort -u)
  fi

  # Check SOURCED_BY (basename match for lib files)
  if [[ -n "${SOURCED_BY[$base]:-}" ]]; then
    read -ra scripts <<< "${SOURCED_BY[$base]}"
    sourced+=("${scripts[@]}")
  fi

  # Check GENERATES (exact path match)
  if [[ -n "${GENERATES[$stripped]:-}" ]]; then
    read -ra outputs <<< "${GENERATES[$stripped]}"
    generated+=("${outputs[@]}")
  fi

  # Check AT_IMPORTED_BY (exact path, then basename fallback)
  if [[ -n "${AT_IMPORTED_BY[$stripped]:-}" ]]; then
    read -ra refs <<< "${AT_IMPORTED_BY[$stripped]}"
    imported+=("${refs[@]}")
  elif [[ -n "${AT_IMPORTED_BY[$base]:-}" ]]; then
    read -ra refs <<< "${AT_IMPORTED_BY[$base]}"
    imported+=("${refs[@]}")
  fi

  # Check VALIDATES_WITH (glob pattern match)
  for pattern in "${!VALIDATES_WITH[@]}"; do
    if matches_pattern "$stripped" "$pattern"; then
      local cmd="${VALIDATES_WITH[$pattern]//FILE/$stripped}"
      validate+=("$cmd")
    fi
  done

  # Any impacts?
  local has_any=false
  if [[ ${#deployed[@]} -gt 0 || ${#sourced[@]} -gt 0 || ${#generated[@]} -gt 0 || ${#imported[@]} -gt 0 || ${#validate[@]} -gt 0 ]]; then
    HAS_IMPACTS=true
    has_any=true
  fi

  # Quiet mode: only care about exit code
  [[ "$QUIET_MODE" == true ]] && return

  # JSON output
  if [[ "$JSON_OUTPUT" == true ]]; then
    local json
    json=$(jq -n \
      --arg file "$stripped" \
      --argjson deployed "$(to_json_array "${deployed[@]}")" \
      --argjson sourced "$(to_json_array "${sourced[@]}")" \
      --argjson generates "$(to_json_array "${generated[@]}")" \
      --argjson imported "$(to_json_array "${imported[@]}")" \
      --argjson validate "$(to_json_array "${validate[@]}")" \
      '{file:$file, deployed_by:$deployed, sourced_by:$sourced, generates:$generates, imported_by:$imported, validate:$validate}')
    JSON_RESULTS+=("$json")
    return
  fi

  # Human-readable output
  echo "BLAST RADIUS: $stripped"
  if [[ "$has_any" == false ]]; then
    echo "  (no downstream impacts)"
    echo ""
    return
  fi

  [[ ${#deployed[@]} -gt 0 ]]  && echo "  DEPLOYED BY: $(IFS=,; echo "${deployed[*]}" | sed 's/,/, /g')"
  [[ ${#sourced[@]} -gt 0 ]]   && echo "  SOURCED BY:  $(IFS=,; echo "${sourced[*]}" | sed 's/,/, /g')"
  [[ ${#generated[@]} -gt 0 ]] && echo "  GENERATES:   $(IFS=,; echo "${generated[*]}" | sed 's/,/, /g')"
  [[ ${#imported[@]} -gt 0 ]]  && echo "  IMPORTED BY: $(IFS=,; echo "${imported[*]}" | sed 's/,/, /g')"
  if [[ ${#validate[@]} -gt 0 ]]; then
    echo "  VALIDATE:"
    for cmd in "${validate[@]}"; do
      echo "    $cmd"
    done
  fi
  echo ""
}

# ── Main ──

for file in "${FILES[@]}"; do
  analyze_file "$file"
done

# JSON: combine all results
if [[ "$JSON_OUTPUT" == true && "$QUIET_MODE" == false ]]; then
  if [[ ${#JSON_RESULTS[@]} -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "${JSON_RESULTS[@]}" | jq -s '.'
  fi
fi

# Quiet mode: exit 1 = has impacts, exit 0 = clean
if [[ "$QUIET_MODE" == true ]]; then
  [[ "$HAS_IMPACTS" == true ]] && exit 1
  exit 0
fi
