# Installation

## TL;DR

```bash
git clone https://github.com/Xza85hrf/claude-code-agent-kit.git
cd claude-code-agent-kit
./install.sh /path/to/your-project
```

## Prerequisites

| Tool | Required | Notes |
|------|:---:|-------|
| `bash` | yes | 4.x or newer (macOS ships 3.2 by default — install via Homebrew: `brew install bash`) |
| `git` | yes | any modern version |
| `jq` | yes | `brew install jq` / `apt install jq` / `winget install jqlang.jq` |
| `claude` CLI | recommended | [Install guide](https://docs.anthropic.com/en/docs/claude-code) |
| `rsync` | optional | Installer uses it when available (preserves perms, skips backups); falls back to `cp` |

## Installer Flags

```
./install.sh [TARGET] [--profile minimal|standard] [--force]
```

| Flag | Effect |
|------|--------|
| *(none)* | Installs into the current directory with `standard` profile |
| `TARGET` | Absolute or relative path — created if missing |
| `--profile minimal` | Safety-only hooks (10 hooks) |
| `--profile standard` | Default — full workflow (30 hooks) |
| `--force` | Skip backup of existing `.claude/` and overwrite |

## What the Installer Does

1. **Prerequisite check** — bash, jq, git, and `claude` CLI. Fails fast with guidance if anything's missing.
2. **Backup existing install** — if `TARGET/.claude/` exists, it's moved to `.claude.backup.YYYYMMDD-HHMMSS/`. `CLAUDE.md` goes to `CLAUDE.md.bak`. Skip this with `--force`.
3. **Copy kit files** — `.claude/`, `CLAUDE.md`, `AGENTS.md`. Uses `rsync` if present.
4. **Make hooks executable** — `chmod +x` across hooks and scripts.
5. **Apply profile** — generates `.claude/settings.local.json` from `profiles/<name>.json`. Preserves your existing `permissions.deny`/`allow` arrays if the file already exists.
6. **Secrets template** — creates `~/.claude-secrets` with commented-out export lines for optional API keys. Perm is `600`. Skipped if the file already exists.

The installer is **idempotent** — re-run it any time. Your prior `.claude/` is always backed up.

## Post-Install

```bash
cd /path/to/your-project
claude
```

Inside Claude Code:

- `CLAUDE.md` is auto-loaded, which pulls in `AGENTS.md` via `@import` and every rule in `.claude/rules/`.
- Hooks from `settings.local.json` activate immediately.
- Invoke skills explicitly: `Skill("test-driven-development")`.

## Switching Profiles Later

```bash
bash .claude/scripts/apply-profile.sh minimal
# or
bash .claude/scripts/apply-profile.sh standard
```

This rewrites `settings.local.json` using the profile JSON, preserving your `permissions` array.

## Optional: Enable Worker Models

Edit `~/.claude-secrets`:

```bash
export OLLAMA_API_KEY="..."       # Ollama Cloud
export OPENAI_API_KEY="..."       # optional — code audit, image gen
export GEMINI_API_KEY="..."       # optional — research, vision
export DEEPSEEK_API_KEY="..."     # optional — second opinions
```

Only fill what you use. The delegation system gracefully degrades — if nothing is set, you just don't get the worker tier.

## Uninstall

```bash
rm -rf /path/to/your-project/.claude /path/to/your-project/CLAUDE.md /path/to/your-project/AGENTS.md
```

If the installer made a backup, restore with:

```bash
mv .claude.backup.<timestamp>/ .claude/
mv CLAUDE.md.bak CLAUDE.md
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `jq: command not found` | `brew install jq` / `apt install jq` / `winget install jqlang.jq` |
| `bash: ./install.sh: Permission denied` | `chmod +x install.sh` |
| `jq: error: Could not open file` when applying profile | `CLAUDE_PROJECT_DIR` env var leaked from a parent shell — `unset CLAUDE_PROJECT_DIR` and retry, or just run from the target directory |
| Hooks don't fire inside Claude Code | Confirm `settings.local.json` exists and has a `hooks` block: `jq '.hooks \| keys' .claude/settings.local.json` |
| `claude` command not found after install | Kit installs config only; install the CLI separately from [Anthropic's docs](https://docs.anthropic.com/en/docs/claude-code) |
| Nothing happens on `Skill("...")` | Skills don't auto-load — you must invoke them explicitly. Type the full `Skill("skill-name")` form or ask Claude to load it |
