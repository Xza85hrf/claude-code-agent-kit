# Ship Workflow Reference

Complete guide to using the `/ship` command for releasing feature branches to main.

## Quick Start

```bash
# Full workflow (interactive)
/ship

# Skip tests (for non-testable features)
/ship --skip-tests

# Create draft PR (for review-only)
/ship --draft

# Non-interactive mode (CI/CD)
/ship --auto
```

## What Ship Does

The `/ship` command automates the 7-step release workflow:

1. **Pre-flight** — Branch context, permissions, cleanup
2. **Sync** — Fetch latest main, rebase if needed
3. **Tests** — Auto-detect and run test suite
4. **Review** — Static analysis, code quality
5. **Changelog** — Extract commits, group by type
6. **PR** — Push branch, create GitHub PR
7. **Summary** — Report results, confirm creation

## When to Use

Use `/ship` when:
- Feature branch is complete and tested
- Ready to create a pull request to main
- Want a guided, automated workflow instead of manual git commands
- Need a rich PR with changelog and test results

**Do NOT use `/ship` when:**
- On the main branch (creates feature branch first)
- Branch has uncommitted changes (will prompt to commit/stash)
- Tests are failing (fix tests first)
- Branch has conflicts with main (resolved interactively)

## Command Options

### --skip-tests

Skip test execution. Useful when:
- Tests are infrastructure-heavy and unavailable in current context
- Feature is documentation-only
- Tests are known to be flaky in CI

**Example:**
```bash
/ship --skip-tests
```

Test result shows as `SKIPPED` in PR body.

### --draft

Create PR as draft. Use when:
- Requesting early feedback before ready to merge
- Work-in-progress that needs review
- Not ready for auto-merge workflows

**Example:**
```bash
/ship --draft
```

PR shows as "Draft" in GitHub, not mergeable until converted to ready.

### --auto

Non-interactive mode — no prompts, proceeds with defaults. Use for:
- CI/CD pipelines
- Automated release processes
- Scripted deployments

**Example:**
```bash
/ship --auto
```

Combines all flags and skips user confirmations.

## Step Breakdown

### Step 1: Pre-flight Checks

Verifies branch is shippable:

```bash
✓ Not on main
✓ Branch name is valid (not 'main')
✓ Tracking branch is set (or creates it)
✓ Creates backup branch for rollback safety
```

**What happens if it fails:**
- On main? Stop. Create feature branch.
- Not tracked? Prompts to push to origin.
- Uncommitted changes? Prompts to commit or stash.

**Backup branch** — Automatically created at `backup/ship-{branch}-{timestamp}`. Safe to delete after PR merge.

### Step 2: Sync with Main

Rebase feature branch onto latest main:

```bash
✓ Fetch latest main from remote
✓ Count commits behind (if any)
✓ Rebase if behind
✓ Resolve conflicts interactively if needed
```

**Why rebase?** Ensures clean, linear history. Prevents merge commits that clutter the log.

**Conflicts?** Displays them, prompts user to resolve, then continues rebase.

### Step 3: Run Tests

Auto-detects and runs test suite:

```bash
Detected: npm | make | pytest | cargo
Running: npm test
```

**Auto-detects runner from:**
- `package.json` → `npm test`
- `Makefile` with test target → `make test`
- `pyproject.toml` or `pytest.ini` → `pytest`
- `Cargo.toml` → `cargo test`
- None detected → `NOT_FOUND` (continues with warning)

**If tests fail:** STOP. Fix tests, re-run `/ship`.

**Test result shows in PR body** — lets reviewers see what was tested.

### Step 4: Pre-Landing Review Gate

Runs static analysis and code quality checks:

```bash
✓ TypeScript check (if tsconfig.json exists)
✓ ESLint (if .eslintrc* exists)
✓ Pre-landing review skill (if available)
```

**If critical issues found:** STOP. Fix issues, re-run `/ship`.

**Warnings/info issues:** Included in PR body for review.

### Step 5: Generate Changelog Entry

Parses commits since main and groups by type:

```
### Added
- New feature (abc1234)

### Fixed
- Bug fix (def5678)

### Changed
- Refactoring (ghi9012)
```

**Conventional commits parsed:**
- `feat:` → Added
- `fix:` → Fixed
- `refactor:` → Changed
- `perf:` → Performance
- `docs:` → Documentation
- Other → Other

