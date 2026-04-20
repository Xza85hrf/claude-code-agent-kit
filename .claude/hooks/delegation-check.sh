#!/bin/bash
# Hook: Delegation + workflow + team router (hot-loading)
# UserPromptSubmit hook — classifies task, injects delegation/workflow/team directives
#
# DESIGN: This hook handles ONLY delegation routing (worker spawning, graduated
# thresholds, team suggestions, workflow detection). Skill routing is handled
# entirely by skill-eval.js via skill-rules.json — no duplication.
#
# Language: "DELEGATE" / "SPAWN TEAM" / "WORKFLOW" — autonomous, not advisory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
USER_MSG=$(echo "$INPUT" | jq -r '.user_message // empty' 2>/dev/null)

# Exit early for empty messages
[ -z "$USER_MSG" ] && exit 0

# Skip obvious non-code commands that need no delegation check
if echo "$USER_MSG" | grep -qiE "^(git |ls |pwd|cat |head |tail |find |grep |chmod |mkdir |cd )"; then
  exit 0
fi

# ─── OLLAMA PRIMARY MODE (skip delegation entirely) ───
# File fallback: env vars don't propagate to hook subprocesses
if [ -z "${LAUNCH_MODE:-}" ]; then
  for _lm_dir in "${CLAUDE_PROJECT_DIR:-.}" "$(git rev-parse --show-toplevel 2>/dev/null)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" "$HOME"; do
    [ -n "$_lm_dir" ] && [ -f "$_lm_dir/.claude/.launch-mode" ] && { LAUNCH_MODE=$(cat "$_lm_dir/.claude/.launch-mode" 2>/dev/null); break; }
  done
fi
_is_ollama_model() {
  echo "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" | grep -qE '^[a-z0-9-]+:(cloud|local|[0-9]+b)$'
}
# Ollama mode flag: skip graduated delegation but keep workflow/team routing
_OLLAMA_MODE=false
if [ "${LAUNCH_MODE:-opus}" = "ollama" ] || _is_ollama_model; then
  _OLLAMA_MODE=true
fi

# ─── WORKFLOW ROUTER (multi-step guided processes) ───
WORKFLOW=""

if echo "$USER_MSG" | grep -qiE "build.*feature|ship.*feature|end.to.end.*feature|feature.*lifecycle|complete.*feature.*cycle"; then
  WORKFLOW="ship-feature"
fi
if echo "$USER_MSG" | grep -qiE "redesign.*frontend|redesign.*(landing|page|site|ui)|premium.*ui|visual.*overhaul|frontend.*redesign"; then
  WORKFLOW="frontend-redesign"
fi
if echo "$USER_MSG" | grep -qiE "security.*hardening|harden.*security|audit.*and.*fix.*security|security.*remediat"; then
  WORKFLOW="security-hardening"
fi
if echo "$USER_MSG" | grep -qiE "build.*api|design.*endpoint|api.*development|create.*api.*with.*test|api.*from.*scratch"; then
  WORKFLOW="api-development"
fi
if echo "$USER_MSG" | grep -qiE "refactor.*safely|safe.*refactor|zero.*regression.*refactor|quality.*cycle.*refactor"; then
  WORKFLOW="refactor-safely"
fi
if echo "$USER_MSG" | grep -qiE "new.*project.*setup|bootstrap.*project|scaffold.*and.*ship|start.*new.*project|greenfield"; then
  WORKFLOW="new-project-setup"
fi
if echo "$USER_MSG" | grep -qiE "overnight.*dev|overnight.*batch|batch.*tasks.*overnight|autonomous.*batch|queue.*overnight"; then
  WORKFLOW="overnight-batch"
fi

# ─── WORKER STATUS (cached by check-ollama-models.sh) ───
WORKER_STATUS=$(cat "${CLAUDE_PROJECT_DIR:-.}/.claude/.worker-status" 2>/dev/null || echo "unknown")

# ─── DELEGATION ROUTER (mandatory, not advisory) ───
# Ollama mode skips delegation — the orchestrator IS the worker model
DELEGATION=""
PLANNING_GATE=""
if $_OLLAMA_MODE; then
  # Jump straight to team router — no graduated delegation for Ollama orchestrator
  :
else

# Numeric batch: "create 9 pages", "build 5 components", "write 3 endpoints"
if echo "$USER_MSG" | grep -qiE "[0-9]+.*(page|file|component|module|endpoint|route|view|screen|service)"; then
  DELEGATION="Batch creation | DO: spawn-worker per file (glm-5.1:cloud). 4+files→ollama-batch.sh"
  PLANNING_GATE="REQUIRED"
