# Agent Enhancement Kit - Index

> Quick navigation for the autonomous coding agent configuration files.

---

## Quick Start

1. **New Project?** → Copy kit to `.claude/` and read [INIT-PROMPT.md](INIT-PROMPT.md)
2. **Need the init prompt?** → [INIT-PROMPT.md](INIT-PROMPT.md)
3. **Understanding the agent?** → [CLAUDE.md](CLAUDE.md)
4. **Test all capabilities?** → [TEST-CAPABILITIES.md](TEST-CAPABILITIES.md)

---

## Core Files

| File | Purpose | Read When |
|------|---------|-----------|
| [CLAUDE.md](CLAUDE.md) | Agent identity, autonomous protocols, decision authority | Always - this is the brain |
| [INIT-PROMPT.md](INIT-PROMPT.md) | Copy-paste prompts to initialize agent | Starting a new session |
| [README.md](README.md) | Setup instructions and overview | First time setup |
| [TEST-CAPABILITIES.md](TEST-CAPABILITIES.md) | Test prompt to verify all capabilities | After setup, to verify |

---

## Frameworks & Guides

| File | Purpose | Read When |
|------|---------|-----------|
| [CRITICAL-THINKING.md](CRITICAL-THINKING.md) | Analysis, debugging, architecture frameworks | Complex problems, debugging |
| [CODING-AGENT-GUIDE.md](CODING-AGENT-GUIDE.md) | Complete tool reference, workflows, patterns | Need tool guidance |
| [SKILLS-MCP-GUIDE.md](SKILLS-MCP-GUIDE.md) | MCP servers, skills, Context7 usage | Using external tools |

---

## Quality & Reference

| File | Purpose | Read When |
|------|---------|-----------|
| [QUALITY-HOOKS.md](QUALITY-HOOKS.md) | Automated quality checks (22 hooks) | Setting up automation |
| [MCP-CATALOG.md](MCP-CATALOG.md) | On-demand MCP loading guide | Need external service MCPs |
| [SKILLS-CATALOG.md](SKILLS-CATALOG.md) | On-demand external skills guide | Need specialized skills |
| [MCP-AND-PLUGINS.md](MCP-AND-PLUGINS.md) | MCP servers & plugins guide | Extending capabilities |
| [OLLAMA-INTEGRATION.md](OLLAMA-INTEGRATION.md) | Local models (Kimi, GLM, Qwen) + DeepSeek | Using local AI |
| [OPTIONAL-EXTENSIONS.md](OPTIONAL-EXTENSIONS.md) | Community resources & advanced setups | Want more features |
| [ERROR-CATALOG.md](ERROR-CATALOG.md) | Common errors and solutions | Encountering errors |
| [CODE-SNIPPETS.md](CODE-SNIPPETS.md) | Reusable code patterns | Writing common patterns |

---

## Installed Skills (18)

Located in `skills/` folder. Skills require **explicit invocation** via `Skill("name")` — they do NOT auto-activate. The `delegation-check` hook reminds the agent which skill to invoke per task type.

### Development Workflow
| Skill | Purpose |
|-------|---------|
| [test-driven-development](skills/test-driven-development/SKILL.md) | RED-GREEN-REFACTOR cycle |
| [writing-plans](skills/writing-plans/SKILL.md) | Detailed implementation planning |
| [executing-plans](skills/executing-plans/SKILL.md) | Batch execution with checkpoints |
| [brainstorming](skills/brainstorming/SKILL.md) | Structured design exploration with frameworks |

### Code Quality
| Skill | Purpose |
|-------|---------|
| [solid](skills/solid/SKILL.md) | SOLID principles, clean code, design patterns |
| [requesting-code-review](skills/requesting-code-review/SKILL.md) | Pre-review checklist |
| [receiving-code-review](skills/receiving-code-review/SKILL.md) | Responding to feedback |
| [subagent-driven-development](skills/subagent-driven-development/SKILL.md) | Two-stage review process |
| [finding-duplicate-functions](skills/finding-duplicate-functions/SKILL.md) | Semantic duplication detection |

### Debugging
| Skill | Purpose |
|-------|---------|
| [systematic-debugging](skills/systematic-debugging/SKILL.md) | Four-phase root cause analysis |
| [verification-before-completion](skills/verification-before-completion/SKILL.md) | Validates fixes work |

### Security
| Skill | Purpose |
|-------|---------|
| [security-review](skills/security-review/SKILL.md) | OWASP Top 10, threat modeling, secure coding patterns |

### Git & Collaboration
| Skill | Purpose |
|-------|---------|
| [using-git-worktrees](skills/using-git-worktrees/SKILL.md) | Parallel development branches |
| [finishing-a-development-branch](skills/finishing-a-development-branch/SKILL.md) | Merge/PR decisions |
| [dispatching-parallel-agents](skills/dispatching-parallel-agents/SKILL.md) | Parallel agents, agent teams, swarm orchestration |

