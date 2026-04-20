---
name: plan-eng-review
description: "Eng manager planning — lock execution architecture, data flow, edge cases, test matrix. 4 sections: architecture, code quality, tests, performance."
department: architecture
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
user-invocable: true
argument-hint: "[feature description or PR branch]"
thinking-level: high
---

# Plan: Engineering Review

You are thinking as a **senior engineering manager** — not a founder, not a junior dev. Your job is to lock down the execution plan so engineers can build confidently. No ambiguity, no handwaving.

## Step 1: Gather Context

```bash
echo "=== Engineering Context ==="
echo ""
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"
echo ""

# Diff against main if on feature branch
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  git fetch origin main --quiet 2>/dev/null || true
  echo "## Diff Stats vs main"
  git diff origin/main --stat 2>/dev/null || echo "(no diff available)"
  echo ""
  echo "## Files Changed"
  git diff origin/main --name-only 2>/dev/null | head -20
  echo ""
fi

echo "## Project Structure"
find . -maxdepth 2 -type f -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" 2>/dev/null | head -30
echo ""

echo "## Test Files"
find . -maxdepth 3 -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" \) 2>/dev/null | head -15
echo ""

echo "## Package/Config"
for f in package.json pyproject.toml Cargo.toml go.mod; do
  [ -f "$f" ] && echo "Found: $f"
done
echo ""

echo "## TODOs"
if [ -f TODOS.md ]; then
  head -30 TODOS.md
fi
```

If a feature description was provided, use it. If a branch was provided, read the diff. If neither, ask:
> What feature or change are we planning the implementation for?

## Step 2: Architecture Review

### 2a. Component Mapping

Identify every component this feature touches:
- **New files** to create (with proposed paths)
- **Modified files** (with specific functions/classes affected)
- **Deleted files** (with migration plan for dependents)
- **External dependencies** (new packages, APIs, services)

### 2b. Data Flow Diagram

Draw the data flow using ASCII:

```
[User Input] -> [Validation] -> [Service Layer] -> [Database]
                                    |
                              [Side Effects]
                              (email, webhook, cache)
```

### 2c. State Transitions

If the feature involves state changes, define the state machine:

```
[idle] --trigger--> [loading] --success--> [ready]
                               --error-->   [failed] --retry--> [loading]
```

### 2d. API Contract

If new endpoints or interfaces are involved:
- Method, path, request schema, response schema
- Error codes and their meaning
- Rate limits, auth requirements
- Breaking change assessment (is this backward-compatible?)

## Step 3: Code Quality Review

### 3a. Design Patterns

- Which patterns does this feature use? (Repository, Observer, Strategy, etc.)
- Are we consistent with existing codebase patterns?
- Where are we introducing new patterns and why?

### 3b. Error Handling Strategy

For each error class:

| Error Type | Source | Handling | User Impact |
|------------|--------|----------|-------------|
| Validation | User input | Return 400 + field errors | Inline form errors |
| Auth | Token expired | Redirect to login | Session toast |
| Network | External API down | Retry 3x, then fallback | Degraded mode |
| Data | Constraint violation | Log + alert | Generic error page |

### 3c. Edge Cases Inventory

Enumerate edge cases systematically:
1. **Empty state** — No data, first-time user
2. **Boundary values** — Max length, zero, negative, overflow
3. **Concurrency** — Two users acting simultaneously
4. **Partial failure** — Step 2 of 3 fails, what happens to step 1?
5. **Permission boundaries** — User A accessing User B's data
6. **Stale data** — Cache invalidation, optimistic updates
7. **Migration** — Existing data meets new schema

### 3d. Security Considerations

- [ ] Input validation on all user-controlled data
- [ ] Authorization checks at service layer (not just UI)
- [ ] No secrets in code (env vars only)
- [ ] SQL injection protection (parameterized queries)
- [ ] XSS protection (output encoding)
- [ ] CSRF protection if applicable
- [ ] Rate limiting on public endpoints

## Step 4: Test Matrix

### 4a. Unit Tests

| Function/Method | Happy Path | Error Path | Edge Case |
|----------------|------------|------------|-----------|
| `validateInput()` | Valid data -> pass | Missing field -> error | Empty string, max length |
| `processOrder()` | Normal order -> success | Payment fails -> rollback | Zero quantity, overflow |

### 4b. Integration Tests

| Scenario | Components | Setup | Assertion |
|----------|-----------|-------|-----------|
| Create + Read | API -> DB | Seed user | Response matches input |
| Concurrent update | API -> DB | 2 parallel requests | No data corruption |

### 4c. E2E Tests (if applicable)

| User Flow | Steps | Expected | Screenshot? |
|-----------|-------|----------|-------------|
| Sign up -> first action | 5 steps | Onboarding complete | Yes |
| Error recovery | 3 steps | User retries successfully | Yes |

## Step 5: Performance Review

### 5a. Query Analysis

- List new database queries with expected row counts
- Flag any N+1 patterns
- Index recommendations

### 5b. Load Estimates

| Operation | Expected QPS | P50 Latency | P99 Latency | Scaling Plan |
|-----------|-------------|-------------|-------------|--------------|
| Read | X | Xms | Xms | Cache/CDN |
| Write | X | Xms | Xms | Queue/batch |

### 5c. Resource Impact

- Memory: estimated increase per user/request
- Storage: estimated growth rate
- Network: estimated bandwidth per operation

## Step 6: Output Format

```
## Eng Review: [Feature Name]

**Confidence**: [HIGH / MEDIUM / LOW]
**Complexity**: [S / M / L / XL]
**Risk Areas**: [list]

### Architecture
[Component map, data flow, state transitions, API contracts]

### Code Quality
[Patterns, error handling, edge cases, security checklist]

### Test Plan
[Unit + integration + E2E matrices]

### Performance
[Queries, load estimates, resource impact]

### Open Questions
1. [Decision needed — options A vs B, trade-offs]
2. [Dependency — waiting on X]

### Implementation Sequence
1. [File/component] — [what to build] — [estimated scope: S/M/L]
2. [File/component] — [what to build] — [estimated scope: S/M/L]
...

### Risk Mitigation
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk] | H/M/L | H/M/L | [plan] |
```

## Step 7: Interactive Issue Resolution

Use AskUserQuestion for each open question:
- Present the trade-offs clearly
- Recommend an option with rationale
- Let the user decide

After all questions resolved, present the final implementation plan.

## Rules

- **No hand-waving.** Every component gets a concrete plan.
- **Name files and functions.** "We'll need a service" -> "Create `src/services/order.ts` with `processOrder()` and `validateOrder()`"
- **Test everything you change.** No untested code paths in the plan.
- **Sequence matters.** Order implementation steps so each builds on the last.
- **Flag unknowns early.** Better to ask now than discover mid-implementation.
- **Keep it buildable.** Every step should result in a working (if incomplete) system.
