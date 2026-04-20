---
name: cost-aware-llm-pipeline
description: Token economics and model selection optimization for multi-model agent architectures. Use when delegating tasks between models, optimizing API costs, or working in budget-constrained environments.
argument-hint: "Optimize delegation strategy to reduce token costs under budget pressure"
department: architecture
thinking-level: medium
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Cost-Aware LLM Pipeline

## When to Activate
- Choosing models for delegation
- Optimizing API costs
- Budget-constrained sessions (weekly usage >60%)
- Setting up new agent workflows

## Model Cost Tiers

| Model | Tier | Best For |
|-------|------|----------|
| Opus | $$$ | Planning, architecture, security, orchestration |
| Sonnet | $$ | Complex reasoning, multi-step tasks |
| Haiku | $ | Exploration, quick analysis |
| Ollama Cloud | Free | Code gen, reviews, boilerplate |
| Ollama Local | Free | Embeddings, simple tasks |

## Task-to-Tier Routing

| Task | Route | Cost |
|------|-------|------|
| Planning/architecture | Opus (keep) | $$$ |
| Code gen >10 lines | Ollama cloud workers | Free |
| Quick review/boilerplate | Ollama cloud | Free |
| Exploration | Haiku subagents | $ |
| Multi-model audit | Mixed cheap models | ~$0.01 |

## Token Optimization Techniques

- **Compress prompts**: Tables > prose (~24% token savings)
- **TOML over JSON for structured inputs**: ~50% fewer tokens for flat/shallow data (see below)
- **Cache repeated context**: `content-hash-cache` pattern
- **Parallel batch**: `ollama-batch.sh` for 4+ tasks (avoids MCP cascade)
- **Progressive loading**: `iterative-retrieval` — send less, refine
- **Delegate code gen**: Workers save 80-98% of Opus tokens

## TOML vs JSON for Prompt Inputs

JSON's quotes, braces, and colons are pure syntactic overhead. TOML expresses the same key-value data with ~50% fewer tokens.

| Format | Example | Tokens |
|--------|---------|--------|
| JSON | `{"name": "John", "role": "engineer", "task": "review"}` | ~223 |
| TOML | `name = "John"\nrole = "engineer"\ntask = "review"` | ~103 |

**When to use TOML**: Configuration-style parameters, named fields with scalar values, flat/shallow structured data in prompts.

**Keep JSON when**: Deeply nested data, array-heavy structures, downstream code requires JSON parsing, or the model must output JSON back.

```python
# Before — JSON input (expensive)
payload = json.dumps({"user": "alice", "task": "summarize", "lang": "en"})

# After — TOML input (same semantics, ~50% fewer tokens)
payload = 'user = "alice"\ntask = "summarize"\nlang = "en"'
```

At scale (10K requests/day): ~1.2M tokens saved — format is not neutral.

## Budget Monitoring

| Tool | Purpose |
|------|---------|
| `check-usage.sh` | Session/weekly usage tracking |
| `.budget-thresholds.env` | Dynamic threshold config |
| `usage-budget-adjust.sh` | Auto-adjust on high usage |

## Anti-Patterns
- Using Opus for boilerplate generation
- No caching strategy for repeated queries
- Sequential execution when tasks are independent
- Sending full codebase context when iterative retrieval suffices
- Ignoring budget mode thresholds
