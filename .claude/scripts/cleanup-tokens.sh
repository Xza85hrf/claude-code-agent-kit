#!/bin/bash
# cleanup-tokens.sh — Manage ephemeral tokens in .claude/.tokens/
# Usage:
#   cleanup-tokens.sh sweep             # Remove expired tokens
#   cleanup-tokens.sh list              # Show all active tokens
#   cleanup-tokens.sh create NAME TTL   # Create a token (TTL in seconds)
#   cleanup-tokens.sh check NAME [TTL]  # Check if token exists and is valid
#   cleanup-tokens.sh revoke NAME       # Remove a specific token
#
# Token format: .claude/.tokens/{name}.token
# Content: Unix timestamp of creation
# TTL: Encoded in filename convention OR passed as parameter

TOKEN_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.tokens"
mkdir -p "$TOKEN_DIR" 2>/dev/null

create_token() {
  local name="$1" ttl="${2:-300}"
  date +%s > "$TOKEN_DIR/${name}.token" 2>/dev/null
  echo "$ttl" > "$TOKEN_DIR/${name}.ttl" 2>/dev/null
}

check_token() {
  local name="$1" ttl="${2:-}"
  local token_file="$TOKEN_DIR/${name}.token"
  local ttl_file="$TOKEN_DIR/${name}.ttl"

  [ -f "$token_file" ] || return 1

  local token_time
  token_time=$(cat "$token_file" 2>/dev/null)
  [ -z "$token_time" ] && return 1

  # Get TTL: explicit param > .ttl file > default 300
  if [ -z "$ttl" ] && [ -f "$ttl_file" ]; then
    ttl=$(cat "$ttl_file" 2>/dev/null)
  fi
  ttl="${ttl:-300}"

  local now age
  now=$(date +%s)
  age=$(( now - token_time ))

  [ "$age" -le "$ttl" ]
}

sweep() {
  local removed=0
  for token_file in "$TOKEN_DIR"/*.token; do
    [ -f "$token_file" ] || continue
    local name
    name=$(basename "$token_file" .token)
    if ! check_token "$name"; then
      rm -f "$token_file" "$TOKEN_DIR/${name}.ttl" 2>/dev/null
      removed=$((removed + 1))
    fi
  done
  echo "Swept $removed expired tokens."
}

list_tokens() {
  local now
  now=$(date +%s)
  local found=0

  for token_file in "$TOKEN_DIR"/*.token; do
    [ -f "$token_file" ] || continue
    found=$((found + 1))
    local name token_time ttl age remaining
    name=$(basename "$token_file" .token)
    token_time=$(cat "$token_file" 2>/dev/null || echo 0)
    ttl_file="$TOKEN_DIR/${name}.ttl"
    ttl=$(cat "$ttl_file" 2>/dev/null || echo 300)
    age=$(( now - token_time ))
    remaining=$(( ttl - age ))

    if [ "$remaining" -gt 0 ]; then
      echo "  ✓ $name — ${remaining}s remaining (TTL: ${ttl}s)"
    else
      echo "  ✗ $name — EXPIRED ${age}s ago (TTL: ${ttl}s)"
    fi
  done

  [ "$found" -eq 0 ] && echo "  No tokens."
}

revoke_token() {
  local name="$1"
  rm -f "$TOKEN_DIR/${name}.token" "$TOKEN_DIR/${name}.ttl" 2>/dev/null
  echo "Revoked: $name"
}

case "${1:-}" in
  create)  create_token "$2" "${3:-300}" ;;
  check)   check_token "$2" "${3:-}" ;;
  sweep)   sweep ;;
  list)    list_tokens ;;
  revoke)  revoke_token "$2" ;;
  *)
    echo "Usage: cleanup-tokens.sh {create|check|sweep|list|revoke} [args]"
    echo "  create NAME [TTL_SECS]    Create token (default TTL: 300s)"
    echo "  check  NAME [TTL_SECS]    Check if valid (exit 0=valid, 1=expired)"
    echo "  sweep                     Remove all expired tokens"
    echo "  list                      Show all tokens with remaining time"
    echo "  revoke NAME               Delete a specific token"
    exit 1
    ;;
esac
