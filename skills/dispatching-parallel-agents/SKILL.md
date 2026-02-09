---
name: dispatching-parallel-agents
description: Use when coordinating multiple agents for parallel work, setting up agent teams, managing task dependencies, or orchestrating complex multi-agent workflows
---

# Agent Swarm Orchestration

## Overview

Claude Code supports multi-agent coordination through the TeammateTool and Task system. This skill covers parallel code reviews, pipeline workflows with dependencies, self-organizing task queues, and divide-and-conquer patterns.

**Core principle:** Dispatch agents strategically - use subagents for quick independent tasks, teammates for persistent collaboration.

## Core Primitives

| Concept | Description |
|---------|-------------|
| **Agent** | A Claude instance capable of tool usage (you are an agent; spawned instances are subagents) |
| **Team** | A named group of agents - one leader + multiple teammates |
| **Teammate** | An agent that joined a team with name, color, and inbox |
| **Task** | Work item with subject, description, status, owner, and dependencies |
| **Inbox** | JSON file for inter-agent messaging at `~/.claude/teams/{name}/inboxes/{agent}.json` |

## When to Use

```
Decision Flow:

Multiple tasks? ─────────────────────┐
        │                            │
        ▼                            │
Are they independent? ───── no ──────┤
        │                            │
       yes                           │
        │                            │
        ▼                            │
Can they run in parallel? ── no ─────┤
        │                            │
       yes                           │
        │                            │
        ▼                            │
Do workers need to COMMUNICATE? ─────┤
        │                            │
       yes                    no     │
        │                     │      │
        ▼                     ▼      ▼
   AGENT TEAM          DISPATCH   Sequential
   (Tier 3)            PARALLEL   execution
                       (Tier 1/2) (single agent)
```

**Use parallel agents when:**
- 2+ independent tasks with no shared state
- Code review from multiple perspectives (security, performance, simplicity)
- Research tasks that don't depend on each other
- Test fixes in different subsystems

**Don't use when:**
- Tasks are related (fixing one might fix others)
- Need to maintain conversation context across tasks
- Agents would edit the same files
- Sequential dependencies between all tasks

## Two Spawning Methods

### Method 1: Subagents (Short-Lived)

Best for quick, independent tasks that return results directly.

```javascript
Task({
  subagent_type: "Explore",
  description: "Find auth files",
  prompt: "Locate authentication-related files in this codebase",
  model: "haiku"  // Use haiku for fast, simple tasks
})
```

**Characteristics:**
- Synchronous execution
- Results returned directly to you
- No team membership or messaging
- Dies when task completes

**Built-in agent types:**
- `Bash` - Git operations and system commands
- `Explore` - Read-only codebase exploration (fast)
- `Plan` - Architecture and strategy planning
- `general-purpose` - Multi-step tasks with full tool access
- `claude-code-guide` - Documentation queries

### Method 2: Teammates (Persistent)

Best for complex workflows requiring coordination and communication.

```javascript
// 1. Create the team (you become leader)
Teammate({ operation: "spawnTeam", team_name: "pr-review" })

// 2. Spawn teammates
Task({
  team_name: "pr-review",
  name: "security-reviewer",
  subagent_type: "general-purpose",
  prompt: "Review authentication code for vulnerabilities...",
  run_in_background: true
})

// 3. Check inbox for results
// Read ~/.claude/teams/pr-review/inboxes/team-lead.json
```

**Characteristics:**
- Team membership with inboxes
- Can communicate with other teammates
- Persistent until shutdown requested
- Shared task list access

## Orchestration Patterns

### Pattern 1: Parallel Specialists

Multiple agents review simultaneously from different perspectives.

```javascript
// Spawn team
Teammate({ operation: "spawnTeam", team_name: "code-review" })

// Launch parallel reviewers
Task({
  team_name: "code-review",
  name: "security",
  prompt: "Review for security vulnerabilities. Report findings to team-lead.",
  run_in_background: true
})

Task({
  team_name: "code-review",
  name: "performance",
  prompt: "Review for performance issues. Report findings to team-lead.",
  run_in_background: true
})

Task({
  team_name: "code-review",
  name: "simplicity",
  prompt: "Review for unnecessary complexity. Report findings to team-lead.",
  run_in_background: true
})

// Monitor inbox, aggregate results
```

