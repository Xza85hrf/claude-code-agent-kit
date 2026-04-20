# Skills

Skills are modular instruction bundles that Claude loads on demand. This kit ships 58 of them, organized into 7 categories.

## Invocation

Skills **never auto-activate**. Invoke explicitly:

```
Skill("test-driven-development")
Skill("security-review")
Skill("ship")
```

The `proactive-skill-trigger` hook (standard profile) suggests matching skills based on files you've recently edited — but it's a suggestion, not an activation.

## Categories

| Category | Count | Example skills |
|----------|:---:|----------------|
| `architecture/` | 11 | `writing-plans`, `thinktank`, `plan-ceo-review`, `multi-model-orchestration` |
| `engineering/` | 19 | `test-driven-development`, `systematic-debugging`, `solid`, `frontend-design-pro`, `backend-design`, `mcp-builder` |
| `quality/` | 10 | `security-review`, `pre-landing-review`, `qa`, `ship`, `accessibility-audit` |
| `workflow/` | 10 | `preflight`, `using-git-worktrees`, `ship`, `cicd-generator`, `learn` |
| `meta/` | 6 | `writing-skills`, `prompt-engineering`, `claude-md-improver`, `automation-recommender` |
| `integration/` | 1 | `browser-control` |
| `optimization/` | 1 | `autodev` |

Full list: [`.claude/skills/skill-table.md`](../.claude/skills/skill-table.md).

## Anatomy of a Skill

```
.claude/skills/<category>/<skill-name>/
├── SKILL.md              # required — the skill itself
└── references/           # optional — supporting docs the skill points to
    ├── pattern-A.md
    └── pattern-B.md
```

`SKILL.md` frontmatter (YAML):

```yaml
---
name: my-skill
description: One-line summary for skill routing. First 150 chars matter most.
argument-hint: "<optional autocomplete hint>"
allowed-tools: "Read, Write, Edit, Bash, Grep"  # optional — restrict tools
model: sonnet                                    # optional — pin model
---
```

Body is standard markdown. No length limit, but shorter is better — skills get loaded into context when invoked.

## Writing a New Skill

1. Pick a category directory.
2. `mkdir .claude/skills/<category>/<my-skill>/`
3. Create `SKILL.md` with frontmatter + body. Required sections:
   - **Overview** — what this skill does
   - **When to Use** — triggering signals
   - **The Process** — steps/phases with explicit actions
   - **References** (optional) — link to `references/*.md` files
4. Append the skill to [`.claude/skills/skill-table.md`](../.claude/skills/skill-table.md):
   ```
   | `my-skill` | One-line description. |
   ```
5. Reload plugins in Claude Code: `/reload-plugins`.
6. Test: `Skill("my-skill")`.

See the `writing-skills` skill itself for the full authoring guide.

## Skill Gate (standard profile)

Certain file patterns require a matching skill be loaded first:

| File pattern | Required skill |
|-------------|---------------|
| Pages, layouts, heroes, `.css` | `frontend-design-pro` |
| Components, forms, data tables | `frontend-engineering` |
| API routes, handlers, services | `backend-design` |
| `auth/**`, `crypto/**` | `security-review` |

Exceptions: files ≤10 lines, test files, type definitions, and kit internals bypass. To disable: set `SKILL_GATE=advisory` in settings.

## Chaining Skills

Some skills chain naturally:

| Start with | Then |
|-----------|------|
| `brainstorming` | → `writing-plans` |
| `writing-plans` | → `test-driven-development` or `executing-plans` |
| `preflight` | → `writing-plans` |
| `pre-landing-review` | → `ship` |
| Any code edit | → `security-review` (for sensitive files) |

Claude will usually chain for you when the first skill's output names the next one.

## Skill vs. Rule vs. Command

| Mechanism | When to use |
|-----------|-------------|
| **Skill** | Complex process the user opts into — has steps, decisions, references |
| **Rule** (`.claude/rules/`) | Always-on behavior the agent should follow without being asked |
| **Command** (`.claude/commands/`) | Shortcut the user types: `/ship`, `/audit`, `/retro` |

Rule of thumb: if the user should ask for it, it's a skill. If it's always true, it's a rule. If it's a one-shot action, it's a command.

## Explicit Non-Goals

- Skills don't auto-activate. The `proactive-skill-trigger` hook suggests; it doesn't inject.
- Skills aren't context padding. If you can express it in a rule, prefer that — rules cost 0 extra tokens on invocation.
- Skills aren't micro — aim for processes that genuinely need guidance across multiple steps.

## Reference

- `.claude/skills/skill-table.md` — all 58 skills in one table
- The `writing-skills` skill — authoring guide with evaluation loop
- The `using-superpowers` skill — discovery + invocation patterns