fi

# Multi-file implementation
if echo "$USER_MSG" | grep -qiE "(multiple|several|many|all|every|each).*(file|page|component|endpoint|module)|across.*codebase|refactor.*project|full.*feature|large.*change"; then
  DELEGATION="Multi-file task | DO: spawn-worker per file (glm-5.1:cloud). You=BRAIN, workers=code gen"
  PLANNING_GATE="REQUIRED"
fi

# Frontend design — brain-first (MCP tools optional for image gen/consultation)
if echo "$USER_MSG" | grep -qiE "landing.*page|hero|visual.*design|css.*design|html.*page|website.*design|marketing.*page|portfolio|redesign.*(website|site|page|frontend)|cinematic|immersive|showreel|3d.*scene|parallax.*design|page.*design|design.*page|design.*component|visual.*component"; then
  DELEGATION="Frontend design | DO: Skill(\"frontend-design-pro\") → spawn-worker code gen → brain integrate+a11y\nLIBS: Shadcn/ui, Framer Motion, ReactBits, Lenis (reset scroll on nav)\nOPTIONAL: gemini-generate-image (4K mockup), openai/deepseek consultation\nAVOID: Inter/Roboto fonts, cyan-on-dark palette, template layouts"
  PLANNING_GATE="REQUIRED"
fi

# Reference URL + frontend task → extract design tokens first
if [ -n "$DELEGATION" ] && echo "$DELEGATION" | grep -q "Frontend design"; then
  if echo "$USER_MSG" | grep -qiE "https?://[^[:space:]]+"; then
    REF_URL=$(echo "$USER_MSG" | grep -oE 'https?://[^[:space:]]+' | head -1)
    DELEGATION="DO FIRST: kit extract-design-tokens.sh \"$REF_URL\" (extract colors/fonts)\n${DELEGATION}"
  fi
fi

# Video/animation content → LTX-2 + Remotion pipeline
if echo "$USER_MSG" | grep -qiE "video.*hero|hero.*video|video.*background|generate.*video|veo|ltx|remotion|animated.*demo|cinematic.*video|showreel"; then
  DELEGATION="Video content | DO: generate-video-ltx2.sh --prompt \"desc\" --mode auto. Fallback: gemini-generate-video\nSUPPORT: Skill(\"remotion-video\") compose, gemini-generate-image 4K assets"
  PLANNING_GATE="REQUIRED"
fi

# Image generation tasks (standalone)
if echo "$USER_MSG" | grep -qiE "generate.*image|create.*image|hero.*image|banner.*image|asset.*gen|4k.*asset|product.*shot|mockup.*image|ai.*image"; then
  [ -z "$DELEGATION" ] && DELEGATION="Image gen | DO: gemini-generate-image (primary) + openai gpt-image-1.5 (alt). Generate, don't describe."
fi

# Video generation tasks (standalone)
if echo "$USER_MSG" | grep -qiE "generate.*video|create.*video|video.*content|hero.*video|background.*video|cinematic.*clip|ai.*video|ltx.*video"; then
  [ -z "$DELEGATION" ] && DELEGATION="Video gen | DO: generate-video-ltx2.sh --prompt \"desc\". Fallback: gemini-generate-video"
  PLANNING_GATE="REQUIRED"
fi

# React/Vue/Svelte pages (common pattern the agent ignores)
if echo "$USER_MSG" | grep -qiE "(react|vue|svelte|next|nuxt).*(page|component|view)|page.*(tsx|jsx|vue|svelte)"; then
  DELEGATION="UI component gen | DO: spawn-worker JSX/template code. You=props+layout+data flow"
  PLANNING_GATE="REQUIRED"
fi

# Component library recommendations (React/Next pages should use modern libs)
if echo "$USER_MSG" | grep -qiE "(react|next|remix).*(page|component|view|section|layout)"; then
  if [ -z "$DELEGATION" ] || ! echo "$DELEGATION" | grep -q "COMPONENT LIBRARIES"; then
    DELEGATION="${DELEGATION:+$DELEGATION\n}LIBS: Shadcn/ui, Framer Motion (AnimatePresence mode='wait'+wouter corrupts!), ReactBits, Lenis (reset on nav)"
  fi
fi

