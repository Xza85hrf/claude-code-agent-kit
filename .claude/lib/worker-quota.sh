#!/usr/bin/env bash
# worker-quota.sh — Shared Ollama-cloud quota-cap detection for worker entry points.
#
# Why this exists: every path that actually calls an Ollama cloud model
# (mcp-cli.sh's raw API wrappers, spawn-worker.sh's claude -p runs,
# multi-model-audit.sh, etc.) needs the same regex to spot the same
# "you are out of weekly quota" error. Keeping the patterns in one file
# stops the entry points from drifting — add a new cap string once and
# every caller benefits.
#
# Consumer: delegation-reminder.sh reads .claude/.worker-status and
# treats "capped" identically to "offline", downgrading the BLOCK tier
# to allow-with-warning so the brain can still write code directly
# instead of deadlocking against an unreachable worker pool.
#
# Reset: session-status.sh rewrites .worker-status on SessionStart after
# its /api/tags probe, so a restored quota auto-clears the cap on the
# next session. Mid-session, the cap stays sticky until something
# explicitly rewrites the file.
#
# Usage:
#   source .claude/lib/worker-quota.sh
#   check_ollama_quota "$raw_response_string" "mcp-cli"
#   check_ollama_quota "$output_file_path"   "spawn-worker"
#
# Returns 0 if a cap was detected (and .worker-status is updated),
# 1 otherwise. Always succeeds even when the status file cannot be
# written — we never want this helper to crash a worker caller.

# Guard against double-sourcing
[ "${_KIT_WORKER_QUOTA_LOADED:-0}" = 1 ] && return 0
_KIT_WORKER_QUOTA_LOADED=1

_worker_status_file() {
  echo "${CLAUDE_PROJECT_DIR:-${PWD}}/.claude/.worker-status"
}

# Ollama cap-signal regex. Observed envelopes (as of 2026-04-15):
#   - "https://ollama.com/upgrade" link in 403 permission_error responses
#   - "weekly usage limit" in plain-text error messages
#   - "model is experiencing high volume" preamble on cloud models
#   - "subscription is required" in paywall-gated responses
# Keep alternatives in one place so new cap strings only need adding here.
_WORKER_QUOTA_REGEX='ollama\.com/upgrade|weekly usage limit|experiencing high volume|subscription is required'

# check_ollama_quota INPUT [SOURCE]
#   INPUT  — a response string OR a path to a file containing one
#   SOURCE — optional label for the warning message (default: "worker")
# Sets .worker-status=capped and emits a stderr warning on hit. Idempotent.
check_ollama_quota() {
  local input="${1:-}"
  local source="${2:-worker}"
  [ -z "$input" ] && return 1

  local hit=0
  if [ -f "$input" ]; then
    grep -qE "$_WORKER_QUOTA_REGEX" "$input" 2>/dev/null && hit=1
  else
    printf '%s' "$input" | grep -qE "$_WORKER_QUOTA_REGEX" 2>/dev/null && hit=1
  fi

  [ "$hit" = 1 ] || return 1

  local sf
  sf=$(_worker_status_file)
  mkdir -p "$(dirname "$sf")" 2>/dev/null || true
  echo "capped" > "$sf" 2>/dev/null || true
  echo "[$source] ollama worker quota hit — .worker-status=capped (resets on next SessionStart)" >&2
  return 0
}

# get_local_fallback_model [LIST]
#   LIST — optional pre-captured `ollama list` output (injection point for
#          tests; if absent, runs the command directly).
# Picks the best locally-downloaded model for worker retry when cloud is
# capped. Cloud models show SIZE "-"; local ones show actual sizes — so
# the `$3 != "-"` filter leaves only downloaded models. Preference list
# ordered by SWE-Bench / code-task suitability; falls through to the
# first-available local model if none of the preferred ones are present.
# Returns 0 + model name on stdout; 1 + empty stdout when nothing local.
get_local_fallback_model() {
  local list
  if [ $# -eq 0 ]; then
    list=$(ollama list 2>/dev/null)
  else
    # Explicit arg (even empty string) = caller is injecting test fixture.
    # Don't silently fall back to the real `ollama list` — that hides empty
    # fixtures and makes "no local available" cases untestable.
    list="$1"
  fi
  local available
  available=$(printf '%s\n' "$list" | awk 'NR>1 && $3 != "-" {print $1}')
  [ -z "$available" ] && return 1
  # Preference order: minimum VRAM first among code-competent local models,
  # so a loaded cap-downgrade retry doesn't also gatecrash the GPU budget.
  # deepcoder:latest (9GB) fits on any card; glm-4.7-flash (19GB) and
  # gemma4:31b (19GB) fit a single 3090 Ti; nemotron (24GB) tight single-card;
  # qwen3-coder-next (51GB) requires multi-card and is the last resort.
  local model
  for model in deepcoder:latest gpt-oss:20b glm-4.7-flash:latest gemma4:31b nemotron-cascade-2:30b qwen3-coder-next:latest; do
    if printf '%s\n' "$available" | grep -qFx "$model"; then
      printf '%s\n' "$model"
      return 0
    fi
  done
  printf '%s\n' "$available" | head -1
}
