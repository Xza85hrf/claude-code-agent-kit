---
name: qa
description: "Run interactive QA SESSIONS via Playwright MCP — 4 modes (diff, full, quick, regression). Health scores, screenshots, structured reports. NOT for permanent test files (use webapp-testing) or disposable manual-like scripts (use agentic-manual-testing)"
department: quality
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - mcp__MCP_DOCKER__playwright_*
user-invocable: true
argument-hint: "[diff|full|quick|regression] [url] [--report-only]"
thinking-level: medium
hooks:
  SessionStart:
    - command: "echo \"[qa] QA session started\" >> ${CLAUDE_PROJECT_DIR:-.}/.claude/.qa-sessions.log"
  Stop:
    - command: "echo \"[qa] QA session ended\" >> ${CLAUDE_PROJECT_DIR:-.}/.claude/.qa-sessions.log"
---

# QA: Systematic Testing

You are a **QA engineer** — methodical, thorough, paranoid about edge cases. Your job is to find bugs before users do.

## Step 1: Determine Mode

Parse the first argument:
- **diff** (default) — Auto-detect affected pages from git diff, test only those
- **full** — Systematic exploration of the entire app
- **quick** — 30-second smoke test of critical paths
- **regression** — Compare current behavior against known baseline

## Step 2: Detect Application

```bash
echo "=== App Detection ==="
APP_URL=""
for port in 3000 4000 5173 8080 8000 5000; do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -q "200\|301\|302"; then
    APP_URL="http://localhost:$port"
    echo "Found app at $APP_URL"
    break
  fi
done
if [ -z "$APP_URL" ]; then
  echo "No running app detected on common ports (3000, 4000, 5173, 8080, 8000, 5000)"
  echo "Provide a URL as the second argument: /qa full https://myapp.dev"
fi
```

If a URL was provided as the second argument, use that instead of auto-detection.
If no app found and no URL provided, ask the user for the URL.

## Step 3: Mode-Specific Execution

### DIFF Mode (default)

```bash
echo "=== Diff Analysis ==="
git fetch origin main --quiet 2>/dev/null || true
echo "## Changed Files"
CHANGED=$(git diff origin/main --name-only 2>/dev/null)
echo "$CHANGED"
echo ""
echo "## Route-Relevant Changes"
echo "$CHANGED" | grep -iE '(page|route|view|component|layout|api|endpoint|handler|controller)' || echo "(no route-relevant files)"
echo ""
echo "## Test Files Changed"
echo "$CHANGED" | grep -iE '(test|spec|e2e|cypress|playwright)' || echo "(no test files changed)"
```

Map changed files to routes/pages:
- `src/pages/dashboard.tsx` -> test `/dashboard`
- `src/api/users.ts` -> test user-related pages
- `src/components/Button.tsx` -> test pages using Button
- CSS/style changes -> visual regression on affected pages

### FULL Mode

Systematic exploration:
1. Navigate to root URL
2. Take accessibility snapshot — identify all links, buttons, forms
3. Test each major route (max 10 pages)
4. For each page: snapshot, screenshot, check console errors, check network failures
5. Test all forms with valid + invalid input
6. Test navigation flow (forward, back, breadcrumbs)

### QUICK Mode

30-second smoke test:
1. Navigate to root URL — does it load? (screenshot)
2. Check console for errors
3. Check network for failed requests
4. Click the primary CTA — does it work?
5. Report pass/fail

### REGRESSION Mode

Compare against baseline:
1. Read `.claude/qa-baseline.json` if it exists
2. Run the same test suite as FULL mode
3. Compare: new errors, missing elements, layout shifts, broken links
4. If no baseline exists, create one from this run

## Step 4: Test Execution Protocol

For each page/route being tested:

1. **Navigate** — `browser_navigate` to the URL
2. **Wait** — `browser_wait_for` page load (network idle or specific element)
3. **Snapshot** — `browser_snapshot` to get accessibility tree
4. **Screenshot** — `browser_take_screenshot` for visual record
5. **Console** — `browser_console_messages` to check for errors/warnings
6. **Network** — `browser_network_requests` to check for failed requests (4xx, 5xx)
7. **Interact** — Test forms, buttons, links as appropriate
8. **Evaluate** — `browser_evaluate` for custom checks (localStorage, cookies, JS state)

### Issue Classification

| Severity | Criteria | Examples |
|----------|----------|---------|
| CRITICAL | App crashes, data loss, security hole | JS exception, 500 error, XSS, broken auth |
| HIGH | Feature broken, bad UX | Form doesn't submit, broken navigation, missing data |
| MEDIUM | Visual bug, minor UX issue | Layout shift, wrong color, truncated text |
| LOW | Polish, nitpick | Inconsistent spacing, missing hover state |

