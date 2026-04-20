#!/bin/bash
# deepseek-fallback.sh — Query DeepSeek with automatic fallback chain
# Usage: bash .claude/scripts/deepseek-fallback.sh "your question here"
# Chain: deepseek-reasoner → deepseek-chat → Ollama deepseek-v3.2:cloud

QUESTION="${1:?Usage: deepseek-fallback.sh QUESTION}"
DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-}"
source "${BASH_SOURCE[0]%/*}/model-config.sh" 2>/dev/null

try_deepseek() {
    curl -s --max-time 30 -X POST https://api.deepseek.com/v1/chat/completions \
        -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$1\", \"messages\": [{\"role\": \"user\", \"content\": $(echo "$QUESTION" | jq -Rs .)}], \"max_tokens\": 4096}" 2>/dev/null
}

try_ollama() {
    curl -s --max-time 60 -X POST "$OLLAMA_HOST/api/chat" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${MODEL_WORKER_REASONING}\", \"messages\": [{\"role\": \"user\", \"content\": $(echo "$QUESTION" | jq -Rs .)}], \"stream\": false}" 2>/dev/null
}

extract() {
    echo "$1" | jq -r '(.choices[0].message.content // .message.content // empty)' 2>/dev/null
}

if [[ -n "$DEEPSEEK_API_KEY" ]]; then
    echo "Trying deepseek-reasoner..." >&2
    RESP=$(try_deepseek "deepseek-reasoner")
    CONTENT=$(extract "$RESP")
    if [[ -n "$CONTENT" ]]; then echo "$CONTENT"; exit 0; fi

    echo "Trying deepseek-chat..." >&2
    RESP=$(try_deepseek "deepseek-chat")
    CONTENT=$(extract "$RESP")
    if [[ -n "$CONTENT" ]]; then echo "$CONTENT"; exit 0; fi
fi

echo "Trying Ollama ${MODEL_WORKER_REASONING}..." >&2
RESP=$(try_ollama)
CONTENT=$(extract "$RESP")
if [[ -n "$CONTENT" ]]; then echo "$CONTENT"; exit 0; fi

echo "All DeepSeek providers failed" >&2
exit 1
