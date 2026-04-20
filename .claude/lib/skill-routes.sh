#!/bin/bash
# skill-routes.sh — Shared file-pattern → skill lookup table
#
# Consolidates duplicate pattern matching from:
#   - skill-gate.sh (PreToolUse gate: 3 domain skills)
#   - proactive-skill-trigger.sh (PostToolUse advisory: 25+ skills)
#   - delegation-reminder.sh (PreToolUse: extension bypass)
#
# Usage: source this file, then call the functions.
# Guard: _SKILL_ROUTES_LOADED prevents double-sourcing.

[[ -n "${_SKILL_ROUTES_LOADED:-}" ]] && return 0
_SKILL_ROUTES_LOADED=1

# ─── BYPASS LOGIC (shared across all three hooks) ───

# Returns 0 (true) if the file should bypass skill/delegation checks.
# Covers: kit infra, config, docs, tests, types, non-code files.
is_hook_bypass_path() {
  local filepath_lower="$1"
  local filename_lower
  filename_lower=$(basename "$filepath_lower")

  # Kit infrastructure — always allow
  case "$filepath_lower" in
    */.claude/*|*/.github/*|*/node_modules/*|*/scripts/*) return 0 ;;
  esac

  # Config, docs, non-code — always allow
  case "$filename_lower" in
    *.json|*.yaml|*.yml|*.toml|*.cfg|*.ini|*.xml) return 0 ;;
    *.md|*.txt|*.log|*.sh|*.env*) return 0 ;;
    *.lock|*.csv|*.svg|*.rst) return 0 ;;
  esac

  # Tests — always allow (TDD should not be gated)
  case "$filename_lower" in
    *.test.*|*.spec.*|test_*|*_test.*) return 0 ;;
  esac
  case "$filepath_lower" in
    */tests/*|*__tests__*|*/e2e/*|*/__mocks__/*) return 0 ;;
  esac

  # Types, interfaces, schemas — always allow
  case "$filename_lower" in
    *type*|*interface*|*schema*|*.d.ts) return 0 ;;
  esac
  case "$filepath_lower" in
    */types/*|*/schemas/*|*/interfaces/*) return 0 ;;
  esac

  return 1
}

# Returns 0 if the file extension indicates non-code (for delegation bypass).
# Stricter than is_hook_bypass_path — only checks extension, not path.
is_noncode_extension() {
  local ext="$1"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    json|yaml|yml|txt|rst|toml|cfg|ini|csv|xml|html|css|svg|lock|log) return 0 ;;
  esac
  return 1
}

# ─── SKILL ROUTE TABLE ───

# Returns the GATE skill (one of 3 domain skills) for a file, or empty.
# This is the "required skill" that skill-gate.sh enforces.
classify_gate_skill() {
  local filepath_lower="$1"
  local filename_lower
  filename_lower=$(basename "$filepath_lower")

  # Frontend design files → frontend-design-pro
  case "$filename_lower" in
    *page*.*sx|*page*.*ue|*page*.*velte) echo "frontend-design-pro"; return 0 ;;
    *layout*.*sx|*layout*.*ue) echo "frontend-design-pro"; return 0 ;;
    *hero*|*landing*|*home*.*sx|*home*.*ue) echo "frontend-design-pro"; return 0 ;;
    *animation*|*motion*|*transition*) echo "frontend-design-pro"; return 0 ;;
    *section*.*sx|*section*.*ue) echo "frontend-design-pro"; return 0 ;;
    *footer*.*sx|*nav*.*sx|*header*.*sx) echo "frontend-design-pro"; return 0 ;;
    *.css|*.scss|*.sass|*.less) echo "frontend-design-pro"; return 0 ;;
  esac

  # Frontend pages/views directories
  case "$filepath_lower" in
    */pages/*.*sx|*/views/*.*sx|*/layouts/*.*sx|*/sections/*.*sx) echo "frontend-design-pro"; return 0 ;;
    */components/*hero*|*/components/*nav*|*/components/*footer*|*/components/*header*) echo "frontend-design-pro"; return 0 ;;
  esac

  # Frontend engineering (functional, not design)
  case "$filename_lower" in
    *component*.*sx|*component*.*ue) echo "frontend-engineering"; return 0 ;;
    *form*.*sx|*table*.*sx|*modal*.*sx|*dialog*.*sx) echo "frontend-engineering"; return 0 ;;
    *dashboard*.*sx|*widget*.*sx) echo "frontend-engineering"; return 0 ;;
  esac

  # Backend files → backend-design
  case "$filename_lower" in
    *handler*|*middleware*|*controller*|*endpoint*) echo "backend-design"; return 0 ;;
    *service*.*s|*service*.*py) echo "backend-design"; return 0 ;;
    *route*.*s|*route*.*py|*router*.*s|*router*.*py) echo "backend-design"; return 0 ;;
  esac
  case "$filepath_lower" in
    */api/*.*s|*/api/*.*py|*/routes/*.*s|*/routes/*.*py) echo "backend-design"; return 0 ;;
    */middleware/*|*/handlers/*|*/controllers/*) echo "backend-design"; return 0 ;;
    */server/*.*s|*/server/*.*py) echo "backend-design"; return 0 ;;
  esac

  return 1
}

# Returns ALL matching advisory skills for a file (newline-separated: skill\tmessage).
# Used by proactive-skill-trigger.sh.
classify_all_skills() {
  local filepath_lower="$1"
  local filename="$2"  # original case basename, for display
  local filename_lower
  filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

  # Security-sensitive files
  case "$filename_lower" in
    *auth*|*token*|*password*|*session*|*crypto*|*secret*|*permission*|*rbac*) \
      echo "security-review	Security-sensitive code ($filename)" ;;
    *) case "$filepath_lower" in
         */security/*|*/auth/*) echo "security-review	Security-sensitive code ($filename)" ;;
       esac ;;
  esac

  # Frontend functional (components, state, a11y)
  case "$filename_lower" in
    *.tsx|*.jsx|*component*|*hook*|*context*|*reducer*|*store*) \
      echo "frontend-engineering	Frontend component ($filename)" ;;
  esac

  # Frontend design (visual, motion, aesthetics)
  case "$filename_lower" in
    *.css|*.scss|*styles*|*landing*|*hero*|*animation*|*theme*) \
      echo "frontend-design-pro	Design/visual code ($filename) — use multi-model pipeline" ;;
  esac

  # HTML/design → Gemini generation
  case "$filename_lower" in
    *.html|*.svg|*mockup*|*design*) \
      echo "using-antigravity	HTML/design ($filename) — use Gemini MCP for generation" ;;
  esac

  # Backend files
  case "$filename_lower" in
    *api*|*route*|*middleware*|*handler*|*service*|*controller*) \
      echo "backend-design	Backend code ($filename)" ;;
    *) case "$filepath_lower" in
         */api/*|*/routes/*) echo "backend-design	Backend code ($filename)" ;;
       esac ;;
  esac

  # Schema/architecture files
  case "$filename_lower" in
    *schema*|*migration*|*model*|*entity*) \
      echo "system-architecture	Schema/model ($filename) — verify design" ;;
    *) case "$filepath_lower" in
         */migrations/*) echo "system-architecture	Schema/model ($filename) — verify design" ;;
       esac ;;
  esac

  # i18n / localization
  case "$filename_lower" in
    *i18n*|*locale*|*translation*|*messages.*) \
      echo "i18n	Internationalization file ($filename)" ;;
    *) case "$filepath_lower" in
         */locales/*) echo "i18n	Internationalization file ($filename)" ;;
       esac ;;
  esac

  # E2E / Playwright
  case "$filename_lower" in
    *.e2e.*|*playwright*) \
      echo "webapp-testing	E2E test ($filename) — use Playwright patterns" ;;
    *) case "$filepath_lower" in
         */e2e/*) echo "webapp-testing	E2E test ($filename) — use Playwright patterns" ;;
       esac ;;
  esac

  # CI/CD pipeline
  case "$filepath_lower" in
    *.github/workflows/*) echo "cicd-generator	CI/CD config ($filename)" ;;
    *) case "$filename_lower" in
         *.gitlab-ci*|*pipeline*|*ci.yml*|*ci.yaml*|*dockerfile*) \
           echo "cicd-generator	CI/CD config ($filename)" ;;
       esac ;;
  esac

  # MCP server files
  case "$filename_lower" in
    *mcp*|.mcp.json) echo "mcp-builder	MCP server code ($filename)" ;;
    *) case "$filepath_lower" in
         */mcp-server/*) echo "mcp-builder	MCP server code ($filename)" ;;
       esac ;;
  esac

  # Changelog
  case "$filename_lower" in
    changelog*) echo "changelog-automation	Changelog ($filename) — auto-generate from git history" ;;
  esac

  # Remotion / video
  case "$filename_lower" in
    *composition*|*remotion*) echo "remotion-video	Video composition ($filename)" ;;
    *) case "$filepath_lower" in
         */video/*) echo "remotion-video	Video composition ($filename)" ;;
       esac ;;
  esac

  # Accessibility
  case "$filename_lower" in
    *a11y*|*accessibility*|*aria*) \
      echo "accessibility-audit	Accessibility file ($filename) — WCAG audit" ;;
  esac

  # CLAUDE.md / project config
  case "$filename_lower" in
    claude.md|agents.md) echo "claude-md-improver	Project config ($filename) — audit quality" ;;
  esac

  # Documentation generation
  case "$filename_lower" in
    *docx*|*pptx*|*xlsx*) echo "doc-generation	Document template ($filename)" ;;
    *) case "$filepath_lower" in
         */docs/templates/*) echo "doc-generation	Document template ($filename)" ;;
       esac ;;
  esac

  # Skill files
  case "$filepath_lower" in
    */skills/*/skill.md) echo "writing-skills	Skill file ($filename) — optimize description + eval" ;;
  esac

  # Debugging / error investigation
  case "$filename_lower" in
    *error*|*bug*|*debug*) \
      echo "systematic-debugging	Error/debug file ($filename) — use hypothesis-driven investigation" ;;
    *) case "$filepath_lower" in
         */debug/*) echo "systematic-debugging	Error/debug file ($filename) — use hypothesis-driven investigation" ;;
       esac ;;
  esac

  # Code quality / SOLID review
  case "$filepath_lower" in
    *review*|*quality*) echo "solid	Quality review context ($filename)" ;;
  esac

  # Refactoring
  case "$filename_lower" in
    *refactor*) echo "code-refactoring	Refactoring ($filename) — use proven refactoring patterns" ;;
    *) case "$filepath_lower" in
         *refactor*) echo "code-refactoring	Refactoring ($filename) — use proven refactoring patterns" ;;
       esac ;;
  esac

  # Planning / specs / requirements
  case "$filename_lower" in
    *prd*|*spec*|*requirements*|*plan*|*roadmap*|*todo*) \
      echo "writing-plans	Planning document ($filename)" ;;
  esac

  # Architecture decisions
  case "$filename_lower" in
    *decision*|*adr*) echo "thinktank	Architecture decision ($filename) — use multi-model consultation" ;;
    *) case "$filepath_lower" in
         */decisions/*) echo "thinktank	Architecture decision ($filename) — use multi-model consultation" ;;
       esac ;;
  esac

  # Project scaffolding (config files)
  case "$filename_lower" in
    package.json|tsconfig.json|vite.config.*|webpack.config.*) \
      echo "project-scaffolder	Project config ($filename) — use best-practice scaffolding" ;;
  esac

  # Backend endpoints / controllers
  case "$filename_lower" in
    *endpoint*|*controller*) \
      echo "backend-endpoint	Endpoint ($filename) — use validation + error handling patterns" ;;
    *) case "$filepath_lower" in
         */controllers/*|*/endpoints/*) \
           echo "backend-endpoint	Endpoint ($filename) — use validation + error handling patterns" ;;
       esac ;;
  esac

  # Performance / benchmarks
  case "$filename_lower" in
    *bench*|*perf*|*optimize*) \
      echo "autodev	Performance file ($filename) — use autonomous optimization loop" ;;
    *) case "$filepath_lower" in
         */benchmark/*) echo "autodev	Performance file ($filename) — use autonomous optimization loop" ;;
       esac ;;
  esac

  # Prompt engineering
  case "$filename_lower" in
    *prompt*|*system-prompt*) \
      echo "prompt-engineering	Prompt file ($filename) — use proven prompt techniques" ;;
    *) case "$filepath_lower" in
         */prompts/*) echo "prompt-engineering	Prompt file ($filename) — use proven prompt techniques" ;;
       esac ;;
  esac

  # New utility/helper files — search first
  case "$filename_lower" in
    *util*|*helper*) \
      echo "search-first	Utility file ($filename) — check for existing solutions before writing" ;;
    *) case "$filepath_lower" in
         */utils/*|*/helpers/*) \
           echo "search-first	Utility file ($filename) — check for existing solutions before writing" ;;
       esac ;;
  esac

  return 0
}

# ─── LAUNCH MODE DETECTION (shared across skill-gate + delegation-reminder) ───

# Returns 0 if running in ollama-primary mode (hooks should skip).
is_ollama_launch_mode() {
  if [ -n "${LAUNCH_MODE:-}" ]; then
    [ "$LAUNCH_MODE" = "ollama" ] && return 0
    return 1
  fi
  local _lm_dir
  for _lm_dir in "${CLAUDE_PROJECT_DIR:-.}" "$(git rev-parse --show-toplevel 2>/dev/null)" "$(cd "$(dirname "${BASH_SOURCE[1]}")/../.." 2>/dev/null && pwd)" "$HOME"; do
    [ -n "$_lm_dir" ] && [ -f "$_lm_dir/.claude/.launch-mode" ] && {
      LAUNCH_MODE=$(cat "$_lm_dir/.claude/.launch-mode" 2>/dev/null)
      [ "$LAUNCH_MODE" = "ollama" ] && return 0
      return 1
    }
  done
  return 1
}