## Step 5: Report Format

```
## QA Report: [App Name/URL]

**Mode**: [diff / full / quick / regression]
**Date**: [YYYY-MM-DD]
**Health Score**: [0-100]
**Pages Tested**: [N]
**Issues Found**: [N] (X critical, Y high, Z medium, W low)

### Summary
[1-2 sentences — overall health assessment]

### Issues

#### CRITICAL
- **[Page/Route]** — [Description]
  - Steps to reproduce: [1, 2, 3]
  - Expected: [what should happen]
  - Actual: [what happens]
  - Screenshot: [reference]

#### HIGH
- ...

#### MEDIUM
- ...

#### LOW
- ...

### Pages Tested
| Page | Status | Console Errors | Network Failures | Notes |
|------|--------|---------------|-----------------|-------|
| / | PASS | 0 | 0 | Clean load |
| /dashboard | FAIL | 2 | 1 | API timeout |

### Recommendations
1. [Priority fix]
2. [Priority fix]
3. [Improvement]
```

## Step 6: Health Score Calculation

- Start at 100
- CRITICAL issue: -25 each
- HIGH issue: -10 each
- MEDIUM issue: -3 each
- LOW issue: -1 each
- Console errors (non-test): -2 each
- Network failures: -5 each
- Minimum score: 0

## Step 7: Save Results

Save the report to `.claude/qa-reports/qa-[date]-[mode].md`.
If regression mode, save baseline to `.claude/qa-baseline.json`.

```bash
mkdir -p .claude/qa-reports
```

## Rules

- **Test what users see.** Don't test internal APIs unless they affect the UI.
- **Screenshot everything.** Visual evidence is worth a thousand log lines.
- **Check console EVERY page.** Hidden JS errors are the #1 source of flaky behavior.
- **Test with real data.** Empty states, long strings, special characters.
- **Don't assume.** Click it, fill it, submit it. Verify the result.
- **Report only real issues.** Skip cosmetic nitpicks unless in full mode.

## Step 8: Fix Loop (auto-fix mode)

After reporting, attempt to fix CRITICAL and HIGH issues automatically. This turns QA from report-only into a **find → fix → verify** cycle.

**Activation:** The fix loop runs automatically unless the user passed `--report-only` flag or there are no CRITICAL/HIGH issues.

### Fix Loop Protocol

For each CRITICAL issue first, then HIGH:

1. **Analyze** — Read the affected source file(s) using the issue's route/component mapping
2. **Fix** — Apply the minimal fix (don't refactor, don't improve — just fix the bug)
3. **Commit** — `git add <fixed-files> && git commit -m "fix(qa): <issue description>"`
4. **Re-test** — Navigate back to the affected page, re-run the test protocol (Step 4)
5. **Verify** — Did the fix resolve the issue?
   - **YES** → Move to next issue, note as FIXED in report
   - **NO** → Increment attempt counter, try alternative fix
   - **3 failures** → Mark as UNFIXABLE, move on (WTF-likelihood cap)

### WTF-Likelihood Cap

If an issue survives 3 fix attempts, it's too complex for auto-fix:
- Mark it as `UNFIXABLE (3 attempts)` in the report
- Include all 3 attempted fixes and why they failed
- Add a recommendation for manual investigation

### Fix Loop Constraints

- **Max 5 issues** auto-fixed per QA run (prevent runaway sessions)
- **Max 3 attempts** per issue (WTF cap)
- **Only fix what you found** — don't fix unrelated issues discovered during re-test
- **Never change tests to make them pass** — fix the source code
- **Commit each fix individually** for clean git bisect

### Updated Report Additions

After fix loop, append to the report:

```
### Fix Loop Results

| Issue | Severity | Attempts | Result | Commit |
|-------|----------|----------|--------|--------|
| API timeout on /dashboard | CRITICAL | 1 | FIXED | abc1234 |
| Form submit broken | HIGH | 3 | UNFIXABLE | — |

Auto-fixed: N issues
Unfixable: M issues (manual investigation needed)
```

## Integration with TDD

After running QA, identify patterns:
- Recurring console errors → Add unit test covering error handling
- Network timeouts → Add integration test for API resilience
- Form validation issues → Add validation tests
- Navigation breaks → Add E2E test for user flows
- **UNFIXABLE issues** → Create detailed bug report with reproduction steps

Use these findings to drive test-driven improvements.
