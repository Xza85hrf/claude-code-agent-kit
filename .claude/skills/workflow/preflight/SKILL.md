---
name: preflight
description: "Use when starting a new project or feature — generates PRD, FLOW, DESIGN, BACKEND docs interactively before any code is written. Prevents specification gaps that cause agent failures."
argument-hint: "Generate PRD, FLOW, DESIGN, and BACKEND specs before starting development"
department: workflow
thinking-level: high
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob"]
---

# Pre-Flight Protocol — Spec Before Code

AI coding agents fail when given incomplete specs — they fill gaps incorrectly and confidently. This skill generates 4 structured specification documents interactively, then sets up session memory to keep the agent anchored throughout development.

## When to Activate

- Starting a new project from scratch
- Beginning a significant new feature (not a small fix)
- Onboarding to an existing project that lacks spec docs
- User runs `/preflight` or `Skill("preflight")`

## 5 Phases

### Phase 0: Check Existing State

Scan `docs/` for existing spec documents:

```
docs/PRD.md     — Product requirements
docs/FLOW.md    — User journey map
docs/DESIGN.md  — Visual/frontend guidelines
docs/BACKEND.md — Tech stack + API contracts
docs/memory.md  — Session continuity
docs/phases.md  — Phase tracking
```

**Decision tree:**
- All 4 core docs exist → offer review/update mode (skip to Phase 5)
- Partial set exists → show which are missing, offer to fill gaps
- None exist → start from scratch (Phase 1)

For `--check` argument: report doc status and exit.
For `--update` argument: read existing docs and offer targeted updates.

### Phase 1: Product Requirements (PRD.md)

Ask structured questions using AskUserQuestion:

1. **What is this product?** — Goal statement in one sentence
2. **Who uses it?** — 1-3 personas with roles and needs
3. **What are the MVP features?** — Scoped list with priorities (P0/P1)
4. **What does "done" look like?** — Testable acceptance criteria
5. **What does it NOT do?** — Explicit negative scope
6. **Constraints?** — Platform, performance, compliance, timeline

Generate `docs/PRD.md` from answers using the template at `.claude/templates/preflight/PRD.md`.

Make acceptance criteria machine-readable where possible (testable conditions, not vague goals).

### Phase 2: App Flow (FLOW.md)

Ask about user journeys:

1. **Entry points** — How users arrive (URL, app launch, deep link)
2. **Key screens/states** — Major views or application states
3. **Transitions** — How users move between states
4. **Error/edge cases** — What happens when things go wrong
5. **Loading/async states** — Spinners, optimistic updates, background jobs
6. **Exit points** — Logout, close, timeout behavior

Generate `docs/FLOW.md` with ASCII flow diagrams using the template at `.claude/templates/preflight/FLOW.md`.

### Phase 3: Design Guidelines (DESIGN.md)

Ask about visual direction:

1. **Reference apps/sites** — Style inspiration (URLs welcome)
2. **Color preferences** — Light/dark mode, brand colors
3. **Typography** — Font preferences or "no preference"
4. **Component patterns** — What UI elements are needed
5. **Motion intent** — Static, subtle transitions, or rich animation

If a reference URL is provided, run `extract-design-tokens.sh` for automated token extraction.

Generate `docs/DESIGN.md` using the template at `.claude/templates/preflight/DESIGN.md`.

Cross-reference: Use Skill("frontend-design-pro") when implementing the design.

### Phase 4: Backend Architecture (BACKEND.md)

Ask about tech decisions:

1. **Language + runtime** — e.g., TypeScript/Node, Python/FastAPI, Go
2. **Framework** — e.g., Next.js, Express, Django
3. **Database(s)** — e.g., PostgreSQL, MongoDB, SQLite
4. **Auth strategy** — JWT, session, OAuth2, API key
5. **Hosting target** — Vercel, AWS, self-hosted, Cloudflare
6. **Third-party APIs** — Payment, email, storage, etc.

Ask about data model:

