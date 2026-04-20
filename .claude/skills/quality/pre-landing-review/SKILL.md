---
name: pre-landing-review
description: "2-pass pre-landing PR review — Critical (blocks ship) + Informational (advisory). Multi-model verified. Use before committing significant changes, after major features, or before merging to main."
department: quality
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Agent
  - AskUserQuestion
user-invocable: true
argument-hint: "[branch=origin/main]"
thinking-level: high
context: fork
agent: Explore
---

# Pre-Landing Review

2-pass review of current branch against main. Critical findings block `/ship`. Informational findings go in PR body.

## Step 1: Branch Check

```bash
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"
```

If on `main` with no diff: "Nothing to review." and stop.

```bash
git fetch origin main --quiet
git diff origin/main --stat
```

## Step 2: Get Full Diff

```bash
git diff origin/main
```

Read the FULL diff before commenting. Do not flag issues already addressed in the diff.

## Step 3: Two-Pass Review

### Pass 1 — CRITICAL (blocks /ship)

#### SQL & Data Safety
- String interpolation in SQL — must use parameterized queries/prepared statements
- TOCTOU races: check-then-set that should be atomic `WHERE + UPDATE`
- `update_column`/`update_columns` bypassing validations on constrained fields
- N+1 queries: missing eager loading for associations used in loops

#### Race Conditions & Concurrency
- Read-check-write without uniqueness constraint or rescue/retry
- `find_or_create_by` on columns without unique DB index — concurrent duplicates
- Status transitions without atomic WHERE old_status UPDATE new_status
- `html_safe` / `dangerouslySetInnerHTML` on user-controlled data (XSS)

#### LLM Output Trust Boundary
- LLM-generated values (emails, URLs, names) written to DB without format validation
- Structured tool output accepted without type/shape checks before DB writes
- LLM responses used in shell commands or SQL without sanitization

#### Auth & Credential Safety
- Hardcoded secrets, API keys, tokens in source (not env vars)
- Passkey material used for encryption (violates auth/encryption separation mandate)
- Missing input validation on auth endpoints
- Credential introspection patterns (echoing tokens/keys)

### Pass 2 — INFORMATIONAL (advisory)

#### Conditional Side Effects
- Code paths that branch but forget side effects on one branch
- Log messages claiming action happened when action was conditionally skipped

#### Magic Numbers & String Coupling
- Bare numeric literals in multiple files — should be named constants
- Error message strings used as query filters elsewhere

#### Dead Code & Consistency
- Variables assigned but never read
- Comments/docstrings describing old behavior after code changed
- Version mismatch between PR title and VERSION/CHANGELOG

#### Test Gaps
- Missing negative-path tests for side effects
- Security enforcement without integration tests
- Assertions on type/status but not side effects (URL attached? field populated?)

#### Shell & Code Injection
- eval/exec with user input — critical injection risk
- Shell escapes in non-shell code with dangerous arguments (detected by command-security.sh)
- Chained commands that could bypass deny patterns

#### Frontend/View
- innerHTML/dangerouslySetInnerHTML without sanitization
- Inline styles in components (re-parsed every render)
- O(n*m) lookups in render loops (Array#find in loop instead of index/Map)

#### Crypto & Entropy
- md5/sha1 for passwords — use bcrypt/argon2/scrypt
- Math.random() for security tokens — use crypto.randomBytes/SecureRandom
- Non-constant-time comparisons on secrets (timing attacks)

## Step 4: Output Format

```
Pre-Landing Review: N issues (X critical, Y informational)

**CRITICAL** (blocking):
- [file:line] Problem description
  Fix: suggested fix

**INFORMATIONAL** (advisory):
- [file:line] Problem description
  Fix: suggested fix
```

If no issues: `Pre-Landing Review: No issues found.`

Be terse. One line problem, one line fix. No preamble.

## Step 5: Critical Issue Resolution

For EACH critical issue, use AskUserQuestion:
- **A**: Fix it now (apply recommended fix)
- **B**: Acknowledge (proceed anyway)
- **C**: False positive — skip

After all questions answered, apply fixes for any "A" choices.

## Step 6: TODOS Cross-Reference

If `TODOS.md` exists in repo root:
- Does this PR close any open TODOs? → "This PR addresses TODO: <title>"
- Does this PR create work that should become a TODO?
- Are there related TODOs providing context?

## Suppressions — DO NOT Flag

- Redundant guards that aid readability and defense-in-depth
- "Add comment explaining threshold" — thresholds change, comments rot
- "This assertion could be tighter" when assertion already covers behavior
- Consistency-only changes with no functional impact
- Eval/scoring threshold changes — tuned empirically
- Harmless no-ops in defensive code
- Shell execution in hook/script infrastructure files
- Localhost in config/dev/test files
- Debug flags in test files
- **Anything already addressed in the diff being reviewed**

Read `.claude/config/review-suppressions.yml` for project-specific suppressions.

## AI-Generated Code Disclosure

If the diff contains AI-generated code, verify the submitter has:

- [ ] Personally reviewed every line and can explain it
- [ ] Tested functionality locally with evidence
- [ ] Checked for hallucinated imports (packages that don't exist)
- [ ] Removed placeholder comments and templates
- [ ] Verified alignment with project architecture

**PR size guard:** >15 files or >400 changed lines → flag as potential "AI dump". Require the submitter to explain each changed file.

**Emergency override:** `[EMERGENCY-AI]` prefix in PR title — still needs basic testing evidence + 24h follow-up review.

## Dispatching Review

### Multi-Model Audit (recommended for significant changes)

```bash
# Review last commit with 4+ cheap models in parallel
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/multi-model-audit.sh" --diff HEAD~1

# Review with specific focus areas
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/multi-model-audit.sh" --diff HEAD~3 --focus "security,performance,bugs"

# Review specific files
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/multi-model-audit.sh" --files "src/auth.ts src/db.ts"
```

Consensus: issues flagged by 2+ models are confirmed; 1 model = possible.

### Acting on Feedback

| Level | Action |
|-------|--------|
| Critical | Fix immediately |
| Important | Fix before proceeding |
| Minor | Note for later |
| Disagreement | Push back with reasoning |

## Rules

- **Read the FULL diff before commenting.** Do not flag issues already addressed.
- **Read-only by default.** Only modify files if user explicitly chooses "Fix it now."
- **Be terse.** One line problem, one line fix. No preamble, no "looks good overall."
- **Only flag real problems.** Skip anything that's fine.
- **For critical findings**: verify with `bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/thinktank.sh" --question "..."` when available.
