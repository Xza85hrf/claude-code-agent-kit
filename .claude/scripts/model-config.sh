#!/usr/bin/env bash
# model-config.sh — Single source of truth for model assignments
#
# Source this file from any script that needs model IDs:
#   source "$(dirname "$0")/model-config.sh"
#
# Update models here when providers release new versions.
# Run list-provider-models.sh to see what's available.
#
# Last updated: 2026-04-09

# ── Load API keys ───────────────────────────────────────
[[ -f "$HOME/.claude-secrets" ]] && source "$HOME/.claude-secrets" 2>/dev/null

# ── API Endpoints ───────────────────────────────────────
source "${BASH_SOURCE[0]%/*}/../lib/env-defaults.sh" 2>/dev/null || OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
export OLLAMA_HOST
export OPENAI_API_URL="https://api.openai.com/v1/chat/completions"
export DEEPSEEK_API_URL="https://api.deepseek.com/v1/chat/completions"
export GEMINI_API_URL="https://generativelanguage.googleapis.com/v1beta/models"

# ── Frontend Design Pipeline (Brain-first, MCP tools optional) ──
export MODEL_FRONTEND="brain"                                  # Route: Brain handles design directly
export MODEL_FRONTEND_WORKER="glm-5.1:cloud"                   # Worker: code generation (SWE-Bench Pro 58.4 SOTA)
# Optional MCP consultation (not mandatory):
export MODEL_FRONTEND_GEMINI="gemini-3.1-pro-preview"          # Gemini — optional image gen/consultation
export MODEL_FRONTEND_OPENAI="gpt-5.2"                         # OpenAI — optional code consultation
export MODEL_FRONTEND_REASONING="deepseek-chat"                # DeepSeek — optional UX review

# ── Code Audit (cheap models, consensus) ────────────────
export MODEL_AUDIT_OPENAI="gpt-5.1-codex-mini"               # codex-mini: uses reasoning_effort, not temperature
export MODEL_AUDIT_OLLAMA="glm-5.1:cloud"                   # Free (Ollama cloud) — SWE-Bench Pro SOTA
export MODEL_AUDIT_DEEPSEEK="deepseek-chat"                 # $0.14/M in, $0.42/M out
export MODEL_AUDIT_GEMINI="gemini-3-flash-preview"           # $0.30/M in, $2.50/M out

# ── Worker Models (Ollama cloud-first) ──────────────────
export MODEL_WORKER_PRIMARY="glm-5.1:cloud"                  # #1 coder — SWE-Bench Pro 58.4 SOTA, AIME 95.3, sustains over 1000s of tool calls
export MODEL_WORKER_REVIEW="minimax-m2.7:cloud"              # #2 coder / review — SWE-Pro 56.22 (matches GPT-5.3-Codex), VIBE-Pro 55.6
export MODEL_WORKER_REASONING="deepseek-v3.2:cloud"          # Deep reasoning
export MODEL_WORKER_REASONING_FALLBACK="nemotron-cascade-2:30b"  # Deep reasoning fallback — IMO+IOI gold, dual thinking/instruct modes
export MODEL_WORKER_FAST="qwen3-coder-next:cloud"            # Fast boilerplate — 80B MoE, 3B active per token, 256K ctx, ultra-efficient
export MODEL_WORKER_AGENTIC="nemotron-3-super:cloud"         # Agentic swarm (120B MoE, 512k ctx)
export MODEL_WORKER_LONGCTX="nemotron-3-super:cloud"         # Long context (512k, 96%+ accuracy)
export MODEL_WORKER_VISION="gemma4:31b-cloud"                # Vision + code — 30.7B dense, 256K ctx, LiveCodeBench 80, Codeforces 2150
export MODEL_WORKER_GPT_OSS_LARGE="gpt-oss:120b-cloud"      # Agentic (OpenAI OSS)

# ── OpenAI Reasoning ───────────────────────────────────
export MODEL_OPENAI_REASONING="o4-mini"                      # $1.10/M in, $4.40/M out (latest reasoning)
export MODEL_OPENAI_CODEX="gpt-5.3-codex"                    # Latest codex (code-specialized)
export MODEL_OPENAI_CHEAP="gpt-5-nano"                       # $0.05/M in, $0.40/M out (ultra-cheap)
export MODEL_OPENAI_MIDTIER="gpt-4.1"                        # $2/M in, $8/M out (balanced)

# ── Image Generation ────────────────────────────────────
export MODEL_IMAGE_GEMINI="gemini-3-pro-image-preview"       # Nano Banana 2 (Gemini 3.1 Flash Image, via MCP)
export MODEL_IMAGE_OPENAI="gpt-image-1.5"                    # OpenAI (via MCP)

