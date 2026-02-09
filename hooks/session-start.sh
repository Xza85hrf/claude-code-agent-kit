#!/bin/bash
# Hook: Provide guidance at session start
# SessionStart hook

# For SessionStart, stdout text is added as context for Claude
cat << 'EOF'
Session initialized with quality hooks active:
- Git safety (blocks destructive operations)
- Secret detection (warns about credentials in code)
- Security checks (SQL injection, command injection)
- Test reminders (after code changes)
- GitHub URL validation (verify paths before fetching)
- Delegation enforcement (reminds to delegate code gen >10 lines to Ollama workers)
- Skill invocation reminders (skills require explicit Skill() calls, not auto-activation)
- Agent teams quality gates (when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)

Best practices:
- Use 'gh api repos/owner/repo/contents' to verify GitHub repo structure before fetching
- Always read files before editing
- Run tests after making changes
- Follow conventional commits format
- DELEGATE code generation >10 lines to Ollama workers (cloud-first: qwen3-coder-next:cloud → local: qwen3-coder-next:latest)
- Use parallel ollama_chat swarm for multi-file tasks
- Cloud models available when OLLAMA_API_KEY is set; 3-tier fallback: cloud → local
- Invoke skills explicitly with Skill("skill-name") — they do NOT auto-activate
- For complex collaborative work, consider agent teams (Tier 3) — Skill("dispatching-parallel-agents")
EOF

exit 0
