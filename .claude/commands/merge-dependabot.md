---
name: merge-dependabot
description: Safely evaluate and merge open Dependabot PRs in batch
argument-hint: "owner/repo (e.g., openssl/openssl)"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - mcp__claude-ide-bridge__githubListPRs
  - mcp__claude-ide-bridge__githubViewPR
  - mcp__claude-ide-bridge__githubPostPRReview
  - mcp__MCP_DOCKER__github_*
---

<!-- manual -->

# Merge Dependabot PRs

Safely evaluate and merge open Dependabot pull requests in batch, discovering test commands from CI and running them in parallel to verify compatibility before merging sequentially.

## Overview

**Objective:** Reduce time spent reviewing and merging Dependabot PRs by automating:
1. Dependency analysis and overlap detection
2. CI discovery (extracting actual test commands from workflows)
3. Parallel evaluation (running tests on each PR batch)
4. Sequential merging (preventing conflicts)

**Key principle:** Evaluate in parallel, merge in sequence.

**Safety:** Never auto-merge major version bumps or PRs with failing CI.

## Workflow

### Phase 1: Audit Configuration

**Goal:** Validate Dependabot configuration and summarize setup.

**Steps:**
1. Fetch `.github/dependabot.yml` from the repository
2. Parse ecosystems, update schedules, and versioning strategy
3. If not found, warn user and suggest creating one
4. Report summary:
   - Enabled ecosystems (npm, pip, cargo, go, etc.)
   - Update frequency for each
   - Version bumping strategy (major, minor, patch)

**Example output:**
```
Dependabot Configuration Summary
- npm: weekly updates, major version bumps enabled
- pip: daily updates, patch-only
- cargo: monthly updates, major version bumps disabled
```

### Phase 2: List and Group Dependabot PRs

**Goal:** Discover all open Dependabot PRs and identify overlapping changes.

**Steps:**
1. Use `mcp__claude-ide-bridge__githubListPRs` with author filter: `dependabot[bot]`
2. Filter for open PRs only (state: open)
3. For each PR:
   - Extract PR number, title, base branch
   - Use `mcp__claude-ide-bridge__githubGetPRDiff` to get changed files
   - Categorize by ecosystem (parse from PR title)
4. Build a dependency map:
   - Identify overlapping PRs (same lockfiles touched)
   - Group into batches: `npm-batch-1`, `npm-batch-2`, `pip-batch-1`, etc.
5. Flag high-risk PRs:
   - Major version bumps (breaking changes)
   - Multiple dependencies in one PR
   - Non-standard dependency management

**Example output:**
```
Found 8 open Dependabot PRs

npm-batch-1 (2 PRs — safe to merge together):
  #123: Bump lodash from 4.17.20 to 4.17.21
  #124: Bump underscore from 1.13.0 to 1.13.1

pip-batch-1 (1 PR — manual review needed):
  #125: Bump django from 3.0 to 4.0 [MAJOR]

cargo-batch-1 (3 PRs — safe to merge):
  #126–128: Various maintenance updates
```

### Phase 3: Discover Test Commands

**Goal:** Extract actual test commands from CI workflows.

**Steps:**
1. List all files in `.github/workflows/`
2. For each workflow file (YAML):
   - Parse for `run:` blocks
   - Identify common test patterns:
     - `npm test`, `npm run test`, `npm run test:*`
     - `pytest`, `py.test`, `python -m pytest`
     - `cargo test`
     - `go test ./...`
     - `make test`
   - Extract full command with flags (e.g., `npm test -- --coverage`)
3. If multiple test commands found, prioritize:
   - Explicit "test" jobs over implicit
   - Commands with coverage reporting
   - Commands that run the full suite (no filters)
4. If no test commands found, use language-specific defaults:
   - **Node.js:** `npm ci && npm test`
   - **Python:** `pip install -e . && pytest`
   - **Rust:** `cargo test`
   - **Go:** `go test ./...`
   - **Ruby:** `bundle install && bundle exec rake test`
   - **Java:** `mvn test`

**Example discovery:**
```
Discovered test commands:
  npm: npm ci && npm test -- --coverage
  python: python -m pytest -v tests/
  cargo: cargo test --all
```

### Phase 4: Evaluate Each Batch

**Goal:** Run tests on each PR batch to verify compatibility.

**Steps:**
1. **For each batch:**
   - Fetch base branch (usually `main` or `master`)
   - Check out a fresh branch: `evaluation/{batch-name}`
   - Apply all PRs in the batch (rebase merge)

2. **Install dependencies** (if needed):
   - Node: `npm ci`
   - Python: `pip install -e .`
   - Rust: `cargo fetch`
   - Go: `go mod download`

