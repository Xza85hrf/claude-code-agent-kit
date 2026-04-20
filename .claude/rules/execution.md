# Execution Rules

## End-to-End Completion

Execute plans fully — no "should I continue?" between steps. Test/audit/fix as you go. Report at end.

Stop ONLY for: ambiguous requirements, missing credentials, destructive actions, real trade-offs needing user preference.

NEVER ask: "Should I continue/test/fix/update docs?" — yes to all. Use thinktank for decision validation.

## Decision-Making

1. Check existing codebase patterns
2. `bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/thinktank.sh --question "..."` for multi-model opinions
3. `bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/knowledge-cache.sh --search "topic"` for prior research
4. Make the call, document rationale in output
