# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `docs/` directory with reference guides: `INSTALLATION.md`, `HOOKS.md`, `DELEGATION.md`, `SKILLS.md`, `AGENT-TEAMS.md`
- `.github/` scaffolding: issue templates (bug, feature), PR template, `CODE_OF_CONDUCT.md`, `SECURITY.md`
- `.github/workflows/validate.yml` CI — runs installer, JSON validation, shell syntax check, leak scan, and README link check on Ubuntu + macOS
- `CHANGELOG.md` (this file)

## [0.2.0] — 2026-04-20

A full refactor. Ports the evolved private kit to the public repo and replaces the original single-commit release.

### Added
- `install.sh` — one-command installer with platform detection (macOS/Linux/WSL), idempotent re-run, backup-on-overwrite, `--profile` and `--force` flags
- `.claude/scripts/apply-profile.sh` — profile switcher (minimal/standard) that preserves `permissions` when regenerating `settings.local.json`
- 58 skills across 7 categories (architecture, engineering, quality, workflow, meta, integration, optimization)
- ~30 quality hooks across 10 events (session, tool-use, permissions, failure handling)
- 20 specialist subagents (reviewers, auditors, debug hypotheses, feature-team roles, coordinator)
- 12 slash commands (`/ship`, `/audit`, `/autodev`, `/retro`, `/preflight`, `/merge-dependabot`, etc.)
- 5 agent-team presets (`audit`, `debug`, `feature`, `review`, `swarm`)
- 15 auto-loaded behavior rules + TypeScript/Python language extensions
- 4 output styles (`dev`, `research`, `review`, `learning`)
- `AGENTS.md` describing multi-model tier structure and worker model routing
- Graduated delegation enforcement (nudge → warn → block) tuned by env vars
- Skill-gate and capability-gate hooks — domain writes require matching skill loaded first
- CLI wrappers in `.claude/scripts/mcp-cli.sh` for Ollama, DeepSeek, Firecrawl (zero context tokens)

### Changed
- `CLAUDE.md` rewritten to use `@import` pattern — pulls in `AGENTS.md` and `.claude/rules/` inline
- Worker model recommendations refreshed to current Ollama Cloud catalogue (`glm-5.1:cloud`, `minimax-m2.7:cloud`, `deepseek-v3.2:cloud`, `qwen3-coder-next:cloud`, `gemma4:31b-cloud`)
- `.gitignore` expanded to exclude all runtime state (`.claude/.*.log`, `.claude/events.jsonl`, `.claude.backup.*`, etc.)
- `CONTRIBUTING.md` updated for the new installer + profile workflow

### Removed
- `CODE-SNIPPETS.md`, `CODING-AGENT-GUIDE.md`, `CRITICAL-THINKING.md`, `ERROR-CATALOG.md`, `INDEX.md`, `INIT-PROMPT.md`, `MCP-AND-PLUGINS.md`, `MCP-CATALOG.md`, `OLLAMA-INTEGRATION.md`, `OPTIONAL-EXTENSIONS.md`, `QUALITY-HOOKS.md`, `SKILLS-CATALOG.md`, `SKILLS-MCP-GUIDE.md`, `TEST-CAPABILITIES.md` — content folded into the new `README.md` + `docs/` guides
- Old `setup.sh` and `setup-env.sh` — replaced by `install.sh`
- `.mcp.json.template` — MCP setup now handled per-project by Claude Code's MCP system directly

## [0.1.0] — 2026-02-09

Initial release.

### Added
- Initial skill set (18 skills)
- 22 quality hooks
- Basic setup script
- Documentation suite (14 markdown guides)
