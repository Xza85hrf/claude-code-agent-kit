# External Skills Catalog

> On-demand external skills from the Claude Code community. Install only what you need per-project.

---

## How External Skills Work

External skills are community-built Claude Code skills that extend the agent's capabilities beyond the 18 built-in skills. They follow the same `Skill("name")` invocation pattern.

### Installation

```bash
# Install from GitHub
claude plugins add <github-url>

# Install from SkillsMP marketplace
# Visit https://skillsmp.com/ for browsable catalog
```

### Hot-Loading Principle

**Only install skills you need for the current project.** Each skill adds to context token usage. The Agent Enhancement Kit keeps base context at ~25K tokens — adding unnecessary skills inflates this.

---

## Recommended External Skills

### Security & Code Safety

| Skill | Source | Purpose | Install |
|-------|--------|---------|---------|
| **differential-review** | Trail of Bits | Security-focused diff review with adaptive depth based on codebase size. Uses "Rationalizations to Reject" pattern. | [trail-of-bits/are-we-secure-yet](https://github.com/anthropics/skills/tree/main/.claude/skills) |
| **insecure-defaults** | Trail of Bits | Catches insecure configuration defaults (weak crypto, permissive CORS, disabled TLS verify). | [trail-of-bits/are-we-secure-yet](https://github.com/anthropics/skills/tree/main/.claude/skills) |

**Why these matter:** Trail of Bits brings professional security auditor patterns — adaptive depth (scales review thoroughness to codebase size) and "Rationalizations to Reject" tables (pre-lists common excuses for skipping security checks).

### Testing & Quality

| Skill | Source | Purpose | Install |
|-------|--------|---------|---------|
| **property-based-testing** | Community | Generates property-based tests using Hypothesis (Python) or fast-check (JS). Finds edge cases unit tests miss. | Search [SkillsMP](https://skillsmp.com/) |
| **static-analysis** | Community | Runs and interprets static analysis tools (ESLint, Pylint, mypy, Clippy) with actionable fix suggestions. | Search [SkillsMP](https://skillsmp.com/) |

### Development Workflow

| Skill | Source | Purpose | Install |
|-------|--------|---------|---------|
| **mcp-builder** | Anthropic | Builds new MCP servers from scratch using Context7 for up-to-date MCP SDK docs. | [anthropics/skills](https://github.com/anthropics/skills) |
| **webapp-testing** | Community | End-to-end web app testing with Playwright. Requires `playwright@claude-plugins-official` plugin. | Search [SkillsMP](https://skillsmp.com/) |

### Language-Specific

| Skill | Source | Purpose | Install |
|-------|--------|---------|---------|
| **modern-python** | Community | Enforces modern Python patterns (3.10+): match statements, dataclasses, type hints, pathlib. | Search [SkillsMP](https://skillsmp.com/) |

---

## Patterns Worth Adopting

These patterns from community skills can be applied in your own skill development:

### 1. Rationalizations to Reject (Trail of Bits)

Pre-list common excuses the agent might use to skip important checks:

```markdown
## Rationalizations to Reject
- "This is just a test file" — Test files often become templates
- "This is internal only" — Internal services get exposed
- "We'll fix this later" — Security debt compounds
- "The framework handles this" — Verify, don't assume
```

### 2. Adaptive Depth by Codebase Size

Scale thoroughness based on project size:

```markdown
## Depth Scaling
- <1K lines: Full line-by-line review
- 1K-10K lines: Focus on public APIs and data flow
- 10K-100K lines: Focus on changes + critical paths
- 100K+ lines: Changes only + architecture review
```

### 3. Allowed-Tools Frontmatter

Restrict which tools a skill can use in its frontmatter:

```yaml
---
allowed-tools:
  - Read
  - Grep
  - Glob
  - WebSearch
---
```

This prevents skills from accidentally modifying files when they should only analyze.

---

## Skill Discovery

### Where to Find Skills

1. **[SkillsMP](https://skillsmp.com/)** — Community marketplace with searchable catalog
2. **[anthropics/skills](https://github.com/anthropics/skills)** — Official Anthropic skills
3. **[awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)** — Curated list
4. **[awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills)** — Community collection
5. **GitHub search**: `claude skill SKILL.md` or `claude-code skill`

### Evaluating Skills Before Installing

```
Before installing any external skill, check:
1. Does it duplicate a built-in skill? → Use built-in instead
2. How many tokens does it add? → Larger skills = more context cost
3. Is it actively maintained? → Check last commit date
4. Does it use allowed-tools? → Prefer skills with restricted tool access
5. Is the source reputable? → Prefer known authors/orgs
```

---

## Creating Custom Skills

Use the built-in `writing-skills` skill to create project-specific skills:

```
Skill("writing-skills")
```

See `.claude/skills/writing-skills/SKILL.md` for the complete skill authoring guide.

---

*Part of the Agent Enhancement Kit. See [INDEX.md](INDEX.md) for navigation.*
