#!/bin/bash
# Hook: Provide guidance at session start with project detection
# SessionStart hook

source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || true
source "${BASH_SOURCE[0]%/*}/../lib/state-manager.sh" 2>/dev/null || true
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# File fallback: env vars don't propagate to hook subprocesses
# Try multiple paths — CLAUDE_PROJECT_DIR may not be set with Ollama backend
if [ -z "${LAUNCH_MODE:-}" ]; then
  for _lm_dir in "${CLAUDE_PROJECT_DIR:-.}" "$(git rev-parse --show-toplevel 2>/dev/null)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" "$HOME"; do
    [ -n "$_lm_dir" ] && [ -f "$_lm_dir/.claude/.launch-mode" ] && {
      LAUNCH_MODE=$(cat "$_lm_dir/.claude/.launch-mode" 2>/dev/null)
      break
    }
  done
fi
CURRENT_MODE="${LAUNCH_MODE:-opus}"

# Auto-detect Ollama when launched via `ollama launch claude` (doesn't write .launch-mode)
# Check env vars that indicate the model IS Ollama even if LAUNCH_MODE was never set
if [ "$CURRENT_MODE" = "opus" ]; then
  _detected_ollama=false
  # Check model name pattern (e.g., glm-5.1:cloud, qwen3:32b)
  if echo "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" | grep -qE '^[a-z0-9-]+:(cloud|local|[0-9]+b)$'; then
    _detected_ollama=true
  fi
  # Check base URL pointing to non-Anthropic host (e.g., localhost:11434)
  if [ -n "${ANTHROPIC_BASE_URL:-}" ] && ! echo "$ANTHROPIC_BASE_URL" | grep -q "anthropic.com"; then
    _detected_ollama=true
  fi
  if $_detected_ollama; then
    CURRENT_MODE="ollama"
  fi
fi

# Write .launch-mode so dashboard and ALL subsequent hooks detect mode correctly
mkdir -p "${PROJECT_DIR}/.claude" 2>/dev/null
echo "$CURRENT_MODE" > "${PROJECT_DIR}/.claude/.launch-mode" 2>/dev/null
echo "$CURRENT_MODE" > "$HOME/.claude/.launch-mode" 2>/dev/null

# Ensure .claude/ dir exists for hooks that write state files
mkdir -p "${PROJECT_DIR}/.claude" 2>/dev/null

# Reset session-scoped state files
: > "${PROJECT_DIR}/.claude/.session-skill-log" 2>/dev/null
if type -t state_set &>/dev/null; then
  state_set session delegation-count "0"
  state_set session hook-profile "${KIT_HOOK_PROFILE:-full}"
else
  echo "0" > "${PROJECT_DIR}/.claude/.session-delegation-count" 2>/dev/null
  echo "${KIT_HOOK_PROFILE:-full}" > "${PROJECT_DIR}/.claude/.hook-profile" 2>/dev/null
fi

# Persist env vars via CLAUDE_ENV_FILE (available in all subsequent Bash commands)
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export LAUNCH_MODE=\"$CURRENT_MODE\"" >> "$CLAUDE_ENV_FILE"
  echo "export KIT_PROJECT_DIR=\"$PROJECT_DIR\"" >> "$CLAUDE_ENV_FILE"
  [ -n "${OLLAMA_API_KEY:-}" ] && echo "export OLLAMA_API_KEY=\"$OLLAMA_API_KEY\"" >> "$CLAUDE_ENV_FILE"
fi

# Mode-specific announcement
if [ "$CURRENT_MODE" = "ollama" ]; then
  cat << 'EOF'
Mode: OLLAMA PRIMARY — Full Claude Code tools. Write code directly.
  Delegation enforcement: disabled
  Tier 2 CLI workers: available for parallel tasks (mcp-cli.sh ollama chat)
  Skills: require explicit Skill() invocation
EOF
else
  cat << 'EOF'
Mode: BRAIN — Orchestrator + workers
  Tier 1 CCC workers: /spawn MODEL "task"
  Tier 2 CLI workers: mcp-cli.sh ollama chat (quick code gen, reviews)
EOF
fi

echo ""

# Base session info — common hooks
cat << 'EOF'
Quality hooks active: git safety, secret detection, security checks, test reminders,
GitHub URL validation, skill invocation reminders, Context7 nudge, verify-after-fix.
EOF

# Mode-specific hooks and practices
if [ "$CURRENT_MODE" = "ollama" ]; then
  cat << 'EOF'

Best practices:
- Read files before editing, run tests after changes
- Follow conventional commits format
- Invoke skills with Skill("name") — NOT auto-activated
- Use mcp-cli.sh ollama chat for parallel sub-tasks (you are the primary coder)
- For complex collaborative work, consider agent teams — Skill("dispatching-parallel-agents")
EOF
else
  cat << 'EOF'
- Delegation enforcement (GRADUATED: advisory 11-50 lines, BLOCKS >50 lines unless delegated)
- Agent teams quality gates (when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)

