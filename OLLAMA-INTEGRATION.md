# Ollama Integration Guide

> Local and cloud models as **workers** for delegation and agent swarms. **Opus remains the brain.**
>
> **Requires Ollama v0.14.0+** — now supports the Anthropic Messages API natively.

---

## What's New: Native Anthropic API Support

Ollama v0.14.0+ implements the **Anthropic Messages API**, enabling:
- **Direct Claude Code compatibility** with open-source models
- Multi-turn conversations with streaming
- System prompts and **tool/function calling**
- Extended thinking and vision capabilities
- Python and JavaScript SDK redirection

**Quick Setup (one command):**
```bash
ollama launch claude
# Or configure without launching:
ollama launch claude --config
```

**Manual Setup:**
```bash
export ANTHROPIC_AUTH_TOKEN=ollama
# Native Linux/macOS: use localhost; WSL: use host.docker.internal
export ANTHROPIC_BASE_URL=http://localhost:11434
claude --model qwen3-coder-next:latest
```

**Minimum context:** 32K tokens (64K recommended). Cloud models run at full capacity.

---

## Architecture: Opus as Brain, Ollama as Workers

```
┌─────────────────────────────────────────────────────────────┐
│                  CLAUDE OPUS (THE BRAIN)                     │
│                                                             │
│   Planning • Complex Reasoning • Final Decisions            │
│   Security Reviews • User Communication • Integration       │
└────────────────────────┬────────────────────────────────────┘
                         │ Delegates & Orchestrates
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   OLLAMA    │  │  DEEPSEEK   │  │   GITHUB    │
│   Workers   │  │  Advisor    │  │   & MCPs    │
│             │  │             │  │             │
│ qwen3-coder-│  │ R1: 2nd     │  │ Repo ops    │
│  next:cloud │  │    opinion  │  │ PR/Issues   │
│ kimi-k2.5   │  │ V3: quick   │  │ Context7    │
│ glm-4.7     │  │    validate │  │             │
│ gemini-3-pro│  │             │  │             │
│ devstral    │  │             │  │             │
│ deepcoder   │  │             │  │             │
└─────────────┘  └─────────────┘  └─────────────┘
  Task Workers    Reasoning Help    External Tools
```

**Key Principle: Opus decides, workers execute. DELEGATE BY DEFAULT — never write code yourself when a worker can handle it.**

---

## Cloud-First Architecture

When `OLLAMA_API_KEY` is set, the Ollama server acts as a proxy for cloud inference. A single endpoint serves both local and remote models — no multiple MCP servers needed.

**3-tier fallback chain:**

1. **Cloud Model** — Full-precision, no local VRAM required (e.g., `qwen3-coder-next:cloud`)
2. **Local Model** — Requires local GPU VRAM (e.g., `qwen3-coder-next:latest`)
3. **Fallback Model** — Lightweight alternative (e.g., `glm-4.7-flash`)

```
Agent → ollama_chat(model="qwen3-coder-next:cloud")
         ↓
  Ollama server (OLLAMA_API_KEY set)
         ↓
  Cloud inference API → response
```

### Cloud ↔ Local Model Mapping

| Role | Cloud | Local |
|------|-------|-------|
| **Primary Coder** | `qwen3-coder-next:cloud` | `qwen3-coder-next:latest` (51GB) |
| **Fast Coder** | `glm-4.7:cloud` | `glm-4.7-flash` (19GB) |
| **Swarm + Vision** | `kimi-k2.5:cloud` | — (cloud-only) |
| **Long Context** | `gemini-3-pro-preview` | — (cloud-only) |
| **Vision (local)** | — | `qwen3-vl:32b` (20GB) / `qwen3-vl:8b` |
| **Agentic SWE** | — | `devstral-small-2` (15GB) |
| **Code Reasoning** | — | `deepcoder` (9GB) |

## Setting Up Cloud Models

