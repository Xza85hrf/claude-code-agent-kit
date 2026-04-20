# Session & Context Management

## Session Naming

Sessions have descriptive names. `session-namer.sh` auto-names from initial prompt.

## Context Continuity

| File | Purpose | When Updated |
|------|---------|-------------|
| `docs/project-state.md` | Branch, changes, health snapshot | SessionStart (auto) |
| `.claude/.session-summary.json` | Last session summary | SessionEnd |
| `.claude/observations.jsonl` | Session observations log | Stop hook |

## Compaction

At ~70% context usage → run `/compact`. After compaction: re-read critical files (CLAUDE.md, current task context). PreCompact hooks save state; PostCompact hooks restore it.

## Context Efficiency

- Delegate code gen to workers (saves 80-98% tokens)
- Parallel agents for multi-file analysis
- On-demand MCPs only; <10 servers, <80 tools
- `/cost` `/compact` `/status` `/clear`

## Embedding and Search

- `auto-embed-start.sh` indexes key files at session start
- `Skill("semantic-search-local")` for concept-based code search
- Knowledge cache at `.claude/.knowledge/` for cross-session persistence

## Enforced by

`session-namer.sh`, `auto-embed-start.sh` (SessionStart), `pre-compact-save.sh` (PreCompact), `post-compact-restore.sh` (PostCompact).