Best practices:
- Read files before editing, run tests after changes
- Follow conventional commits format
- DELEGATE code generation >10 lines to Ollama workers (>50 lines BLOCKED without delegation)
- Use parallel mcp-cli.sh ollama chat swarm for multi-file tasks (cloud-first: glm-5.1:cloud)
- Cloud models available when OLLAMA_API_KEY is set; 3-tier fallback: cloud → local
- Invoke skills with Skill("name") — NOT auto-activated
- For complex collaborative work, consider agent teams (Tier 3) — Skill("dispatching-parallel-agents")
EOF
fi

# Project type detection
PROJECT_TIPS=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  # Node/Electron/React project
  HAS_ELECTRON=$(grep -q '"electron"' "$PROJECT_DIR/package.json" 2>/dev/null && echo "yes" || echo "no")
  HAS_REACT=$(grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null && echo "yes" || echo "no")
  HAS_VITE=$(grep -q '"vite"' "$PROJECT_DIR/package.json" 2>/dev/null && echo "yes" || echo "no")

  if [ "$HAS_ELECTRON" = "yes" ]; then
    PROJECT_TIPS="Electron project detected. Use Context7 for Electron/electron-builder docs."
  fi
  if [ "$HAS_REACT" = "yes" ]; then
    PROJECT_TIPS="${PROJECT_TIPS:+$PROJECT_TIPS }React frontend detected. Use Context7 for React docs."
  fi
  if [ "$HAS_VITE" = "yes" ]; then
    PROJECT_TIPS="${PROJECT_TIPS:+$PROJECT_TIPS }Vite bundler detected."
  fi
