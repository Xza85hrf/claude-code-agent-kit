---
name: writing-plans
description: Complex multi-step tasks. Use when creating implementation plans for features, breaking down large tasks into bite-sized steps, or documenting plans for other engineers to execute.
argument-hint: "Plan the implementation of a notification system with email and push channels"
allowed-tools: Read, Write, Grep, Glob
model: opus
effort: high
context: fork
agent: Plan
department: architecture
references: []
---

# Writing Plans

## Overview

Write comprehensive implementation plans with:
- Exact files to touch per task
- Complete code samples
- Testing approach
- Bite-sized tasks (2-5 minutes each)
- DRY, YAGNI, TDD, frequent commits

Assume skilled developer with zero codebase context.

**Announce:** "I'm using the writing-plans skill to create the implementation plan."

**Save to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

## Requirements

- Exact file paths
- Complete code samples
- Exact commands with expected output
- Reference skills with @ syntax
- DRY, YAGNI, TDD, frequent commits

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven:** Use subagent-driven-development skill. Fresh subagent per task + code review.

**If Parallel Session:** Open new session in worktree. New session uses executing-plans skill.
