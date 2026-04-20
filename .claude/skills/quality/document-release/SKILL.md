---
name: document-release
description: Post-ship documentation sync — update docs, generate test plan, sync README, and verify all references after a release
argument-hint: "[version]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: quality
disable-model-invocation: false
references: []
thinking-level: medium
---

# Document Release: Post-Ship Doc Sync

Run this after `/ship` completes to ensure documentation stays in sync with the release.

**Announce at start:** "Running document-release to sync docs with the latest release."

## Arguments

- `$ARGUMENTS[0]` — Version string (optional). If not provided, read from VERSION file or latest git tag.

## Process

### Step 1: Detect Release Context

```bash
# Get version
VERSION=$(cat VERSION 2>/dev/null || git describe --tags --abbrev=0 2>/dev/null || echo "unreleased")
BRANCH=$(git branch --show-current)
BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || echo "main")
DIFF_FILES=$(git diff $BASE --name-only)
```

### Step 2: Scan for Stale Documentation

Check if any changed source files have corresponding docs that need updating:

1. **API changes** — If any API endpoints changed, check for:
   - OpenAPI/Swagger specs
   - API documentation in `docs/`
   - README API sections

2. **Config changes** — If config schema changed:
   - Environment variable docs
   - Setup/installation guides
   - Docker/deployment configs

3. **Feature changes** — If new features added:
   - Feature documentation
   - Usage examples
   - Screenshots/diagrams (flag as needing manual update)

4. **Dependency changes** — If package.json/requirements.txt changed:
   - Installation docs
   - Compatibility notes

### Step 3: Update Documentation

For each stale doc found:

1. Read the current doc
2. Read the changed source code
3. Update the doc to reflect the changes
4. Preserve existing formatting and style

**Auto-update these if they exist:**
- `README.md` — version badges, feature lists, installation commands
- `docs/` — any doc referencing changed files
- `CONTRIBUTING.md` — if dev workflow changed
- `docs/project-state.md` — update current state

### Step 4: Generate Test Plan

Create a test plan for the release based on changes:

```markdown
## Test Plan — vX.Y.Z

### Changed Areas
- [list of changed modules/features]

### Regression Tests
- [ ] [existing functionality that could be affected]

### New Feature Tests
- [ ] [new features to verify]

### Edge Cases
- [ ] [boundary conditions from the diff]

### Manual Verification
- [ ] [things that need human eyes]
```

Output the test plan. If a `docs/test-plans/` directory exists, save it there.

### Step 5: Cross-Reference Check

Verify no broken references:

```bash
# Check for references to renamed/deleted files
git diff $BASE --diff-filter=DR --name-only | while read deleted; do
  grep -rl "$deleted" docs/ README.md CONTRIBUTING.md 2>/dev/null
done
```

Fix any broken references found.

### Step 6: Summary

```
Document Release Complete — vX.Y.Z

Docs Updated:    N files
Test Plan:       Generated
Broken Refs:     N fixed
Stale Docs:      N flagged for review

Files modified:
- [list]
```

Commit doc changes: `git commit -am "docs: sync documentation for vX.Y.Z"`

## When to Use

- After `/ship` completes successfully
- Before announcing a release
- When docs drift is suspected
- After major refactoring

## See Also

- `Skill("ship")` — Release workflow that precedes this
- `Skill("changelog-automation")` — Changelog generation
