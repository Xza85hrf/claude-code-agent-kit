#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# validate-kit.sh — Agent Enhancement Kit Health Check
# =============================================================================
# Validates CLAUDE.md, hooks, skills, MCP config, Ollama, env vars, etc.
# Exit 0 if no FAILs, exit 1 if any FAILs.
# =============================================================================

# --- Color codes ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Auto-detect project root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Counters ---
OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# --- Output helpers ---
pad_label() {
  local label="$1"
  local max_len=23
  local pad_len=$(( max_len - ${#label} ))
  local dots=""
  for (( i=0; i<pad_len; i++ )); do dots+="."; done
  printf "%s %s" "$label" "$dots"
}

result_ok() {
  local label="$1"
  local detail="$2"
  pad_label "$label"
  printf " ${GREEN}[OK]${RESET} %s\n" "$detail"
  (( OK_COUNT++ )) || true
}

result_warn() {
  local label="$1"
  local detail="$2"
  pad_label "$label"
  printf " ${YELLOW}[WARN]${RESET} %s\n" "$detail"
  (( WARN_COUNT++ )) || true
}

result_fail() {
  local label="$1"
  local detail="$2"
  pad_label "$label"
  printf " ${RED}[FAIL]${RESET} %s\n" "$detail"
  (( FAIL_COUNT++ )) || true
}

# =============================================================================
# Check functions
# =============================================================================

check_claude_md() {
  local file="$PROJECT_ROOT/CLAUDE.md"
  if [[ ! -f "$file" ]]; then
    result_fail "CLAUDE.md" "File not found"
    return
  fi
  local lines
  lines=$(wc -l < "$file")
  if [[ "$lines" -eq 0 ]]; then
    result_fail "CLAUDE.md" "File is empty"
    return
  fi
  if ! grep -qE "Agent Identity|Autonomous Coding Agent" "$file"; then
    result_fail "CLAUDE.md" "Missing agent identity section"
    return
  fi
  result_ok "CLAUDE.md" "$lines lines"
}

check_agents_md() {
  local claude_md="$PROJECT_ROOT/CLAUDE.md"
  local agents_md="$PROJECT_ROOT/AGENTS.md"
  # Only check if CLAUDE.md references AGENTS.md
  if [[ -f "$claude_md" ]] && grep -q "AGENTS\.md" "$claude_md"; then
    if [[ -f "$agents_md" ]]; then
      local lines
      lines=$(wc -l < "$agents_md")
      result_ok "AGENTS.md" "$lines lines"
    else
      result_warn "AGENTS.md" "Referenced in CLAUDE.md but not found"
    fi
  else
    # Not referenced, check if it exists anyway
    if [[ -f "$agents_md" ]]; then
      local lines
      lines=$(wc -l < "$agents_md")
      result_ok "AGENTS.md" "$lines lines (not referenced in CLAUDE.md)"
    else
      result_ok "AGENTS.md" "Not referenced, not needed"
    fi
  fi
}

check_hook_scripts() {
  local hooks_dir="$PROJECT_ROOT/.claude/hooks"
  if [[ ! -d "$hooks_dir" ]]; then
    result_fail "Hook scripts" "Directory .claude/hooks/ not found"
    return
  fi
  local total=0
  local executable=0
  local non_exec=()
  while IFS= read -r -d '' f; do
    (( total++ )) || true
    if [[ -x "$f" ]]; then
      (( executable++ )) || true
    else
      non_exec+=("$(basename "$f")")
    fi
  done < <(find "$hooks_dir" -maxdepth 1 -name '*.sh' -print0)

  if [[ "$total" -eq 0 ]]; then
    result_warn "Hook scripts" "No .sh files found in .claude/hooks/"
    return
  fi
  if [[ ${#non_exec[@]} -gt 0 ]]; then
    result_fail "Hook scripts" "$executable/$total executable (missing: ${non_exec[*]})"
  else
    result_ok "Hook scripts" "$total/$total executable"
  fi
}

check_hook_registration() {
  local settings="$PROJECT_ROOT/.claude/settings.local.json"
  if [[ ! -f "$settings" ]]; then
    settings="$PROJECT_ROOT/.claude/settings.json"
  fi
  if [[ ! -f "$settings" ]]; then
    result_warn "Hook registration" "No settings.local.json or settings.json found"
    return
  fi

  local hooks_dir="$PROJECT_ROOT/.claude/hooks"
  local missing=()
  local total=0

  # Extract hook script basenames from settings JSON
  while IFS= read -r script_name; do
    [[ -z "$script_name" ]] && continue
    (( total++ )) || true
    if [[ ! -f "$hooks_dir/$script_name" ]]; then
      missing+=("$script_name")
    fi
  done < <(grep -oP '\.claude/hooks/\K[a-zA-Z0-9_-]+\.sh' "$settings" | sort -u)

  if [[ "$total" -eq 0 ]]; then
    result_warn "Hook registration" "No hooks found in settings"
    return
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    result_fail "Hook registration" "Missing scripts: ${missing[*]}"
  else
    result_ok "Hook registration" "All $total registered hooks exist"
  fi
}

check_skills() {
  local skills_dir="$PROJECT_ROOT/.claude/skills"
  if [[ ! -d "$skills_dir" ]]; then
    result_fail "Skills" "Directory .claude/skills/ not found"
    return
  fi

  local count
  # Count unique skills (by basename, skills can be nested in dept subdirs)
  count=$(find -L "$skills_dir" -name "SKILL.md" -exec dirname {} \; | xargs -I{} basename {} | sort -u | wc -l)

  if [[ "$count" -eq 0 ]]; then
    result_fail "Skills" "No skill directories with SKILL.md found"
  else
    result_ok "Skills" "$count skills found"
  fi
}

check_skill_frontmatter() {
  local skills_dir="$PROJECT_ROOT/.claude/skills"
  if [[ ! -d "$skills_dir" ]]; then
    result_fail "Skill frontmatter" "Directory .claude/skills/ not found"
    return
  fi

  local total=0
  local valid=0
  local invalid=()
  while IFS= read -r -d '' skill_md; do
    total=$((total + 1))
    local first_line
    first_line=$(head -1 "$skill_md")
    if [[ "$first_line" == "---" ]]; then
      valid=$((valid + 1))
    else
      invalid+=("$(dirname "$skill_md" | sed "s|$skills_dir/||")")
    fi
  done < <(find -L "$skills_dir" -name "SKILL.md" -print0)
  # Deduplicate count (skills may exist at root + dept subdir)
  total=$(find -L "$skills_dir" -name "SKILL.md" -exec dirname {} \; | xargs -I{} basename {} | sort -u | wc -l)

  if [[ "$total" -eq 0 ]]; then
    result_warn "Skill frontmatter" "No SKILL.md files found"
    return
  fi
  if [[ ${#invalid[@]} -gt 0 ]]; then
    result_fail "Skill frontmatter" "$valid/$total have YAML frontmatter (missing: ${invalid[*]})"
  else
    result_ok "Skill frontmatter" "$valid/$total have YAML frontmatter"
  fi
}

check_skills_registry() {
  local skills_dir="$PROJECT_ROOT/.claude/skills"
  local registry="$skills_dir/skills.yml"
  if [[ ! -f "$registry" ]]; then
    result_warn "Skills registry" "skills.yml not found"
    return
  fi

  # Count unique skills (by basename, deduped)
  local dir_count
  dir_count=$(find -L "$skills_dir" -name "SKILL.md" -exec dirname {} \; | xargs -I{} basename {} | sort -u | wc -l)

  # Count skills in registry (lines matching "- name:" pattern)
  local registry_count
  registry_count=$(grep -cE '^\s*-\s*name:' "$registry" 2>/dev/null || echo 0)

  if [[ "$dir_count" -eq "$registry_count" ]]; then
    result_ok "Skills registry" "skills.yml matches ($dir_count skills)"
  else
    result_warn "Skills registry" "Mismatch: $dir_count dirs vs $registry_count in skills.yml"
  fi
}

check_ollama() {
  local host="${OLLAMA_HOST:-http://localhost:11434}"
  # Strip protocol for display
  local display_host="${host#http://}"
  display_host="${display_host#https://}"

  if curl -s --connect-timeout 3 --max-time 5 "$host/api/tags" >/dev/null 2>&1; then
    result_ok "Ollama" "Reachable at $display_host"
  else
    result_warn "Ollama" "Unreachable at $display_host"
  fi
}

check_mcp_config() {
  local mcp_file="$HOME/.claude.json"
  if [[ ! -f "$mcp_file" ]]; then
    result_warn "MCP config" "~/.claude.json not found"
    return
  fi
  local server_count
  server_count=$(jq -r '.mcpServers | length' "$mcp_file" 2>/dev/null || echo 0)
  if [[ "$server_count" -gt 0 ]]; then
    result_ok "MCP config" "~/.claude.json valid ($server_count servers)"
  else
    result_warn "MCP config" "~/.claude.json has no MCP servers"
  fi
}

check_env_vars() {
  local vars_to_check=(OLLAMA_HOST DELEGATION_MODE LAUNCH_MODE DEEPSEEK_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN)
  local missing=()
  for var in "${vars_to_check[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    result_ok "Environment" "All key env vars set"
  else
    result_warn "Environment" "${missing[*]} not set"
  fi
}

check_team_presets() {
  local presets_dir="$PROJECT_ROOT/.claude/team-presets"
  if [[ ! -d "$presets_dir" ]]; then
    result_ok "Team presets" "No team-presets/ directory (optional)"
    return
  fi

  local total=0
  local valid=0
  local invalid=()
  for f in "$presets_dir"/*.json; do
    [[ ! -f "$f" ]] && continue
    (( total++ )) || true
    if jq empty "$f" 2>/dev/null; then
      (( valid++ )) || true
    else
      invalid+=("$(basename "$f")")
    fi
  done

  if [[ "$total" -eq 0 ]]; then
    result_ok "Team presets" "No preset files found (optional)"
    return
  fi
  if [[ ${#invalid[@]} -gt 0 ]]; then
    result_fail "Team presets" "$valid/$total valid (invalid: ${invalid[*]})"
  else
    result_ok "Team presets" "$total presets valid"
  fi
}

check_agent_definitions() {
  local agents_dir="$PROJECT_ROOT/.claude/agents"
  if [[ ! -d "$agents_dir" ]]; then
    result_ok "Agent definitions" "No agents/ directory (optional)"
    return
  fi

  local total=0
  local valid=0
  local invalid=()
  for f in "$agents_dir"/*.md; do
    [[ ! -f "$f" ]] && continue
    (( total++ )) || true
    local first_line
    first_line=$(head -1 "$f")
    if [[ "$first_line" == "---" ]]; then
      (( valid++ )) || true
    else
      invalid+=("$(basename "$f")")
    fi
  done

  if [[ "$total" -eq 0 ]]; then
    result_ok "Agent definitions" "No .md files in agents/ (optional)"
    return
  fi
  if [[ ${#invalid[@]} -gt 0 ]]; then
    result_fail "Agent definitions" "$valid/$total have YAML frontmatter (missing: ${invalid[*]})"
  else
    result_ok "Agent definitions" "$total agents found"
  fi
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo "=== Agent Enhancement Kit Health Check ==="
echo ""

check_claude_md
check_agents_md
check_hook_scripts
check_hook_registration
check_skills
check_skill_frontmatter
check_skills_registry
check_ollama
check_mcp_config
check_env_vars
check_team_presets
check_agent_definitions

echo ""
printf "Result: ${GREEN}%d OK${RESET}, ${YELLOW}%d WARN${RESET}, ${RED}%d FAIL${RESET}\n" \
  "$OK_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