7. **Core entities** — What data objects exist
8. **Relationships** — How entities connect
9. **API endpoints** — What operations are needed

Generate `docs/BACKEND.md` using the template at `.claude/templates/preflight/BACKEND.md`.

Cross-reference: Use Skill("backend-design") when implementing the architecture.

### Phase 5: Session Setup

1. Generate `docs/memory.md` — initial state summarized from all 4 docs
2. Generate `docs/phases.md` — phase breakdown derived from PRD features
3. Check for `.claudeignore` — suggest creating one if missing
4. Suggest adding to project's CLAUDE.md:
   ```
   Read docs/PRD.md, docs/FLOW.md, docs/DESIGN.md, docs/BACKEND.md at session start
   ```
5. Output summary: "Preflight complete. 4 spec docs + session memory ready."

## Question Strategy — MANDATORY

**CRITICAL: You MUST use AskUserQuestion for every phase.** Never skip questions because the user's prompt contains context — that context is a starting point, NOT answers. The user must explicitly confirm or choose through AskUserQuestion.

**Why this exists:** The #1 failure mode of this skill is the agent auto-answering questions from prompt context. The user's initial prompt describes the project — the questions validate assumptions, surface gaps, and force deliberate choices. Skipping questions defeats the entire purpose of preflight.

**Rules:**
- Each phase MUST present at least one AskUserQuestion before generating its doc
- Use the user's prompt context to pre-populate option descriptions, NOT to skip asking
- Batch 2-3 related questions per AskUserQuestion call (max 4)
- Always include the user's context as a suggested option, but let them confirm or change it
- If the user provided detail for a topic, make that the first option labeled "(from your brief)"
- Accept "no preference" and use best-practice defaults

For each question:
- Explain WHY this matters (what goes wrong without it)
- Offer 2-4 concrete options when applicable
- Frame questions around decisions and trade-offs, not data entry

## Output

All documents are written to `docs/` at the project root. Templates are skeletons — this skill fills them interactively with the user's answers.

## Integration

- **Before:** Skill("brainstorming") for idea exploration
- **After:** Skill("writing-plans") to break features into tasks
- **After:** Skill("project-scaffolder") to set up codebase from BACKEND spec
- **Workflow:** Part of `preflight` and `new-project-setup` workflows

## Track Management (Conductor-inspired)

After preflight generates the 4 spec docs, features can be organized as **tracks** — self-contained work units with specs, plans, and semantic revert capability.

### Creating Tracks

For `--track <name>` argument:

1. Create `docs/tracks/<track-id>/spec.md` from PRD subset
2. Create `docs/tracks/<track-id>/plan.md` with phased task breakdown
3. Register in `docs/tracks.md` (master registry)
4. Each track gets: status (draft/active/done/archived), priority, dependencies

### Semantic Revert

Tracks enable **undo by logical unit** (not file-level git revert):

- Revert a track: all commits tagged `[track:<id>]` are identified and reverted
- Revert a phase: only commits for that phase within the track
- Revert a task: single task's commits

Convention: commits within a track use `feat(track-id): task description` format.

### Track Lifecycle

| Command | Action |
|---------|--------|
| `--track new` | Create spec + plan for a feature |
| `--track status` | Show all tracks with completion % |
| `--track archive <id>` | Move to `docs/tracks/_archive/` |
| `--track restore <id>` | Restore from archive |

### Track Artifacts

```
docs/
├── tracks.md           # Master registry
└── tracks/
    ├── _archive/       # Archived tracks
    └── <track-id>/
        ├── spec.md     # Requirements (from PRD subset)
        ├── plan.md     # Phased task breakdown
        └── index.md    # Track navigation
```

## Anti-Patterns

- **Auto-answering from prompt context** — the user's initial prompt is a brief, not answers. ALWAYS ask.
- Generating docs without AskUserQuestion confirmation
- Filling in default values without confirmation
- Skipping negative scope (the most common source of agent failure)
- Making acceptance criteria vague ("it works") instead of testable
- Treating "the user already told me" as a reason to skip questions
