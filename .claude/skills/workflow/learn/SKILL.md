---
name: learn
description: "Extract and persist reusable patterns from the current session. Use after solving a tricky problem, discovering a project convention, or when the user says 'remember this'."
argument-hint: "Save the debugging technique I just used for future sessions"
allowed-tools: Bash, Read, Write, Grep, Glob
model: inherit
department: workflow
references: []
thinking-level: medium
---

# Learn

**Announce at start:** "I'm using the learn skill to capture session patterns."

## Pattern Detection

Analyze recent conversation for actionable, non-trivial patterns:

| Category | Examples |
|---|---|
| Error resolutions | "WSL symlinks break with sed -i" |
| Project conventions | "All hooks use jq -n for JSON output" |
| Tool patterns | "Use mcp-cli.sh ollama chat for delegation token before Edit" |
| Architecture decisions | "additionalContext only works on SessionStart" |
| Debugging techniques | "Check hook output with echo {} pipe" |

**Confidence scoring:**
- **High**: Verified solution with clear reasoning, reproducible
- **Medium**: Solution works but context/edge cases unclear
- **Low**: Partial information, needs more validation

## Storage Format

Write to `~/.claude/projects/<project>/memory/<topic>.md`:

```markdown
# <Pattern Title>

**Confidence:** High/Medium/Low
**Date:** YYYY-MM-DD
**Source:** Session observation / User request

## Pattern
Clear description of the technique/convention.

## Example
Concrete code or command showing usage.

## Why It Works
Reasoning behind the approach.
```

Then update `MEMORY.md` index with a reference to the new file.

## Process

1. **Scan context** for non-trivial patterns worth persisting
2. **De-duplicate**: `grep -r "pattern-keyword" ~/.claude/projects/*/memory/`
3. **Present candidates** to user with confidence scores
4. **On approval**: Write topic file + update MEMORY.md index
5. **On existing match**: Offer to update/merge instead of duplicate

## Red Flags

**Never:**
- Persist trivial one-liners (obvious patterns Claude already knows)
- Write without user approval
- Duplicate existing memory entries
- Save session-specific state (current task, temp files) as patterns

**Always:**
- Include confidence level and reasoning
- Check for existing entries before writing
- Respect "don't remember this" requests
- Keep entries concise (pattern + example + reasoning)
