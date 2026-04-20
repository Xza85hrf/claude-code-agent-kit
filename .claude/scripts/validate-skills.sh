#!/bin/bash
set -euo pipefail

# validate-skills.sh — Lint Claude Code skill files for quality
# Usage: validate-skills.sh [--fix] [--verbose]

FIX_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)    FIX_MODE=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        *)        echo "Usage: $0 [--fix] [--verbose]"; exit 1 ;;
    esac
done

# Resolve relative to script location (works from any CWD)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${_SCRIPT_DIR}/../skills"
# Plugin installs flatten skills to plugin_root/skills/ (not .claude/skills/)
# Prefer the path with more SKILL.md files (flattened plugin has 81, .claude/skills may have stale partial)
_ALT_DIR="${_SCRIPT_DIR}/../../skills"
if [[ -d "$_ALT_DIR" ]]; then
  _count_primary=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l)
  _count_alt=$(find "$_ALT_DIR" -name "SKILL.md" 2>/dev/null | wc -l)
  [[ "$_count_alt" -gt "$_count_primary" ]] && SKILLS_DIR="$_ALT_DIR"
fi
SKILLS_YML="$SKILLS_DIR/skills.yml"

[[ -d "$SKILLS_DIR" ]] || { echo "Error: skills directory not found"; exit 1; }

# Read departments from skills.yml
declare -a DEPARTMENTS=()
if [[ -f "$SKILLS_YML" ]]; then
    while IFS= read -r line; do
        # Match department directory names (lines under departments: that are directory-like)
        if [[ "$line" =~ ^[[:space:]]+-\ +(.+)$ ]]; then
            dept="${BASH_REMATCH[1]}"
            dept="${dept%:}"
            dept=$(echo "$dept" | xargs)  # trim whitespace
            DEPARTMENTS+=("$dept")
        fi
    done < "$SKILLS_YML"
fi

# Also auto-discover departments from directory names
while IFS= read -r dir; do
    dept=$(basename "$dir")
    found=false
    for d in "${DEPARTMENTS[@]}"; do
        [[ "$d" == "$dept" ]] && found=true && break
    done
    [[ "$found" == false ]] && DEPARTMENTS+=("$dept")
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

$VERBOSE && echo "Departments: ${DEPARTMENTS[*]:-none}"

# Find skill files
mapfile -t SKILL_FILES < <(find "$SKILLS_DIR" -type f -name "*.md" 2>/dev/null | \
    grep -vE '/(SKILL-INDEX|README|TEAMMATE-TEMPLATE|skill-schema)\.md$' | \
    grep -vE '/references/' | \
    grep -vE '(-REFERENCE|-prompt|REFERENCE|anti-patterns|condition-based|defense-in-depth|root-cause-tracing|third-party-pivot|anthropic-best-practices|testing-skills-with-subagents|code-reviewer|test-brief)\.md$' | \
    grep -E '/(SKILL|skill)\.md$' | sort)

$VERBOSE && echo "Found ${#SKILL_FILES[@]} skill files"

passed=0
warnings=0
failures=0
declare -A SEEN_NAMES