# Code review → multi-model audit
if echo "$USER_MSG" | grep -qiE "review.*pr|code.*review|audit.*code|security.*audit"; then
  DELEGATION="Code review | DO: /audit --diff HEAD --focus bugs,security,logic"
fi

# Boilerplate/CRUD
if echo "$USER_MSG" | grep -qiE "scaffold|boilerplate|crud|basic.*setup|starter|template|generate.*model"; then
  DELEGATION="Boilerplate | DO: mcp-cli.sh ollama chat qwen3-coder-next:cloud"
fi

# System architecture / schema design
if echo "$USER_MSG" | grep -qiE "system.*design|database.*schema|microservice.*architect|api.*design|event.*driven.*architect"; then
  DELEGATION="Architecture | DO: Skill(\"system-architecture\") → delegate impl to workers"
  PLANNING_GATE="REQUIRED"
fi

# Backend services/API implementation
if echo "$USER_MSG" | grep -qiE "api.*endpoint|middleware|handler|service.*layer|rest.*api|graphql|webhook|caching|rate.*limit|circuit.*breaker|observability|health.*check|logging|background.*job|queue|worker.*process|microservice.*impl|backend.*service|server.*side"; then
  [ -z "$DELEGATION" ] && {
    DELEGATION="Backend impl | DO: Skill(\"backend-design\") → spawn-worker code → Skill(\"security-review\") → worker tests → brain integrate\nPIPELINE: worker-orchestrator.sh --task \"desc\" --stages \"implement,test,review\""
    PLANNING_GATE="REQUIRED"
  }
fi

# Security implementation (auth, encryption, permissions, RBAC, tokens)
if echo "$USER_MSG" | grep -qiE "implement.*(auth|login|signup|register|password|encrypt|permission|rbac|oauth|jwt|session|token|credential|2fa|mfa)|auth.*system|permission.*system|role.*based|access.*control|security.*implement"; then
  DELEGATION="Security impl | DO: Skill(\"security-review\") → Skill(\"writing-plans\") → multi-model-audit → brain auth code → workers support code\nWARN: NEVER delegate auth/crypto to workers. Workers=models,DTOs,tests,boilerplate only"
  PLANNING_GATE="REQUIRED"
fi

# Testing campaigns (batch test creation, test suites, E2E setup)
if echo "$USER_MSG" | grep -qiE "write.*tests|add.*test.*suite|test.*coverage|batch.*test|e2e.*setup|playwright.*setup|testing.*strategy|integration.*test|test.*campaign|expand.*test|comprehensive.*test"; then
  [ -z "$DELEGATION" ] && {
    DELEGATION="Test campaign | DO: Skill(\"test-driven-development\") → spawn-worker test files → Skill(\"webapp-testing\") E2E\nBATCH: 4+ tests→ollama-batch.sh. You=scenarios, workers=test code"
    PLANNING_GATE="REQUIRED"
  }
fi

# Refactoring (large-scale code improvements, deduplication, tech debt)
if echo "$USER_MSG" | grep -qiE "refactor.*(project|codebase|module|system|multiple)|large.*refactor|major.*refactor|cross.*file.*refactor|rename.*across|restructure|reorganize.*code|tech.*debt.*sprint|dedup.*project|consolidate.*code"; then
  [ -z "$DELEGATION" ] && {
    DELEGATION="Large refactor | DO: Skill(\"code-refactoring\") → Skill(\"writing-plans\") → spawn-worker changes → multi-model-audit → verify\nPRE: Skill(\"finding-duplicate-functions\"). Small tested steps only."
    PLANNING_GATE="REQUIRED"
  }
fi

# CI/CD pipeline setup (GitHub Actions, GitLab CI, deployment)
if echo "$USER_MSG" | grep -qiE "setup.*(ci|cd|pipeline|action|workflow)|create.*(pipeline|action|workflow)|github.*action|gitlab.*ci|deploy.*pipeline|ci.?cd.*config|continuous.*(integration|deployment)"; then
  [ -z "$DELEGATION" ] && {
    DELEGATION="CI/CD | DO: Skill(\"cicd-generator\") → spawn-worker YAML → verify syntax. You=stages+strategy"
  }
fi

# Document generation (reports, PDFs, spreadsheets, presentations)
if echo "$USER_MSG" | grep -qiE "generate.*(report|pdf|docx|pptx|xlsx|spreadsheet|document|invoice|presentation)|create.*(report|pdf|document)|export.*(pdf|excel|word)"; then
  [ -z "$DELEGATION" ] && {
    DELEGATION="Doc gen | DO: Skill(\"doc-generation\") → spawn-worker template → brain integrate"
  }
