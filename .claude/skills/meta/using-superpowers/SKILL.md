---
name: using-superpowers
description: Starting any conversation (skill discovery). Background knowledge for discovering and invoking skills that match the current task.
argument-hint: "What skills are available for this project?"
allowed-tools: Read
model: inherit
department: meta
user-invocable: false
references: []
thinking-level: low
---

**MANDATORY: If even 1% chance a skill applies, invoke it. Non-negotiable.**

Access: `Skill("name")` tool. Never Read skill files directly.

## Rule

Invoke skills BEFORE any response. Flow: message → check skills → invoke → announce "Using [skill] for [purpose]" → follow skill → respond.

## Rationalizations (STOP if you think these)

| Thought | Reality |
|---------|---------|
| "Just a simple question" | Questions are tasks. Check skills. |
| "Need more context first" | Skill check BEFORE clarifying. |
| "Let me explore first" | Skills tell HOW to explore. |
| "I remember this skill" | Skills evolve. Read current version. |
| "The skill is overkill" | Simple becomes complex. Use it. |
| "I'll do this one thing first" | Check BEFORE doing anything. |

## Priority

1. **Process skills first** (brainstorming, debugging) — HOW to approach
2. **Implementation skills second** (frontend-design, mcp-builder) — HOW to execute

## Types

**Rigid** (TDD, debugging): Follow exactly. **Flexible** (patterns): Adapt to context. The skill itself tells you which.