1. Get an API key from [ollama.com](https://ollama.com)
2. Add to `.mcp.json`: `"OLLAMA_API_KEY": "your-key-here"`
3. Or export in shell: `export OLLAMA_API_KEY="your-key-here"`
4. Verify setup via the `check-ollama-models` hook at session start

> **Note:** Empty `OLLAMA_API_KEY` or unset = cloud disabled, local-only mode.

---

## Worker Model Roles

| Model | Architecture | Size | Context | Role | Delegate When |
|-------|-------------|------|---------|------|---------------|
| `qwen3-coder-next:latest` | MoE 80B/3B active | 52 GB (q4) | 256K | **Primary Coder** | Complex coding, agentic tasks (RL-trained on 800K executable tasks) |
| `kimi-k2.5:cloud` | Multimodal | Remote | 256K | **Swarm Agent + Vision** | Multi-step sub-tasks, tool calling, vision-based code gen from UI designs |
| `glm-4.7-flash` | MoE 30B/3B active | 19 GB (q4) | 198K | **Fast Coder** | Boilerplate, CRUD, quick generation (SWE-bench 59.2) |
| `gemini-3-pro-preview` | Multimodal | Remote | 1M | **Long Context Analyst** | Whole-repo analysis, massive document processing, text+image+audio+video |
| `glm-4.7:cloud` | MoE 30B/3B active | Remote | 198K | **Balanced Worker** | Medium complexity tasks at full precision |
| `devstral-small-2` | Dense 24B | 15 GB | 384K | **Agentic SWE Coder** | Multi-file editing, tool calling, SWE-bench 65.8% |
| `deepcoder` | Qwen2-based 14B | 9 GB | 128K | **Code Reasoning** | Algorithmic tasks, o3-mini level reasoning, HumanEval+ 92.6% |

---

## Mandatory Auto-Delegation Rules

**You MUST delegate by default. Doing work yourself that a worker can handle wastes Opus tokens and context window.**

```
⚠️  ALWAYS DELEGATE (no exceptions):          🧠 OPUS KEEPS (only these):
├── Code generation >10 lines                  ├── Multi-step tool chains (Read→Edit→Bash)
├── Boilerplate / CRUD / scaffolding           ├── Security-critical final review
├── Writing or generating tests                ├── Architecture decisions
├── Code review / explanation                  ├── Integrating worker output into codebase
├── Refactoring existing code                  ├── User-facing communication
├── Parallel file analysis (use swarm)         ├── Go/no-go decisions on worker output
├── Image/screenshot understanding             └── Tasks that need YOUR tools
├── Large file/repo analysis
└── Embedding generation

DECISION FLOW — before writing ANY code:
┌──────────────────────────────────────┐
│ "Can an Ollama worker handle this?"  │
│                                      │
│   YES → DELEGATE immediately         │
│   NO  → Do it yourself (rare)        │
└──────────────────────────────────────┘

MULTI-FILE TASKS — ALWAYS use agent swarm:
┌──────────────────────────────────────┐
│ 2+ independent files or subtasks?    │
│                                      │
│   → Spawn parallel kimi-k2.5:cloud   │
│   → Each agent handles one sub-task  │
│   → You collect, synthesize, decide  │
└──────────────────────────────────────┘
```

---

## MCP Server Options

### Option 1: ollama-mcp (Full SDK Access)

Full Ollama control - manage models, generate, chat, embeddings.

**Standard Configuration (Ollama running locally):**
```json
{
  "ollama": {
    "command": "npx",
    "args": ["-y", "ollama-mcp"],
    "env": {
      "OLLAMA_HOST": "http://localhost:11434"
    }
  }
}
```

**WSL Configuration (Ollama running on Windows host):**
```json
{
  "ollama": {
    "command": "npx",
    "args": ["-y", "ollama-mcp"],
    "env": {
      "OLLAMA_HOST": "http://localhost:11434"
    }
  }
}
```

> **WSL Note:** When Ollama runs on Windows and Claude Code runs in WSL, use `host.docker.internal` which resolves to the Windows host IP.

**Tools Provided:**
| Tool | Purpose |
|------|---------|
| `ollama_list` | List available models |
| `ollama_pull` | Download models |
| `ollama_generate` | Text completion |
| `ollama_chat` | Multi-turn chat (with tools) |
| `ollama_embed` | Create embeddings |
| `ollama_show` | Model details |
| `ollama_ps` | Running models |

### Option 2: OllamaClaude (Task Delegation)

Delegate coding tasks to local models - massive token savings.

```json
{
  "ollama-delegate": {
    "command": "node",
    "args": ["/path/to/ollama-claude/index.js"],
    "env": {
      "DEFAULT_MODEL": "kimi-k2.5:cloud",
      "FALLBACK_MODEL": "glm-4.7-flash"
    }
  }
}
```

**Tools Provided:**
| Tool | Token Usage | Purpose |
|------|-------------|---------|
| `generate_code` | ~200 tokens | Generate new code |
| `explain_code` | ~150 tokens | Explain code |
| `review_code` | ~150 tokens | Review code |
| `refactor_code` | ~200 tokens | Refactor code |
| `fix_code` | ~200 tokens | Fix bugs |
| `write_tests` | ~250 tokens | Write unit tests |
| `review_file` | ~50 tokens | Review file by path (file-aware) |
| `explain_file` | ~50 tokens | Explain file by path |
| `analyze_files` | ~50 tokens | Analyze multiple files |

**Token Savings Example:**
```
Traditional approach: Send 4000-token file to Claude
OllamaClaude: Send 50-token path → Local model reads file

Savings: 98.75% reduction
```

---

## Setup Instructions

### Step 1: Ensure Ollama is Running

```bash
# Windows (PowerShell)
ollama serve

# Or start in background
Start-Process ollama -ArgumentList "serve" -WindowStyle Hidden
```

### Step 2: Install OllamaClaude (Optional but Recommended)

```bash
# Clone the delegation server
git clone https://github.com/Jadael/OllamaClaude.git ~/.claude/mcp-servers/ollama-claude
cd ~/.claude/mcp-servers/ollama-claude
npm install

# Configure your models in index.js (optional)
# DEFAULT_MODEL = "kimi-k2.5:cloud"
# FALLBACK_MODEL = "glm-4.7-flash"
```

### Step 3: Add to .mcp.json

```json
{
  "mcpServers": {
    "ollama": {
      "command": "npx",
      "args": ["-y", "ollama-mcp"]
    },
    "ollama-delegate": {
      "command": "node",
      "args": ["/home/user/.claude/mcp-servers/ollama-claude/index.js"],
      "env": {
        "DEFAULT_MODEL": "kimi-k2.5:cloud",
        "FALLBACK_MODEL": "glm-4.7-flash"
      }
    }
  }
}
```

### Step 4: Set Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
# Native: use localhost; WSL: use host.docker.internal
export OLLAMA_HOST="http://localhost:11434"
export OLLAMA_DEFAULT_MODEL="kimi-k2.5:cloud"
export OLLAMA_FALLBACK_MODEL="glm-4.7-flash"
```

---

## Model Selection Strategy

### For Coding Tasks

```
COMPLEX CODING (agentic tasks, full implementations):
→ qwen3-coder-next:latest (RL-trained, 256K ctx, best coding accuracy)
→ kimi-k2.5:cloud (when tool calling + vision needed)

SIMPLE TASKS (refactoring, formatting, boilerplate):
→ glm-4.7-flash (fast, 19GB, SWE-bench 59.2)
→ devstral-small-2 (agentic SWE, 15GB, SWE-bench 65.8%)
→ deepcoder (code reasoning, 9GB, o3-mini level)

REASONING & SECOND OPINIONS:
→ DeepSeek R1 (deep reasoning)
→ DeepSeek V3 (quick validation)
```

### For Vision Tasks

```
VISION + CODE GENERATION:
→ kimi-k2.5:cloud (generates code from UI designs/screenshots)

MULTIMODAL ANALYSIS (text + image + audio + video):
→ gemini-3-pro-preview (1M context, all input types)
```

### For Long Context Tasks

```
WHOLE-REPO ANALYSIS:
→ gemini-3-pro-preview (1M context input)
→ qwen3-coder-next:latest (256K context, coding-optimized)

LARGE DOCUMENT PROCESSING:
→ gemini-3-pro-preview (text + images + audio + video)
```

### For Background Tasks

```
EMBEDDINGS:
→ Local embedding model via ollama_embed

CODE INDEXING:
→ ollama_embed + vector store

PARALLEL SUBTASKS:
→ Multiple ollama_chat calls with different models

AGENT SWARM:
→ kimi-k2.5:cloud (decomposes into parallel domain-specific agents)
```

---

## Delegation Patterns (Opus → Workers)

### Pattern 1: Delegate Complex Coding

**You (Opus) delegate a coding task to the RL-trained specialist:**

```
You: "I need a REST API with validation and error handling."
  → Call ollama_chat with qwen3-coder-next:latest
  → Worker returns full implementation (trained on 800K executable tasks)
  → You review: architecture, security, edge cases
  → You refine critical logic yourself
  → You integrate into solution
```

### Pattern 2: Fast Boilerplate

**You (Opus) need quick scaffolding:**

```
You: "I need CRUD boilerplate for a user model."
  → Call ollama_generate with glm-4.7-flash
  → Worker returns boilerplate fast (19GB, SWE-bench 59.2)
  → You review and integrate
```

### Pattern 3: Get Second Opinion

**You (Opus) want to validate your reasoning:**

```
You: "My algorithm handles edge cases, but let me verify."
  → Call deepseek chat_completion with R1
  → Prompt: "Review this algorithm for edge cases: [code]"
  → DeepSeek suggests: "Consider negative inputs"
  → You evaluate: "Good point, I'll add that check"
  → You make the final decision
```

### Pattern 4: Vision + Code Generation

**You (Opus) need to generate code from a visual spec:**

```
You: "User provided a UI screenshot. Generate the component."
  → Call ollama_chat with kimi-k2.5:cloud
  → Prompt: "Generate React component from this UI design" + image
  → Worker returns code generated from visual understanding
  → You review, refine, and integrate
```

### Pattern 5: Agent Swarm

**You (Opus) spawn parallel workers for independent tasks:**

```
You: "I need to analyze 5 files for patterns. Parallel is faster."
  → Spawn 5 ollama_chat calls with kimi-k2.5:cloud
  → Each agent analyzes one file (domain-specific decomposition)
  → Workers return their findings
  → You synthesize: "Files 1,3,5 use pattern A; 2,4 use pattern B"
  → You make architectural recommendation
```

### Pattern 6: Long Context Analysis

**You (Opus) need to analyze an entire repository or massive document:**

```
You: "Analyze the entire codebase for architectural patterns."
  → Call ollama_chat with gemini-3-pro-preview (1M context)
  → Send full repo content in a single prompt
  → Worker returns comprehensive analysis
  → You evaluate and synthesize into recommendations
```

### Pattern 7: Quick Validation

**You (Opus) want fast sanity check:**

```
You: "Is this regex correct? Quick check."
  → Call deepseek multi_turn_chat with V3
  → Prompt: "Validate this regex: [pattern]"
  → V3: "Valid, but doesn't handle [case]"
  → You decide whether to fix it
```

### Key Principle

```
┌─────────────────────────────────────────────────┐
│  YOU (OPUS) always:                             │
│  • Decide WHAT to delegate                      │
│  • Review ALL worker output                     │
│  • Make FINAL decisions                         │
│  • Handle CRITICAL logic yourself               │
│  • Communicate with USER directly               │
└─────────────────────────────────────────────────┘
```

---

## Token Usage Comparison

| Task | Claude Only | With Ollama | Savings |
|------|-------------|-------------|---------|
| Review 1000-line file | ~4000 tokens | ~50 tokens | 98.75% |
| Generate boilerplate | ~500 tokens | ~100 tokens | 80% |
| Explain complex code | ~800 tokens | ~100 tokens | 87.5% |
| Write unit tests | ~1000 tokens | ~150 tokens | 85% |

**Note:** Claude still handles orchestration, so you get the best of both worlds.

---

## Actual MCP Tool Call Syntax

### List Available Models
```
ollama_list
```
Returns: List of installed models with sizes and details.

### Generate Text (Completion)
```
ollama_generate
  model: "glm-4.7-flash"
  prompt: "Generate a TypeScript function that validates email addresses"
  options: {"temperature": 0.2}
```

### Chat for Coding Tasks
```
ollama_chat
  model: "qwen3-coder-next:latest"
  messages: [
    {"role": "system", "content": "You are an expert coding agent. Return only code."},
    {"role": "user", "content": "Implement a REST API with validation for user registration"}
  ]
```

### Chat with Model (Multi-turn)
```
ollama_chat
  model: "kimi-k2.5:cloud"
  messages: [
    {"role": "system", "content": "You are a code reviewer"},
    {"role": "user", "content": "Review this function: [code]"}
  ]
```

### Vision + Code Generation
```
ollama_chat
  model: "kimi-k2.5:cloud"
  messages: [
    {"role": "user", "content": "Generate a React component matching this UI design", "images": ["base64_encoded_image"]}
  ]
```

### Long Context Analysis
```
ollama_chat
  model: "gemini-3-pro-preview"
  messages: [
    {"role": "user", "content": "Analyze this entire codebase for patterns and anti-patterns: [full repo content]"}
  ]
```

### Create Embeddings
```
ollama_embed
  model: "nomic-embed-text"
  input: "function to validate email addresses"
```

### Model Management
```
# Pull recommended models
ollama_pull
  model: "qwen3-coder-next:latest"    # Primary coder (52GB q4)

ollama_pull
  model: "glm-4.7-flash"       # Fast coder (19GB q4)

ollama_pull
  model: "devstral-small-2"    # Agentic SWE coder (15GB)

ollama_pull
  model: "deepcoder"            # Code reasoning (9GB)

# Cloud models (no pull needed)
# kimi-k2.5:cloud, gemini-3-pro-preview, glm-4.7:cloud

# Show model details
ollama_show
  model: "qwen3-coder-next:latest"

# List running models
ollama_ps
```

---

## Troubleshooting

### Ollama Not Responding

```bash
# Check if running (standard)
curl http://localhost:11434/api/tags

# Check if running (WSL with Windows Ollama)
curl http://host.docker.internal:11434/api/tags

# Restart
ollama serve
```

### Model Not Found

```bash
# List available
ollama list

# Pull if needed
ollama pull kimi-k2.5:cloud
```

### Slow Performance

```bash
# Check GPU usage
nvidia-smi

# Use smaller model
export OLLAMA_FALLBACK_MODEL="devstral-small-2"
```

### MCP Connection Failed

1. Verify Ollama is running: `curl localhost:11434` (WSL: use `host.docker.internal:11434`)
2. Check MCP server path in config
3. Restart Claude Code after config changes

---

## Advanced: Custom Model Configuration

### Creating Task-Specific Models

```bash
# Create a coding-optimized model
cat << 'EOF' > Modelfile
FROM kimi-k2.5:cloud
SYSTEM "You are a coding assistant. Be concise and return only code when asked for code."
PARAMETER temperature 0.2
PARAMETER num_ctx 32768
EOF

ollama create coding-assistant -f Modelfile
```

### Using Custom Models

```json
{
  "env": {
    "DEFAULT_MODEL": "coding-assistant"
  }
}
```

---

## Recommended Model Specs

Quick reference for hardware planning:

| Model | Type | Download | VRAM (q4) | Context | Best For |
|-------|------|----------|-----------|---------|----------|
| `qwen3-coder-next:latest` | Local | 52 GB | ~32 GB | 256K | Coding tasks, agentic workflows |
| `glm-4.7-flash` | Local | 19 GB | ~12 GB | 198K | Fast coding, boilerplate |
| `devstral-small-2` | Local | 15 GB | ~10 GB | 384K | Agentic SWE, multi-file editing |
| `deepcoder` | Local | 9 GB | ~6 GB | 128K | Code reasoning, algorithmic tasks |
| `kimi-k2.5:cloud` | Cloud | — | — | 256K | Agent swarm, vision+code |
| `gemini-3-pro-preview` | Cloud | — | — | 1M | Long context, multimodal |
| `glm-4.7:cloud` | Cloud | — | — | 198K | Medium tasks at full precision |

**Minimum setup:** `glm-4.7-flash` (19GB) + `deepcoder` (9GB) for local coding + cloud models for specialized tasks.
**Recommended setup:** `qwen3-coder-next:latest` (52GB) + `glm-4.7-flash` (19GB) + `devstral-small-2` (15GB) + cloud models.

---

## Resources

- [Ollama Documentation](https://docs.ollama.com)
- [Ollama + Claude Code Integration](https://docs.ollama.com/integrations/claude-code)
- [Ollama Blog: Claude Code](https://ollama.com/blog/claude)
- [ollama-mcp](https://github.com/rawveg/ollama-mcp) - Full SDK MCP
- [OllamaClaude](https://github.com/Jadael/OllamaClaude) - Task delegation
- [Ollama Model Library](https://ollama.com/library)

---

*Part of the Agent Enhancement Kit*
