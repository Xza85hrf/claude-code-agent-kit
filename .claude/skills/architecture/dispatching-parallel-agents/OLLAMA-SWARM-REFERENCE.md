# Ollama Worker Swarm Reference

For maximum efficiency, delegate grunt work to Ollama workers while Opus orchestrates.

## Ollama Worker Swarm Pattern

```javascript
// Opus spawns local model workers for parallel analysis

// Worker 1: Analyze file with fast coder
bash .claude/scripts/mcp-cli.sh ollama chat(
  model: "glm-4.7-flash",
  messages: [{ role: "user", content: "Analyze patterns in auth.ts: [file content]" }]
})

// Worker 2: Analyze file with fast coder (parallel)
bash .claude/scripts/mcp-cli.sh ollama chat(
  model: "glm-4.7-flash",
  messages: [{ role: "user", content: "Analyze patterns in user.ts: [file content]" }]
})

// Worker 3: Vision analysis if needed
bash .claude/scripts/mcp-cli.sh ollama chat(
  model: "kimi-k2.5:cloud",
  messages: [{ role: "user", content: "Describe this UI screenshot", images: ["..."] }]
})

// Step 2: Opus collects and synthesizes results
```

## Model Selection for Swarm Tasks (Cloud-First)

| Task Type | Cloud (preferred) | Local (fallback) | Why |
|-----------|-------------------|------------------|-----|
| Complex coding | `qwen3-coder-next:cloud` | `qwen3-coder-next:latest` (51GB) | 80B FP8 cloud / Q4_K_M local, 262K ctx |
| Multi-step with tools | `kimi-k2.5:cloud` | — (cloud-only) | Best tool calling + thinking + vision |
| Fast code generation | `glm-4.7:cloud` | `glm-4.7-flash` (19GB) | Cloud full / local 30B MoE quantized |
| Image/UI analysis | `kimi-k2.5:cloud` | `qwen3-vl:32b` (20GB) | Vision + multimodal capabilities |
| Large repo analysis | `gemini-3-pro-preview` | — (cloud-only) | 1M context window, vision + thinking |
| Agentic SWE tasks | — | `devstral-small-2` (15GB) | Multi-file editing, tool calling |
| Code reasoning | — | `deepcoder` (9GB) | Algorithmic tasks, o3-mini level reasoning |

## Hybrid Pattern: Claude Subagents + Ollama Workers

```javascript
// Use Claude subagent to orchestrate Ollama workers
Task({
  subagent_type: "general-purpose",
  prompt: `
    You are coordinating a file analysis task.

    1. Use mcp-cli.sh ollama chat with glm-4.7-flash to analyze each file:
       - src/auth.ts
       - src/user.ts
       - src/api.ts

    2. Collect the analysis from each worker
    3. Synthesize findings into a summary

    Report back with the combined analysis.
  `,
  run_in_background: true
})
```

## Token Savings with Ollama Delegation

| Approach | Tokens Used | Notes |
|----------|-------------|-------|
| Send file to Opus | ~4000 | Full file in context |
| Send path to Ollama | ~50 | Ollama reads file locally |
| **Savings** | **98%** | Massive cost reduction |

**Remember:** Opus = Brain. Ollama = Workers. Always review worker output.
