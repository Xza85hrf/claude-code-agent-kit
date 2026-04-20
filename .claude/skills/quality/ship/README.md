# Ship: Complete Release Workflow

The `/ship` command provides a production-grade, guided release workflow for shipping feature branches to main with minimal manual steps.

## Overview

Ship automates the entire release process:

```
Feature Branch
    ↓
1. Pre-flight checks (backup creation, branch validation)
    ↓
2. Sync with main (fetch, rebase if needed)
    ↓
3. Run tests (auto-detect npm/make/pytest/cargo)
    ↓
4. Pre-landing review (TypeScript, ESLint, security)
    ↓
5. Generate changelog (parse commits, group by type)
    ↓
6. Push & create PR (with rich body)
    ↓
7. Summary & verification
    ↓
GitHub PR Created
```

## Quick Start

```bash
# Interactive release workflow
/ship

# Production-ready: non-interactive, safe for CI/CD
/ship --auto

# Draft PR for early feedback
/ship --draft

# Skip tests (for docs-only changes)
/ship --skip-tests
```

## Files & Structure

```
.claude/
├── commands/
│   └── ship.md                           # Command definition (47 lines)
│
├── skills/quality/ship/
│   ├── SKILL.md                          # Complete workflow guide (430 lines)
│   ├── REFERENCE.md                      # Quick reference & troubleshooting (352 lines)
│   └── README.md                         # This file
│
└── scripts/
    ├── ship-workflow.sh                  # Main orchestrator (63 lines)
    └── lib/ship/
        ├── utils.sh                      # Logging & user interaction (46 lines)
        ├── config.sh                     # Shared state (10 lines)
        ├── step-preflight.sh             # Step 1: Pre-flight checks (43 lines)
        ├── step-sync.sh                  # Step 2: Sync with main (26 lines)
        ├── step-tests.sh                 # Step 3: Run tests (59 lines)
        ├── step-review.sh                # Step 4: Pre-landing review (26 lines)
        ├── step-changelog.sh             # Step 5: Generate changelog (58 lines)
        └── step-pr.sh                    # Step 6-7: PR & summary (85 lines)
```

**Total:** 10 focused files, 416 lines of implementation + 829 lines of documentation.

## Architecture

### Modular Design

Each workflow step is in its own shell module:

- **Single Responsibility** — Each module does one thing well
- **Max 85 lines** — Enforces simplicity and readability
- **Shared utilities** — Logging, colors, user prompts reused
- **Clear interfaces** — Modules set global variables for orchestrator

### Orchestrator Pattern

```bash
# Main script coordinates steps
main() {
  parse_args "$@"           # Handle flags
  step_preflight || exit 1  # Each step can fail
  step_sync || exit $?
  step_tests || exit $?
  # ... etc
  print_summary             # Report results
}
```

### Module Composition

Each step is sourced and called:

```bash
source lib/ship/step-tests.sh
step_tests  # Function call, returns exit code
```

## Feature Highlights

### Safety Features

**Backup Branch Creation**
```bash
BACKUP_BRANCH="backup/ship-${BRANCH}-$(date +%s)"
git branch "$BACKUP_BRANCH"
```
Safe rollback point before any destructive operations.

**Test Result Validation**
- Auto-detects runner (npm/make/pytest/cargo)
- Fails fast if tests fail
- Captures result in PR body

**Conflict Detection & Resolution**
- Detects rebase conflicts
- Shows conflicted files
- Guides user through resolution
- Continues rebase after manual fix

**Review Gate**
- TypeScript compilation check
- ESLint validation (if available)
- Optional integration with pre-landing-review skill
- Critical issues block PR creation

### Smart Changelog Generation

Parses conventional commits and groups by type:

```bash
feat: new API endpoint     → ### Added
fix: memory leak          → ### Fixed
refactor: extract helper  → ### Changed
perf: cache results       → ### Performance
docs: update README       → ### Documentation
```

**Output format:** Keep a Changelog compatible
**Storage:** Prepends to CHANGELOG.md if exists

### Rich PR Body

Automatically includes:

```markdown
## Summary
[Changelog entry]

## Changes
X files changed, Y insertions(+), Z deletions(-)

## Testing
Test result: PASS

## Checklist
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Ready to merge
```

## Command Options