for filepath in "${SKILL_FILES[@]}"; do
    filename=$(basename "$filepath" .md)
    # SKILL.md files use parent directory as name
    if [[ "$filename" == "SKILL" || "$filename" == "skill" ]]; then
        skill_label=$(basename "$(dirname "$filepath")")
    else
        skill_label="$filename"
    fi

    # Read file
    content=$(cat "$filepath")

    # Check frontmatter exists
    if [[ ! "$content" == ---* ]]; then
        echo "[FAIL] $skill_label — missing frontmatter (no --- header)"
        failures=$((failures + 1))
        continue
    fi

    # Extract frontmatter block (first --- to second --- only)
    frontmatter=$(echo "$content" | awk '/^---$/{if(++n==2)exit}n==1{print}')

    if [[ -z "$frontmatter" ]]; then
        echo "[FAIL] $skill_label — empty or malformed frontmatter"
        failures=$((failures + 1))
        continue
    fi

    # Parse fields
    name_val=$(echo "$frontmatter" | grep -E '^name:' | sed 's/^name:[[:space:]]*//' | tr -d '\r' || true)
    desc_val=$(echo "$frontmatter" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' | tr -d '\r' || true)
    dept_val=$(echo "$frontmatter" | grep -E '^department:' | sed 's/^department:[[:space:]]*//' | tr -d '\r' || true)
    tools_val=$(echo "$frontmatter" | grep -E '^allowed-tools:' | sed 's/^allowed-tools:[[:space:]]*//' | tr -d '\r' || true)
    # Handle YAML list format (allowed-tools:\n  - item)
    if [[ -z "$tools_val" ]]; then
        tools_val=$(echo "$frontmatter" | sed -n '/^allowed-tools:/,/^[^ -]/{ /^  *- /p; }' | tr -d '\r' || true)
    fi
    think_val=$(echo "$frontmatter" | grep -E '^thinking-level:' | sed 's/^thinking-level:[[:space:]]*//' | tr -d '\r' || true)

    # Check required fields
    missing=()
    [[ -z "$name_val" ]] && missing+=("name")
    [[ -z "$desc_val" ]] && missing+=("description")
    [[ -z "$dept_val" ]] && missing+=("department")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[FAIL] $skill_label — missing required: ${missing[*]}"
        failures=$((failures + 1))
        continue
    fi

    # Check duplicate names
    if [[ -v SEEN_NAMES["$name_val"] ]]; then
        echo "[FAIL] $skill_label — duplicate name '$name_val' (also in ${SEEN_NAMES[$name_val]})"
        failures=$((failures + 1))
        continue
    fi
    SEEN_NAMES["$name_val"]="$filepath"

    # Validate department (skip in flattened plugin structure where skill dirs are direct children)
    _is_flattened=false
    _parent_dir=$(dirname "$filepath")
    [[ "$(dirname "$_parent_dir")" == "$SKILLS_DIR" || "$_parent_dir" == "$SKILLS_DIR/"* && ! -d "$SKILLS_DIR/$dept_val" ]] && _is_flattened=true
    if [[ "$_is_flattened" == false ]]; then
      dept_valid=false
      for d in "${DEPARTMENTS[@]}"; do
          [[ "$d" == "$dept_val" ]] && dept_valid=true && break
      done
      if [[ "$dept_valid" == false ]]; then
          echo "[FAIL] $skill_label — department '$dept_val' not in skills.yml"
          failures=$((failures + 1))
          continue
      fi
    fi

    # Validate description length
    desc_len=${#desc_val}
    if [[ $desc_len -le 20 ]]; then
        echo "[FAIL] $skill_label — description too short (${desc_len} chars, need >20)"
        failures=$((failures + 1))
        continue
    fi

    if [[ $desc_len -ge 200 ]]; then
        echo "[WARN] $skill_label — description very long (${desc_len} chars)"
        warnings=$((warnings + 1))
        continue
    fi

    # Check body content — first sed removes line 1 through closing ---
    body=$(sed '1,/^---$/d' "$filepath" | sed '/^[[:space:]]*$/d')
    if [[ -z "$body" ]]; then
        echo "[FAIL] $skill_label — empty body after frontmatter"
        failures=$((failures + 1))
        continue
    fi

    # Check recommended fields
    warn_msgs=()
    [[ -z "$tools_val" ]] && warn_msgs+=("missing allowed-tools")
    [[ -z "$think_val" ]] && warn_msgs+=("missing thinking-level")

    if [[ ${#warn_msgs[@]} -gt 0 ]]; then
        echo "[WARN] $skill_label — ${warn_msgs[*]}"
        warnings=$((warnings + 1))
    else
        $VERBOSE && echo "[PASS] $skill_label"
        passed=$((passed + 1))
    fi
done

echo ""
echo "Summary: $passed passed, $warnings warnings, $failures failures (${#SKILL_FILES[@]} total)"

[[ $failures -gt 0 ]] && exit 1
exit 0
