---
name: systematic-debugging
description: Errors or unexpected behavior. Use when investigating bugs, tracing root causes, diagnosing test failures, or resolving unexpected system behavior methodically.
argument-hint: "Debug why the /api/users endpoint returns 500 intermittently under load"
allowed-tools: Read, Bash, Grep, Glob
model: opus
effort: high
department: engineering
references:
  - condition-based-waiting.md
  - defense-in-depth.md
  - root-cause-tracing.md
  - third-party-pivot.md
thinking-level: high
---

# Systematic Debugging

## Overview

Quick patches mask underlying issues. ALWAYS find root cause before fixing. Symptom fixes are failure.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

ANY technical issue: test failures, production bugs, unexpected behavior, performance issues, build failures, integration issues.

**ESPECIALLY:** time pressure, multiple failed fixes, incomplete understanding
**NEVER skip:** simple issues, time constraints, deadline pressure

## The Four Phases

You MUST complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

1. **Read Error Messages** — Don't skip. Note line numbers, file paths, error codes.
2. **Reproduce Consistently** — Verify exact steps. If not reproducible, gather more data.
3. **Check Recent Changes** — Git diff, dependencies, config, environment.

4. **Gather Evidence in Multi-Component Systems**

   **WHEN system has multiple components (CI → build → signing, API → service → database):**

   **BEFORE proposing fixes, add diagnostic instrumentation:**
   ```
   For EACH component boundary:
     - Log what data enters component
     - Log what data exits component
     - Verify environment/config propagation
     - Check state at each layer

   Run once to gather evidence showing WHERE it breaks
   THEN analyze evidence to identify failing component
   THEN investigate that specific component
   ```

   **Example (multi-layer system):**
   ```bash
   # Layer 1: Workflow
   echo "=== Secrets available in workflow: ==="
   echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

   # Layer 2: Build script
   echo "=== Env vars in build script: ==="
   env | grep IDENTITY || echo "IDENTITY not in environment"

   # Layer 3: Signing script
   echo "=== Keychain state: ==="
   security list-keychains
   security find-identity -v

   # Layer 4: Actual signing
   codesign --sign "$IDENTITY" --verbose=4 "$APP"
   ```

   **This reveals:** Which layer fails (secrets → workflow ✓, workflow → build ✗)

5. **Trace Data Flow**

   **WHEN error is deep in call stack:**

   See `root-cause-tracing.md` in this directory for the complete backward tracing technique.

   **Quick version:**
   - Where does bad value originate?
   - What called this with bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

### Phase 2: Pattern Analysis

1. **Find Working Examples** — Locate similar code in same codebase.
2. **Compare References** — Read reference implementation completely.
3. **Identify Differences** — List every difference, no matter how small.
4. **Understand Dependencies** — Components needed, config, assumptions.

### Phase 3: Hypothesis and Testing

1. **Form Single Hypothesis** — State clearly why X causes the issue. Write it down.
2. **Test Minimally** — Smallest possible change. One variable at a time.
3. **Verify Before Continuing** — Works? Move to Phase 4. Doesn't? New hypothesis.
4. **When Stuck** — Say "I don't understand X". Research or ask for help.

### Phase 4: Implementation

1. **Create Failing Test** — Must have before fixing.
2. **Implement Single Fix** — One change. No "while I'm here" improvements.
3. **Verify Fix** — Test passes? No regressions?
4. **If Fix Fails** — < 3 attempts: return to Phase 1. ≥ 3 attempts: STOP, question architecture.
5. **Architectural Problem** — Each fix reveals coupling/symptoms in new places → refactor, don't continue fixing.

## Red Flags

STOP if thinking: "Quick fix", "Just try X", "Multiple changes at once", "Skip test", "Probably X", "Don't fully understand", "Adapt pattern differently", "Propose fixes without investigation", "One more fix attempt" (≥3 tried), "Each fix reveals new problems"