### Pattern 2: Pipeline (Sequential with Dependencies)

Tasks flow through stages, each unblocking the next.

```javascript
// Create tasks with dependencies
TaskCreate({ subject: "Fetch requirements", description: "..." })  // id: 1
TaskCreate({ subject: "Design API", description: "..." })          // id: 2
TaskCreate({ subject: "Implement endpoints", description: "..." }) // id: 3
TaskCreate({ subject: "Write tests", description: "..." })         // id: 4

// Set up dependency chain
TaskUpdate({ taskId: "2", addBlockedBy: ["1"] })  // Design waits for requirements
TaskUpdate({ taskId: "3", addBlockedBy: ["2"] })  // Implement waits for design
TaskUpdate({ taskId: "4", addBlockedBy: ["3"] })  // Tests wait for implementation

// Tasks auto-unblock when dependencies complete
```

### Pattern 3: Swarm (Self-Organizing)

Workers independently claim available tasks from a pool.

```javascript
// Create task pool
TaskCreate({ subject: "Fix auth tests", description: "..." })
TaskCreate({ subject: "Fix API tests", description: "..." })
TaskCreate({ subject: "Fix UI tests", description: "..." })

// Spawn workers with self-organizing prompt
const workerPrompt = `
You are a task worker. Your loop:
1. TaskList to find unclaimed tasks (no owner, not blocked)
2. TaskUpdate to claim one (set owner to your name)
3. TaskUpdate to mark in_progress
4. Complete the work
5. TaskUpdate to mark completed
6. Repeat until no tasks remain
`;

Task({ name: "worker-1", prompt: workerPrompt, run_in_background: true })
Task({ name: "worker-2", prompt: workerPrompt, run_in_background: true })
Task({ name: "worker-3", prompt: workerPrompt, run_in_background: true })
```

### Pattern 4: Research + Implementation

Research phase informs implementation.

```javascript
// Research phase (parallel)
const authResearch = Task({
  subagent_type: "Explore",
  prompt: "How is authentication currently implemented?"
})

const dbResearch = Task({
  subagent_type: "Explore",
  prompt: "What database patterns are used?"
})

// Wait for research results, then implement
// Use research findings in implementation prompt
```

### Pattern 5: Coordinated Refactoring

Multiple files refactored in parallel, tests updated after all complete.

```javascript
TaskCreate({ subject: "Refactor auth module", description: "..." })     // id: 1
TaskCreate({ subject: "Refactor user module", description: "..." })     // id: 2
TaskCreate({ subject: "Refactor api module", description: "..." })      // id: 3
TaskCreate({ subject: "Update all tests", description: "..." })         // id: 4

// Tests wait for ALL refactors
TaskUpdate({ taskId: "4", addBlockedBy: ["1", "2", "3"] })

// Dispatch parallel refactoring agents
Task({ prompt: "Complete task 1: Refactor auth module", run_in_background: true })
Task({ prompt: "Complete task 2: Refactor user module", run_in_background: true })
Task({ prompt: "Complete task 3: Refactor api module", run_in_background: true })

// Task 4 auto-unblocks when 1, 2, 3 all complete
```

## TeammateTool Operations

| Operation | Purpose | Example |
|-----------|---------|---------|
| `spawnTeam` | Create team, become leader | `{ operation: "spawnTeam", team_name: "feature-x" }` |
| `write` | Message one teammate | `{ operation: "write", target_agent_id: "reviewer", value: "Check auth" }` |
| `broadcast` | Message all (use sparingly) | `{ operation: "broadcast", value: "Status check" }` |
| `requestShutdown` | Ask teammate to exit | `{ operation: "requestShutdown", target_agent_id: "worker" }` |
| `approveShutdown` | Confirm ready to exit | `{ operation: "approveShutdown" }` |
| `cleanup` | Remove team resources | `{ operation: "cleanup" }` |

