# Delegation Rules

## Execution Tiers

| Tier | Engine | Best For | Cost |
|------|--------|----------|------|
| 0 | Orchestrator (interactive) | Brain, security, orchestration | $$$ |
| 1a | `claude -p` + Ollama | Multi-file impl, autonomous tasks | Free |
| 1b | `codex exec --oss` + Ollama | Shell/DevOps/file-heavy tasks (77% Terminal-Bench) | Free |
| 2 | `mcp-cli.sh ollama chat` | Quick code gen, reviews | Free |
| 2b | `free-models` MCP | Extra free workers (OpenRouter) | Free |
| 2c | `groq_chat` MCP | Ultra-fast inference (750-1000 T/s) — agentic, teams, speed-critical | Free |
| 3 | Task tool (Haiku) | Exploration, Claude reasoning | $ |
| 4 | Agent Teams | Collaborative, competing hypotheses | $$ |
| 5 | Git Worktrees | Long-running branches | Free |
| 6 | Codex CLI (`codex exec --oss`) | Plan review, terminal tasks, 5th audit voice | Free (Ollama) |
| 7 | OpenSpace MCP | Self-evolving skills, community skill library, autonomous multi-tool tasks | Free |

Brain tools + reasoning? → Tier 0 | Complex multi-file? → Tier 1a | Shell/DevOps? → Tier 1b (codex) | Simple gen? → Tier 2/2b | Speed-critical? → Tier 2c (Groq) | Claude reasoning? → Tier 3 | Coordination? → Tier 4 | Long-running? → Tier 5 | Plan review/terminal? → Tier 6 | Community skills/auto-evolve? → Tier 7. Tier 1a = default for impl.

### Free Models (Tier 2b)
OpenRouter: `openrouter_chat` — nemotron-3-super (262K), step-3.5-flash (256K), nemotron-3-nano (256K), minimax-m2.5 (196K), trinity-large (131K).
GitHub Models: disabled (not working). Use Groq instead.

### Groq (Tier 2c — always on)
`groq_chat` — ultra-fast inference. Models: llama-4-scout (750 T/s, 30K TPM), gpt-oss-20b (1000 T/s), gpt-oss-120b (500 T/s), qwen3-32b (400 T/s), kimi-k2 (60 RPM), llama-3.3-70b (280 T/s), compound/compound-mini (450 T/s, agentic with built-in tools). Free tier with rate limits (30-60 RPM, 6K-70K TPM).
Use for: speed-critical workers, agentic teams, quick reviews, burst delegation.

## Auto-Delegation

<!-- DELEGATION-START -->
```
DELEGATE (MUST — cloud first):
├── Multi-file impl → Tier 1: spawn-worker.sh "glm-5.1:cloud"
├── Code gen >10 lines → Tier 2: ollama_chat glm-5.1:cloud
├── Boilerplate/CRUD → Tier 2: qwen3-coder-next:cloud
├── Code review → multi-model-audit.sh (includes Codex 5th voice)
├── Plan review → codex exec --oss (second-opinion on architecture)
├── Terminal/DevOps → codex exec --oss -m glm-5.1:cloud (shell, Makefile, CLI)
├── Tests → Tier 1/2
├── Reasoning → Tier 2: deepseek-v3.2:cloud
├── Frontend design → Open Pencil (.fig) / Figma (cloud) → Stitch → 21st.dev → frontend-design-pro → workers
├── Backend → Skill(backend-design) + workers + audit
├── Security → Skill(security-review) + brain auth logic + worker support
├── Refactoring → Skill(code-refactoring) + workers + audit
├── Image → Gemini/OpenAI MCP
├── Video → LTX-2 / Gemini
├── Browser tasks → PinchTab MCP (DOM-based, 800 tokens/page) → browser-use (vision fallback)
├── Desktop app control → Windows-MCP (GUI) / CLI-Anything (open-source) / Playwright (proprietary)
├── Any non-tool task → Tier 1 (complex) or Tier 2 (simple)

BRAIN KEEPS:
├── Planning, architecture
├── Security review (final pass)
├── Multi-step tool orchestration
├── Worker result integration
├── User communication
└── Tasks needing Claude Code tools
```
<!-- DELEGATION-END -->