# ── Embedding Models ───────────────────────────────────
export MODEL_EMBEDDING="qwen3-embedding:8b"                    # Full index (high quality, slower)
export MODEL_EMBEDDING_FAST="mxbai-embed-large"                  # Query embedding (fast search)

# ── Fallback Models ─────────────────────────────────────
export MODEL_FALLBACK_PRIMARY="deepseek-v3.1:671b-cloud"     # #1 Coder fallback
export MODEL_FALLBACK_REVIEW="minimax-m2.5:cloud"            # #2 Coder/Review fallback (previous gen)
export MODEL_FALLBACK_WORKER="$MODEL_FALLBACK_REVIEW"        # Alias for scripts using old name
export MODEL_FALLBACK_AUDIT="gemini-2.5-flash"               # Cheap, reliable
export MODEL_FALLBACK_FRONTEND="gpt-5.1"                     # Previous gen ($1.25/$10), still good
export MODEL_FALLBACK_AUDIT_OPENAI="gpt-4.1-mini"            # Mid-tier cheap ($0.40/$1.60)

# ── Helper: get model for a role ────────────────────────
# Usage: model=$(get_model "audit_openai")
get_model() {
  local role="${1^^}"  # uppercase
  role="MODEL_${role}"
  echo "${!role:-unknown}"
}

# ── Helper: list all configured models ──────────────────
list_configured_models() {
  echo "## Configured Models (model-config.sh)"
  echo ""
  echo "### Frontend Design Pipeline (Brain-first)"
  echo "  Primary:           Brain (self)"
  echo "  Worker:            $MODEL_FRONTEND_WORKER"
  echo "  Gemini (optional): $MODEL_FRONTEND_GEMINI"
  echo "  OpenAI (optional): $MODEL_FRONTEND_OPENAI"
  echo "  Reasoning (opt):   $MODEL_FRONTEND_REASONING"
  echo ""
  echo "### Code Audit"
  echo "  OpenAI:            $MODEL_AUDIT_OPENAI"
  echo "  Ollama:            $MODEL_AUDIT_OLLAMA"
  echo "  DeepSeek:          $MODEL_AUDIT_DEEPSEEK"
  echo "  Gemini:            $MODEL_AUDIT_GEMINI"
  echo ""
  echo "### Workers (Ollama)"
  echo "  Primary:           $MODEL_WORKER_PRIMARY"
  echo "  Review:            $MODEL_WORKER_REVIEW"
  echo "  Reasoning:         $MODEL_WORKER_REASONING"
  echo "  Fast:              $MODEL_WORKER_FAST"
  echo "  Agentic:           $MODEL_WORKER_AGENTIC"
  echo ""
  echo "### OpenAI Reasoning/Specialized"
  echo "  Reasoning:         $MODEL_OPENAI_REASONING"
  echo "  Codex:             $MODEL_OPENAI_CODEX"
  echo "  Mid-tier:          $MODEL_OPENAI_MIDTIER"
  echo "  Ultra-cheap:       $MODEL_OPENAI_CHEAP"
  echo ""
  echo "### Image Generation"
  echo "  Gemini:            $MODEL_IMAGE_GEMINI"
  echo "  OpenAI:            $MODEL_IMAGE_OPENAI"
}

# ── Cognitive Profiles (DeepMind AGI Framework, Mar 2026) ──
# 5 faculties: reasoning, metacognition, generation, problem_solving, executive_function
export COGNITIVE_PROFILE_glm5="8,6,9,7,7"
export COGNITIVE_PROFILE_deepseek_v3="9,8,7,9,7"
export COGNITIVE_PROFILE_minimax_m2="7,5,8,6,5"
export COGNITIVE_PROFILE_nemotron="8,7,8,8,8"
export COGNITIVE_PROFILE_qwen3="7,6,7,7,6"
export COGNITIVE_PROFILE_gpt_oss="7,5,8,6,5"
export COGNITIVE_PROFILE_devstral="8,6,9,7,6"
export COGNITIVE_PROFILE_kimi_k2="8,7,7,8,7"

get_cognitive_score() {
  local profile_var="COGNITIVE_PROFILE_${1}"
  local profile="${!profile_var:-5,5,5,5,5}"
  IFS=',' read -ra s <<< "$profile"
  case "$2" in
    reasoning) echo "${s[0]:-5}" ;; metacognition) echo "${s[1]:-5}" ;;
    generation) echo "${s[2]:-5}" ;; problem_solving) echo "${s[3]:-5}" ;;
    executive_function) echo "${s[4]:-5}" ;; *) echo "5" ;;
  esac
}

get_cognitive_sum() {
  local key="$1" sum=0; IFS=',' read -ra fs <<< "$2"
  for f in "${fs[@]}"; do sum=$((sum + $(get_cognitive_score "$key" "$f"))); done
  echo "$sum"
}

# If run directly (not sourced), show config
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  list_configured_models
fi
