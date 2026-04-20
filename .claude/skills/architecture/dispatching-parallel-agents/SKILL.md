---
name: dispatching-parallel-agents
description: Coordinating parallel agent work. Use when orchestrating multi-agent teams, dispatching subagents for parallel code reviews, or managing pipeline workflows with task dependencies.
argument-hint: "Dispatch a team of 3 agents to parallelize the API, UI, and test implementation"
allowed-tools: Read, Bash, Grep, Glob
model: opus
context: fork
agent: general-purpose
department: architecture
disable-model-invocation: true
references:
  - TEAMMATE-TEMPLATE.md
  - AGENT-TEAMS-REFERENCE.md
  - OLLAMA-SWARM-REFERENCE.md
thinking-level: medium
---

# Agent Swarm Orchestration

## Overview

Claude Code supports multi-agent coordination through TeammateTool and Task system for parallel code reviews, pipeline workflows, task queues, and divide-and-conquer patterns.

**Core principle:** Use subagents for quick independent tasks, teammates for persistent collaboration.

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

**Use when:** 2+ independent tasks, code review from multiple perspectives, independent research, parallel test fixes
**Skip when:** Tasks are related, context needed across tasks, shared file editing, sequential dependencies

## Two Spawning Methods

### Method 1: Subagents (Short-Lived)

Quick, independent tasks returning results directly.

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

Complex workflows requiring coordination and messaging.

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

| Trait | Requirement |
|-------|-------------|
| Focused | One clear problem domain |
| Self-contained | All context included |
| Specific output | What should the agent return? |

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

**Avoid:** Too broad ("Fix all tests"), missing context ("Fix the race condition"), no constraints, vague output ("Fix it")

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

Persistent multi-agent collaboration with inter-agent messaging and shared task lists. Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**When to use:** Agents need to share mid-task findings, competing hypotheses debugging, cross-layer coordination.

**Full reference:** See `AGENT-TEAMS-REFERENCE.md` in this directory for patterns, setup, and best practices.

---

## Best Practices

- Match method to need
- Use meaningful names
- Write explicit prompts with all context
- Leverage task dependencies for ordering
- Check inboxes before assuming completion
- Include retry logic in worker prompts
- Prefer targeted writes over broadcast
- Always cleanup team resources

## Integration with Ollama Workers

Delegate grunt work to Ollama workers while Opus orchestrates. See `OLLAMA-SWARM-REFERENCE.md` for patterns, models, and hybrid approaches.
