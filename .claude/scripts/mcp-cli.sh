#!/usr/bin/env bash
# mcp-cli.sh — CLI wrappers for MCP servers (replaces MCP tool calls with direct API)
# Saves ~28K context tokens by removing ollama/deepseek/firecrawl MCP servers
# Usage: bash .claude/scripts/mcp-cli.sh <service> <command> [args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/env-defaults.sh" 2>/dev/null || true
# Shared Ollama cap detection — also used by spawn-worker.sh. Defines
# check_ollama_quota() and _worker_status_file(). See worker-quota.sh
# for the cap-signal regex and .worker-status reset semantics.
source "${SCRIPT_DIR}/../lib/worker-quota.sh" 2>/dev/null || true

# ─── Config ───────────────────────────────────────────────────────────
OLLAMA_HOST="${OLLAMA_HOST:-http://$(ip route show default | awk '{print $3}'):11434}"
DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-$(grep DEEPSEEK_API_KEY ~/.claude-secrets 2>/dev/null | cut -d= -f2)}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-$(grep FIRECRAWL_API_KEY ~/.claude-secrets 2>/dev/null | cut -d= -f2)}"

# ─── Helpers ──────────────────────────────────────────────────────────
json_output() { jq -r '.' 2>/dev/null <<< "$1" || echo "$1"; }

die() { echo "ERROR: $*" >&2; exit 1; }

# ─── Ollama ───────────────────────────────────────────────────────────
ollama_chat() {
  local model="${1:?model required}" prompt="${2:?prompt required}" system="${3:-}" temperature="${4:-0.7}"
  local body raw
  body=$(jq -n \
    --arg model "$model" \
    --arg system "$system" \
    --arg prompt "$prompt" \
    --argjson temp "$temperature" \
    '{model: $model, messages: ([if $system != "" then {role:"system",content:$system} else empty end] + [{role:"user",content:$prompt}]), stream: false, options: {temperature: $temp}}')
  raw=$(curl -sS "${OLLAMA_HOST}/api/chat" -d "$body")
  check_ollama_quota "$raw" "mcp-cli" || true
  jq -r '.message.content // .error // .' <<< "$raw"
}

ollama_generate() {
  local model="${1:?model required}" prompt="${2:?prompt required}" system="${3:-}" temperature="${4:-0.7}"
  local body raw
  body=$(jq -n \
    --arg model "$model" \
    --arg system "$system" \
    --arg prompt "$prompt" \
    --argjson temp "$temperature" \
    '{model: $model, prompt: $prompt, system: $system, stream: false, options: {temperature: $temp}}')
  raw=$(curl -sS "${OLLAMA_HOST}/api/generate" -d "$body")
  check_ollama_quota "$raw" "mcp-cli" || true
  jq -r '.response // .error // .' <<< "$raw"
}

ollama_embed() {
  local model="${1:?model required}" input="${2:?input required}"
  curl -sS "${OLLAMA_HOST}/api/embed" -d "$(jq -n --arg m "$model" --arg i "$input" '{model:$m,input:$i}')" | jq '.embeddings'
}

ollama_list() { curl -sS "${OLLAMA_HOST}/api/tags" | jq -r '.models[] | "\(.name)\t\(.size / 1048576 | floor)MB"'; }
ollama_ps() { curl -sS "${OLLAMA_HOST}/api/ps" | jq '.models'; }
ollama_show() { curl -sS "${OLLAMA_HOST}/api/show" -d "$(jq -n --arg m "${1:?model}" '{name:$m}')"; }
ollama_pull() { curl -sS "${OLLAMA_HOST}/api/pull" -d "$(jq -n --arg m "${1:?model}" '{name:$m,stream:false}')"; }
ollama_delete() { curl -sS -X DELETE "${OLLAMA_HOST}/api/delete" -d "$(jq -n --arg m "${1:?model}" '{name:$m}')"; }
ollama_copy() { curl -sS "${OLLAMA_HOST}/api/copy" -d "$(jq -n --arg s "${1:?source}" --arg d "${2:?dest}" '{source:$s,destination:$d}')"; }

ollama_web_search() {
  local model="${1:?model required}" query="${2:?query required}"
  curl -sS "${OLLAMA_HOST}/api/chat" -d "$(jq -n \
    --arg m "$model" --arg q "$query" \
    '{model:$m,messages:[{role:"user",content:$q}],stream:false,tools:[{type:"function",function:{name:"web_search",description:"Search the web",parameters:{type:"object",properties:{query:{type:"string"}},required:["query"]}}}]}')" | jq '.'
}

ollama_web_fetch() {
  local url="${1:?url required}"
  curl -sS "${OLLAMA_HOST}/api/chat" -d "$(jq -n \
    --arg u "$url" \
    '{model:"glm-4.7-flash",messages:[{role:"user",content:("Fetch and summarize: " + $u)}],stream:false}')" | jq -r '.message.content // .'
}