**Action:** Return to Phase 1. If ≥3 fixes failed: Question architecture.

## Human Signals You're Off Track

- "Is that not happening?" → You assumed without verifying
- "Will it show us...?" → Add evidence gathering
- "Stop guessing" → Propose fixes without understanding
- "Ultrathink this" → Question fundamentals
- "We're stuck?" → Your approach isn't working

**Action:** Return to Phase 1.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question pattern, don't fix again. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |

## When Process Reveals "No Root Cause"

If investigation shows environmental/timing/external issue: document findings, implement handling (retry/timeout/errors), add monitoring. 95% of "no root cause" cases are incomplete investigation.

## Supporting Techniques

These techniques are part of systematic debugging and available in this directory:

- **`root-cause-tracing.md`** - Trace bugs backward through call stack to find original trigger
- **`defense-in-depth.md`** - Add validation at multiple layers after finding root cause
- **`condition-based-waiting.md`** - Replace arbitrary timeouts with condition polling
- **`third-party-pivot.md`** - When to replace a third-party asset instead of continuing to debug it (3-attempt rule, platform-specific bugs)

**Related skills:**
- **superpowers:test-driven-development** - For creating failing test case (Phase 4, Step 1)
- **superpowers:test-driven-development** - Verify fix worked before claiming success

## Impact

| Metric | Systematic | Random |
|--------|-----------|--------|
| Time to fix | 15-30 min | 2-3 hours |
| First-time success | 95% | 40% |
| New bugs | ~0 | Common |

## Worked Examples

<example>
Context: An API endpoint returns 500 errors intermittently — roughly 1 in 20 requests fails, but only during peak hours.

**Phase 1 — Root Cause Investigation:**
- Read the error logs: `ConnectionPoolExhausted: no available connections after 5000ms timeout`.
- Reproduce: Run 50 concurrent requests with `ab -n 50 -c 50`. Failure appears at concurrency > 30.
- Check recent changes: A new middleware was added last week that makes a sub-query per request but never closes its connection.

**Phase 2 — Pattern Analysis:**
- Compare the new middleware to an older middleware that also queries the DB. The older one uses `finally { connection.release() }`. The new one does not.

**Phase 3 — Hypothesis and Testing:**
- Hypothesis: "The new middleware leaks DB connections because it never calls `release()`."
- Minimal test: Add `connection.release()` in a `finally` block. Re-run the 50-concurrent-request load test. Zero failures.

**Phase 4 — Implementation:**
- Write a test that opens connections in a loop without releasing, asserting the pool exhausts. Verify it fails before the fix, passes after.
- Apply the single-line `finally` fix. All tests green, load test clean.

<commentary>
The key insight is that "intermittent" + "only under load" immediately points to a resource contention issue. Starting with reproduction under controlled concurrency narrows the hypothesis space from "anything" to "something that scales with parallelism" — which is almost always connections, locks, or memory. Reading the error message carefully (ConnectionPoolExhausted) then gives you the answer directly. Most developers skip the reproduction step and guess at application logic bugs, wasting hours.
</commentary>
</example>

## Available Tools

- **context7**: When debugging framework-specific behavior, fetch current docs: `resolve-library-id` → `query-docs`
- **deepseek-reasoner**: When stuck after 3+ hypotheses fail, get a second opinion on the diagnosis
- **mcp-cli.sh ollama chat**: Delegate isolated code analysis to a worker when investigating multiple files

## Decision Framework

- If error in tests only → Check test fixture staleness, mock configuration, test environment
- If error in production only → Check environment variables, config differences, external service state
- If error everywhere → Check recent git changes: `git log --oneline -5`, bisect if needed
- If error is intermittent → Suspect resource contention: connection pools, race conditions, timeouts
- If error message is vague → Add targeted logging at suspected boundary, reproduce, read logs
- If fix attempts aren't working → STOP. Re-read the actual error. Restate the hypothesis. You may be solving the wrong problem.
