#!/bin/bash
# circuit-breaker.sh — Circuit breaker library for worker health management
# Inspired by Turnstone's BackendHealthMonitor + circuit breaker pattern
#
# States: CLOSED (healthy) → OPEN (skip) → HALF_OPEN (probe) → CLOSED
# Source this file: source .claude/lib/circuit-breaker.sh

CB_STATE_FILE="${CB_STATE_FILE:-${CLAUDE_PROJECT_DIR:-.}/.claude/.worker-health.json}"
CB_LOG_FILE="${CB_LOG_FILE:-${CLAUDE_PROJECT_DIR:-.}/.claude/.worker-health.log}"
CB_CONFIG_FILE="${CB_CONFIG_FILE:-${CLAUDE_PROJECT_DIR:-.}/.claude/config/health-config.yaml}"
CB_FAILURE_THRESHOLD=3
CB_COOLDOWN_SECONDS=60
CB_SUCCESS_THRESHOLD=2
CB_FALLBACK_CHAIN=("glm-5.1:cloud" "minimax-m2.7:cloud" "deepseek-v3.2:cloud" "qwen3-coder-next:cloud")

_cb_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_cb_log() { mkdir -p "$(dirname "$CB_LOG_FILE")" 2>/dev/null; echo "[$(_cb_ts)] $1" >> "$CB_LOG_FILE"; }
_cb_future_ts() {
  local s=$1
  date -u -d "+$s seconds" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
  date -u -v+${s}S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_cb_read_config() {
  [ -f "$CB_CONFIG_FILE" ] || return 0
  local v
  v=$(grep -E '^\s*failure_threshold:' "$CB_CONFIG_FILE" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' | head -1) && [ -n "$v" ] && CB_FAILURE_THRESHOLD="$v"
  v=$(grep -E '^\s*cooldown_seconds:' "$CB_CONFIG_FILE" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' | head -1) && [ -n "$v" ] && CB_COOLDOWN_SECONDS="$v"
  v=$(grep -E '^\s*success_threshold:' "$CB_CONFIG_FILE" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' | head -1) && [ -n "$v" ] && CB_SUCCESS_THRESHOLD="$v"
}

cb_init() {
  _cb_read_config
  mkdir -p "$(dirname "$CB_STATE_FILE")" 2>/dev/null
  [ -f "$CB_STATE_FILE" ] || echo '{"workers":{}}' > "$CB_STATE_FILE"
}

cb_get_state() {
  local worker="$1"
  cb_init
  jq -r ".workers[\"$worker\"].state // \"closed\"" "$CB_STATE_FILE" 2>/dev/null || echo "closed"
}

cb_should_allow() {
  local worker="$1"
  cb_check_cooldown "$worker"
  [ "$(cb_get_state "$worker")" != "open" ]
}

cb_check_cooldown() {
  local worker="$1"
  cb_init
  local cd
  cd=$(jq -r ".workers[\"$worker\"].cooldown_until // \"\"" "$CB_STATE_FILE" 2>/dev/null)
  [ -z "$cd" ] || [ "$cd" = "null" ] && return 0

  local now cdts
  now=$(date -u +%s)
  cdts=$(date -d "$cd" +%s 2>/dev/null || echo 0)
  [ "$now" -ge "$cdts" ] || return 0

  local tmp
  tmp=$(mktemp)
  jq ".workers[\"$worker\"].state = \"half_open\" | .workers[\"$worker\"].cooldown_until = \"\"" "$CB_STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$CB_STATE_FILE"
  _cb_log "TRANSITION: $worker -> HALF_OPEN (cooldown expired)"
}

cb_record_success() {
  local worker="$1" state ts succ tmp
  state=$(cb_get_state "$worker")
  ts=$(_cb_ts)
  cb_init
  tmp=$(mktemp)

  if [ "$state" = "half_open" ]; then
    succ=$(jq -r ".workers[\"$worker\"].successes // 0" "$CB_STATE_FILE" 2>/dev/null)
    succ=$((succ + 1))
    if [ "$succ" -ge "$CB_SUCCESS_THRESHOLD" ]; then
      jq ".workers[\"$worker\"] = {\"state\":\"closed\",\"failures\":0,\"successes\":0,\"last_success\":\"$ts\",\"last_failure\":\"\",\"opened_at\":\"\",\"cooldown_until\":\"\"}" "$CB_STATE_FILE" > "$tmp" && mv "$tmp" "$CB_STATE_FILE"
      _cb_log "TRANSITION: $worker -> CLOSED (probe succeeded)"
    else
      jq ".workers[\"$worker\"].successes = $succ | .workers[\"$worker\"].last_success = \"$ts\"" "$CB_STATE_FILE" > "$tmp" && mv "$tmp" "$CB_STATE_FILE"
    fi
  else
    jq ".workers[\"$worker\"] = {\"state\":\"closed\",\"failures\":0,\"successes\":0,\"last_success\":\"$ts\",\"last_failure\":\"\",\"opened_at\":\"\",\"cooldown_until\":\"\"}" "$CB_STATE_FILE" > "$tmp" && mv "$tmp" "$CB_STATE_FILE"
  fi
  rm -f "$tmp" 2>/dev/null || true
}

cb_record_failure() {
  local worker="$1" state ts cdts fail tmp
  state=$(cb_get_state "$worker")
  ts=$(_cb_ts)
  cdts=$(_cb_future_ts "$CB_COOLDOWN_SECONDS")
  cb_init
  tmp=$(mktemp)

  if [ "$state" = "half_open" ]; then
    jq ".workers[\"$worker\"] = {\"state\":\"open\",\"failures\":$CB_FAILURE_THRESHOLD,\"successes\":0,\"last_success\":\"\",\"last_failure\":\"$ts\",\"opened_at\":\"$ts\",\"cooldown_until\":\"$cdts\"}" "$CB_STATE_FILE" > "$tmp" && mv "$tmp" "$CB_STATE_FILE"
    _cb_log "TRANSITION: $worker -> OPEN (probe failed)"
  elif [ "$state" = "closed" ]; then
    fail=$(jq -r ".workers[\"$worker\"].failures // 0" "$CB_STATE_FILE" 2>/dev/null)
    fail=$((fail + 1))
    if [ "$fail" -ge "$CB_FAILURE_THRESHOLD" ]; then
      jq ".workers[\"$worker\"] = {\"state\":\"open\",\"failures\":$fail,\"successes\":0,\"last_success\":\"\",\"last_failure\":\"$ts\",\"opened_at\":\"$ts\",\"cooldown_until\":\"$cdts\"}" "$CB_STATE_FILE" > "$tmp" && mv "$tmp" "$CB_STATE_FILE"
      _cb_log "TRANSITION: $worker -> OPEN (threshold reached: $fail/$CB_FAILURE_THRESHOLD)"
    else
      jq ".workers[\"$worker\"].failures = $fail | .workers[\"$worker\"].last_failure = \"$ts\"" "$CB_STATE_FILE" > "$tmp" && mv "$tmp" "$CB_STATE_FILE"
    fi
  fi
  rm -f "$tmp" 2>/dev/null || true
}

cb_get_fallback() {
  local worker="$1" fb
  for fb in "${CB_FALLBACK_CHAIN[@]}"; do
    [ "$fb" = "$worker" ] && continue
    cb_check_cooldown "$fb"
    [ "$(cb_get_state "$fb")" != "open" ] && echo "$fb" && return 0
  done
  return 1
}
