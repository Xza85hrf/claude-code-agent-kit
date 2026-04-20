---
name: multi-model-orchestration
description: Route task aspects to domain-specific AI models with orchestrator integration. Use for full-stack features, cross-domain tasks, or architecture requiring multiple expert perspectives.
argument-hint: "Route frontend, backend, and DevOps aspects of the payment system to specialist models"
department: architecture
thinking-level: high
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Multi-Model Orchestration

## When to Activate
- Full-stack features (frontend + backend + infra)
- Cross-domain tasks (security + performance + UX)
- Architecture decisions requiring multiple expert perspectives

## Role-Based Routing

| Role | Model | Responsibility |
|------|-------|----------------|
| Orchestrator | Opus | Planning, integration, final decisions |
| Code Gen | Ollama Cloud (minimax-m2.7) | Implementation, boilerplate |
| Deep Reasoning | DeepSeek V3.2 | Algorithm design, complex logic |
| Design Review | Gemini | Visual feedback, UI patterns |
| Security Audit | Multi-model consensus | 2+ models must agree |

## Orchestration Phases

```
RESEARCH → IDEATION → PLAN → EXECUTE → OPTIMIZE → REVIEW
```

| Phase | Lead Model | Quality Gate | Integration |
|-------|-----------|--------------|-------------|
| RESEARCH | Opus | Sources validated, gaps identified | Aggregate findings |
| IDEATION | Opus + DeepSeek | 3+ viable approaches | Synthesize options |
| PLAN | Opus | Estimates complete, risks mapped | Final roadmap |
| EXECUTE | Ollama Cloud | Tests passing | Merge code |
| OPTIMIZE | DeepSeek | Measurable improvement | Apply results |
| REVIEW | Gemini + multi-model | All checks pass | Final approval |

## Cross-Model Checks
- **Generate → Review**: Model A builds, Model B critiques
- **Consensus**: Security requires 2+ models agree (multi-model-audit.sh)
- **Orchestrator decides**: Resolves conflicts, approves progression

## Session Management
- Track progress via TaskList, checkpoint after each phase
- Rollback on quality gate failure
- Resume from any phase after /compact

## Integration
- `thinktank` — brainstorming, architecture validation
- `dispatching-parallel-agents` — concurrent model execution
- `cost-aware-llm-pipeline` — optimize token usage per phase