fi

# Browser/scraping tasks → PinchTab routing
if echo "$USER_MSG" | grep -qiE "browse|scrape|open.*url|fetch.*page|web.*page|screenshot.*page|fill.*form|navigate.*to|check.*website|extract.*from.*site|read.*webpage"; then
  [ -z "$DELEGATION" ] && {
    DELEGATION="Browser task | DO: Skill(\"browser-control\") → enable PinchTab (+pinchtab) → pinchtab_navigate+snapshot (~800 tokens)\nFALLBACK: browser-use for visual/complex workflows, WebFetch for simple static content\nNEVER use WebFetch for rich pages — PinchTab is 10x more token-efficient"
  }
fi

# URL processing (user sends a URL to analyze)
if echo "$USER_MSG" | grep -qiE "https?://[^[:space:]]+"; then
  if [ -z "$DELEGATION" ] || ! echo "$DELEGATION" | grep -q "Browser"; then
    DELEGATION="${DELEGATION:+$DELEGATION\n}[HOOK:url] URL detected | DO: Use PinchTab (pinchtab_navigate+snapshot, ~800 tokens) over WebFetch (~10K tokens). Enable: +pinchtab"
  fi
fi

# Shell/DevOps/CLI tasks → Codex Tier 1b (77% Terminal-Bench vs 65% Claude Code)
if echo "$USER_MSG" | grep -qiE "shell.*script|bash.*script|makefile|dockerfile|docker.*compose|devops|deploy.*script|ci.*script|migration.*script|setup.*script|infra.*as.*code|terraform|ansible|helm|systemd|cron.*job|nginx.*config|apache.*config"; then
  [ -z "$DELEGATION" ] && DELEGATION="Shell/DevOps task | DO: spawn-worker --engine codex (Tier 1b, better at shell). Fallback: Tier 1a (spawn-worker glm-5.1:cloud)"
fi

# Generic implementation (catch-all for code tasks not caught above)
if [ -z "$DELEGATION" ] && echo "$USER_MSG" | grep -qiE "implement|create|build|write|generate|make.*(page|component|file|function|class|module)"; then
  DELEGATION="Code task | DO: >10L single→mcp-cli.sh ollama chat glm-5.1:cloud, multi-file→spawn-worker, 4+→ollama-batch.sh, review→multi-model-audit.sh | BLOCK: >50L without delegation"
fi

fi # end delegation skip for Ollama mode

# ─── TEAM ROUTER ───
TEAM=""
if echo "$USER_MSG" | grep -qiE "frontend.*(and|&).*backend|full-stack|cross-layer|end-to-end feature"; then
  TEAM="SPAWN TEAM: Cross-layer task → TeamCreate with layer-specific teammates"
fi
if echo "$USER_MSG" | grep -qiE "execute.*plan|implement.*plan|run.*plan" && echo "$USER_MSG" | grep -qiE "task|step|phase"; then
  TEAM="SPAWN TEAM: Plan execution → agent team for parallel task execution"
fi
if echo "$USER_MSG" | grep -qiE "investigat.*hypothes|debug.*(multiple|several)|flaky.*test|competing.*theor"; then
  TEAM="SPAWN TEAM: Competing hypotheses → parallel investigation threads"
fi
if echo "$USER_MSG" | grep -qiE "agent team|spawn team|use team|create team"; then
  TEAM="SPAWN TEAM: Explicit request → TeamCreate immediately"
fi

# Full feature implementation (significant features with multiple layers)
if echo "$USER_MSG" | grep -qiE "full.*feature|complete.*feature|implement.*feature.*(with|including)|feature.*with.*(test|frontend|backend|api|database)"; then
  [ -z "$TEAM" ] && TEAM="TEAM: Full feature → preset feature.json (lead+frontend+backend). File ownership enforced."
fi

# Security audit (comprehensive security review)
if echo "$USER_MSG" | grep -qiE "security.*audit|audit.*security|penetration.*test|threat.*model|vulnerability.*scan|owasp.*audit|full.*security.*review"; then
  [ -z "$TEAM" ] && TEAM="TEAM: Security audit → preset audit.json (injection+auth+data+deps agents)"
fi