## Frontend Pipeline

**Design sources (dual-path):**
- `.fig files` (local) → `openpencil export -f jsx --style tailwind` → tokens via `openpencil analyze colors/typography`
- `Figma URL` (cloud) → Figma MCP `get_design_context` → Code Connect mappings
- Reference URL → `extract-design-tokens.sh "<URL>"` → tokens JSON (cached 24h)

Design-heavy (full pipeline): Open Pencil/Figma → Stitch (mockup-to-code) → 21st.dev (premium components) → Skill(frontend-design-pro) (process) → workers gen → brain integrates.
Functional (forms, tables, state): Ollama workers directly.
Image: Gemini `gemini-generate-image` (4K) / OpenAI `gpt-image-1.5`.
Video: LTX-2 `generate-video-ltx2.sh` / Gemini fallback.
Mockup-to-code: Stitch MCP `generate_screen_from_text` → `fetch_screen_code` → workers refine.
Premium components: 21st.dev Magic MCP — natural language → React components with 3D/animation.
Local HTTPS: `slim start app PORT` for secure dev (passkeys, OAuth, cookies).

## Code Audit

`multi-model-audit.sh`: OpenAI codex-mini + Ollama cloud + DeepSeek V3.2 + Gemini 3 Flash + Codex CLI.
Consensus: 2+ models flag → report. 1 model → note as "possible".

## Pipelines (auto-injected by delegation-check.sh)

| Task | Pipeline |
|------|----------|
| Backend | Skill(backend-design) → workers → security-review → tests → integrate |
| Security | Skill(security-review) → plan → audit → brain auth → workers support |
| Testing | Skill(TDD) → workers tests → webapp-testing E2E → batch |
| Refactoring | Skill(code-refactoring) → plan → workers → audit → verify |
| CI/CD | Skill(cicd-generator) → workers YAML → verify |
| Frontend | Open Pencil/Figma → Stitch → 21st.dev → frontend-design-pro → workers → integrate |

**NEVER delegate auth/crypto logic to workers.**

## Graduated Enforcement

| Lines | Action |
|-------|--------|
| ≤THRESHOLD (default 10, env 25) | Allow |
| >THRESHOLD, ≤BLOCK_THRESHOLD | 1st: Advisory (warn, allow). 2nd+: BLOCK |
| >BLOCK_THRESHOLD (default 50, env 200) | BLOCK unless delegation token exists |

Token bypass: 5-min token created after `ollama_chat`/`ollama_generate`. Ollama unreachable: downgrades to advisory (never blocks without workers).

## Skill Gate (structural)

Domain file writes require matching skill loaded first (`skill-gate.sh`):
- Pages/layouts/heroes/CSS → `Skill("frontend-design-pro")`
- Components/forms/tables → `Skill("frontend-engineering")`
- Handlers/routes/services → `Skill("backend-design")`

Token: `.claude/.tokens/skill-{name}.token` (30-min TTL, created by `skill-token.sh`). Small edits (≤10 lines), kit files, tests, types bypass.

## Budget-Aware Thresholds

| Weekly Usage | Advisory | Block |
|-------------|----------|-------|
| <60% (green) | 10 lines | 50 lines |
| 60-79% (yellow) | 7 lines | 35 lines |
| ≥80% (red) | 5 lines | 25 lines |

Auto-adjusted by `check-usage.sh` → `.budget-thresholds.env`. Fallback: green tier.

## spawn-worker.sh

Flags: `--max-turns N` `--retry MODEL|auto` `--timeout SECS` `--repeat-prompt` (non-reasoning only) `--read-only` `--engine codex|ollama`

4+ parallel tasks → `ollama-batch.sh`. 2-3 → direct `ollama_chat`.

## Post-Delegation

Verify all worker output. Retry once (pass@2). Security-critical: pass^1 — fail = escalate.
