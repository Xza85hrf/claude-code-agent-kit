---
name: receiving-code-review
description: Processing code review feedback. Use when receiving review comments, evaluating suggested changes against codebase reality, or implementing review feedback methodically.
argument-hint: "Address the 5 review comments on PR #42, prioritizing the security findings"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: quality
references: []
thinking-level: medium
---

# Code Review Reception

Code review requires technical evaluation, not emotional performance.

**Core principle:** Verify before implementing. Ask before assuming. Technical correctness over social comfort.

## The Response Pattern

```
1. READ: Complete feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY: Check against codebase reality
4. EVALUATE: Technically sound for THIS codebase?
5. RESPOND: Technical acknowledgment or reasoned pushback
6. IMPLEMENT: One item at a time, test each
```

## Forbidden Responses

**NEVER say:**
- "You're absolutely right!" (CLAUDE.md violation)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement
- Ask clarifying questions
- Push back with technical reasoning if wrong
- Just start working (actions > words)

## Handling Unclear Feedback

```
IF any item is unclear:
  STOP - do not implement anything yet
  ASK for clarification on unclear items

WHY: Items may be related. Partial understanding = wrong implementation.
```

**Example:**
```
Partner: "Fix 1-6"
You understand 1,2,3,6. Unclear on 4,5.

❌ WRONG: Implement 1,2,3,6 now, ask about 4,5 later
✅ RIGHT: "I understand items 1,2,3,6. Need clarification on 4 and 5 before proceeding."
```

## From Your Human Partner

- Trusted — implement after understanding
- Still ask if scope unclear
- No performative agreement
- Skip to action or technical acknowledgment

## From External Reviewers

**BEFORE implementing:**
1. Technically correct for THIS codebase?
2. Breaks existing functionality?
3. Reason for current implementation?
4. Works on all platforms/versions?
5. Does reviewer understand full context?

**If suggestion seems wrong:** Push back with technical reasoning.

**If can't easily verify:** "I can't verify this without [X]. Should I [investigate/ask/proceed]?"

**If conflicts with partner's prior decisions:** Stop and discuss with partner first.

## YAGNI Check

```
IF reviewer suggests "implementing properly":
  grep codebase for actual usage

  IF unused: "This endpoint isn't called. Remove it (YAGNI)?"
  IF used: Then implement properly
```

## Implementation Order

1. Clarify anything unclear FIRST
2. Then implement in order:
   - Blocking issues (breaks, security)
   - Simple fixes (typos, imports)
   - Complex fixes (refactoring, logic)
3. Test each fix individually
4. Verify no regressions

## When To Push Back

Push back when:
- Suggestion breaks existing functionality
- Reviewer lacks full context
- Violates YAGNI (unused feature)
- Technically incorrect for this stack
- Legacy/compatibility reasons exist
- Conflicts with architectural decisions

**How:** Use technical reasoning, ask specific questions, reference working tests/code, involve partner if architectural.

## Acknowledging Correct Feedback

When feedback IS correct:
```
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch - [specific issue]. Fixed in [location]."
✅ [Just fix it and show in the code]

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ ANY gratitude expression
```

Why no thanks: Actions speak. The code itself shows you heard the feedback.

## Correcting Your Pushback

If you pushed back and were wrong:
```
✅ "You were right - I checked [X] and it does [Y]. Implementing now."
✅ "Verified and you're correct. My understanding was wrong because [reason]. Fixing."

❌ Long apology
❌ Defending why you pushed back
❌ Over-explaining
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Assuming reviewer is right | Check if breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |

## GitHub Replies

Reply to inline review comments in the comment thread, not as top-level PR comment.

## The Bottom Line

External feedback = suggestions to evaluate, not orders to follow.

Verify. Question. Then implement. No performative agreement. Technical rigor always.
