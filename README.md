# Claude Code Agent Kit

> Transform Claude Code into an autonomous world-class coding agent.

An open-source configuration kit that turns [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into an expert-level autonomous software engineer. Drop these files into any project to get 18 engineering skills, 22 quality hooks, multi-model delegation, and professional development workflows — out of the box.

---

## Quick Start

```bash
# 1. Clone the kit
git clone https://github.com/anthropics/claude-code-agent-kit.git

# 2. Install into your project
cd claude-code-agent-kit
./setup.sh /path/to/your-project

# 3. Start Claude Code in your project
cd /path/to/your-project
claude
```

That's it. The agent reads `CLAUDE.md` automatically and operates with enhanced protocols.

> **First session?** Copy the initialization prompt from [INIT-PROMPT.md](INIT-PROMPT.md) for optimal startup.

---

## What's Included

| Component | Count | Description |
|-----------|-------|-------------|
| **Skills** | 18 | Professional engineering workflows (TDD, debugging, SOLID, security, etc.) |
| **Hooks** | 22 | Automated quality checks (git safety, secrets, security, delegation) |
| **Guides** | 15+ | Architecture, MCP config, Ollama integration, critical thinking |
| **MCP Configs** | 2 | Core `.mcp.json` + `.mcp.json.template` for extended services |
| **Setup** | 2 | Automated `setup.sh` + environment `setup-env.sh` |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              CLAUDE OPUS (THE BRAIN)                │
│                                                     │
│   Planning · Architecture · Security · Decisions    │
│   User communication · Quality review               │
└────────────────────┬────────────────────────────────┘
                     │ delegates
         ┌───────────┼───────────┐
         ▼           ▼           ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │  OLLAMA  │ │ DEEPSEEK │ │   MCP    │
   │ Workers  │ │ Advisor  │ │ Services │
   └──────────┘ └──────────┘ └──────────┘
   Code gen      2nd opinion   Context7
   Reviews       Edge cases    GitHub
   Boilerplate   Complex logic Serena
```

**Opus decides, workers execute. Opus always reviews.**

The agent automatically delegates code generation (>10 lines) to local Ollama models, saving context tokens and cost. Quality hooks enforce this delegation pattern.

---

## Skills System

Skills require **explicit invocation** via `Skill("name")` — they never auto-activate. The `delegation-check` hook reminds which skill to invoke per task type.

### Key Skills

| Skill | Invocation | Use When |
|-------|------------|----------|
| Test-Driven Development | `Skill("test-driven-development")` | Implementing features or fixing bugs |
| Systematic Debugging | `Skill("systematic-debugging")` | Any error, test failure, or unexpected behavior |
| SOLID Principles | `Skill("solid")` | Writing or reviewing code quality |
| Security Review | `Skill("security-review")` | Handling user input, auth, APIs, sensitive data |
| Writing Plans | `Skill("writing-plans")` | Complex multi-step tasks |
| Executing Plans | `Skill("executing-plans")` | Following through on implementation plans |
| Brainstorming | `Skill("brainstorming")` | Starting new features or exploring requirements |
| Parallel Agents | `Skill("dispatching-parallel-agents")` | Multi-file tasks, agent team coordination |
| Verification | `Skill("verification-before-completion")` | Before declaring any work complete |

[See all 18 skills →](INDEX.md#installed-skills-18)

---

## Quality Hooks

22 automated hooks that run on every tool use — no manual intervention needed.

| Category | Hooks | What They Do |
|----------|-------|-------------|
| **Git Safety** | block-dangerous-git, validate-commit | Block force push, reset --hard; enforce conventional commits |
| **Security** | check-secrets, security-check | Detect API keys in code; catch SQL/command injection |
| **Delegation** | delegation-check, delegation-reminder-write/edit, delegation-token | Enforce code gen delegation to Ollama workers |
| **Code Quality** | test-reminder, check-file-size, prevent-common-mistakes | Remind to test; warn on large files |
| **Error Recovery** | handle-fetch-error, handle-tool-failure, safe-parallel-bash | Guidance on failures; prevent sibling cancellation |
| **Session** | session-start, check-ollama-models, stop-skill-check | Initialize with best practices; verify models; completion checklist |
| **URL Safety** | validate-github-url, verify-before-explore | Prevent 404s from wrong GitHub paths |
| **Agent Teams** | teammate-idle, task-completed | Check for unclaimed tasks; block on merge conflicts |

[Full hook documentation →](QUALITY-HOOKS.md)

---

## Multi-Model Architecture

The kit uses a **4-tier execution model** to optimize cost and capabilities:

| Tier | Engine | Cost | Best For |
|------|--------|------|----------|
| **1. Ollama Workers** | Local/cloud models | Free | Code generation, reviews, boilerplate |
| **2. Subagents** | Claude (Task tool) | API tokens | Codebase exploration, multi-tool workflows |
| **3. Agent Teams** | Multiple Claude instances | API tokens (high) | Complex collaborative work, competing hypotheses |
| **4. Manual Parallel** | Git worktrees | Human time | Long-running feature branches |

### Worker Models (via Ollama)

| Model | Role | When to Use |
|-------|------|------------|
| `qwen3-coder-next` | **Primary Coder** | Complex code generation, agentic workflows |
| `glm-4.7-flash` | **Fast Coder** | Boilerplate, CRUD, quick tasks |
| `kimi-k2.5:cloud` | **Swarm Agent + Vision** | Multi-step tasks, screenshot analysis |
| `devstral-small-2` | **Agentic SWE** | Multi-file editing with tool calling |
| `deepcoder` | **Code Reasoning** | Algorithmic problems (o3-mini level) |
| DeepSeek R1 | **Reasoning Advisor** | Second opinions on complex logic |

### Cloud-First Selection

When `OLLAMA_API_KEY` is set, the system automatically tries cloud model variants first, falling back to local models:

```
Cloud model → Local model → Fallback model
```

[Full Ollama integration guide →](OLLAMA-INTEGRATION.md)

---

## MCP Servers

The kit uses **on-demand MCP loading** to keep context lean (~25K base tokens vs ~80K+ with everything enabled).

### Core (Always-On)

| Server | Purpose |
|--------|---------|
| `context7` | Live documentation lookup for any library |
| `memory` | Persistent memory across sessions |
| `sequential-thinking` | Chain-of-thought reasoning |

### Optional (Enable Per-Project)

| Server | Purpose | Setup |
|--------|---------|-------|
| `ollama` | Local model delegation | [Install Ollama](https://ollama.ai) |
| `deepseek` | R1 reasoning advisor | [Get API key](https://platform.deepseek.com) |
| `github` | PR/issue operations | [Get token](https://github.com/settings/tokens) |
| `serena` | Semantic code analysis | Via MCP config |

Enable additional MCPs via `.claude/settings.local.json`. See [MCP-CATALOG.md](MCP-CATALOG.md) for the full list including Notion, Sentry, Figma, Stripe, and more.

---

## Configuration

### Customize for Your Project

Edit the **Project-Specific Section** at the bottom of `CLAUDE.md`:

```markdown
## Project-Specific Section

### Naming Conventions
- Components: PascalCase (UserProfile.tsx)
- Utilities: camelCase (formatDate.ts)

### API Conventions
- RESTful under /api
- Return { data, error } format

### Testing Requirements
- Unit tests for all business logic
- E2E tests for critical user flows
```

### Add Custom Hooks

1. Create a script in `.claude/hooks/`
2. Register it in `.claude/settings.local.json`
3. See [QUALITY-HOOKS.md](QUALITY-HOOKS.md) for the hook format

### Add Custom Skills

1. Create `skills/my-skill/SKILL.md`
2. Add to [INDEX.md](INDEX.md) and [SKILLS-CATALOG.md](SKILLS-CATALOG.md)

---

## Prerequisites

| Requirement | Required | Notes |
|-------------|----------|-------|
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | Yes | Anthropic's CLI tool |
| Bash | Yes | For hooks and setup script |
| [jq](https://jqlang.github.io/jq/) | Yes | JSON processing in hooks |
| [Ollama](https://ollama.ai) | Optional | Local AI worker models |
| [DeepSeek API key](https://platform.deepseek.com) | Optional | R1 reasoning advisor |
| [GitHub token](https://github.com/settings/tokens) | Optional | For GitHub MCP operations |

---

## Manual Installation

If you prefer not to use `setup.sh`:

```bash
# Copy CLAUDE.md to your project root
cp CLAUDE.md /path/to/your-project/

# Copy everything else to .claude/
mkdir -p /path/to/your-project/.claude
cp -r hooks/ skills/ /path/to/your-project/.claude/
cp settings.local.json /path/to/your-project/.claude/
cp *.md /path/to/your-project/.claude/    # Reference docs

# Copy MCP config template
cp .mcp.json.template /path/to/your-project/.mcp.json

# Make hooks executable
chmod +x /path/to/your-project/.claude/hooks/*.sh

# Set up environment variables
source setup-env.sh  # Edit values first!
```

---

## Installed File Structure

After running `setup.sh`, your project will have:

```
your-project/
├── CLAUDE.md                          # Agent brain (project root)
├── .mcp.json                          # MCP server config (from template)
└── .claude/
    ├── hooks/                         # 22 quality check scripts
    │   ├── block-dangerous-git.sh
    │   ├── check-secrets.sh
    │   ├── delegation-check.sh
    │   ├── test-reminder.sh
    │   └── ... (18 more)
    ├── skills/                        # 18 engineering skills
    │   ├── test-driven-development/
    │   │   └── SKILL.md
    │   ├── systematic-debugging/
    │   │   ├── SKILL.md
    │   │   ├── root-cause-tracing.md
    │   │   └── defense-in-depth.md
    │   ├── solid/
    │   │   ├── SKILL.md
    │   │   └── references/            # SOLID, design patterns, etc.
    │   ├── security-review/
    │   │   ├── SKILL.md
    │   │   └── references/            # OWASP, threat modeling
    │   └── ... (14 more)
    ├── settings.local.json            # Hook registration config
    ├── QUALITY-HOOKS.md
    ├── OLLAMA-INTEGRATION.md
    ├── SKILLS-MCP-GUIDE.md
    ├── INDEX.md                       # Navigation index
    └── ... (10+ more guides)
```

---

## Testing

After installation, verify everything works:

1. **Quick test**: Start Claude Code and ask it to read `CLAUDE.md`
2. **Full test**: Copy the prompt from [TEST-CAPABILITIES.md](TEST-CAPABILITIES.md) to verify all MCP connections, worker delegation, hooks, and skills

---

## Autonomous Operation

The agent operates with clear decision authority:

| Level | Actions | Examples |
|-------|---------|---------|
| **Autonomous** | Acts without asking | Read files, run tests, fix obvious bugs, commit to feature branches |
| **Confirm First** | Asks before acting | Delete files, change APIs, modify schemas, architectural changes |
| **Escalate** | Always asks human | Production deploys, credentials, destructive git operations |

---

## Documentation Index

| Document | Purpose |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Agent identity, protocols, decision authority |
| [INDEX.md](INDEX.md) | Quick navigation for all files |
| [INIT-PROMPT.md](INIT-PROMPT.md) | Copy-paste initialization prompts |
| [QUALITY-HOOKS.md](QUALITY-HOOKS.md) | Hook documentation and format |
| [OLLAMA-INTEGRATION.md](OLLAMA-INTEGRATION.md) | Multi-model setup and delegation |
| [SKILLS-MCP-GUIDE.md](SKILLS-MCP-GUIDE.md) | Skills and MCP usage guide |
| [MCP-CATALOG.md](MCP-CATALOG.md) | On-demand MCP service catalog |
| [CRITICAL-THINKING.md](CRITICAL-THINKING.md) | Analysis and debugging frameworks |
| [TEST-CAPABILITIES.md](TEST-CAPABILITIES.md) | Full capability verification test |

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Reporting issues
- Submitting pull requests
- Adding new hooks and skills
- Coding standards

---

## License

[MIT](LICENSE) — use it, modify it, share it.

---

## Acknowledgments

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic
- [Context7](https://context7.com/) for live documentation lookup
- [Ollama](https://ollama.ai) for local model inference
- [DeepSeek](https://deepseek.com) for reasoning models
- Inspired by the Claude Code community and [awesome-claude-code](https://github.com/anthropics/awesome-claude-code)
