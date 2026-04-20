# Skill Routing — Auto-Load Skills by Intent

## Mandatory: Load Skills Before Acting

When the task matches a skill domain, load the skill FIRST — before any edits or code generation. Do not bypass capability-gate hooks by getting delegation tokens without loading the proper skill.

## Intent → Skill Routing Table

| Intent Signal | Skill to Load | Notes |
|--------------|---------------|-------|
| "build a feature", "implement", "add functionality" | `Skill("writing-plans")` then `Skill("test-driven-development")` | Plan first, TDD second |
| "refactor", "clean up", "improve code quality" | `Skill("code-refactoring")` | Follow with solid if complex |
| "debug", "fix bug", "error", "failing", "broken" | `Skill("systematic-debugging")` | Use hypothesis agents for hard bugs |
| "review", "check this", "audit" | `Skill("pre-landing-review")` | Dispatches review agents |
| "security", "auth", "permissions", "OWASP" | `Skill("security-review")` | Brain handles directly — never delegate auth |
| "pentest", "harden", "RLS", "ZAP", "SNYK", "attack sim" | `/security-harden` | 5-layer pipeline: RLS → Code Scan → ZAP → Infra → Attack Sim |
| "architecture", "design system", "schema", "database" | `Skill("system-architecture")` | Use thinktank for big decisions |
| "deploy", "ship", "release", "merge to main" | `Skill("ship")` | Full release workflow |
| "plan", "break down", "strategy" | `Skill("writing-plans")` or `/paul:plan` | PAUL for structured loop, writing-plans for task breakdown |
| "new project", "incubate", "ideate" | `/seed` then `Skill("writing-plans")` | SEED for typed ideation, then detailed planning |
| "test", "coverage", "TDD" | `Skill("test-driven-development")` | Always test-first |
| "frontend", "UI", "component", "page" | `Skill("frontend-engineering")` or `Skill("frontend-design-pro")` | Engineering for functional, design-pro for visual |
| "backend", "API", "endpoint", "server" | `Skill("backend-design")` | Follow with backend-endpoint for implementation |
| "CI/CD", "pipeline", "workflow", "deploy" | `Skill("cicd-generator")` | Generate + verify |
| "performance", "optimize", "speed", "bundle" | `Skill("autodev")` | Autonomous optimization loop |
| "i18n", "translate", "localize" | `Skill("i18n")` | Multi-language support |
| "accessibility", "a11y", "WCAG" | `Skill("accessibility-audit")` | WCAG 2.1 compliance |
| "decision", "trade-off", "should we" | `Skill("thinktank")` | Multi-model consultation |
| "overnight", "batch", "autonomous" | `Skill("overnight-dev")` | Unattended TDD loop |
| "scaffold", "new project", "bootstrap" | `Skill("project-scaffolder")` | Best-practice structure |
| "MCP server", "tool integration" | `Skill("mcp-builder")` | Build custom MCP servers |
| "video", "animation", "Remotion" | `Skill("remotion-video")` | Programmatic video creation |
| "document", "report", "DOCX", "PDF" | `Skill("doc-generation")` | Office document generation |
| "design system", "color palette", "visual style", "look and feel" | `Skill("design-systems")` | 54 real-world design systems, chains to frontend-design-pro |
| "browse", "scrape", "web page", "open URL", "fill form", "screenshot page" | `Skill("browser-control")` | PinchTab MCP — enable with `+pinchtab` |

## MCP Server Restore (required before using MCP tools)

On-demand MCP servers are **removed** from `~/.claude.json` to save context tokens. Before using any MCP tool, restore the server first:

| Task Domain | Restore Command | Servers Added |
|-------------|----------------|---------------|
| Frontend design | `bash .claude/scripts/mcp-profile.sh design` | gemini, stitch, 21st-dev-magic, animate-ui, reactbits |
| Web browsing | `bash .claude/scripts/mcp-profile.sh +pinchtab` | pinchtab |
| Browser automation | `bash .claude/scripts/mcp-profile.sh +browser-use` | browser-use |
| IDE LSP/debugging | `bash .claude/scripts/mcp-profile.sh +claude-ide-bridge` | claude-ide-bridge |
| Free workers | `bash .claude/scripts/mcp-profile.sh +free-models` | free-models |
| Code review/audit | `bash .claude/scripts/mcp-profile.sh +code-review-graph` | code-review-graph (22 tools, blast-radius) |
| All servers | `bash .claude/scripts/mcp-profile.sh full` | all 15 servers |

After restoring, run `/mcp` to reconnect. Servers are backed up in `~/.claude-mcp-ondemand-backup.json`.

## Frontend Pipeline (non-negotiable)

0. **Restore design servers**: `bash .claude/scripts/mcp-profile.sh design` then `/mcp`
1. (Optional) `Skill("design-systems")` → choose visual style from 54 companies
2. Stitch MCP `generate_screen_from_text` → download HTML reference
3. Load `Skill("frontend-design-pro")`
4. React Bits MCP (`+reactbits`) for animated components
5. Delegate code generation to `ollama_chat` workers (glm-5.1:cloud)
6. Brain reviews worker output, integrates, runs tests

Never write >50 lines of frontend code directly without a delegation token. Never bypass capability-gate by grabbing a quick worker token — load the skill instead.

## Workflow Auto-Start

| Task Pattern | Workflow |
|-------------|----------|
| End-to-end feature development | `ship-feature`: plans → TDD → review → verify → ship |
| Visual redesign or UI overhaul | `frontend-redesign`: design tokens → components → test → polish |
| Security audit or hardening | `security-hardening`: threat model → audit → remediate → verify |
| API development | `api-development`: design → implement → test → document |
| Code refactoring | `refactor-safely`: plan → refactor → audit → verify |
| New project setup | `new-project-setup`: scaffold → config → CI → verify |

When a skill completes and has `chain_after` in skills.yml, automatically load the next skill. For architectural decisions, invoke `Skill("thinktank")` for multi-model opinions before committing.