## Task System

```javascript
// Create task
TaskCreate({
  subject: "Review authentication",
  description: "Check app/services/auth/ for vulnerabilities",
  activeForm: "Reviewing authentication"  // Shown while in progress
})

// Update task
TaskUpdate({ taskId: "1", status: "in_progress" })
TaskUpdate({ taskId: "1", status: "completed" })

// Set dependencies
TaskUpdate({ taskId: "2", addBlockedBy: ["1"] })  // Task 2 waits for task 1

// List all tasks
TaskList()
```

## Agent Prompt Best Practices

**Good prompts are:**
1. **Focused** - One clear problem domain
2. **Self-contained** - All context needed
3. **Specific about output** - What should the agent return?

```markdown
# Good prompt example

Fix the 3 failing tests in src/agents/auth.test.ts:

1. "should validate tokens" - expects valid token check
2. "should reject expired tokens" - timing issue
3. "should handle refresh" - race condition

Your task:
1. Read the test file and understand each test
2. Identify root cause (timing? logic? race condition?)
3. Fix the tests - replace timeouts with event-based waiting if needed
4. Do NOT change production code unless it's actually buggy

Return: Summary of root cause and changes made.
```

**Common mistakes:**
- Too broad: "Fix all the tests" (agent gets lost)
- No context: "Fix the race condition" (where?)
- No constraints: Agent might refactor everything
- Vague output: "Fix it" (what changed?)

## Spawn Backends

Claude Code auto-detects the best backend:

| Backend | When Used | Visibility |
|---------|-----------|------------|
| `in-process` | Default outside tmux | Hidden, dies with leader |
| `tmux` | Inside tmux session | Visible panes, persistent |
| `iterm2` | In iTerm2 with `it2` CLI | Split panes |

## Graceful Shutdown

```javascript
// 1. Request shutdown from all teammates
Teammate({ operation: "requestShutdown", target_agent_id: "worker-1" })
Teammate({ operation: "requestShutdown", target_agent_id: "worker-2" })

// 2. Wait for shutdown approvals (check inbox)

// 3. Cleanup team resources
Teammate({ operation: "cleanup" })
```

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| "Cannot cleanup with active members" | Teammates still running | requestShutdown first |
| "Team does not exist" | No spawnTeam called | Call spawnTeam before spawning |
| Crashed teammate | Agent errored out | 5-min heartbeat timeout, reclaim tasks |
| Task stuck | Worker crashed | TaskUpdate to remove owner, reassign |

## Environment Variables (Auto-Set for Teammates)

- `CLAUDE_CODE_TEAM_NAME` - Team identifier
- `CLAUDE_CODE_AGENT_ID` - Unique agent ID
- `CLAUDE_CODE_AGENT_NAME` - Human-readable name
- `CLAUDE_CODE_AGENT_TYPE` - Agent type used
- `CLAUDE_CODE_AGENT_COLOR` - Terminal color

## Quick Reference

```
SUBAGENTS (short-lived):
Task({ subagent_type: "Explore", prompt: "...", model: "haiku" })
→ Fast, returns result directly, no coordination

TEAMMATES (persistent):
Teammate({ operation: "spawnTeam", team_name: "..." })
Task({ team_name: "...", name: "...", prompt: "...", run_in_background: true })
→ Coordination, messaging, shared tasks

TASK DEPENDENCIES:
TaskUpdate({ taskId: "2", addBlockedBy: ["1"] })
→ Task 2 waits for task 1

MESSAGING:
Teammate({ operation: "write", target_agent_id: "...", value: "..." })
→ Check inbox at ~/.claude/teams/{name}/inboxes/{agent}.json

SHUTDOWN:
requestShutdown → wait for approvals → cleanup
```

## Agent Teams (Experimental)

Agent Teams add a third collaborative tier: multiple persistent Claude instances with inter-agent messaging, shared task lists, and self-coordination.

### Enabling Agent Teams

```bash
# Environment variable
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Or in .claude/settings.json
{ "agentTeams": true }
```

