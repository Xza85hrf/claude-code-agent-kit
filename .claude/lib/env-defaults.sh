#!/bin/bash
# env-defaults.sh — Centralized environment defaults for all kit scripts/hooks
#
# Usage: source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh"
#   Or:  source "$SCRIPTS_DIR/../lib/env-defaults.sh"
#
# Provides:
#   OLLAMA_HOST — Ollama API endpoint (default: WSL gateway IP:11434)
#   CLAUDE_PROJECT_DIR — Project root directory
#   SCRIPTS_DIR — Kit scripts directory (plugin-aware)

# Guard against double-sourcing
[[ -n "${_KIT_ENV_LOADED:-}" ]] && return 0
_KIT_ENV_LOADED=1

# Source API credentials first so any OLLAMA_HOST override set in
# ~/.claude-secrets takes effect before the probe below.
[[ -f "$HOME/.claude-secrets" ]] && source "$HOME/.claude-secrets" 2>/dev/null

# Project directory — resolution chain:
#   CLAUDE_PROJECT_DIR (Claude Code native) → KIT_PROJECT_DIR (session-start.sh) → git root → cwd
if [[ -z "${CLAUDE_PROJECT_DIR:-}" || "${CLAUDE_PROJECT_DIR}" == "." ]]; then
  export CLAUDE_PROJECT_DIR="${KIT_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
fi

# Derive kit root from this file's location (works when sourced by hooks)
_KIT_ROOT_DERIVED="$(cd "${BASH_SOURCE[0]%/*}/../.." 2>/dev/null && pwd)"

# Ollama host resolution (cached + validating). Order:
#   1. Cache hit (<5min): use it.
#   2. Inherited $OLLAMA_HOST that actually answers: use it.
#      (Shell rc files often hardcode a stale gateway IP that broke between
#       WSL restarts. Don't blindly trust — validate with a 1s probe.)
#   3. Probe http://localhost:11434 (mirrored WSL or Ollama running natively
#      inside WSL).
#   4. Probe http://<default-gateway>:11434 (NAT mode → Windows host Ollama).
#   5. Fallback to the gateway form anyway so downstream curls fail cleanly.
# The cache lives in $KIT/.claude/.ollama-host so every hook process doesn't
# reprobe. Delete it to force re-resolution.
_OLLAMA_CACHE="${CLAUDE_PROJECT_DIR:-${_KIT_ROOT_DERIVED:-$HOME}}/.claude/.tokens/ollama-host"
_OLLAMA_RESOLVED=""
# Cache hit?
if [[ -f "$_OLLAMA_CACHE" && -z "$(find "$_OLLAMA_CACHE" -mmin +5 -print 2>/dev/null)" ]]; then
  _OLLAMA_RESOLVED="$(cat "$_OLLAMA_CACHE" 2>/dev/null)"
fi
# Validate inherited value if cache missed
if [[ -z "$_OLLAMA_RESOLVED" && -n "${OLLAMA_HOST:-}" ]]; then
  if curl -s --connect-timeout 1 --max-time 1 "${OLLAMA_HOST}/" >/dev/null 2>&1; then
    _OLLAMA_RESOLVED="$OLLAMA_HOST"
  fi
fi
# Probe candidates if still no answer
if [[ -z "$_OLLAMA_RESOLVED" ]]; then
  _WSL_GATEWAY="$(ip route show default 2>/dev/null | awk '{print $3}')"
  for _candidate in "http://localhost:11434" "http://${_WSL_GATEWAY:-172.26.112.1}:11434"; do
    if curl -s --connect-timeout 1 --max-time 1 "${_candidate}/" >/dev/null 2>&1; then
      _OLLAMA_RESOLVED="$_candidate"
      break
    fi
  done
  _OLLAMA_RESOLVED="${_OLLAMA_RESOLVED:-http://${_WSL_GATEWAY:-172.26.112.1}:11434}"
  unset _WSL_GATEWAY _candidate
fi
# Write cache and export (overrides any stale inherited value)
mkdir -p "$(dirname "$_OLLAMA_CACHE")" 2>/dev/null || true
echo "$_OLLAMA_RESOLVED" > "$_OLLAMA_CACHE" 2>/dev/null || true
OLLAMA_HOST="$_OLLAMA_RESOLVED"
unset _OLLAMA_CACHE _OLLAMA_RESOLVED
export OLLAMA_HOST

# Plugin-compatible scripts resolution chain:
#   CLAUDE_PLUGIN_ROOT (hooks) → KIT_ROOT (env var) → BASH_SOURCE → project fallback
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/.claude/scripts}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${KIT_ROOT:+${KIT_ROOT}/.claude/scripts}}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${_KIT_ROOT_DERIVED:+${_KIT_ROOT_DERIVED}/.claude/scripts}}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${CLAUDE_PROJECT_DIR:-.}/.claude/scripts}"
export SCRIPTS_DIR

# Lib directory (for sourcing sibling libs)
export KIT_LIB_DIR="${BASH_SOURCE[0]%/*}"

# NTFS-safe file truncation (> file hangs on NTFS/WSL)
truncate_file() {
  python3 -c "open('$1','w').close()" 2>/dev/null || : > "$1"
}
