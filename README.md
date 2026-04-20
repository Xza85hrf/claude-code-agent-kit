# Claude Code Agent Kit

> Turn Claude Code into a senior autonomous coding agent. One command to install.

An opinionated configuration kit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drops 58 skills, ~30 quality hooks, 20 specialist subagents, 5 team presets, and a graduated delegation model into any project — so the agent can plan, delegate bulk code gen to cheaper workers, review the result, and ship.

---

## Quick Start

```bash
git clone https://github.com/Xza85hrf/claude-code-agent-kit.git
cd claude-code-agent-kit
./install.sh /path/to/your-project
cd /path/to/your-project
claude
```

That's it. Run `./install.sh --help` to see flags (`--profile minimal|standard`, `--force`).

> Already have a `.claude/` directory in your target? The installer moves it to `.claude.backup.<timestamp>/` first. Re-runnable and safe.

---

## What Ships

| Component | Count | Purpose |
|-----------|-------|---------|
| Skills | **58** | TDD, debugging, SOLID, security review, planning, frontend/backend, CI/CD, accessibility, shipping, and more |
| Hooks | **~30** | Git safety, secrets scanning, delegation enforcement, test reminders, blast-radius checks, skill gates |
| Agents | **20** | Reviewers, auditors, debug hypothesis agents, feature-team roles, coordinator |
| Commands | **12** | `/ship`, `/audit`, `/autodev`, `/retro`, `/preflight`, `/merge-dependabot`, and more |
| Team presets | **5** | `audit`, `debug`, `feature`, `review`, `swarm` |
| Rules | auto-loaded | Safety, delegation, git, quality, tool-usage, skill-routing, language-specific (TS/Python) |
| Profiles | **2** | `minimal` (safety only) and `standard` (full workflow) |
| Output styles | **4** | `dev`, `research`, `review`, `learning` |

---

## Architecture

```
            ┌──────────────────────────┐
            │    Claude Code (brain)   │
            │                          │
            │  plan · decide · review  │
            │        integrate         │
            └────────────┬─────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │  Ollama  │   │ Subagents│   │  Teams   │
    │  Cloud / │   │  (Haiku/ │   │  2-4     │
    │  local   │   │  Sonnet) │   │ teammates│
    └──────────┘   └──────────┘   └──────────┘
    Code gen       Exploration    Parallel +
    Boilerplate    Research       competing
    Reviews        Multi-step     hypotheses
```

**Graduated delegation.** Above a line threshold the kit nudges you to delegate; past a block threshold it stops you from writing long files by hand unless a worker has been used recently. Tune thresholds or switch to pure advisory mode — see `AGENTS.md`.

**Brain keeps:** planning, security & auth logic, integration, user communication, anything needing Claude Code's tools.

---

## Skills: Explicit Invocation

Skills **never auto-activate**. Invoke: `Skill("test-driven-development")`. The `proactive-skill-trigger` hook suggests matching skills based on what you just edited.

High-traffic skills:

| Skill | Use When |
|-------|----------|
| `test-driven-development` | Any new feature or bug fix |
| `systematic-debugging` | Errors, failing tests, unexpected behavior |
| `security-review` | Touching auth, user input, external APIs |
| `writing-plans` | Non-trivial multi-step work |
| `ship` | Full release workflow — tests, review, changelog, PR |
| `thinktank` | Architectural trade-offs — 3–4 models give independent opinions |
| `pre-landing-review` | Before merging anything significant |
| `frontend-design-pro` / `frontend-engineering` | UI work (design vs. functional) |
| `backend-design` / `backend-endpoint` | API and service work |
| `brainstorming` | Early-stage feature ideation |

[Full skill list →](.claude/skills/skill-table.md)

---

## Hooks: 10 Events, ~30 Hooks

The `standard` profile wires safety, delegation, and workflow enforcement into Claude Code's hook points.

| Category | Representative hooks | What they do |
|----------|---------------------|-------------|
| Git safety | `block-dangerous-git`, `validate-commit`, `blast-radius-check`, `review-gate`, `build-before-push` | Block force-push/reset-hard, enforce Conventional Commits, preview PR review before pushing |
| Secrets / security | `check-secrets`, `security-check`, `damage-control` | Block API keys hitting disk, catch injection patterns, protect critical paths |
| Delegation | `delegation-check`, `delegation-reminder`, `delegation-token`, `capability-gate`, `skill-gate` | Enforce worker delegation when file size warrants it; require matching skill loaded for domain writes |
| Quality | `test-reminder`, `prevent-common-mistakes`, `handle-tool-failure` | Nudge tests after edits, catch common mistakes, explain errors |
| Session | `session-start`, `session-end`, `stop-skill-check`, `proactive-skill-trigger` | Capture state, suggest skills after edits |