# Comprehensive code review (significant PR or codebase review)
if echo "$USER_MSG" | grep -qiE "comprehensive.*review|full.*code.*review|review.*entire|thorough.*review|review.*codebase|deep.*review"; then
  [ -z "$TEAM" ] && TEAM="TEAM: Comprehensive review → preset review.json (security+perf+arch) + multi-model-audit.sh"
fi

# Large refactoring (cross-file, cross-module)
if echo "$USER_MSG" | grep -qiE "refactor.*(entire|whole|full|complete)|major.*restructur|rewrite.*module|reorganize.*(project|codebase)"; then
  [ -z "$TEAM" ] && TEAM="TEAM: Large refactor → adapted feature preset (lead+impl-1+impl-2). Independent units per agent."
fi

# ─── CONTRACT CHECK: inject active contract criteria ───
CONTRACT_CTX=""
CONTRACT_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/contracts"
if [ -d "$CONTRACT_DIR" ]; then
  for contract in "$CONTRACT_DIR"/*.contract.md; do
    [ -f "$contract" ] || continue
    STATUS=$(head -20 "$contract" | grep -E '^status:' | awk '{print $2}' | tr -d ' ')
    if [ "$STATUS" = "active" ]; then
      TASK_NAME=$(head -20 "$contract" | grep -E '^task:' | sed 's/^task: *//')
      UNCHECKED=$(grep -c '^\- \[ \]' "$contract" 2>/dev/null || echo "0")
      CONTRACT_CTX="[HOOK:contract] Active contract: ${TASK_NAME} (${UNCHECKED} criteria remaining) | Validate with evaluator agent before shipping"
      break
    fi
  done
fi

# ─── BUILD OUTPUT (hot-load: only inject what matched) ───
OUTPUT_PARTS=()

if [ -n "$DELEGATION" ]; then
  DEL_TEXT="[HOOK:delegate] ${DELEGATION}"
  if [ "$WORKER_STATUS" = "offline" ]; then
    DEL_TEXT="${DEL_TEXT}\n(workers currently offline — write code directly, delegate when available)"
  elif [ "$PLANNING_GATE" = "REQUIRED" ]; then
    DEL_TEXT="${DEL_TEXT}\nPLAN REQUIRED: List files → assign YOU vs WORKER → specify model → execute. >50L without delegation=BLOCKED"
  fi
  OUTPUT_PARTS+=("$DEL_TEXT")
fi

if [ -n "$TEAM" ]; then
  OUTPUT_PARTS+=("[HOOK:team] ${TEAM}\nProtocol: TeamCreate → TaskCreate → spawn teammates")
fi

if [ -n "$WORKFLOW" ]; then
  STEP1=$(bash "$SCRIPT_DIR/../scripts/invoke-workflow.sh" "$WORKFLOW" --start 2>/dev/null | head -10 || echo "")
  OUTPUT_PARTS+=("[HOOK:workflow] Matched: $WORKFLOW | DO: /workflow $WORKFLOW --start${STEP1:+\nStep 1: $STEP1}")
  # Inject contract requirement for workflow tasks
  if [ -z "$CONTRACT_CTX" ]; then
    OUTPUT_PARTS+=("[HOOK:contract] Workflow detected — define sprint contract BEFORE implementation | DO: Skill(\"sprint-contract\")")
  fi
fi

# Inject active contract context if exists
if [ -n "$CONTRACT_CTX" ]; then
  OUTPUT_PARTS+=("$CONTRACT_CTX")
fi

# If nothing matched, check if it's a code task at all
if [ ${#OUTPUT_PARTS[@]} -eq 0 ]; then
  # Ollama mode: no delegation fallback — only workflow/team would inject
  if $_OLLAMA_MODE; then
    exit 0
  elif echo "$USER_MSG" | grep -qiE "implement|fix|create|build|refactor|test|review|commit|push|deploy|write code|edit code|generate|scaffold|migrate"; then
    OUTPUT_PARTS+=("[HOOK:delegate] Code task | >10L→spawn-worker (Tier 1a), shell/DevOps→spawn-worker --engine codex (Tier 1b), quick→mcp-cli.sh ollama chat, 4+→ollama-batch.sh | BLOCK: >50L")
  else
    # Non-code message — zero injection, save context
    exit 0
  fi
fi

# Combine and output
COMBINED=""
for part in "${OUTPUT_PARTS[@]}"; do
  [ -n "$COMBINED" ] && COMBINED="${COMBINED}\n\n"
  COMBINED="${COMBINED}${part}"
done

jq -n --arg ctx "$COMBINED" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'

exit 0
