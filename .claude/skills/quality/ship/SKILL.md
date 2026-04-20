---
name: ship
description: Ship current branch — complete release workflow with tests, review gate, changelog, and PR creation. Use when ready to merge a feature branch to main.
argument-hint: "[--skip-tests] [--draft] [--auto]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: quality
disable-model-invocation: false
references: []
thinking-level: medium
---

# Ship: Complete Release Workflow

You are running the `ship` skill. This is a production-grade release workflow for shipping feature branches to main.

**Announce at start:** "I'm using the ship skill to release this branch. I'll execute a complete workflow: pre-flight checks → test → review → changelog → PR."

## Arguments

- `$ARGUMENTS[0]` — Optional flags:
  - `--skip-tests`: Bypass test execution (only if tests are infeasible)
  - `--draft`: Create PR as draft (review-only, not mergeable)
  - `--auto`: Non-interactive mode — proceed with defaults, minimal confirmations

## Core Process

### Step 1: Pre-flight Checks

**Goal:** Verify the branch is shippable.

```bash
BRANCH=$(git branch --show-current)
git status --porcelain
git rev-parse @{u} 2>/dev/null  # check tracking branch
```

**Checks:**
- [ ] Not on `main` — If on main, STOP: "Cannot ship from main. Create a feature branch first."
- [ ] Branch is tracked on origin — If not, offer to push to origin first
- [ ] Uncommitted changes — If dirty, ask:
  - Commit with provided message?
  - Stash and proceed?
  - Cancel and fix?

**Create backup branch:**
```bash
git branch backup/ship-${BRANCH}-$(date +%s)
```

### Step 2: Sync with Main

**Goal:** Rebase onto latest main to avoid merge conflicts.

```bash
git fetch origin main --quiet
BEHIND=$(git rev-list --count HEAD..origin/main)
echo "Commits behind main: $BEHIND"
```

**If behind:**
- Attempt rebase: `git rebase origin/main`
- If conflicts:
  - STOP with conflict markers displayed
  - Offer: "Resolve conflicts in editor? (vim/nano/vscode)"
  - If user resolves: continue with `git rebase --continue`
  - If user aborts: `git rebase --abort` and stop

**If rebase fails:**
- Show `git status` and error message
- Suggest: "Run `git rebase --abort` and resolve conflicts manually"
- STOP workflow

### Step 3: Run Tests (unless --skip-tests)

**Goal:** Verify the feature doesn't break existing functionality.

**Auto-detect test runner:**

```bash
# Priority order:
if [[ -f package.json ]]; then
  npm test
elif [[ -f Makefile ]] && grep -q "^test:" Makefile; then
  make test
elif [[ -f pyproject.toml ]] || [[ -f pytest.ini ]]; then
  pytest
elif [[ -f Cargo.toml ]]; then
  cargo test
else
  echo "No tests detected"
  # Continue with warning
fi
```

**Test result handling:**

- **All tests pass:** Continue to Step 4
- **Some tests fail:** STOP
  - Show test output with failure details
  - Suggest: "Fix failing tests, then re-run `/ship`"
  - Offer rollback: "Restore from backup branch?"
- **Test runner error (not test failures):** Ask
  - "Test runner had an error. Skip tests and continue? (--skip-tests)"
  - If no: STOP

### Step 4: Pre-Landing Review Gate

**Goal:** Catch critical issues before creating PR.

**Check for review skill:**
```bash
if [[ -f .claude/skills/quality/pre-landing-review/SKILL.md ]]; then
  Skill("pre-landing-review")
fi
```

**If pre-landing-review skill exists:**
- Run it with current branch context
- Collect findings into `$REVIEW_FINDINGS`
- **Critical issues:** STOP with findings displayed
- **Warnings/info:** Continue with findings in PR body

**If skill doesn't exist, run lightweight checks:**
```bash
# Syntax check (if applicable)
if [[ -f tsconfig.json ]]; then
  npx tsc --noEmit 2>/dev/null || echo "TypeScript check failed"
fi

# Lint check (if available)
if command -v eslint &> /dev/null; then
  eslint . --max-warnings 0 2>/dev/null || true
fi
```

### Step 5: Generate Changelog Entry

**Goal:** Document the changes in a structured format.

**Extract commits:**
```bash
COMMITS=$(git log origin/main..HEAD --pretty=format:"%h|%s|%b" --reverse)
```

**Parse conventional commits:**

Group by type:
- `feat:` → "### Added"
- `fix:` → "### Fixed"
- `refactor:` → "### Changed"
- `perf:` → "### Performance"
- `docs:` → "### Documentation"
- `test:` → "### Testing"
- Other → "### Other"

**Generate entry:**
```markdown
## [Unreleased] - YYYY-MM-DD

### Added
- Feature 1 (abc1234)
- Feature 2 (def5678)

### Fixed
- Bug 1 (ghi9012)

### Changed
- Refactor X (jkl3456)

...
```