3. **Run discovered test command:**
   - Capture output and exit code
   - Set timeout: 30 minutes per batch
   - Stop on first failure (don't continue if tests fail)

4. **Evaluate results:**
   - ✓ PASS: All tests passed → mark PRs ready to merge
   - ✗ FAIL: Tests failed → investigate
     - Are tests flaky? Run once more
     - Is it a real incompatibility? Flag for manual review
   - ⚠ TIMEOUT: Tests exceeded 30 min → skip batch

5. **Check for breaking changes:**
   - Parse PR titles/bodies for "BREAKING CHANGE"
   - If major version bump and breaking changes → require manual review
   - If patch version bump → auto-merge if tests pass

**Example evaluation output:**
```
Evaluating npm-batch-1...
  Checking out feature/npm-batch-1
  Applying #123 (lodash)
  Applying #124 (underscore)
  Running: npm ci && npm test -- --coverage

  Results: PASS ✓
    - 342 tests passed
    - 1.2s execution time

Status: Ready to merge

---

Evaluating pip-batch-1...
  Checking out feature/pip-batch-1
  Applying #125 (django 3.0→4.0)
  Running: pip install -e . && pytest -v tests/

  Results: FAIL ✗
    - 5 tests failed (incompatible API changes)
    - Error: `django.conf.settings.MIDDLEWARE` requires list, not tuple

Status: MANUAL REVIEW REQUIRED
  - Django 4.0 incompatibility detected
  - User must resolve deprecation warnings
```

### Phase 5: Merge Passing Batches (Sequential)

**Goal:** Merge PRs that passed evaluation, one batch at a time.

**Steps:**
1. **For each ready-to-merge batch:**
   - Merge PR #1 via `mcp__claude-ide-bridge__githubPostPRReview` (squash strategy)
   - Wait for CI to complete on main branch (poll status)
   - If CI passes on main: continue to next PR
   - If CI fails on main: STOP, revert, flag batch for manual review

2. **Revert on failure:**
   - If post-merge CI fails, revert the merge
   - Create incident report: which PR caused the failure
   - Investigate: Why didn't pre-merge tests catch this?
   - Flag PR for manual review

3. **Report merge sequence:**
   ```
   Merged in sequence:
   ✓ #123 (lodash) — CI passed
   ✓ #124 (underscore) — CI passed
   ✗ #126 (cargo-1) — CI failed post-merge, REVERTED

   Summary: 2/3 merged successfully. 1 requires investigation.
   ```

## Command Invocation

```bash
/merge-dependabot owner/repo
```

**Examples:**
```bash
/merge-dependabot openssl/openssl
/merge-dependabot nodejs/node
/merge-dependabot python/cpython
```

**Arguments:**
- `owner/repo` — GitHub repository (e.g., `torvalds/linux`)

## Safety Guardrails

1. **Never auto-merge:**
   - PRs with failing CI checks
   - Major version bumps with breaking changes (without explicit approval)
   - PRs that modify code beyond dependencies (`.yml`, test files, etc.)

2. **Always ask before:**
   - Merging PRs to `main` or `master` (primary branches)
   - Merging >10 PRs in one session
   - Merging if pre-merge tests failed

3. **Rollback triggers:**
   - Post-merge CI failure
   - Regression test failure (if regression suite exists)
   - Any test failure >10 seconds after merge completion

## Failure Handling

**If pre-merge test fails:**
- Run test again (flake check)
- If passes on retry: mark as flaky, proceed with caution
- If fails again: flag PR, skip to next batch, report at end

**If post-merge CI fails:**
- Revert merge immediately via `mcp__claude-ide-bridge__githubPostPRReview --revert`
- Create issue with diagnostic info
- Report: "Merge #XYZ reverted due to CI failure"

**If no CI/tests found:**
- Ask user: "No test command discovered. Proceed with merge anyway?"
- Default: require explicit user confirmation

## Rollback Guidance

If merges cause production issues:

1. **Identify problematic PR:**
   ```bash
   git log --oneline | grep -i dependabot
   ```

2. **Revert in reverse order:**
   ```bash
   git revert <commit-sha>
   git push origin main
   ```

3. **Investigate:**
   - Did pre-merge tests pass but post-merge CI fail? Test flakiness.
   - Did compatibility issues emerge in production? Missing test coverage.

4. **Report:**
   - Which PR caused the issue
   - Why pre-merge tests didn't catch it
   - Recommended fix or additional tests needed

## Verification Checklist

- [ ] Dependabot config found and valid
- [ ] All open Dependabot PRs listed and grouped
- [ ] Test command discovered from CI (or fallback used)
- [ ] Each batch evaluated successfully (or failure documented)
- [ ] Passing batches merged sequentially with post-merge verification
- [ ] Any failures rolled back immediately
- [ ] Final report generated with summary of merged/skipped/failed PRs

## Expected Output

```
╔══════════════════════════════════════════════════════════════╗
║            Dependabot Merge Report — openssl/openssl         ║
╚══════════════════════════════════════════════════════════════╝

1. Configuration
   ✓ Dependabot enabled
   - npm: weekly updates (major versions enabled)
   - pip: daily updates (patch-only)

2. Open PRs Found: 8
   ✓ npm-batch-1: 2 PRs ready
   ✓ pip-batch-1: 1 PR ready
   ⚠ cargo-batch-1: 3 PRs (manual review needed)

3. Test Discovery
   - npm: npm ci && npm test -- --coverage
   - python: pip install -e . && pytest -v
   - cargo: cargo test --all

4. Evaluation Results
   ✓ npm-batch-1: PASS (342 tests, 1.2s)
   ✓ pip-batch-1: PASS (156 tests, 3.4s)
   ✗ cargo-batch-1: FAIL (API incompatibility detected)

5. Merge Results
   ✓ #123 (lodash) merged, CI passed
   ✓ #124 (underscore) merged, CI passed
   ⏭ #125–127 (cargo) skipped (evaluation failed)

Summary
   Total PRs: 8
   Merged: 2
   Skipped: 3 (failing tests)
   Manual review: 3 (major version bumps)

Next steps: Review cargo PRs #125–127 for API compatibility
```

## Tips & Tricks

- **Flaky tests?** Use `--retry-count 2` to re-run failures once
- **Large monorepo?** Evaluation may timeout; use `--timeout 60` to extend
- **Specific ecosystem only?** Ask user: "Filter to only npm PRs?" before starting
- **Dry-run mode?** Evaluate all batches but don't merge; show final report only

## Related Skills

- `Skill("test-driven-development")` — Ensure tests are meaningful
- `Skill("backend-design")` — Evaluate dependency impacts on architecture
- `Skill("security-review")` — Check for security implications of updates
