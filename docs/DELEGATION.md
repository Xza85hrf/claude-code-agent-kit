# Delegation

Claude Code is the brain. Workers are cheap, fast models doing bulk code generation. This kit wires a graduated delegation system that nudges (and eventually blocks) you from writing large files by hand when a worker would do it better.

## Why

Brain tokens are expensive. Worker tokens are cheap or free. For a typical feature:

- Planning, architectural decisions, security review → **brain** (expensive, but irreplaceable)
- Boilerplate, CRUD, test scaffolding, second opinions → **worker** (fast, cheap, good enough with brain review)

Measured savings vary by task — delegating straightforward code gen to Ollama Cloud workers typically saves 80–98% of equivalent brain output.

## Tier Table

| Tier | Engine | When |
|------|--------|------|
| 0 | Orchestrator (Claude Code) | Planning, auth/crypto, integration, user communication |
| 1 | `claude -p` + Ollama | Multi-file implementation, long autonomous tasks |
| 2 | `mcp-cli.sh ollama chat "<model>" "<prompt>"` | Quick code gen, reviews, refactors |
| 3 | Task-tool subagents (Haiku / Sonnet) | Exploration, research, multi-step Claude reasoning |
| 4 | Agent Teams | 3+ parallel specialists with file ownership |
| 5 | Git worktrees | Long-running parallel branches |

## Graduated Enforcement

The `delegation-reminder` hook watches `Write`/`Edit` and tracks lines since the last worker call. Thresholds come from env vars set by the active profile:

| Lines | Behavior |
|-------|----------|
| `≤ DELEGATION_THRESHOLD` (default 10) | Silent |
| `> threshold`, `≤ DELEGATION_BLOCK_THRESHOLD` (default 50) | 1st time: advisory warning. 2nd+: BLOCK |
| `> DELEGATION_BLOCK_THRESHOLD` | BLOCKED unless a delegation token exists |

Delegation token: created for 5 minutes after any `mcp-cli.sh ollama chat`/`ollama_chat`/`ollama_generate` call. Means "the brain used a worker recently — trust it for one more large file".

### Tuning

Set in `.claude/settings.local.json` under `env`:

```json
{
  "env": {
    "DELEGATION_MODE": "graduated",    // graduated | advisory | off
    "DELEGATION_THRESHOLD": "10",
    "DELEGATION_BLOCK_THRESHOLD": "50"
  }
}
```

- `graduated` — full enforcement
- `advisory` — warns but never blocks
- `off` — hooks still run but never emit delegation guidance

## Worker Setup

### Ollama Cloud (recommended, fixed pricing)

1. Create account at [ollama.com](https://ollama.com) and grab an API key.
2. Add to `~/.claude-secrets`:

   ```bash
   export OLLAMA_API_KEY="ol-..."
   export OLLAMA_HOST="https://ollama.com"
   ```

3. Test:

   ```bash
   bash .claude/scripts/mcp-cli.sh ollama list
   bash .claude/scripts/mcp-cli.sh ollama chat "glm-5.1:cloud" "Write a hello-world in Python"
   ```

Ollama Cloud runs production-grade models (GLM-5, MiniMax M2.7, DeepSeek V3.2, Nemotron, Qwen3 Coder, Gemma4) on NVIDIA B300 hardware. Pricing is fixed tiers ($0/$20/$100 monthly) — no per-token surprises.

### Local Ollama

If you prefer local:

```bash
ollama serve &
ollama pull qwen3-coder
ollama pull glm-5-flash
```

The scripts default to `http://localhost:11434` if `OLLAMA_HOST` isn't set.

### Alternative Providers

The kit also speaks OpenAI, DeepSeek, Gemini via CLI wrappers. Add keys to `~/.claude-secrets`:

```bash
export OPENAI_API_KEY="sk-..."
export DEEPSEEK_API_KEY="..."
export GEMINI_API_KEY="..."
```

Use `mcp-cli.sh deepseek chat "deepseek-reasoner" "<prompt>"` for second opinions on hard logic, etc.

## Worker Model Selection

| Role | Primary | Fallback |
|------|---------|----------|
| #1 coder | `glm-5.1:cloud` | `deepseek-v3.1:671b-cloud` |
| #2 coder / review | `minimax-m2.7:cloud` | `minimax-m2.5:cloud` |
| Deep reasoning | `deepseek-v3.2:cloud` | `nemotron-cascade-2:30b` |
| Fast / boilerplate | `qwen3-coder-next:cloud` | `glm-5.1:cloud` |
| Agentic tasks | `nemotron-3-super:cloud` | `deepseek-v3.2:cloud` |
| Vision + code | `gemma4:31b-cloud` | (local) `qwen3-vl:32b` |

## Multi-Model Audit

Get consensus from 3–4 models in parallel:

```bash
bash .claude/scripts/multi-model-audit.sh src/auth.ts src/session.ts
```

Models flag issues independently. If ≥2 flag the same thing, it's included in the report. Single-model flags are noted as "possible".

## Thinktank

For decisions rather than code:

```bash
Skill("thinktank")
# or directly:
bash .claude/scripts/thinktank.sh --question "Should we use Redis or SQLite for session storage in a single-node deploy?"
```

Routes to 3–4 models in parallel (DeepSeek, GPT-5-mini, Ollama cloud, Gemini), aggregates opinions, highlights agreements and disagreements.

## What Brain Never Delegates

- Authentication logic
- Credential handling
- Crypto primitives / key derivation
- Permission/authorization checks
- Final security review before ship
- User communication

These always stay with the orchestrator. The `skill-gate` + `capability-gate` hooks enforce this for auth-related paths.

## Capability Pipeline

When the brain calls a capability-enabling MCP tool (e.g. image generation, research), `capability-tracker.sh` mints a 60-minute token. This lets skill-gate and capability-gate know "yes, a pipeline is in flight" and allow large downstream writes.

Flow: `mcp__gemini__generate_image → token minted → frontend-design-pro skill loaded → 100-line CSS write allowed`.

Without this, design work would be blocked by delegation thresholds even though the brain is legitimately orchestrating a pipeline.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Blocked writing a 60-line test file | Tests are exempted by default. If still blocked, check `delegation-reminder.sh`'s bypass list and add `*.test.ts` or similar |
| Worker times out | `mcp-cli.sh` has a 60s default; override with `OLLAMA_TIMEOUT=120 bash ...` |
| "No delegation token" but I just used a worker | Token TTL is 5 min. Re-invoke the worker, then retry the write |
| Want to write code by hand occasionally | `DELEGATION_MODE=advisory` in settings, or just use the `thinktank` / `mcp-cli.sh ollama chat` escape hatch once — that mints a token for 5 min |
