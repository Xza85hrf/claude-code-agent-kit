---
name: thinktank
description: Multi-model decision consultation — queries 3-4 AI models in parallel for independent expert opinions on architecture and design trade-offs.
argument-hint: "Should we use message queues or event streaming for this system?"
department: architecture
effort: high
thinking-level: high
context: fork
agent: Plan
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Thinktank — Multi-Model Decision Consultation

## When to Use
- Facing an architectural decision with multiple valid approaches
- Technology choice (library A vs B, pattern X vs Y)
- Design trade-offs where domain expertise matters
- Before committing to a direction that's hard to reverse
- When the execution rule says "consult the thinktank" instead of asking the user

## Process

### 1. Frame the Question
Be specific. Include constraints, context, and what success looks like.

Bad: "What database should I use?"
Good: "For a multi-tenant SaaS with 10K users, should we use row-level security in PostgreSQL or separate schemas per tenant? Key constraints: cost-sensitive, team has PostgreSQL experience, need to support tenant data export."

### 2. Run the Consultation

```bash
# Basic question
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/thinktank.sh" --question "Your specific question here"

# With code context
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/thinktank.sh" \
  --question "Should this auth middleware use JWT or session tokens?" \
  --context "$(cat src/auth/middleware.ts)" \
  --focus "security,performance"

# Save decision to knowledge cache for future reference
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/thinktank.sh" \
  --question "Your question" \
  --cache-topic "auth-jwt-vs-sessions" \
  --verbose
```

### 3. Interpret Results

| Signal | Meaning | Action |
|--------|---------|--------|
| All models agree | Strong consensus | Go with it |
| 3/4 agree | Likely correct | Note the dissent, proceed |
| 2/2 split | Genuine trade-off | User preference matters — ask |
| All disagree | Complex problem | Add more context, re-run |

### 4. Document the Decision
If the decision is architectural, append to `docs/decisions.md`:

```markdown
## ADR-XXX: [Title]
- **Date:** YYYY-MM-DD
- **Status:** Accepted
- **Context:** [The question]
- **Thinktank:** [Summary of model opinions]
- **Decision:** [What was chosen and why]
- **Consequences:** [What becomes easier/harder]
```

## Models Used (all cheap)

| Model | Strength | Cost |
|-------|----------|------|
| DeepSeek V3.2 | Reasoning, architecture | $0.14/M |
| OpenAI codex-mini | Breadth, patterns | via /v1/responses |
| Ollama Cloud | Speed, free alternative | Free |
| Gemini 3 Flash | Structural analysis | $0.30/M |

Total cost per consultation: ~$0.001-0.01

## Integration

Used by `.claude/rules/execution.md` — consult thinktank instead of asking user. Decision → frame → consult → decide → document → continue.