| Option | Effect | Use Case |
|--------|--------|----------|
| (none) | Interactive with confirmations | Hands-on releases |
| `--skip-tests` | Skip test execution | Docs-only changes |
| `--draft` | Create draft PR | Early feedback, not ready to merge |
| `--auto` | Non-interactive, defaults | CI/CD pipelines |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — PR created |
| 1 | Pre-flight failure (branch validation, permissions) |
| 2 | Rebase failure (conflicts not resolved) |
| 3 | Test failure (tests didn't pass) |
| 4 | Review gate failure (critical issues found) |
| 5 | PR creation failure (gh CLI issue, auth problem) |
| 130 | User cancelled (interactive mode only) |

## Integration

### With Existing Skills

**Before Ship:**
- `Skill("test-driven-development")` — Verify all tests pass before shipping

**After Ship:**
- `Skill("pre-landing-review")` — Explicitly assign reviewers
- Link PR to issue tracking for sprint planning

**Related:**
- `Skill("test-driven-development")` — TDD best practices ensure tests are robust
- `Skill("solid")` — Code quality principles for clean changes

### With CI/CD

Use `--auto` flag for automated releases:

```yaml
# .github/workflows/release.yml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: |
          git config user.name "Release Bot"
          git config user.email "bot@example.com"
          bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/ship-workflow.sh" --auto
```

## Usage Patterns

### Pattern 1: Interactive Release

```bash
/ship
# Follow prompts, confirmations between steps
# Best for: hands-on development, small teams
```

### Pattern 2: Draft for Feedback

```bash
/ship --draft
# Creates PR but not mergeable
# Best for: early reviews, RFC-style feedback
```

### Pattern 3: Production CI/CD

```bash
/ship --auto
# Fully automated, suitable for pipelines
# Best for: nightly releases, auto-deployments
```

### Pattern 4: Docs-Only Changes

```bash
/ship --skip-tests
# Skip tests, useful when infrastructure unavailable
# Best for: documentation updates, configuration changes
```

### Pattern 5: Combine Flags

```bash
/ship --skip-tests --draft --auto
# Maximum automation with minimal overhead
# Best for: nightly docs sync, automated backports
```

## Error Scenarios & Recovery

### Scenario 1: Branch on Main

```
✗ Cannot ship from main branch
→ Fix: Create feature branch first
  git checkout -b feature/your-feature
```

### Scenario 2: Rebase Conflict

```
✗ Rebase conflict detected
→ Fix: Resolve conflicts, then continue
  # Fix conflicts in editor
  git add .
  git rebase --continue
  /ship  # Re-run workflow
```

### Scenario 3: Tests Failed

```
✗ Tests failed
→ Fix: Debug and fix tests
  npm test  # or make test / pytest / cargo test
  git add . && git commit -m "fix: test failures"
  /ship  # Re-run workflow
```

### Scenario 4: PR Already Exists

```
⚠ PR already exists for this branch
→ Reuses existing PR, optionally updates body
```

### Scenario 5: gh CLI Not Installed

```
✗ GitHub CLI (gh) not installed
→ Fix: Install from https://cli.github.com/
```

## Rollback Strategy

If any step fails catastrophically:

```bash
# Revert to backup branch
git checkout backup/ship-{branch}-{timestamp}

# Delete the failed attempt
git branch -D {branch}
git push origin -d {branch}

# Restore the feature branch from backup (optional)
git checkout -b {branch} backup/ship-{branch}-{timestamp}
```

Safe to delete backup branch after confirming PR merge:

```bash
git branch -d backup/ship-{branch}-{timestamp}
```

## Testing the Workflow

### Manual Test (Dry-Run)

```bash
# Create a test branch
git checkout -b test/ship-workflow

# Make a small change
echo "# Test change" >> README.md
git add README.md
git commit -m "test: dry-run ship workflow"

# Run with --draft flag for safety
/ship --draft

# Review the created PR
gh pr view --web

# Clean up
git checkout main
git branch -D test/ship-workflow
gh pr close {pr-number}
```

### CI/CD Test

```bash
# Add to CI pipeline
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/ship-workflow.sh" --auto

# Check exit code
echo "Exit code: $?"
```

## Troubleshooting

### "No test runner detected"

**Cause:** Repository has no test infrastructure.

**Result:** Tests skipped with warning `TEST_RESULT=NOT_FOUND`.

**Fix:**
```bash
# Create test runner config, then re-run /ship
# OR use --skip-tests if no tests planned
/ship --skip-tests
```

### "TypeScript compilation warnings"

**Cause:** `tsconfig.json` exists with compilation issues.

**Result:** Workflow continues but issues shown in PR body.

**Fix:** Review and fix TypeScript issues before merging.

### "Changelog entry manual edit needed"

**Cause:** Conventional commits not followed.

**Result:** PR body shows generated changelog for manual review.

**Fix:** Either update commits to follow conventional format, or manually edit PR body.

## Performance

- **Full workflow:** ~30-60 seconds (test execution time varies)
- **Without tests:** ~10-15 seconds
- **Pre-flight only:** ~2 seconds
- **Bottleneck:** Test execution (npm test, pytest, etc.)

## Security & Safety

### Branch Protection

- Cannot ship from main (prevents accidental merges)
- Checks remote tracking is set (prevents orphaned branches)
- Creates backup branch (safe rollback)

### Test Validation

- Requires tests to pass (unless --skip-tests)
- Captures test result in PR (prevents blind merges)

### Review Gate

- Pre-landing review skill integration (if available)
- TypeScript and ESLint validation
- Blocks on critical issues

### PR Body

- Auto-generated from commits (accurate changelog)
- Includes test results (verification evidence)
- Includes diff stats (scope visibility)
- Includes checklist (merge gate reminder)

## Limitations & Future Enhancements

### Current Limitations

- Requires gh CLI (GitHub only)
- Rebase-only (no merge strategy option)
- Conventional commits expected (fallback to "Other")
- Requires git 2.20+ (for modern features)

### Potential Enhancements

- [ ] GitLab CI support (via `gl` CLI)
- [ ] Configurable merge strategy (merge vs rebase)
- [ ] Custom changelog format
- [ ] Automatic reviewer assignment (via CODEOWNERS)
- [ ] Semantic versioning integration
- [ ] Deploy after merge (optional GitHub Actions)

## Contributing

To improve the ship workflow:

1. **Bug fixes:** Edit relevant module in `lib/ship/`
2. **New steps:** Create new `step-{name}.sh` module
3. **Documentation:** Update SKILL.md and REFERENCE.md
4. **Testing:** Dry-run with `--draft` flag first

Remember: Ship is a critical workflow — test thoroughly before merging changes.

## See Also

- `/ship` — Use this command to release
- `Skill("test-driven-development")` — Gate before shipping
- `Skill("test-driven-development")` — Ensure tests are robust
- `Skill("solid")` — Code quality principles
- `docs/DEVELOPMENT-GUIDE.md` — Project development workflow

---

**Last updated:** 2026-03-15
**Status:** Production-ready
**Tested on:** bash 5.1+, git 2.40+, macOS + Linux