**Updates CHANGELOG.md** — If exists, prepends entry. If not, skips (no auto-create).

### Step 6: Push & Create PR

Pushes branch and creates GitHub PR:

```bash
✓ Push branch to origin
✓ Create PR via gh CLI
✓ Include changelog, test results, checklist
```

**PR body includes:**
- Changelog entry
- Diff stats (X files, Y insertions, Z deletions)
- Test results
- Checklist for reviewer

**If PR already exists:** Uses existing PR, optionally updates body.

**Requires:** `gh` CLI installed and authenticated.

### Step 7: Summary & Verification

Reports results and suggests next steps:

```
✅ Ship Workflow Complete

Branch:        feature/my-feature
Commits:       5
Tests:         PASS
Review:        OK
PR Status:     READY
PR URL:        https://github.com/.../pull/123

📋 Next Steps:
1. Request review from team
2. Address review feedback
3. Merge when approved
```

**Optionally:** Opens PR in browser for quick access.

## Error Recovery

| Problem | Fix |
|---------|-----|
| "Cannot ship from main" | Create feature branch: `git checkout -b feature/your-feature` |
| "Not tracking remote" | Either continue (will push) or: `git push -u origin branch` |
| Rebase conflict | Resolve conflicts, run: `git rebase --continue`, re-run `/ship` |
| Tests fail | Fix code, run tests manually, re-run `/ship` |
| Network error on push | Check internet, retry: `git push origin branch`, re-run `/ship` |
| PR creation fails | Check: `gh auth status`, verify repo access |
| No gh CLI | Install from: https://cli.github.com/ |

## Rollback

If anything goes wrong, restore from backup branch:

```bash
git checkout backup/ship-{branch}-{timestamp}
git branch -D feature-branch
git push origin -d feature-branch
```

Then delete the backup branch when confirmed:

```bash
git branch -D backup/ship-{branch}-{timestamp}
```

## Integration with Other Skills

- **Before ship** — Use `Skill("test-driven-development")` to confirm all tests pass
- **After ship** — Link PR to: `Skill("pre-landing-review")` for explicit reviewer assignment
- **If complex** — Use `Skill("writing-plans")` first to structure large changes

## Tips & Tricks

### Combine flags

```bash
/ship --skip-tests --draft --auto
```

Useful for CI/CD: skip tests, create draft, proceed automatically.

### Use in CI/CD

```bash
#!/bin/bash
set -e
cd /path/to/project
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/ship-workflow.sh" --auto
```

Creates PR automatically on successful build.

### Review before commit

Before running `/ship`, verify with:

```bash
git log origin/main..HEAD --oneline
git diff origin/main --stat
npm test  # or your test command
```

### Check PR before merge

After `/ship` completes:

```bash
gh pr view {branch}  # View PR details
gh pr review {branch} --approve  # Add approval
```

## Troubleshooting

### "Branch not tracking remote"

**Cause:** Local branch not set up to track origin branch.

**Fix:**
```bash
git push -u origin branch-name
# Then re-run /ship
```

### "Rebase conflict"

**Cause:** Changes on main conflict with your branch.

**Fix:**
```bash
# Resolve conflicts in your editor
git add .
git rebase --continue
# Then re-run /ship
```

### "Tests failed"

**Cause:** Test suite returned non-zero exit code.

**Fix:**
```bash
# Run tests manually to debug
npm test  # or make test, pytest, cargo test
# Fix the issue
git add .
git commit -m "fix: test failures"
# Then re-run /ship
```

### "gh pr create failed"

**Cause:** GitHub CLI not installed or not authenticated.

**Fix:**
```bash
# Install gh
brew install gh  # macOS
# OR
choco install gh  # Windows
# OR
sudo apt install gh  # Linux

# Authenticate
gh auth login
# Then re-run /ship
```

### "No test runner detected"

**Cause:** No package.json, Makefile, pytest, or Cargo config found.

**Result:** Tests skipped (TEST_RESULT shows `NOT_FOUND`).

**Fix:** Create test runner config, or use `--skip-tests` flag.

## See Also

- `Skill("test-driven-development")` — TDD best practices
- `Skill("test-driven-development")` — Gate for completion claims
- `Skill("solid")` — Code quality principles
- `/workflow ship-feature` — Structured workflow view