### Agent Teams vs Subagents

| Dimension | Subagents (Tier 2) | Agent Teams (Tier 3) |
|-----------|-------------------|----------------------|
| **Lifecycle** | Short-lived, dies on completion | Persistent, stays until shutdown |
| **Communication** | Report back to parent only | Inter-agent messaging (inboxes) |
| **Task sharing** | No shared state | Shared TaskList, claim from pool |
| **Cost** | Moderate (one Claude instance) | High (N Claude instances) |
| **Coordination** | None between siblings | Full coordination via messages |
| **Use for** | Independent parallel tasks | Collaborative, communicating work |

### Delegate Mode (Shift+Tab)

Toggle between writing code yourself and delegating to teammates:
- **You-write mode**: Normal operation, you type and execute
- **Delegate mode**: Describe intent, teammates execute collaboratively

### Plan Approval Workflow

1. Leader creates implementation plan via `writing-plans` skill
2. Teammates review the plan (each from their specialty)
3. Leader approves or revises based on feedback
4. Teammates claim tasks from shared TaskList and execute

### Pattern 6: Competing Hypotheses Debugging

```javascript
// Spawn team for multi-hypothesis investigation
Teammate({ operation: "spawnTeam", team_name: "debug-flaky-test" })

// Each teammate investigates a different hypothesis
Task({
  team_name: "debug-flaky-test",
  name: "timing-investigator",
  prompt: "Investigate whether the flaky test is caused by race conditions or timing issues...",
  run_in_background: true
})

Task({
  team_name: "debug-flaky-test",
  name: "state-investigator",
  prompt: "Investigate whether shared mutable state between tests causes the flakiness...",
  run_in_background: true
})

// Teammates share findings via messages as they discover clues
// Leader synthesizes and identifies actual root cause
```

### Pattern 7: Cross-Layer Coordination

```javascript
// Frontend + backend + tests coordinated simultaneously
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

### Pattern 8: Parallel Review with Challenge

```javascript
// Two reviewers who must challenge each other's findings
Teammate({ operation: "spawnTeam", team_name: "adversarial-review" })

Task({ team_name: "adversarial-review", name: "reviewer-a",
  prompt: "Review the PR for issues. After your review, message reviewer-b with your findings. Then review their findings and challenge any you disagree with.",
  run_in_background: true })

Task({ team_name: "adversarial-review", name: "reviewer-b",
  prompt: "Review the PR for issues. After your review, message reviewer-a with your findings. Then review their findings and challenge any you disagree with.",
  run_in_background: true })

// Leader collects both perspectives + challenges for final decision
```

### Display Modes

| Backend | When Used | Visibility |
|---------|-----------|------------|
| `in-process` | Default outside tmux | Hidden, dies with leader |
| `tmux` | Inside tmux session | Visible panes, persistent |
| `iterm2` | In iTerm2 with `it2` CLI | Split panes |

### Quality Hooks for Teams

Two hooks enforce quality in team workflows:
- **`teammate-idle`** (TeammateIdle): Checks for unclaimed tasks before allowing a teammate to go idle
- **`task-completed`** (TaskCompleted): Blocks task completion if unresolved merge conflicts exist

### Team Best Practices

1. **Reserve teams for genuinely collaborative work** — don't use Tier 3 when Tier 1/2 suffices
2. **Keep teams small** — 2-4 teammates max; more adds coordination overhead
3. **Use targeted writes over broadcast** — messaging one agent is cheaper than messaging all
4. **Always clean up** — `requestShutdown` all teammates, then `cleanup` team resources
5. **Monitor costs** — each teammate is a full Claude instance consuming tokens

### Shutdown and Cleanup

```javascript
// 1. Request shutdown from all teammates
Teammate({ operation: "requestShutdown", target_agent_id: "worker-1" })
Teammate({ operation: "requestShutdown", target_agent_id: "worker-2" })

// 2. Wait for shutdown approvals (check inbox)

