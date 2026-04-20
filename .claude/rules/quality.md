# Quality & Testing

## Definition of Done

Every code change: type checks pass, no regressions, tests pass, worker output verified.

## What Requires Tests

| Change Type | Test Requirement |
|-------------|-----------------|
| New feature | Unit tests + integration tests |
| Bug fix | Regression test proving the fix |
| UI component | Render tests + interaction tests |
| API endpoint | Request/response tests + error cases |
| Refactor | Existing tests must still pass |
| Config change | Verify build + existing tests pass |

## Test-After-Edit Rule

After every Edit/Write to a source file, run related tests before continuing. The `test-reminder.sh` hook enforces this.

## Coverage Standards

- New code: aim for >80% branch coverage
- Bug fixes: 100% coverage of the fixed path
- Never mock what you can test directly
- Test edge cases: null, empty, boundary values

## Framework Conventions

| Project Type | Framework | Runner |
|-------------|-----------|--------|
| React/TS | Vitest + @testing-library/react | `npx vitest run` |
| Node/TS | Vitest | `npx vitest run` |
| Python | pytest | `pytest` |

## Retry: pass@k / pass^k

- **pass@k**: 1 of k succeeds. Normal code gen: k=2 (retry once).
- **pass^k**: ALL must succeed. Security/auth/migrations: k=1. Fail → escalate.

## Hooks

110 hooks auto-enforce safety (full profile). Hook with message → read advice. Hook blocks → fix the issue. Never bypass (--no-verify) unless user asks.

Worker completion: `git diff → typecheck → test → accept or retry once`

## Enforced by

`test-reminder.sh` (PostToolUse) — fires after code edits, reminds to run tests.
