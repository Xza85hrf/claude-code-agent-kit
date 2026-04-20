# Git Workflow

## Conventional Commits

Format: `type(scope): description`

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | No behavior change |
| `perf` | Performance improvement |
| `test` | Adding/fixing tests |
| `chore` | Build, CI, tooling |

Scope = component/file area (e.g., `dashboard`, `hooks`, `rules`).

## Protected Operations

| Action | Policy |
|--------|--------|
| Force push to main | BLOCKED — always |
| `git reset --hard` | Confirm with user first |
| Amending published commits | Confirm with user first |
| Deleting branches | Only if merged or user requests |
| `--no-verify` | Never unless user explicitly asks |

## Commit Hygiene

- No secrets or `.env` values in commit messages
- No merge commits on main — rebase preferred
- Commit after each logical change, not in bulk

## Enforced by

`validate-commit.sh` (PostToolUse), `block-dangerous-git.sh` (PreToolUse).