// 3. Cleanup team resources
Teammate({ operation: "cleanup" })
```

### Limitations

- **Experimental feature** — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- **No Ollama access** — teammates are Claude instances, not local models
- **High token cost** — each teammate consumes full Claude context
- **File conflicts** — teammates editing the same file can cause merge conflicts (use `task-completed` hook)
- **Not for auto-delegation** — too expensive for routine tasks; use consciously

---

## Best Practices

1. **Match method to need** - Subagents for quick tasks, teammates for coordination
2. **Use meaningful names** - "security-reviewer" not "worker-1"
3. **Write explicit prompts** - Include all context the agent needs
4. **Leverage dependencies** - Let task system handle ordering
5. **Check inboxes** - Don't assume agents completed successfully
6. **Build retry logic** - Include recovery in worker prompts
7. **Prefer targeted writes** - `write` over `broadcast` (cost)
8. **Always cleanup** - Remove team resources when done

## Integration with Ollama Workers

### Using Local Models for Agent Swarm

For maximum efficiency, delegate grunt work to Ollama workers while Opus orchestrates:

```javascript
// Pattern: Ollama Worker Swarm
// Opus spawns local model workers for parallel analysis

// Step 1: Use ollama_chat for each worker
// (These are NOT Claude subagents, they're local model calls)

// Worker 1: Analyze file with fast coder
ollama_chat({
  model: "glm-4.7-flash",
  messages: [{ role: "user", content: "Analyze patterns in auth.ts: [file content]" }]
})

// Worker 2: Analyze file with fast coder (parallel)
ollama_chat({
  model: "glm-4.7-flash",
  messages: [{ role: "user", content: "Analyze patterns in user.ts: [file content]" }]
})

// Worker 3: Vision analysis if needed
ollama_chat({
  model: "kimi-k2.5:cloud",
  messages: [{ role: "user", content: "Describe this UI screenshot", images: ["..."] }]
})

// Step 2: Opus collects and synthesizes results
// YOU make the final decisions based on worker outputs
```

### Model Selection for Swarm Tasks (Cloud-First)

Try cloud models first when `OLLAMA_API_KEY` is set; fall back to local if unavailable.

| Task Type | Cloud (preferred) | Local (fallback) | Why |
|-----------|-------------------|------------------|-----|
| Complex coding | `qwen3-coder-next:cloud` | `qwen3-coder-next:latest` (51GB) | 80B FP8 cloud / Q4_K_M local, 262K ctx |
| Multi-step with tools | `kimi-k2.5:cloud` | — (cloud-only) | Best tool calling + thinking + vision |
| Fast code generation | `glm-4.7:cloud` | `glm-4.7-flash` (19GB) | Cloud full / local 30B MoE quantized |
| Image/UI analysis | `kimi-k2.5:cloud` | `qwen3-vl:32b` (20GB) | Vision + multimodal capabilities |
| Large repo analysis | `gemini-3-pro-preview` | — (cloud-only) | 1M context window, vision + thinking |
| Agentic SWE tasks | — | `devstral-small-2` (15GB) | Multi-file editing, tool calling, SWE-bench 65.8% |
| Code reasoning | — | `deepcoder` (9GB) | Algorithmic tasks, o3-mini level reasoning |

### Hybrid Pattern: Claude Subagents + Ollama Workers

```javascript
// For complex tasks: Use Claude subagent to orchestrate Ollama workers
Task({
  subagent_type: "general-purpose",
  prompt: `
    You are coordinating a file analysis task.

    1. Use ollama_chat with glm-4.7-flash to analyze each file:
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

### Token Savings with Ollama Delegation

| Approach | Tokens Used | Notes |
|----------|-------------|-------|
| Send file to Opus | ~4000 | Full file in context |
| Send path to Ollama | ~50 | Ollama reads file locally |
| **Savings** | **98%** | Massive cost reduction |

**Remember:** Opus = Brain. Ollama = Workers. Always review worker output.

---

## Real-World Impact

From debugging session with 6 test failures across 3 files:
- 3 agents dispatched in parallel (one per file)
- All investigations completed concurrently
- All fixes integrated successfully
- Zero conflicts between changes
- Time: 3 problems solved in time of 1
