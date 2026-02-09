#!/bin/bash
# Hook: Check Ollama worker model availability at session start
# SessionStart hook — runs alongside session-start.sh
#
# Detects cloud (via OLLAMA_API_KEY) and local models.
# Reports availability status for each tier.
# Fails gracefully if Ollama is unreachable (just reports it).

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

# Define expected models per tier
CLOUD_MODELS="qwen3-coder-next:cloud glm-4.7:cloud kimi-k2.5:cloud gemini-3-pro-preview"
LOCAL_MODELS="qwen3-coder-next:latest glm-4.7-flash qwen3-vl:32b devstral-small-2 deepcoder"

# Try to reach Ollama with a short timeout
MODELS_JSON=$(curl -s --max-time 3 "$OLLAMA_HOST/api/tags" 2>/dev/null)

echo "Ollama worker status:"

# Cloud tier: available when OLLAMA_API_KEY is set and non-empty
if [ -n "$OLLAMA_API_KEY" ]; then
  CLOUD_LIST=$(echo "$CLOUD_MODELS" | sed 's/ /, /g')
  echo "  Cloud (OLLAMA_API_KEY set): $CLOUD_LIST"
else
  echo "  Cloud: disabled (set OLLAMA_API_KEY to enable cloud models)"
fi

# Local tier: check Ollama API for installed models
if [ -z "$MODELS_JSON" ] || ! echo "$MODELS_JSON" | jq -e '.models' > /dev/null 2>&1; then
  echo "  Local: UNREACHABLE at $OLLAMA_HOST"
  echo "  Start Ollama or set OLLAMA_HOST to fix."
  exit 0
fi

# Extract local model names
AVAILABLE=$(echo "$MODELS_JSON" | jq -r '.models[].name' 2>/dev/null | sort)

MISSING=""
FOUND=""
for MODEL in $LOCAL_MODELS; do
  # Check if any available model starts with or matches the expected name
  if echo "$AVAILABLE" | grep -qi "^${MODEL%%:*}"; then
    FOUND="$FOUND $MODEL"
  else
    MISSING="$MISSING $MODEL"
  fi
done

if [ -n "$FOUND" ]; then
  echo "  Local:$(echo "$FOUND" | sed 's/ /, /g; s/^, //')"
fi

if [ -n "$MISSING" ]; then
  echo "  Missing local:$(echo "$MISSING" | sed 's/ /, /g; s/^, //')"
  echo "  Pull missing models: ollama pull <model-name>"
fi

if [ -z "$MISSING" ]; then
  echo "  All expected worker models available."
fi

exit 0
