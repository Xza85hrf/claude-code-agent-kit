# Team Presets Reference

## What Are Team Presets?

Team presets are pre-configured team compositions stored as JSON files in `.claude/team-presets/`. They eliminate the repetitive manual setup of defining agents, roles, file ownership, and task templates every time you need a common team pattern.

Instead of manually calling TeamCreate, TaskCreate, and spawning agents with custom prompts each time, you load a preset and the team structure is ready to go.

## Available Presets

| Preset | Agents | Use Case |
|--------|--------|----------|
| `review.json` | security-reviewer, perf-reviewer, arch-reviewer | Code review with specialized reviewers |
| `debug.json` | hypothesis-a, hypothesis-b, hypothesis-c | Competing hypotheses debugging |
| `feature.json` | feature-lead, impl-frontend, impl-backend | Full-stack feature development |
| `audit.json` | audit-injection, audit-auth, audit-data, audit-deps | Security audit across attack surfaces |

## How to Use

Opus reads the preset JSON, creates the team, spawns agents, and assigns tasks:

1. **Read the preset**: `Read .claude/team-presets/{preset}.json`
2. **Create the team**: `TeamCreate` with preset name and description
3. **Create tasks**: `TaskCreate` for each agent using `task_template` with variables filled in
4. **Spawn agents**: Use `Task` tool to spawn each agent defined in `agents[]`
5. **Assign tasks**: `TaskUpdate` with `owner` set to each agent's `name`

### Variable Substitution

Task templates contain placeholders that Opus fills at spawn time:

- `{agent.focus}` — replaced with the agent's `focus` field
- `{base_branch}` — the branch to diff against (review preset)
- `{bug_description}` — user-provided bug description (debug preset)
- `{feature_description}` — user-provided feature spec (feature preset)

### Example: Spawning a Review Team

```
1. Read .claude/team-presets/review.json
2. TeamCreate: name="review-pr-42", description="Review PR #42"
3. TaskCreate for each agent:
   - "Review changes for OWASP top 10, auth flows..." (security-reviewer)
   - "Review changes for N+1 queries, re-renders..." (perf-reviewer)
   - "Review changes for SOLID violations, coupling..." (arch-reviewer)
4. Spawn 3 Haiku teammates with TEAMMATE-TEMPLATE.md
5. Assign tasks by owner name
6. Collect results, synthesize, shutdown
```

## File Ownership Rules

Each agent has a `file_ownership` array of glob patterns defining which files they are responsible for.

**Rules:**
- Agents should only modify or deeply review files matching their ownership patterns
- If an agent needs changes in files outside their ownership, they create a task dependency for the owning agent
- Ownership patterns are advisory for review/audit presets (agents report on their domain) and enforced for feature presets (agents only edit their files)
- No two agents in the same preset should have overlapping ownership for write operations

**Why this matters:** File ownership prevents merge conflicts when multiple agents work in parallel. Without it, two agents editing the same file will produce conflicting changes that require manual resolution.

## Customizing Presets

### For a Specific Project

Copy a preset and adjust:
- **Agent names/roles** to match your team's domain
- **File ownership patterns** to match your project structure
- **Focus areas** to cover your specific concerns
- **Model selection** — use `sonnet` for lead/complex roles, `haiku` for parallel workers

### Creating a New Preset

Follow the JSON schema:

```json
{
  "name": "preset-name",
  "description": "What this team does",
  "agents": [
    {
      "name": "agent-name",
      "role": "Human-readable role description",
      "subagent_type": "general-purpose",
      "model": "haiku",
      "focus": "What this agent concentrates on",
      "file_ownership": ["**/relevant/**", "**/*.ext"]
    }
  ],
  "task_template": "Template with {variables} for task creation."
}
```

**Guidelines:**
- Keep teams to 2-4 agents (diminishing returns beyond 4)
- Use `haiku` for most agents, `sonnet` only for lead/orchestrator roles
- Make file ownership non-overlapping for write-heavy presets
- Write task templates that produce structured, comparable output across agents
