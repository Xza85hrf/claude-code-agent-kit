#!/bin/bash
# Hook: Skill and verification check before stopping
# Stop hook — fires when the agent is about to finish responding
#
# Outputs a plain-text verification checklist to stdout.
# Stop hooks do NOT support hookSpecificOutput/additionalContext —
# only PreToolUse, UserPromptSubmit, and PostToolUse do.
# Plain text stdout is added as context (same pattern as SessionStart).

cat << 'EOF'
── COMPLETION CHECKLIST (stop hook) ──

Before finishing, verify:

1. SKILL CHECK: Did I invoke appropriate skills?
   - Code work → Skill("test-driven-development")?
   - Bug/error → Skill("systematic-debugging")?
   - Quality → Skill("solid")?
   - Security → Skill("security-review")?
   - Before commit → Skill("verification-before-completion")?
   (If pure Q&A or simple lookup, no skills needed — OK)

2. DELEGATION CHECK:
   - Did I delegate code gen >10 lines to Ollama workers?
   - If I wrote code myself, was it tool-dependent work?

3. VERIFICATION CHECK:
   - Code edits → tests run or syntax verified?
   - New files → correct location?
   - Promises → all delivered?

If anything was missed, address it now.
── END CHECKLIST ──
EOF

exit 0
