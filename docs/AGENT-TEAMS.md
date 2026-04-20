# Agent Teams

Subagents are scoped Claude instances you can spawn for independent work. Agent Teams add coordination — a lead plus 2–4 teammates with file-ownership boundaries, working in parallel.

## Subagents (Always Available)

20 subagent definitions ship in `.claude/agents/`:

| Agent | What it does |
|-------|-------------|
| `arch-reviewer` | SOLID violations, coupling, abstraction leaks, dead code |
| `audit-auth` | Authentication & access control flaws |
| `audit-data` | PII exposure, insecure storage, missing encryption |
| `audit-deps` | CVEs, insecure defaults, missing security headers |
| `audit-injection` | SQL / command / XSS / template injection |
| `codebase-explorer` | Read-only architecture mapping |
| `coordinator` | Manages dependencies between teammates |
| `evaluator` | QA via Playwright against sprint contracts |
| `feature-lead` | Feature architect — interfaces, reviews, integration |
| `hypothesis-a/b/c` | Debug investigators with competing root-cause theories |
| `impl-backend` | Backend implementer (scoped file ownership) |
| `impl-frontend` | Frontend implementer (scoped file ownership) |
| `meta-agent` | Generates new agent `.md` files from descriptions |
| `perf-reviewer` | N+1 queries, bundle bloat, memory leaks |
| `reviewer` | General-purpose code review |
| `security-reviewer` | OWASP top 10, auth flows, secrets |
| `skill-reviewer` | Reviews skills/hooks/agents for quality |
| `worker` | General implementation worker |

Spawn one via the `Task` tool:

```
Spawn the security-reviewer on src/auth/session.ts
```

Claude picks the agent by description, scopes it to the work, and returns results.

## Agent Teams

For tasks that split cleanly across 3+ workers, Teams give you:

- **File ownership boundaries** — each teammate gets explicit paths they can touch
- **Parallel execution** — work happens concurrently
- **A coordinator** — tracks blockers, resolves contention
- **A 2-level delegation** — teammates can spawn their own workers

### Enable

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude
```

### Presets

Five presets live in `.claude/team-presets/`:

| Preset | Composition | Use for |
|--------|-------------|---------|
| `audit` | 4 audit specialists (auth, data, deps, injection) | Full security audit before release |
| `debug` | 3 hypothesis agents (A: data, B: infra, C: logic) | Hard bugs with unclear root cause |
| `feature` | `feature-lead` + `impl-backend` + `impl-frontend` + `coordinator` | End-to-end cross-layer feature |
| `review` | `reviewer` + `security-reviewer` + `perf-reviewer` | Pre-landing PR review |
| `swarm` | `coordinator` + N workers | Parallel bulk work (batch refactor, test generation) |

### Protocol

Claude handles this, but the shape is:

1. `TeamCreate` with a preset
2. `TaskCreate` for each unit of work
3. Spawn teammates — they `TaskUpdate` to claim tasks
4. Monitor — the lead watches progress, unblocks contention
5. `shutdown_request` when done
6. `TeamDelete`

Rules:

- No two teammates own the same file
- Teammates delegate code gen to Ollama workers (still free)
- Coordinator resolves merge conflicts

### When To Use vs. Not

| Use a team when | Don't when |
|----------------|-----------|
| Task has 3+ independent sub-tasks | Task is sequential |
| Work spans multiple files/layers | One file, one change |
| You need competing hypotheses (debug) | The root cause is already known |
| Parallel speedup > coordination cost | Coordination > the work itself |

For simple "do this one thing," a single subagent is always better than a team.

## Hypothesis Pattern (Debug)

The `debug` preset runs three agents in parallel, each with a pre-committed theory:

- **A** investigates data & state — race conditions, cache staleness, stale snapshots
- **B** investigates infra & config — env vars, dependencies, timeouts, networking
- **C** investigates logic & algorithms — off-by-one, null handling, type coercion

Each returns confidence + evidence. The lead picks the winner (or requests more investigation if none is confident).

Works well for:
- Intermittent bugs (helps catch race conditions vs. logic errors)
- Cross-stack issues (one of the three usually owns the layer)
- Review stalemates (3 independent votes)

## Custom Agents

Each agent is a single markdown file with frontmatter:

```yaml
---
name: my-agent
description: One-line — used to route work to this agent
tools: [Read, Grep, Glob, Bash]   # restrict the agent's tool set
model: haiku                       # pick cost tier: haiku, sonnet, opus
---

# System prompt body
You are a specialist in ...

## Triggering Conditions
Spawn me when ...

## Deliverables
Return ...
```

Drop into `.claude/agents/my-agent.md`. Claude autodiscovers it.

Use the `meta-agent` subagent to generate new agent files from natural language descriptions:

```
Task(meta-agent, "Create an agent that reviews database migrations for safety")
```

## Reference

- Agent definitions: `.claude/agents/*.md`
- Team presets: `.claude/team-presets/*.json`
- `AGENTS.md` at repo root for the full tier + role spec
