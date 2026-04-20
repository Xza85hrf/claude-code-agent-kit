#!/usr/bin/env bash
# list-provider-models.sh — Query all API providers for available models
#
# Usage:
#   bash .claude/scripts/list-provider-models.sh              # All providers
#   bash .claude/scripts/list-provider-models.sh openai       # OpenAI only
#   bash .claude/scripts/list-provider-models.sh gemini       # Gemini only
#   bash .claude/scripts/list-provider-models.sh ollama       # Ollama only
#   bash .claude/scripts/list-provider-models.sh deepseek     # DeepSeek only
#   bash .claude/scripts/list-provider-models.sh --config     # Show current config
#
# Helps you pick the latest models when updating model-config.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model-config.sh" 2>/dev/null

FILTER="${1:-all}"
TIMEOUT=15

# ── OpenAI ──────────────────────────────────────────────
list_openai() {
  local key="${OPENAI_API_KEY:-}"
  if [[ -z "$key" ]]; then
    echo "  [SKIP] OPENAI_API_KEY not set"
    return
  fi

  local response
  response=$(curl -s --max-time "$TIMEOUT" "https://api.openai.com/v1/models" \
    -H "Authorization: Bearer $key" 2>/dev/null)

  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = sorted([m['id'] for m in data.get('data', [])], key=lambda x: x.lower())
# Group by prefix
groups = {}
for m in models:
    prefix = m.split('-')[0] + '-' + m.split('-')[1] if '-' in m else m
    groups.setdefault(prefix, []).append(m)

# Show most relevant groups
priority = ['gpt-5', 'gpt-4', 'o3', 'o4', 'gpt-image']
shown = set()
for p in priority:
    for key in sorted(groups.keys()):
        if key.startswith(p) and key not in shown:
            shown.add(key)
            for m in groups[key]:
                print(f'  {m}')
" 2>/dev/null || echo "  [ERROR] Failed to parse response"
}

# ── Gemini ──────────────────────────────────────────────
list_gemini() {
  local key="${GEMINI_API_KEY:-}"
  if [[ -z "$key" ]]; then
    echo "  [SKIP] GEMINI_API_KEY not set"
    return
  fi

  local response
  response=$(curl -s --max-time "$TIMEOUT" \
    "https://generativelanguage.googleapis.com/v1beta/models?key=${key}" 2>/dev/null)

  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = [m['name'].replace('models/', '') for m in data.get('models', [])]
# Filter to relevant models (gemini-3, gemini-2.5, skip gemma/embedding)
relevant = [m for m in sorted(models) if m.startswith('gemini-') and 'embed' not in m]
for m in relevant:
    tag = ''
    if '3.1' in m: tag = ' ← LATEST'
    elif '3-' in m: tag = ' ← CURRENT'
    elif '2.0' in m: tag = ' ⚠ RETIRING Jun 2026'
    print(f'  {m}{tag}')
" 2>/dev/null || echo "  [ERROR] Failed to parse response"
}

# ── Ollama ──────────────────────────────────────────────
list_ollama() {
  local auth_header=""
  [[ -n "${OLLAMA_API_KEY:-}" ]] && auth_header="Authorization: Bearer $OLLAMA_API_KEY"

  local response
  response=$(curl -s --max-time "$TIMEOUT" "${OLLAMA_HOST}/api/tags" \
    ${auth_header:+-H "$auth_header"} 2>/dev/null)

  if [[ -z "$response" ]] || echo "$response" | grep -q "error"; then
    echo "  [ERROR] Ollama not reachable at $OLLAMA_HOST"
    return
  fi

  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = sorted([m['name'] for m in data.get('models', [])])
cloud = [m for m in models if ':cloud' in m]
local = [m for m in models if ':cloud' not in m]
if cloud:
    print('  Cloud models:')
    for m in cloud: print(f'    {m}')
if local:
    print('  Local models:')
    for m in local: print(f'    {m}')
if not cloud and not local:
    print('  No models found')
" 2>/dev/null || echo "  [ERROR] Failed to parse response"
}

# ── DeepSeek ────────────────────────────────────────────
list_deepseek() {
  local key="${DEEPSEEK_API_KEY:-}"
  if [[ -z "$key" ]]; then
    echo "  [SKIP] DEEPSEEK_API_KEY not set"
    return
  fi

  local response
  response=$(curl -s --max-time "$TIMEOUT" "https://api.deepseek.com/v1/models" \
    -H "Authorization: Bearer $key" 2>/dev/null)

  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = sorted([m['id'] for m in data.get('data', [])])
for m in models:
    print(f'  {m}')
" 2>/dev/null || echo "  [ERROR] Failed to parse response"
}

# ── Main ────────────────────────────────────────────────
if [[ "$FILTER" == "--config" ]]; then
  list_configured_models
  exit 0
fi

echo "# Available Models by Provider"
echo "# Run: bash .claude/scripts/list-provider-models.sh"
echo "# Then update: .claude/scripts/model-config.sh"
echo ""

if [[ "$FILTER" == "all" || "$FILTER" == "openai" ]]; then
  echo "## OpenAI (current: $MODEL_AUDIT_OPENAI / $MODEL_FRONTEND_OPENAI)"
  list_openai
  echo ""
fi

if [[ "$FILTER" == "all" || "$FILTER" == "gemini" ]]; then
  echo "## Gemini (current: $MODEL_AUDIT_GEMINI / $MODEL_FRONTEND_PRIMARY)"
  list_gemini
  echo ""
fi

if [[ "$FILTER" == "all" || "$FILTER" == "ollama" ]]; then
  echo "## Ollama (current: $MODEL_WORKER_PRIMARY)"
  list_ollama
  echo ""
fi

if [[ "$FILTER" == "all" || "$FILTER" == "deepseek" ]]; then
  echo "## DeepSeek (current: $MODEL_AUDIT_DEEPSEEK)"
  list_deepseek
  echo ""
fi

echo "---"
echo "To update models: edit .claude/scripts/model-config.sh"
