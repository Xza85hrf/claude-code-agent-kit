# AGENTS.md — Multi-Model Agent Specification

## Architecture

**Orchestrator (brain):** Claude Code — plans, decides, integrates, handles user communication.
**Workers:** Ollama models, OpenAI, DeepSeek, Gemini — code gen, reviews, parallel tasks.

The brain keeps planning, security review, final integration, and anything needing Claude Code's tool access. Workers do bulk implementation, boilerplate, and second opinions.

## Execution Tiers

| Tier | Engine | Best For | Cost |
|------|--------|----------|------|
| 0 | Orchestrator (Claude Code) | Planning, security, integration, user comms | $$$ |
| 1 | `claude -p` + Ollama | Multi-file implementation, autonomous tasks | Free |
| 2 | `mcp-cli.sh ollama chat` | Quick code gen, reviews | Free |
| 3 | Task tool subagents | Exploration, multi-step Claude reasoning | $ |
| 4 | Agent Teams (2+ teammates) | Collaborative work, competing hypotheses | $$ |
| 5 | Git worktrees | Long-running parallel branches | Free |

Decision flow: brain tools needed → Tier 0. Multi-file impl → Tier 1. Simple gen → Tier 2. Claude reasoning → Tier 3. Coordination → Tier 4.

## Worker Models (via Ollama)

Ollama Cloud runs production-grade models at fixed pricing ($0 / $20 / $100 per month). Point the `ollama` CLI at `https://ollama.com/v1` with `OLLAMA_API_KEY`. Local models work too.

| Role | Primary | Fallback |
|------|---------|----------|
| Coder #1 | `glm-5.1:cloud` | `deepseek-v3.1:671b-cloud` |
| Coder #2 / Review | `minimax-m2.7:cloud` | `minimax-m2.5:cloud` |
| Deep reasoning | `deepseek-v3.2:cloud` | `nemotron-cascade-2:30b` |
| Fast / boilerplate | `qwen3-coder-next:cloud` | `glm-5.1:cloud` |
| Agentic | `nemotron-3-super:cloud` | `deepseek-v3.2:cloud` |
| Vision + code | `gemma4:31b-cloud` | `qwen3-vl:32b` (local) |

Route a call via CLI wrapper: `bash .claude/scripts/mcp-cli.sh ollama chat "<model>" "<prompt>"`.

## Graduated Delegation

The `delegation-reminder` hook nudges toward worker delegation based on lines written:

| Lines | Behavior |
|-------|----------|
| ≤ `DELEGATION_THRESHOLD` (default 10) | Allowed silently |
| > threshold, ≤ `DELEGATION_BLOCK_THRESHOLD` (default 50) | Advisory warning (1st time) → BLOCK (2nd+) |
| > block threshold | BLOCKED unless a delegation token exists (created after an `ollama_chat` call within 5 min) |

Tune via env vars in `.claude/settings.local.json`. Set `DELEGATION_MODE=advisory` to never block.

## Agents (Subagent Definitions)

| Agent | Role | Teams |
|-------|------|-------|
| `arch-reviewer` | Architecture review — SOLID, coupling, dead code | review |
| `audit-auth` | Authentication & access control auditor | audit |
| `audit-data` | Data protection / PII leakage auditor | audit |
| `audit-deps` | Dependency / CVE / config auditor | audit |
| `audit-injection` | SQL / command / XSS / template injection | audit |
| `codebase-explorer` | Read-only architecture mapping | — |
| `coordinator` | Team coordination and dependency management | feature |
| `evaluator` | QA via Playwright against sprint contracts | — |
| `feature-lead` | Feature architect — interfaces, reviews, integration | feature |
| `hypothesis-a` | Debug theory: data & state | debug |
| `hypothesis-b` | Debug theory: infrastructure & config | debug |
| `hypothesis-c` | Debug theory: logic & algorithm | debug |
| `impl-backend` | Backend implementer (scoped file ownership) | feature |
| `impl-frontend` | Frontend implementer (scoped file ownership) | feature |
| `meta-agent` | Generate new `.md` agent files from descriptions | — |
| `perf-reviewer` | Performance review — N+1, bundle, memory | review |
| `reviewer` | General-purpose read-only code review | — |
| `security-reviewer` | Security review — OWASP, auth, injection | review |
| `skill-reviewer` | Review skills, hooks, agents, commands for quality | — |
| `worker` | General implementation worker | — |

## Agent Teams

Enable: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Use for 3+ independent cross-layer tasks.
Protocol: `TeamCreate` → `TaskCreate` → spawn 2–4 teammates → monitor → shutdown → `TeamDelete`.

Presets (`.claude/team-presets/`):

| Preset | Composition | Use For |
|--------|-------------|---------|
| `audit` | 4 audit specialists | Full security/quality audit |
| `debug` | 3 hypothesis agents | Hard bugs with competing theories |
| `feature` | Lead + 2 implementers + coordinator | End-to-end feature dev |
| `review` | 3 review specialists | PR review, pre-landing |
| `swarm` | Coordinator + N workers | Parallel bulk work |

## Code Audit

`bash .claude/scripts/multi-model-audit.sh <files>` runs 3–4 models in parallel and reports consensus. Two models flag → include. One model → note as "possible".

**Never delegate auth or crypto logic to workers.** Brain handles it directly.

## Skill Gate (structural enforcement)

Domain file writes in the `standard` profile require the matching skill be loaded first:

- Pages / layouts / heroes / CSS → `Skill("frontend-design-pro")`
- Components / forms / tables → `Skill("frontend-engineering")`
- Handlers / routes / services → `Skill("backend-design")`

Exceptions: small edits (≤10 lines), test files, type definitions, and kit internals bypass.
Set `SKILL_GATE=advisory` in settings to downgrade to warnings only.
