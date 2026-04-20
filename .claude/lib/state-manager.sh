#!/bin/bash
# state-manager.sh — Unified read/write interface for all kit state
#
# Provides consistent API across tokens, logs, knowledge, metrics, and config.
# Each domain maps to underlying file(s) with format-aware operations.
#
# Usage:
#   source .claude/lib/state-manager.sh
#   state_get token delegation            # Read token timestamp
#   state_set token delegation "$(date +%s)"  # Write token
#   state_append observations '{"ts":...}'    # Append JSONL entry
#   state_query worker '.status=="success"'   # Query with jq filter
#   state_list knowledge                  # List knowledge topics
#   state_expire token                    # Clean expired tokens
#   state_exists token delegation         # Check if token exists + valid
#
# Domains: token, observation, session, audit, worker, knowledge, budget,
#          metric, dashboard, event, workstream, research

[[ -n "${_STATE_MANAGER_LOADED:-}" ]] && return 0
_STATE_MANAGER_LOADED=1

_PROJECT="${CLAUDE_PROJECT_DIR:-.}"
_STATE_BASE="$_PROJECT/.claude"

# --- Path resolution per domain ---

_state_path() {
  local domain="$1" key="${2:-}"
  case "$domain" in
    token)       echo "$_STATE_BASE/.tokens/${key}.token" ;;
    token-ttl)   echo "$_STATE_BASE/.tokens/${key}.ttl" ;;
    observation) echo "$_STATE_BASE/observations.jsonl" ;;
    session)
      case "$key" in
        summary)    echo "$_STATE_BASE/.session-summary.json" ;;
        name)       echo "$_STATE_BASE/.session-name" ;;
        snapshot)   echo "$_STATE_BASE/.session-snapshot.json" ;;
        skill-log)  echo "$_STATE_BASE/.session-skill-log" ;;
        delegation-count) echo "$_STATE_BASE/.session-delegation-count" ;;
        *)          echo "$_STATE_BASE/.session-${key}" ;;
      esac ;;
    audit)       echo "$_STATE_BASE/.audit-trail.jsonl" ;;
    worker)      echo "$_STATE_BASE/worker-performance.log" ;;
    knowledge)
      if [ -z "$key" ]; then
        echo "$_STATE_BASE/.knowledge/index.json"
      else
        local sanitized
        sanitized=$(echo "$key" | tr ' /A-Z' '--a-z' | tr -cd 'a-z0-9-')
        echo "$_STATE_BASE/.knowledge/topics/${sanitized}.md"
      fi ;;
    budget)      echo "$_STATE_BASE/.budget-thresholds.env" ;;
    metric)      echo "$_STATE_BASE/.metrics.jsonl" ;;
    dashboard)   echo "$_STATE_BASE/.dashboard-events.jsonl" ;;
    event)       echo "$_STATE_BASE/.events/${key}.jsonl" ;;
    workstream)
      case "$key" in
        state)  echo "$_STATE_BASE/.workstream-state" ;;
        events) echo "$_STATE_BASE/.workstream-events.jsonl" ;;
        *)      echo "$_STATE_BASE/.workstream-${key}" ;;
      esac ;;
    research)    echo "$_STATE_BASE/.research/.last-run.json" ;;
    judge)       echo "$_STATE_BASE/.judge-verdicts.jsonl" ;;
    guard)       echo "$_STATE_BASE/.output-guard.jsonl" ;;
    context)     echo "$_STATE_BASE/context-snapshot.json" ;;
    *)           echo "$_STATE_BASE/.${domain}" ;;
  esac
}

# --- Core API ---

# state_get DOMAIN KEY
# Read a value. Returns content or empty string.
state_get() {
  local domain="$1" key="${2:-}"
  local _fp
  _fp=$(_state_path "$domain" "$key")
  [ -f "$_fp" ] || return 1
  cat "$_fp" 2>/dev/null
}

# state_set DOMAIN KEY VALUE
# Write a value (overwrites). Creates parent dirs.
state_set() {
  local domain="$1" key="${2:-}" value="$3"
  local _fp
  _fp=$(_state_path "$domain" "$key")
  mkdir -p "$(dirname "$_fp")" 2>/dev/null
  echo "$value" > "$_fp"
}

