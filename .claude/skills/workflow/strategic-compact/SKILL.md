---
name: strategic-compact
description: Intelligent context compaction strategy — when and how to compact for optimal session performance. Use during long sessions, at context pressure points, or before complex multi-step tasks.
argument-hint: "Compact context before complex multi-step refactoring task"
department: workflow
thinking-level: medium
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Strategic Compact

## When to Activate
- Long sessions (>30 min or extensive dialogue)
- Context usage >70%
- After large explorations or file reads (>500 lines)
- Before complex multi-step tasks needing clean context

## Compact Signals

| Signal | Threshold | Action |
|--------|-----------|--------|
| Tool call count | >50 | `suggest-compact.sh` hook triggers |
| Context usage | >70% | Run `/compact` proactively |
| Major task phase | Completed | Compact before next phase |
| New unrelated task | Starting | Compact for clean slate |
| Large file reads | >500 lines | Consider compact |

## Pre-Compact Checklist
- State auto-saved by `pre-compact-save.sh` hook
- Note current task, git branch, modified files
- Identify context to preserve in compact summary
- Commit or stash uncommitted work if needed

## Post-Compact Recovery
1. Read `.claude/.pre-compact-state.json` for prior state
2. Re-read critical files: `CLAUDE.md`, current task file
3. Resume via `TaskList`
4. Run `git status` for orientation
5. Check `git diff` for in-progress changes

## Preserve vs Drop

| PRESERVE | DROP |
|----------|------|
| Task context/goals | Exploration results already acted on |
| Architectural decisions | Verbose tool outputs |
| File paths discovered | Superseded plans |
| Error patterns found | Completed step details |
| Unresolved blockers | Redundant confirmations |

## Integration
- `suggest-compact.sh` — monitors tool calls, suggests timing
- `pre-compact-save.sh` — saves state before compact
- `session-end-persist.sh` — resets counter on session end
- `context-management.md` rule — governing policy
