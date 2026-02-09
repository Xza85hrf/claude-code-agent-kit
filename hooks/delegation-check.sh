#!/bin/bash
# Hook: Delegation and skill check reminder
# UserPromptSubmit hook — runs before every user message
#
# Injects a structured checklist as additionalContext to enforce
# delegation rules and explicit skill invocation. Does not block.

# UserPromptSubmit hooks receive JSON on stdin but we don't need to inspect it.
# We unconditionally output the reminder.

cat << 'JSONEOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "── DELEGATION & SKILL CHECK (enforced by hook) ──\n\nBefore responding, classify this task:\n\n1. DELEGATION CHECK:\n   • Will I generate >10 lines of code? → DELEGATE to Ollama worker (cloud-first: qwen3-coder-next:cloud → local: qwen3-coder-next:latest)\n   • Is this boilerplate/CRUD/scaffolding? → DELEGATE to glm-4.7:cloud (or glm-4.7-flash local)\n   • Does this involve 2+ independent files? → SWARM via parallel ollama_chat calls\n   • Is this a code review request? → DELEGATE to qwen3-coder-next:cloud (or qwen3-coder-next:latest)\n   • Complex collaborative work needing inter-agent comms? → AGENT TEAM (Tier 3)\n   • Can this be done WITHOUT my tools (Read, Edit, Bash, Grep)? → DELEGATE\n\n2. WORK TYPE:\n   • Tool-dependent (Read/Edit/Bash/Grep needed) → I do this myself\n   • Content generation (text-in/text-out) → DELEGATE to Ollama worker\n   • Architecture/reasoning → I do this, optionally consult DeepSeek\n\n3. SKILL CHECK:\n   Skills do NOT auto-activate. If this task matches a skill, I MUST invoke it explicitly:\n   • Implementing/fixing code → Skill(\"test-driven-development\")\n   • Bug or test failure → Skill(\"systematic-debugging\")\n   • Complex multi-step task → Skill(\"writing-plans\")\n   • Executing a plan → Skill(\"executing-plans\")\n   • Code quality/design → Skill(\"solid\")\n   • Security-sensitive code → Skill(\"security-review\")\n   • Before committing → Skill(\"verification-before-completion\")\n   • Parallel agent work or agent teams → Skill(\"dispatching-parallel-agents\")\n   • Plan with independent tasks → Skill(\"subagent-driven-development\")\n\n4. CONTEXT CHECK:\n   • If this is a long session, consider running /cost to check token usage.\n   • At ~70% context usage, suggest /compact to the user.\n   • Delegation to Ollama workers saves 80-98% of context tokens.\n\nRemember: DELEGATE FIRST, CODE LAST. Workers are free; Opus tokens are expensive.\n── END DELEGATION CHECK ──"
  }
}
JSONEOF

exit 0
