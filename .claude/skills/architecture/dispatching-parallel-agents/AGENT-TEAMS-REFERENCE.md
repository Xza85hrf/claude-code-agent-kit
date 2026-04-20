# Agent Teams Reference (Experimental)

Agent Teams add a third collaborative tier: multiple persistent Claude instances with inter-agent messaging, shared task lists, and self-coordination.

## Enabling Agent Teams

```bash
# Environment variable
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Or in .claude/settings.json
{ "agentTeams": true }
```

## Agent Teams vs Subagents

| Dimension | Subagents (Tier 2) | Agent Teams (Tier 3) |
|-----------|-------------------|----------------------|
| **Lifecycle** | Short-lived, dies on completion | Persistent, stays until shutdown |
| **Communication** | Report back to parent only | Inter-agent messaging (inboxes) |
| **Task sharing** | No shared state | Shared TaskList, claim from pool |
| **Cost** | Moderate (one Claude instance) | High (N Claude instances) |
| **Coordination** | None between siblings | Full coordination via messages |
| **Use for** | Independent parallel tasks | Collaborative, communicating work |

## Delegate Mode (Shift+Tab)

Toggle between writing code yourself and delegating to teammates:
- **You-write mode**: Normal operation, you type and execute
- **Delegate mode**: Describe intent, teammates execute collaboratively

## Plan Approval Workflow

1. Leader creates implementation plan via `writing-plans` skill
2. Teammates review the plan (each from their specialty)
3. Leader approves or revises based on feedback
4. Teammates claim tasks from shared TaskList and execute

## Team Patterns

### Competing Hypotheses Debugging

```javascript
Teammate({ operation: "spawnTeam", team_name: "debug-flaky-test" })

Task({
  team_name: "debug-flaky-test",
  name: "timing-investigator",
  prompt: "Investigate whether the flaky test is caused by race conditions...",
  run_in_background: true
})

Task({
  team_name: "debug-flaky-test",
  name: "state-investigator",
  prompt: "Investigate whether shared mutable state between tests causes the flakiness...",
  run_in_background: true
})
// Leader synthesizes findings
```

### Cross-Layer Coordination

```javascript
Teammate({ operation: "spawnTeam", team_name: "full-stack-feature" })

Task({ team_name: "full-stack-feature", name: "backend-dev",
  prompt: "Implement the API endpoint. Message frontend-dev with the response schema when ready.",
  run_in_background: true })

Task({ team_name: "full-stack-feature", name: "frontend-dev",
  prompt: "Wait for backend-dev's schema message, then implement the UI component.",
  run_in_background: true })

Task({ team_name: "full-stack-feature", name: "test-writer",
  prompt: "Write integration tests as endpoints and components are completed.",
  run_in_background: true })
```

### Adversarial Review

```javascript
Teammate({ operation: "spawnTeam", team_name: "adversarial-review" })

Task({ team_name: "adversarial-review", name: "reviewer-a",
  prompt: "Review the PR for issues. After your review, message reviewer-b with your findings. Then review their findings and challenge any you disagree with.",
  run_in_background: true })

Task({ team_name: "adversarial-review", name: "reviewer-b",
  prompt: "Review the PR for issues. After your review, message reviewer-a with your findings. Then review their findings and challenge any you disagree with.",
  run_in_background: true })
```

## Quality Hooks for Teams

- **`teammate-idle`** (TeammateIdle): Checks for unclaimed tasks before allowing a teammate to go idle
- **`task-completed`** (TaskCompleted): Blocks task completion if unresolved merge conflicts exist

## Team Best Practices

1. **Reserve teams for genuinely collaborative work** — don't use Tier 3 when Tier 1/2 suffices
2. **Keep teams small** — 2-4 teammates max; more adds coordination overhead
3. **Use targeted writes over broadcast** — messaging one agent is cheaper than messaging all
4. **Always clean up** — `requestShutdown` all teammates, then `cleanup` team resources
5. **Monitor costs** — each teammate is a full Claude instance consuming tokens

## Limitations

- **Experimental feature** — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- **No Ollama access** — teammates are Claude instances, not local models
- **High token cost** — each teammate consumes full Claude context
- **File conflicts** — teammates editing the same file can cause merge conflicts (use `task-completed` hook)
- **Not for auto-delegation** — too expensive for routine tasks; use consciously
