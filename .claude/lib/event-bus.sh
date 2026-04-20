#!/bin/bash
# event-bus.sh — Internal pub/sub for hook-to-hook communication
#
# Enables hooks to communicate without going through git commit or token files.
# File-based JSONL topics with TTL cleanup.
#
# Usage:
#   source .claude/lib/event-bus.sh
#   event_publish "sync" '{"trigger":"model-config.sh","action":"kit-sync"}'
#   event_subscribe "sync" callback_fn
#   event_peek "sync"              # last event
#   event_drain "sync" 5           # last 5 events
#   event_cleanup                  # prune expired events
#
# Topics: sync, skill, delegation, worker, audit, phoenix, health
# Events stored: .claude/.events/{topic}.jsonl
# Checkpoints: .claude/.events/.cursors/{subscriber}.{topic}

[[ -n "${_EVENT_BUS_LOADED:-}" ]] && return 0
_EVENT_BUS_LOADED=1

_EVENT_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.events"
_CURSOR_DIR="$_EVENT_DIR/.cursors"
_EVENT_TTL="${EVENT_BUS_TTL:-3600}"  # default 1 hour

# Ensure dirs exist
mkdir -p "$_EVENT_DIR" "$_CURSOR_DIR" 2>/dev/null

# event_publish TOPIC DATA
# Append a timestamped event to topic. DATA is a JSON string or plain text.
event_publish() {
  local topic="$1" data="$2"
  local ts
  ts=$(date +%s)
  local file="$_EVENT_DIR/${topic}.jsonl"

  # Build event JSON
  local event
  if echo "$data" | jq empty 2>/dev/null; then
    event=$(jq -nc --arg ts "$ts" --arg topic "$topic" --argjson data "$data" \
      '{ts:($ts|tonumber),topic:$topic,data:$data}')
  else
    event=$(jq -nc --arg ts "$ts" --arg topic "$topic" --arg data "$data" \
      '{ts:($ts|tonumber),topic:$topic,data:$data}')
  fi

  echo "$event" >> "$file"
}

# event_peek TOPIC [N]
# Print last N events (default 1) from topic. Returns JSON lines.
event_peek() {
  local topic="$1" count="${2:-1}"
  local file="$_EVENT_DIR/${topic}.jsonl"
  [ -f "$file" ] || return 0
  tail -n "$count" "$file" 2>/dev/null
}

# event_drain TOPIC [N]
# Read last N events, output to stdout. No cursor tracking.
event_drain() {
  local topic="$1" count="${2:-10}"
  local file="$_EVENT_DIR/${topic}.jsonl"
  [ -f "$file" ] || return 0
  tail -n "$count" "$file" 2>/dev/null
}

# event_since TOPIC SINCE_TS
# Read all events after timestamp. Used for cursor-based subscription.
event_since() {
  local topic="$1" since="$2"
  local file="$_EVENT_DIR/${topic}.jsonl"
  [ -f "$file" ] || return 0
  awk -v since="$since" -F'"ts":' '{
    split($2, a, /[,}]/);
    if (a[1]+0 > since+0) print
  }' "$file" 2>/dev/null
}

# event_subscribe TOPIC SUBSCRIBER_NAME CALLBACK_FN
# Read unprocessed events for subscriber, call callback for each, update cursor.
event_subscribe() {
  local topic="$1" subscriber="$2" callback="$3"
  local cursor_file="$_CURSOR_DIR/${subscriber}.${topic}"
  local last_ts=0 events latest_ts event_ts

  [ -f "$cursor_file" ] && last_ts=$(cat "$cursor_file" 2>/dev/null)

  events=$(event_since "$topic" "$last_ts")
  [ -z "$events" ] && return 0

  latest_ts="$last_ts"
  while IFS= read -r event; do
    [ -z "$event" ] && continue
    event_ts=$(echo "$event" | jq -r '.ts' 2>/dev/null)
    "$callback" "$event" 2>/dev/null
    if [ "$event_ts" -gt "$latest_ts" ] 2>/dev/null; then
      latest_ts="$event_ts"
    fi
  done <<< "$events"

  echo "$latest_ts" > "$cursor_file"
}

# event_count TOPIC
# Count events in topic file.
event_count() {
  local file="$_EVENT_DIR/${1}.jsonl"
  [ -f "$file" ] || { echo 0; return; }
  wc -l < "$file" | tr -d ' '
}

# event_topics
# List all active topics.
event_topics() {
  find "$_EVENT_DIR" -maxdepth 1 -name '*.jsonl' -exec basename {} .jsonl \; 2>/dev/null | sort
}

# event_cleanup [TTL_SECONDS]
# Remove events older than TTL from all topics. Compact files in place.
event_cleanup() {
  local ttl="${1:-$_EVENT_TTL}"
  local cutoff
  cutoff=$(( $(date +%s) - ttl ))

  for file in "$_EVENT_DIR"/*.jsonl; do
    [ -f "$file" ] || continue
    local tmp="${file}.tmp"
    awk -v cutoff="$cutoff" -F'"ts":' '{
      split($2, a, /[,}]/);
      if (a[1]+0 >= cutoff+0) print
    }' "$file" > "$tmp" 2>/dev/null
    mv "$tmp" "$file" 2>/dev/null
  done

  # Clean stale cursors (subscribers gone for >24h)
  find "$_CURSOR_DIR" -type f -mmin +1440 -delete 2>/dev/null
}

# event_reset TOPIC
# Clear all events for a topic.
event_reset() {
  local file="$_EVENT_DIR/${1}.jsonl"
  [ -f "$file" ] && : > "$file"
}

# event_wait TOPIC TIMEOUT_SECS
# Block until a new event appears on topic or timeout. Returns 0 if event, 1 if timeout.
event_wait() {
  local topic="$1" timeout="${2:-30}"
  local file="$_EVENT_DIR/${topic}.jsonl"
  local start_count
  start_count=$(event_count "$topic")

  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    sleep 1
    elapsed=$((elapsed + 1))
    local now_count
    now_count=$(event_count "$topic")
    if [ "$now_count" -gt "$start_count" ]; then
      return 0
    fi
  done
  return 1
}