# state_append DOMAIN ENTRY
# Append a line to a JSONL/log file. Auto-rotates when over limit.
# Domains: observation, audit, worker, metric, dashboard, judge, guard
state_append() {
  local domain="$1" entry="$2"
  local _fp
  _fp=$(_state_path "$domain")
  mkdir -p "$(dirname "$_fp")" 2>/dev/null
  echo "$entry" >> "$_fp"

  # Determine rotation limit based on domain
  local limit
  case "$domain" in
    observation) limit=1000 ;;
    audit) limit=10000 ;;
    worker) limit=2000 ;;
    metric) limit=50000 ;;
    *) limit=5000 ;;
  esac

  # Check line count and rotate if over limit
  local line_count
  line_count=$(wc -l < "$_fp" 2>/dev/null || echo 0)
  if [ "$line_count" -gt "$limit" ]; then
    tail -n $((limit - 1)) "$_fp" > "${_fp}.tmp" && mv "${_fp}.tmp" "$_fp"
  fi
}

# state_query DOMAIN JQ_FILTER [LIMIT]
# Query JSONL files with jq. Returns matching lines.
state_query() {
  local domain="$1" filter="$2" limit="${3:-50}"
  local _fp
  _fp=$(_state_path "$domain")
  [ -f "$_fp" ] || return 1
  tail -n 500 "$_fp" 2>/dev/null | jq -c "select($filter)" 2>/dev/null | tail -n "$limit"
}

# state_list DOMAIN
# List entries/keys for a domain.
state_list() {
  local domain="$1"
  case "$domain" in
    token)
      find "$_STATE_BASE/.tokens" -name '*.token' -exec basename {} .token \; 2>/dev/null | sort ;;
    knowledge)
      find "$_STATE_BASE/.knowledge/topics" -name '*.md' -exec basename {} .md \; 2>/dev/null | sort ;;
    event)
      find "$_STATE_BASE/.events" -maxdepth 1 -name '*.jsonl' -exec basename {} .jsonl \; 2>/dev/null | sort ;;
    session)
      echo "summary name snapshot skill-log delegation-count" | tr ' ' '\n' ;;
    *)
      local _fp
      _fp=$(_state_path "$domain")
      [ -f "$_fp" ] && wc -l < "$_fp" | tr -d ' '
      ;;
  esac
}

# state_exists DOMAIN KEY
# Check if state exists. For tokens, also validates TTL.
state_exists() {
  local domain="$1" key="${2:-}"
  local _fp
  _fp=$(_state_path "$domain" "$key")
  [ -f "$_fp" ] || return 1

  # Token TTL validation
  if [ "$domain" = "token" ]; then
    local created ttl_file ttl now
    created=$(cat "$_fp" 2>/dev/null)
    [ -z "$created" ] && return 1
    now=$(date +%s)

    # Check .ttl file first, then hardcoded defaults
    ttl_file="$_STATE_BASE/.tokens/${key}.ttl"
    if [ -f "$ttl_file" ]; then
      ttl=$(cat "$ttl_file" 2>/dev/null)
    else
      case "$key" in
        delegation)          ttl=300 ;;    # 5 min
        skill-*)             ttl=1800 ;;   # 30 min
        capability-pipeline) ttl=3600 ;;   # 60 min
        *)                   ttl=300 ;;    # default 5 min
      esac
    fi

    [ $((now - created)) -le "$ttl" ] 2>/dev/null || return 1
  fi
  return 0
}