# ─── DeepSeek ─────────────────────────────────────────────────────────
deepseek_chat() {
  local model="${1:-deepseek-chat}" prompt="${2:?prompt required}" system="${3:-}" temperature="${4:-0.7}"
  [ -z "$DEEPSEEK_API_KEY" ] && die "DEEPSEEK_API_KEY not set"
  local body
  body=$(jq -n \
    --arg model "$model" \
    --arg system "$system" \
    --arg prompt "$prompt" \
    --argjson temp "$temperature" \
    '{model: $model, messages: ([if $system != "" then {role:"system",content:$system} else empty end] + [{role:"user",content:$prompt}]), temperature: $temp, stream: false}')
  curl -sS "https://api.deepseek.com/chat/completions" \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" | jq -r '.choices[0].message.content // .error // .'
}

deepseek_list_models() {
  [ -z "$DEEPSEEK_API_KEY" ] && die "DEEPSEEK_API_KEY not set"
  curl -sS "https://api.deepseek.com/models" \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" | jq -r '.data[].id'
}

deepseek_balance() {
  [ -z "$DEEPSEEK_API_KEY" ] && die "DEEPSEEK_API_KEY not set"
  curl -sS "https://api.deepseek.com/user/balance" \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" | jq '.'
}

# ─── Firecrawl ────────────────────────────────────────────────────────
FIRECRAWL_BASE="https://api.firecrawl.dev/v1"

firecrawl_scrape() {
  local url="${1:?url required}" formats="${2:-markdown}"
  [ -z "$FIRECRAWL_API_KEY" ] && die "FIRECRAWL_API_KEY not set"
  curl -sS "${FIRECRAWL_BASE}/scrape" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg u "$url" --arg f "$formats" '{url:$u,formats:($f | split(","))}' )" | jq '.'
}

firecrawl_crawl() {
  local url="${1:?url required}" limit="${2:-10}"
  [ -z "$FIRECRAWL_API_KEY" ] && die "FIRECRAWL_API_KEY not set"
  curl -sS "${FIRECRAWL_BASE}/crawl" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg u "$url" --argjson l "$limit" '{url:$u,limit:$l}')" | jq '.'
}

firecrawl_search() {
  local query="${1:?query required}" limit="${2:-5}"
  [ -z "$FIRECRAWL_API_KEY" ] && die "FIRECRAWL_API_KEY not set"
  curl -sS "${FIRECRAWL_BASE}/search" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg q "$query" --argjson l "$limit" '{query:$q,limit:$l}')" | jq '.'
}

firecrawl_map() {
  local url="${1:?url required}"
  [ -z "$FIRECRAWL_API_KEY" ] && die "FIRECRAWL_API_KEY not set"
  curl -sS "${FIRECRAWL_BASE}/map" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg u "$url" '{url:$u}')" | jq '.'
}

firecrawl_extract() {
  local url="${1:?url required}" schema="${2:-}"
  [ -z "$FIRECRAWL_API_KEY" ] && die "FIRECRAWL_API_KEY not set"
  local body
  if [ -n "$schema" ]; then
    body=$(jq -n --arg u "$url" --argjson s "$schema" '{urls:[$u],schema:$s}')
  else
    body=$(jq -n --arg u "$url" '{urls:[$u]}')
  fi
  curl -sS "${FIRECRAWL_BASE}/extract" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" | jq '.'
}

# ─── Router ───────────────────────────────────────────────────────────
SERVICE="${1:?Usage: mcp-cli.sh <service> <command> [args...]}"
COMMAND="${2:?Usage: mcp-cli.sh <service> <command> [args...]}"
shift 2

# Guard: warn if remaining args start with -- (positional-only API)
if [[ "${1:-}" == --* ]]; then
  echo "WARNING: mcp-cli.sh uses positional args, not flags." >&2
  echo "  Usage: mcp-cli.sh $SERVICE $COMMAND \"model\" \"prompt\" [\"system\"] [\"temp\"]" >&2
  echo "  Got: mcp-cli.sh $SERVICE $COMMAND $*" >&2
  die "Use positional args: mcp-cli.sh $SERVICE $COMMAND \"value1\" \"value2\" ..."
fi

case "${SERVICE}" in
  ollama)
    case "${COMMAND}" in
      chat)     ollama_chat "$@" ;;
      generate) ollama_generate "$@" ;;
      embed)    ollama_embed "$@" ;;
      list)     ollama_list ;;
      ps)       ollama_ps ;;
      show)     ollama_show "$@" ;;
      pull)     ollama_pull "$@" ;;
      delete)   ollama_delete "$@" ;;
      copy)     ollama_copy "$@" ;;
      web_search) ollama_web_search "$@" ;;
      web_fetch)  ollama_web_fetch "$@" ;;
      *)        die "Unknown ollama command: ${COMMAND}" ;;
    esac ;;
  deepseek)
    case "${COMMAND}" in
      chat)        deepseek_chat "$@" ;;
      list_models) deepseek_list_models ;;
      balance)     deepseek_balance ;;
      *)           die "Unknown deepseek command: ${COMMAND}" ;;
    esac ;;
  firecrawl)
    case "${COMMAND}" in
      scrape)  firecrawl_scrape "$@" ;;
      crawl)   firecrawl_crawl "$@" ;;
      search)  firecrawl_search "$@" ;;
      map)     firecrawl_map "$@" ;;
      extract) firecrawl_extract "$@" ;;
      *)       die "Unknown firecrawl command: ${COMMAND}" ;;
    esac ;;
  *)
    die "Unknown service: ${SERVICE}. Available: ollama, deepseek, firecrawl" ;;
esac