**Update CHANGELOG.md:**
- If exists: prepend new entry under [Unreleased]
- If not exists: create CHANGELOG.md in Keep a Changelog format
- Ask for confirmation: "Review changelog entry before PR?"

### Step 6: Push & Create PR

**Goal:** Push branch and create GitHub PR with rich body.

```bash
git push origin $BRANCH -u
```

**Build PR body:**
```
# [Branch Title]

## Summary
[Changelog entry excerpt]

## Changes
- X files changed
- Y insertions(+)
- Z deletions(-)

## Testing
[Test results from Step 3]

## Review Findings
[From Step 4, if any]

## Checklist
- [x] Tests passing
- [x] Code reviewed
- [x] Documentation updated
- [ ] Ready to merge
```

**Create PR:**
```bash
gh pr create \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --base main \
  --head "$BRANCH" \
  $([[ "$DRAFT" == "true" ]] && echo "--draft" || echo "")
```

**If `gh pr create` fails:**
- Check if PR already exists: `gh pr list --head $BRANCH`
- If exists: Show PR URL, offer to update body
- If not: Show error, suggest manual creation via GitHub web UI

### Step 7: Summary & Verification

**Goal:** Confirm PR created and report results.

```
✅ Ship Workflow Complete

Branch:         $BRANCH
Commits:        $(git rev-list --count origin/main..$BRANCH)
Tests:          PASS / SKIP
Review:         OK / WARNINGS
PR Status:      DRAFT / READY
PR URL:         $PR_URL

📋 PR Body:
$PR_BODY

🎯 Next Steps:
1. Request review from team
2. Address review feedback
3. Merge when approved

💾 Backup branch: backup/ship-${BRANCH}-*
   (Safe to delete after PR merge)
```

**Interactive prompts (unless --auto):**
- "Assign reviewers now?" → Open PR page to add reviewers
- "Copy PR URL to clipboard?" (on supported shells)
- "Open PR in browser?" → `gh pr view --web`

## Error Recovery

| Error | Recovery |
|-------|----------|
| Dirty working tree | Commit or stash before continuing |
| Rebase conflict | Resolve manually, `git rebase --continue` |
| Tests fail | Fix code, run tests again, re-run `/ship` |
| Network error on push | Check internet, retry: `git push origin $BRANCH` |
| PR creation fails | Check `gh auth` status, verify repo access |
| No tracking branch | Run: `git push -u origin $BRANCH`, then `/ship` again |

## Rollback

If anything goes wrong, revert to backup branch:

```bash
git checkout backup/ship-${BRANCH}-*
git branch -D $BRANCH
git push origin -d $BRANCH  # Delete remote branch
```

## Decision Tree

```
/ship [flags]
  ├─ Pre-flight OK?
  │  ├─ NO → Fix issue, re-run
  │  └─ YES → Continue
  ├─ Tests --skip-tests?
  │  ├─ YES → Skip
  │  ├─ NO → Run tests
  │  │   ├─ PASS → Continue
  │  │   └─ FAIL → STOP, fix tests
  ├─ Review findings?
  │  ├─ CRITICAL → STOP, fix issues
  │  └─ INFO → Continue with findings in PR
  ├─ Changelog ready?
  │  ├─ CONFIRM → Continue
  │  └─ EDIT → Update and re-check
  ├─ Push & PR create
  │  ├─ SUCCESS → Continue
  │  └─ FAIL → Debug, retry
  └─ Summary & Next Steps
```

## Verification Checklist

After `/ship` completes, verify:

- [ ] PR created at correct URL
- [ ] PR title matches branch intent
- [ ] PR body includes changelog, test results, review findings
- [ ] Branch pushed to origin (not just local)
- [ ] Base branch is `main` (not `develop` or other)
- [ ] No uncommitted changes remain locally
- [ ] Backup branch created successfully (visible in `git branch -a`)

## Notes

- **This workflow is atomic** — either completes fully or rolls back to backup state
- **Requires external tools:** `git` (2.20+), `gh` CLI (authenticated)
- **Non-interactive mode** — Use `--auto` for CI/CD pipelines only
- **Always confirm before merging** — PR creation ≠ auto-merge, requires human approval

## Branch Completion Options

After ship workflow completes (or if PR isn't desired), present:

1. **Merge locally** — `git checkout main && git pull && git merge <branch> && git branch -d <branch>`
2. **Push and create PR** — (default ship behavior above)
3. **Keep branch as-is** — Report: "Keeping branch. Worktree preserved at <path>."
4. **Discard** — Require typed "discard" confirmation. Delete branch + worktree.

**Worktree cleanup:** For options 1 and 4, check `git worktree list` and remove associated worktree.

## See Also

- `Skill("test-driven-development")` — Ensure tests are robust (includes verification gate)
- `Skill("pre-landing-review")` — Full review before PR (includes multi-model audit dispatch)
- `/workflow ship-feature` — Structured workflow with more context
