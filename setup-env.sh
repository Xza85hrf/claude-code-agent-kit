#!/bin/bash
# Setup script for Agent Enhancement Kit environment variables
# Run: source setup-env.sh (or add contents to ~/.bashrc)

# ============================================================
# REQUIRED: Set your actual values before running
# ============================================================

# GitHub Personal Access Token (for GitHub MCP server)
# Get from: https://github.com/settings/tokens
export GITHUB_TOKEN="ghp_your_token_here"

# n8n MCP Token (if using n8n automation)
# Get from: n8n > Settings > API > Create token
export N8N_MCP_TOKEN="your_n8n_token_here"

# ============================================================
# OPTIONAL: API Keys for extended capabilities
# ============================================================

# DeepSeek API (for reasoning tasks)
# Get from: https://platform.deepseek.com/api_keys
export DEEPSEEK_API_KEY="sk-your_deepseek_key"

# OpenAI API (for embeddings in claude-context)
# Get from: https://platform.openai.com/api-keys
export OPENAI_API_KEY="sk-your_openai_key"

# Gemini API (for PAL multi-model orchestration)
# Get from: https://aistudio.google.com/apikey
export GEMINI_API_KEY="your_gemini_key"

# OpenRouter API (for PAL access to many models)
# Get from: https://openrouter.ai/keys
export OPENROUTER_API_KEY="sk-or-your_key"

# Firecrawl API (for web scraping)
# Get from: https://firecrawl.dev
export FIRECRAWL_API_KEY="fc-your_key"

# Zilliz/Milvus (for claude-context vector search)
# Get from: https://cloud.zilliz.com
export MILVUS_TOKEN="your_milvus_token"

# Supabase (if using Supabase MCP)
export SUPABASE_PROJECT_REF="your_project_ref"

# ============================================================
# Ollama Configuration
# ============================================================

# Ollama host
# WSL: use host.docker.internal to reach Windows host
# Native Linux/macOS: use localhost
export OLLAMA_HOST="http://localhost:11434"

# Default model for coding tasks
export OLLAMA_DEFAULT_MODEL="kimi-k2.5:cloud"

# Fallback model for simpler tasks
export OLLAMA_FALLBACK_MODEL="glm-4.7-flash"

# ============================================================
# Verify setup
# ============================================================
echo "Environment variables loaded!"
echo "GitHub Token: ${GITHUB_TOKEN:0:10}..."
echo "Ollama Host: $OLLAMA_HOST"
echo "Default Model: $OLLAMA_DEFAULT_MODEL"