Switch profile later: `bash .claude/scripts/apply-profile.sh minimal` (or `standard`).

---

## Worker Models

Free tier via [Ollama Cloud](https://ollama.com) — fixed $0/$20/$100 monthly pricing, no per-token charges. Optional: OpenAI, DeepSeek, Gemini via API keys.

| Role | Primary | Why |
|------|---------|-----|
| #1 coder | `glm-5.1:cloud` | Best overall SWE-Bench |
| #2 coder / review | `minimax-m2.7:cloud` | Second opinion, matches frontier SWE |
| Deep reasoning | `deepseek-v3.2:cloud` | Hybrid thinking mode |
| Fast / boilerplate | `qwen3-coder-next:cloud` | Ultra-efficient 3B-active MoE |
| Vision + code | `gemma4:31b-cloud` | Multimodal understanding |

Models are wired via CLI wrapper `bash .claude/scripts/mcp-cli.sh ollama chat "<model>" "<prompt>"` — no MCP server required, zero context cost.

Set `OLLAMA_API_KEY` in `~/.claude-secrets` (the installer creates a template if missing) to enable cloud models.

---

## Agent Teams

3+ specialists working in parallel with assigned file ownership. Useful for cross-layer features or audits.

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude
# Then: "Spawn the audit team on src/auth/"
```

Presets: `audit` (4 specialists), `debug` (3 hypothesis agents), `feature` (lead + 2 implementers + coordinator), `review` (3 reviewers), `swarm` (coordinator + workers). See `.claude/team-presets/`.

---

## Prerequisites

| Required | Optional |
|----------|----------|
| `bash` | `claude` CLI ([install](https://docs.anthropic.com/en/docs/claude-code)) |
| `git` | `OLLAMA_API_KEY` for cloud workers |
| `jq` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `DEEPSEEK_API_KEY` |

Platforms: macOS, Linux, WSL2. Windows native bash (Git Bash / MSYS) should work but is not primary-tested.

---

## Customize

**Project conventions.** Edit the bottom of `CLAUDE.md` (Project-Specific Section). Example: naming, API conventions, test requirements.

**Profile.** `bash .claude/scripts/apply-profile.sh minimal` to drop delegation/skill-gate enforcement.

**Add a skill.** Create `.claude/skills/<category>/my-skill/SKILL.md`, then append to `.claude/skills/skill-table.md`. See `writing-skills` skill for the full process.

**Add a hook.** Drop a script in `.claude/hooks/`, register it in a profile JSON, re-run `apply-profile.sh`.

**Add a rule.** `.claude/rules/my-rule.md` — rules auto-load at session start.

---

## Project Structure After Install

```
your-project/
├── CLAUDE.md                       # Agent identity + project conventions
├── AGENTS.md                       # Multi-model agent spec
└── .claude/
    ├── settings.local.json         # Generated from profile
    ├── hooks/                      # ~30 quality hooks
    ├── skills/                     # 58 skills, organized by category
    ├── agents/                     # 20 subagent definitions
    ├── commands/                   # 12 slash commands
    ├── team-presets/               # 5 agent team compositions
    ├── output-styles/              # 4 output style profiles
    ├── profiles/                   # minimal / standard
    ├── rules/                      # Auto-loaded behavior rules
    ├── lib/                        # Shared Bash libraries
    ├── scripts/                    # Delegation, audit, profile tools
    └── config/                     # Tool policies, damage-control patterns
```

---

## Design Choices

- **Replace, don't deprecate.** When a new implementation supersedes old, the old code is removed. No backward-compatible shims.
- **Brain keeps auth, crypto, and final review.** Workers never see auth logic.
- **Delegation is graduated, not absolute.** Small edits bypass; large files require a worker. Tunable via env vars.
- **Skills never auto-activate.** Explicit `Skill(...)` invocation keeps the conversation predictable.
- **Hooks prefer to warn, not block.** Only safety-critical patterns block outright. Everything else is advisory with an escalation path.

---

## Contributing

Bug reports, new skills, and hook contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

[MIT](LICENSE) — use it, fork it, ship it.

---

## Acknowledgments

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic
- [Ollama](https://ollama.ai) for local + cloud model inference
- Design inspiration from the Claude Code community