# state_expire DOMAIN
# Clean expired entries for a domain.
state_expire() {
  local domain="$1"
  case "$domain" in
    token)
      local now
      now=$(date +%s)
      for tf in "$_STATE_BASE/.tokens"/*.token; do
        [ -f "$tf" ] || continue
        local name created ttl ttl_file
        name=$(basename "$tf" .token)
        created=$(cat "$tf" 2>/dev/null)
        [ -z "$created" ] && continue

        ttl_file="$_STATE_BASE/.tokens/${name}.ttl"
        if [ -f "$ttl_file" ]; then
          ttl=$(cat "$ttl_file" 2>/dev/null)
        else
          case "$name" in
            delegation)          ttl=300 ;;
            skill-*)             ttl=1800 ;;
            capability-pipeline) ttl=3600 ;;
            *)                   ttl=300 ;;
          esac
        fi

        if [ $((now - created)) -gt "$ttl" ] 2>/dev/null; then
          rm -f "$tf" "$ttl_file" 2>/dev/null
        fi
      done ;;
    audit)
      # Rotate if >10MB
      local _fp
      _fp=$(_state_path audit)
      if [ -f "$_fp" ]; then
        local size
        size=$(stat -c%s "$_fp" 2>/dev/null || echo 0)
        if [ "$size" -gt 10485760 ] 2>/dev/null; then
          mv "$_fp" "${_fp}.1" 2>/dev/null
          : > "$_fp"
        fi
      fi ;;
    observation)
      # Cap at 1000 lines
      local _fp
      _fp=$(_state_path observation)
      if [ -f "$_fp" ]; then
        local lines
        lines=$(wc -l < "$_fp" | tr -d ' ')
        if [ "$lines" -gt 1000 ] 2>/dev/null; then
          tail -n 1000 "$_fp" > "${_fp}.tmp" && mv "${_fp}.tmp" "$_fp"
        fi
      fi ;;
    event)
      # Delegate to event-bus cleanup if loaded
      if type event_cleanup &>/dev/null; then
        event_cleanup
      fi ;;
  esac
}

# state_count DOMAIN [JQ_FILTER]
# Count entries. Optional jq filter for JSONL domains.
state_count() {
  local domain="$1" filter="${2:-}"
  local _fp
  _fp=$(_state_path "$domain")
  [ -f "$_fp" ] || { echo 0; return; }

  if [ -n "$filter" ]; then
    jq -c "select($filter)" "$_fp" 2>/dev/null | wc -l | tr -d ' '
  else
    wc -l < "$_fp" 2>/dev/null | tr -d ' '
  fi
}

# state_last DOMAIN [N]
# Get last N entries from a JSONL domain. Default 1.
state_last() {
  local domain="$1" count="${2:-1}"
  local _fp
  _fp=$(_state_path "$domain")
  [ -f "$_fp" ] || return 1
  tail -n "$count" "$_fp" 2>/dev/null
}

# state_clear DOMAIN [KEY]
# Clear/truncate state. For JSONL: truncate file. For keyed: remove key.
state_clear() {
  local domain="$1" key="${2:-}"
  if [ -n "$key" ]; then
    local _fp
    _fp=$(_state_path "$domain" "$key")
    [ -f "$_fp" ] && : > "$_fp"
  else
    local _fp
    _fp=$(_state_path "$domain")
    [ -f "$_fp" ] && : > "$_fp"
  fi
}

# state_summary
# Quick overview of all state domains with entry counts.
state_summary() {
  echo "=== Kit State Summary ==="
  printf "%-15s %s\n" "Domain" "Entries/Size"
  printf "%-15s %s\n" "-------" "------------"

  # Tokens
  local tc
  tc=$(find "$_STATE_BASE/.tokens" -name '*.token' 2>/dev/null | wc -l | tr -d ' ')
  printf "%-15s %s active\n" "token" "$tc"

  # JSONL domains
  local _fp lines
  for domain in observation audit worker metric dashboard judge guard; do
    _fp=$(_state_path "$domain")
    if [ -f "$_fp" ]; then
      lines=$(wc -l < "$_fp" 2>/dev/null | tr -d ' ')
      printf "%-15s %s entries\n" "$domain" "$lines"
    else
      printf "%-15s %s\n" "$domain" "(none)"
    fi
  done

  # Knowledge
  local kc
  kc=$(find "$_STATE_BASE/.knowledge/topics" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  printf "%-15s %s topics\n" "knowledge" "$kc"

  # Events
  local ec
  ec=$(find "$_STATE_BASE/.events" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  printf "%-15s %s topics\n" "event" "$ec"

  # Session
  printf "%-15s %s\n" "session" "$([ -f "$_STATE_BASE/.session-name" ] && cat "$_STATE_BASE/.session-name" || echo '(unnamed)')"
}
