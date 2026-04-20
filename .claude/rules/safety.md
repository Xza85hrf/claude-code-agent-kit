# Safety Rules

## Secrets Prevention

Never commit secrets, API keys, tokens, or passwords into code files.

| Blocked Pattern | Example | Where Allowed |
|----------------|---------|---------------|
| API keys | `sk-...`, `AKIA...`, `AIza...` | `~/.claude-secrets` only |
| Bearer tokens | `Authorization: Bearer ...` | Runtime env vars |
| Private keys | `-----BEGIN RSA PRIVATE KEY-----` | Never in repo |
| Connection strings | `postgres://user:pass@host` | `.env` files (gitignored) |
| Hardcoded passwords | `password = "..."` | Never |

**Exemptions**: Shell scripts in `.claude/hooks/` and `.claude/scripts/` may reference env var names (not values).
`.env` files MUST be in `.gitignore`. Use `.env.example` for docs. Access via `source ~/.claude-secrets`.

## Path Protection

| Protected Path | Policy |
|---------------|--------|
| `.claude/` | noDelete — hooks, rules, scripts, config |
| `CLAUDE.md`, `AGENTS.md` | noDelete — project config |
| `node_modules/` | noDelete unless `npm install` follows |
| `package-lock.json` | noDelete — use `npm install` instead |
| `dist/`, `build/` | Safe to delete (rebuild artifacts) |

## Command Safety

| Blocked | Why | Alternative |
|---------|-----|-------------|
| `rm -rf /` or `rm -rf ~` | Catastrophic | Scope the path |
| `dd if=/dev/zero` | Disk wipe | Never needed |
| `chmod -R 777` | Security hole | Use specific permissions |
| `kill -9 1` | System crash | Target specific PID |
| `> /dev/sda` | Disk corruption | Never needed |

## Shell Safety

- Always quote file paths with spaces
- Never use `eval` with user input
- Prefer `subprocess.run(shell=False)` in Python
- Use `set -euo pipefail` in new scripts

## Bypassing path protection (deliberate edits inside protected dirs)

Deleting or overwriting a file under a `noDelete` / `readOnly` path (`.claude/hooks/`, `.claude/scripts/`, `.claude/lib/`, etc.) is blocked by default. To authorize a one-off edit:

- Wrap it: `bash .claude/scripts/allow-protected.sh rm .claude/scripts/old.sh`
- Or manually: `date +%s > .claude/.damage-control-bypass` in one turn, then the destructive command in the next — the token is valid for 5 minutes, auto-expires.

`zeroAccess` paths (`.env`, credentials) stay absolute — no bypass, ever.

## Enforced by

`check-secrets.sh` (PostToolUse) — blocks commits with secrets. `damage-control.sh` (PreToolUse, minimal tier — always active).