elif [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  PROJECT_TIPS="Python project detected. Activate venv first, use pytest for tests."
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  PROJECT_TIPS="Rust project detected. Use cargo build/test."
elif [ -f "$PROJECT_DIR/go.mod" ]; then
  PROJECT_TIPS="Go project detected. Use go build/test."
fi

# Embeddings status
EMBEDDINGS_FILE="$PROJECT_DIR/.claude/.embeddings/vectors.jsonl"
if [ -f "$EMBEDDINGS_FILE" ] && [ -s "$EMBEDDINGS_FILE" ]; then
  CHUNK_COUNT=$(wc -l < "$EMBEDDINGS_FILE" 2>/dev/null || echo 0)
  echo ""
  echo "Embeddings: $CHUNK_COUNT chunks indexed."
  echo "  BEFORE multi-round Grep/Glob, use: /embed --search \"query\""
  echo "  Find related files: /embed --related path/to/file"
fi

# Context warm-start: reload recent session snapshot if <1h old
SNAPSHOT="$PROJECT_DIR/.claude/.session-summary.json"
if [ -f "$SNAPSHOT" ]; then
  SNAP_TS=$(jq -r '.timestamp // empty' "$SNAPSHOT" 2>/dev/null)
  if [ -n "$SNAP_TS" ]; then
    SNAP_EPOCH=$(date -d "$SNAP_TS" +%s 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    AGE=$(( NOW_EPOCH - SNAP_EPOCH ))
    if [ "$AGE" -lt 3600 ] && [ "$AGE" -gt 0 ]; then
      OBS_COUNT=$(jq -r '.observations // 0' "$SNAPSHOT" 2>/dev/null)
      TOP_TOOLS=$(jq -r '.top_tools // {} | to_entries | map(.key) | join(", ")' "$SNAPSHOT" 2>/dev/null)
      echo ""
      echo "Warm start: previous session ${AGE}s ago ($OBS_COUNT observations, tools: $TOP_TOOLS)"
    fi
  fi
fi

# Git info
GIT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
GIT_CHANGES=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

if [ -n "$PROJECT_TIPS" ] || [ -n "$GIT_BRANCH" ]; then
  echo ""
  echo "Project context:"
  [ -n "$PROJECT_TIPS" ] && echo "  $PROJECT_TIPS"
  [ -n "$GIT_BRANCH" ] && echo "  Git: branch=$GIT_BRANCH, uncommitted changes=$GIT_CHANGES"
fi

# Auto-sync CLAUDE.md + AGENTS.md from kit source to project
# Works for any project (git or not), skips the kit repo itself
KIT_SOURCE="${KIT_ROOT:-}"
if [ -n "$KIT_SOURCE" ] && [ ! -f "$PROJECT_DIR/.claude-plugin/plugin.json" ]; then
  for docfile in CLAUDE.md AGENTS.md; do
    SRC="$KIT_SOURCE/$docfile"
    DST="$PROJECT_DIR/$docfile"
    [ -f "$SRC" ] || continue
    if [ ! -f "$DST" ]; then
      # New project — copy template, advise /init-project
      cp "$SRC" "$DST" 2>/dev/null && echo "Created $docfile from kit template. Run /init-project to customize."
    else
      SRC_HASH=$(md5sum "$SRC" 2>/dev/null | cut -d' ' -f1)
      DST_HASH=$(md5sum "$DST" 2>/dev/null | cut -d' ' -f1)
      if [ "$SRC_HASH" != "$DST_HASH" ]; then
        if [ "$docfile" = "CLAUDE.md" ] && grep -q "^## Project Config" "$DST" 2>/dev/null; then
          # Merge: kit header + project's Project Config section
          python3 -c "
import sys
source = open(sys.argv[1]).read()
target = open(sys.argv[2]).read()
marker = '## Project Config'
src_idx = source.find(marker)
src_header = source[:src_idx] if src_idx != -1 else source
tgt_idx = target.find(marker)
tgt_config = target[tgt_idx:] if tgt_idx != -1 else ''
open(sys.argv[2], 'w').write(src_header + tgt_config)
" "$SRC" "$DST" 2>/dev/null && echo "Synced CLAUDE.md (preserved Project Config)"
        else
          # AGENTS.md or CLAUDE.md without project config — overwrite
          cp "$SRC" "$DST" 2>/dev/null && echo "Synced $docfile from kit source"
        fi
      fi
    fi
  done
fi

# Global plugin auto-update (only in kit repo)
GLOBAL_PLUGIN="$HOME/.claude/plugins/local/agent-enhancement-kit"
if [ -f "$PROJECT_DIR/.claude-plugin/plugin.json" ] && [ -d "$GLOBAL_PLUGIN" ]; then
  KIT_TS=$(stat -c %Y "$PROJECT_DIR/hooks/hooks.json" 2>/dev/null || echo 0)
  GLB_TS=$(stat -c %Y "$GLOBAL_PLUGIN/hooks/hooks.json" 2>/dev/null || echo 0)
  if [ "$KIT_TS" -gt "$GLB_TS" ] 2>/dev/null; then
    echo ""
    echo "Global plugin is stale — auto-updating..."
    UPDATE_SCRIPT="$PROJECT_DIR/.claude/scripts/install-global.sh"
    if [ -f "$UPDATE_SCRIPT" ]; then
      bash "$UPDATE_SCRIPT" --force --skip-globals 2>&1 | tail -5
    else
      echo "Warning: install-global.sh not found. Run: /update-global --force"
    fi
  fi
fi

# Claude docs change detection (only in kit repo, max once every 3 days)
DOCS_CHECK_SCRIPT="$PROJECT_DIR/.claude/scripts/check-claude-docs.sh"
DOCS_STATUS="$PROJECT_DIR/.claude/.doc-snapshots/last-check.json"
OLLAMA_CHECK_SCRIPT="$PROJECT_DIR/.claude/scripts/check-ollama-docs.sh"
OLLAMA_STATUS="$PROJECT_DIR/.claude/.doc-snapshots/ollama/last-check.json"
if [ -f "$DOCS_CHECK_SCRIPT" ] && [ -f "$PROJECT_DIR/.claude-plugin/plugin.json" ]; then
  DOCS_AGE=999999
  if [ -f "$DOCS_STATUS" ]; then
    DOCS_TS=$(jq -r '.timestamp // empty' "$DOCS_STATUS" 2>/dev/null)
    if [ -n "$DOCS_TS" ]; then
      DOCS_EPOCH=$(date -d "$DOCS_TS" +%s 2>/dev/null || echo 0)
      DOCS_AGE=$(( $(date +%s) - DOCS_EPOCH ))
    fi
  fi
  if [ "$DOCS_AGE" -gt 259200 ]; then
    # >3 days since last check — run --deep to fetch changes (not just hash)
    bash "$DOCS_CHECK_SCRIPT" --deep > "$PROJECT_DIR/.claude/.doc-snapshots/last-run.log" 2>&1 &
  elif [ -f "$DOCS_STATUS" ]; then
    # If previous check found changes but wasn't deep, run --deep now
    PREV_CHANGES=$(jq -r '.changes_found // 0' "$DOCS_STATUS" 2>/dev/null || echo 0)
    if [ "$PREV_CHANGES" -gt 0 ] && [ ! -f "$PROJECT_DIR/.claude/.doc-snapshots/deep-done" ]; then
      bash "$DOCS_CHECK_SCRIPT" --deep > "$PROJECT_DIR/.claude/.doc-snapshots/last-run.log" 2>&1 &
      touch "$PROJECT_DIR/.claude/.doc-snapshots/deep-done" 2>/dev/null || true
    fi
  fi
  # Also check Ollama docs on same schedule
  if [ -f "$OLLAMA_CHECK_SCRIPT" ]; then
    OLLAMA_AGE=999999
    if [ -f "$OLLAMA_STATUS" ]; then
      OLL_TS=$(jq -r '.timestamp // empty' "$OLLAMA_STATUS" 2>/dev/null)
      if [ -n "$OLL_TS" ]; then
        OLL_EPOCH=$(date -d "$OLL_TS" +%s 2>/dev/null || echo 0)
        OLLAMA_AGE=$(( $(date +%s) - OLL_EPOCH ))
      fi
    fi
    if [ "$OLLAMA_AGE" -gt 259200 ]; then
      bash "$OLLAMA_CHECK_SCRIPT" --deep > "$PROJECT_DIR/.claude/.doc-snapshots/ollama/last-run.log" 2>&1 &
    fi
  fi
fi

exit 0