### Terminal & Automation
| Skill | Purpose |
|-------|---------|
| [using-tmux-for-interactive-commands](skills/using-tmux-for-interactive-commands/SKILL.md) | Control interactive CLI tools (vim, REPLs, git -i) |

### Meta
| Skill | Purpose |
|-------|---------|
| [using-superpowers](skills/using-superpowers/SKILL.md) | Framework introduction |
| [writing-skills](skills/writing-skills/SKILL.md) | Creating new skills |

---

## Decision Authority Reference

```
AUTONOMOUS (Act without asking):
├── Reading, exploring codebase
├── Running tests and linters
├── Fixing obvious bugs
├── Refactoring within patterns
├── Writing tests
└── Git commits to feature branches

CONFIRM FIRST:
├── Deleting files/code
├── Changing public APIs
├── Database schema changes
└── Architectural changes

ESCALATE (Always ask):
├── Production deployments
├── Credentials/secrets
└── Destructive git operations
```

---

## Key Protocols

### Before Any Task
```
STOP → THINK → PLAN → ACT → VERIFY
```

### Self-Correction
```
Error detected → Stop → Diagnose → Fix → Verify → Resume
```

### Proactive Behaviors
```
Read before edit → Test after change → Check linting → Follow patterns
```

---

## MCP Servers (6 Active)

| Server | Purpose | Key Tools |
|--------|---------|-----------|
| `memory` | Persistent memory | Store/recall across sessions |
| `context7` | Live docs | resolve-library-id, query-docs |
| `sequential-thinking` | Reasoning | Chain-of-thought |
| `ollama` | Local AI | ollama_chat, ollama_generate, ollama_embed |
| `deepseek` | R1 Reasoning | chat_completion (reasoner), multi_turn_chat |
| `github` | Repo ops | PRs, issues, code |

---

## 4-Tier Execution Model

```
OPUS 4.6 = THE BRAIN (You)
├── Complex reasoning & planning
├── Final decisions & quality review
├── Security-critical code
├── User communication
└── Orchestrating all tiers

TIER 1 — Ollama Workers (Free, text-in/text-out):
├── qwen3-coder-next:cloud → Primary coder (cloud, full precision)
├── qwen3-coder-next:latest → Primary coder (local, 80B MoE, 256K ctx)
├── glm-4.7-flash    → Fast boilerplate, CRUD (30B MoE)
├── kimi-k2.5:cloud  → Swarm agent + vision (256K ctx)
├── gemini-3-pro-preview → Long context analyst (1M ctx)
├── devstral-small-2 → Agentic SWE coder (24B, 384K ctx, tools+vision)
├── deepcoder        → Code reasoning (14B, o3-mini level)
└── DeepSeek R1/V3   → Second opinions

TIER 2 — Subagents (Claude, report back only):
└── Task tool with Explore, Plan, general-purpose agents

TIER 3 — Agent Teams (Experimental, inter-agent messaging):
└── Multiple Claude instances with shared tasks + messaging
    Enable: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

TIER 4 — Manual Parallel (Git worktrees, human-managed)
```

---

## Quality Hooks (22 Active)

| Category | Hooks |
|----------|-------|
| Git Safety | block-dangerous-git, validate-commit |
| Security | check-secrets, security-check |
| URL Validation | validate-github-url, verify-before-explore |
| Code Quality | test-reminder, check-file-size, prevent-common-mistakes |
| Error Recovery | handle-fetch-error, handle-tool-failure |
| Parallel Safety | safe-parallel-bash |
| Delegation | delegation-check, delegation-reminder-write, delegation-reminder-edit, serena-write-guard, delegation-token |
| Session | session-start, check-ollama-models |
| Completion | stop-skill-check |
| Agent Teams | teammate-idle, task-completed |

---

## File Locations in Target Project

```
your-project/
├── CLAUDE.md                  ← Agent brain (root)
├── .claude/
│   ├── CRITICAL-THINKING.md
│   ├── SKILLS-MCP-GUIDE.md
│   ├── QUALITY-HOOKS.md
│   ├── MCP-AND-PLUGINS.md     ← MCP servers & plugins
│   ├── ERROR-CATALOG.md
│   ├── CODE-SNIPPETS.md
│   ├── SKILLS-CATALOG.md
│   ├── hooks/                 ← Quality hooks (22 scripts)
│   └── skills/                ← All 18 skills
└── .mcp.json                  ← MCP server config (use .mcp.json.template)
```

---

*Part of the Agent Enhancement Kit for autonomous world-class coding agents.*
