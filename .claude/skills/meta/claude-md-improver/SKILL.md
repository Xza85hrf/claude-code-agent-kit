---
name: claude-md-improver
description: Audit and improve CLAUDE.md quality. Use when setting up a new project, reviewing an existing CLAUDE.md for completeness, or after significant architectural changes. Scores A-F across key dimensions.
argument-hint: "Audit the CLAUDE.md in this project and suggest improvements"
allowed-tools: Read, Grep, Glob
model: inherit
department: quality
references: []
thinking-level: medium
---

# CLAUDE.md Quality Audit

## Purpose

Audit a project's CLAUDE.md (and related config files like `.claude/rules/`, `.mcp.json`, skills, hooks) for completeness, accuracy, and effectiveness. Produces a letter grade (A-F) with actionable improvement suggestions based on the scoring rubric.

## Scoring Rubric

Grade across 8 dimensions, each 0-10 points (80 total, then map to A-F):

### 1. Project Identity (0-10)

- Has project name and description (3pts)
- Explains what the project does in one paragraph (4pts)
- States the primary language and framework (3pts)

**Evidence to check:**
- "What Is This Project" section exists
- Description answers: What does this project do? Who uses it? Why does it exist?
- Primary tech stack is explicit (not implied)

### 2. Tech Stack Table (0-10)

- Lists all layers (frontend, backend, DB, deployment) (4pts)
- Includes version info or notes (3pts)
- No stale/inaccurate entries (3pts)

**Evidence to check:**
- "Tech Stack" section with a 4+ column table
- Versions match actual dependencies (verify against package.json, go.mod, requirements.txt, etc.)
- Framework names are current (not outdated docs)
- All layers relevant to the project are present

### 3. Commands Section (0-10)

- Has install, dev, build, test, typecheck commands (5pts)
- Commands actually work (verified by running them) (3pts)
- Includes linting/formatting commands (2pts)

**Evidence to check:**
- "Commands" section with bash snippets
- Each command has a comment explaining what it does
- Commands match what's in package.json scripts, Makefile, or equivalent
- No placeholder text like `[Add commands]`

### 4. Coding Rules (0-10)

- Has P0 (never violate) rules (4pts)
- Has P1 (should follow) rules (3pts)
- Has P2 (prefer when practical) rules (3pts)
- Rules are specific, not vague (bonus if true)

**Evidence to check:**
- "Coding Rules" or "Rules" section with constraint tiers (P0/P1/P2)
- Rules reference actual project decisions (language, patterns, testing, naming)
- Each rule is concrete enough to be enforced in code review
- No generic advice like "write clean code" — specific to this project

### 5. Context Layers (0-10)

- Core (architecture decisions, auth, DB schema overview) (4pts)
- Standards (API style, error patterns, test patterns) (3pts)
- Current (sprint goal, in-progress work, known issues) (3pts)

**Evidence to check:**
- "Context Layers" or equivalent section
- Core section documents architectural decisions (monolith/microservices, sync/async, etc.)
- Standards section shows patterns developers should follow
- Current section updated recently (not stale sprint goals from months ago)

### 6. Reference Implementation (0-10)

- Points to a real, exemplary file in the codebase (5pts)
- States what patterns to follow from that file (5pts)

**Evidence to check:**
- "Reference Implementation" section exists
- File path is absolute and the file exists
- Describes 2-3 specific patterns from that file (naming, error handling, structure)
- Not just "look at this file" — specific instruction

### 7. Agent Configuration (0-10)

- Decision authority matrix present (4pts)
- Skills referenced or configured (3pts)
- Delegation/worker rules if applicable (3pts)

**Evidence to check:**
- "Decision Authority Matrix" or equivalent showing Autonomous/Confirm/Escalate categories
- References to .claude/ directory if present, or cloud settings
- If multi-agent or delegation setup exists, rules are documented
- Links to AGENTS.md, delegation.md, or skills if they exist

### 8. Quality Checklist (0-10)

- Definition of Done checklist (5pts)
- Project-specific checks beyond generic ones (5pts)

**Evidence to check:**
- "Quality Checklist" or "Definition of Done" section
- Checklist has 4+ items specific to this project
- Includes type checking, testing, and deployment checks if relevant
- Not just generic checklist — tied to project's actual needs

## Grade Scale

- **A (72-80)**: Excellent — comprehensive, accurate, actionable. Developer can onboard in 30min. Decisions are clear. Tech stack is current.
- **B (60-71)**: Good — covers basics well, some gaps. Mostly actionable. Needs minor updates.
- **C (48-59)**: Adequate — minimal viable config. Generic advice mixed with specific rules. Could be clearer.
- **D (36-47)**: Poor — major gaps, stale content, placeholder text. Missing critical sections. Hard to onboard.
- **F (0-35)**: Failing — placeholder CLAUDE.md or largely empty. Unusable as-is.

## Audit Process

1. **Read CLAUDE.md** — Use Read tool. Check @import references.
2. **Score Each Dimension** — Count points based on evidence, not assumptions. Be evidence-based.
3. **Key principle:** Missing section = 0 points. Stale command = note it.

3. **Cross-Reference** — Verify tech stack versions, run commands, confirm reference file exists, spot-check rules.
4. **Calculate Score** — Sum 8 dimensions. Map: 80-72=A, 71-60=B, 59-48=C, 47-36=D, 35-0=F.
5. **Top 3 Improvements** — Identify lowest-scoring dimensions. Provide specific text to paste.
6. **Quick Wins** — List 3-5 fixes < 5 min each.
7. **Report** — Use template below.

## Report Template

```
## CLAUDE.md Audit Report

**Overall Grade: [X] ([score]/80)**

Audit of: [path/to/CLAUDE.md]
Audited: [YYYY-MM-DD]

### Scoring Summary

| Dimension | Score | Status | Notes |
|-----------|-------|--------|-------|
| Project Identity | X/10 | ✓/✗ | [1-2 sentences] |
| Tech Stack | X/10 | ✓/✗ | [1-2 sentences] |
| Commands | X/10 | ✓/✗ | [1-2 sentences] |
| Coding Rules | X/10 | ✓/✗ | [1-2 sentences] |
| Context Layers | X/10 | ✓/✗ | [1-2 sentences] |
| Reference Impl | X/10 | ✓/✗ | [1-2 sentences] |
| Agent Config | X/10 | ✓/✗ | [1-2 sentences] |
| Quality Checklist | X/10 | ✓/✗ | [1-2 sentences] |

### Top 3 Highest-Impact Improvements

**1. [Dimension]: [Title]**
- **Issue**: [What's missing or wrong]
- **Impact**: [Why this matters]
- **Suggested Fix**: [Specific text to add or change]
- **Effort**: [< 5 min / 5-15 min / > 15 min]

**2. [Dimension]: [Title]**
- [Same structure]

**3. [Dimension]: [Title]**
- [Same structure]

### Quick Wins (All < 5 minutes)

- [ ] [Small fix 1 with specific action]
- [ ] [Small fix 2 with specific action]
- [ ] [Small fix 3 with specific action]
- [ ] [Small fix 4 with specific action]
- [ ] [Small fix 5 with specific action]

### Key Observations

[2-3 sentences about the overall quality, consistency, and readiness of this CLAUDE.md]

### Next Steps

- If score is **A-B**: No action needed. Consider periodic review (every 6 months).
- If score is **C**: Address top 3 improvements. Audit again after.
- If score is **D-F**: Major restructuring needed. Consider using `Skill("writing-plans")` to plan updates, then re-audit.
```

## Key Principles

- Score based on evidence, not assumptions
- "Specific" = actual text to paste, not vague instructions
- Don't penalize for unneeded features. Score in context.
- Good CLAUDE.md = new developer understands project in 30 min
- Cross-reference sparingly. Spot-check 1-2 commands, 2-3 files.
- Stale content is worse than missing content

## After Audit

- **A-B:** Suggest periodic review (6 months)
- **C:** Offer quick wins, then `Skill("writing-plans")` for larger updates
- **D-F:** Recommend `Skill("writing-plans")` for restructuring, schedule follow-up

Do NOT commit changes. Present report, let user decide.

## Audit Scenarios

| Scenario | Expected Grade | Focus |
|----------|----------------|----- |
| New project | C-D | Tech Stack, Commands |
| Existing project | B-C | Context currency, version accuracy |
| Post-architectural change | Lower expected | Catch stale Context, outdated rules |
| Large team | Higher standards | Rules, Reference, Agent Config |

## Worked Example

Context: Auditing a hypothetical Python FastAPI project's CLAUDE.md.

**Dimension 1: Project Identity (Score: 8/10)**
- Section exists, 3 sentences long
- Explains it's a user API backend
- States Python 3.11 + FastAPI
- Missing: doesn't explain intended users (internal tool? public API?)

**Dimension 2: Tech Stack (Score: 6/10)**
- Table present with Frontend, Backend, Database, Deployment
- Notes say "Python 3.11" but requirements.txt says 3.10
- Versions missing for FastAPI, SQLAlchemy
- No deployment platform listed (AWS? Docker?)

**Dimension 3: Commands (Score: 9/10)**
- Has install, dev, test, typecheck, lint
- Spot-check: `pip install -r requirements.txt` works
- `pytest` works
- Small issue: `mypy` command is missing but referenced in rules

**Dimension 4: Coding Rules (Score: 7/10)**
- P0 section exists: "No secrets, all code typed"
- P1 section exists: "Use type hints, write tests"
- P2 section: only one item (sparse)
- Missing: no rule about API versioning or endpoint naming

**Dimension 5: Context Layers (Score: 5/10)**
- Core layer: mentions "REST API, JWT auth, PostgreSQL"
- Standards layer: missing (no mention of error format, pagination, etc.)
- Current layer: sprint goal from 6 months ago (stale)

**Dimension 6: Reference Implementation (Score: 3/10)**
- No section at all

**Dimension 7: Agent Config (Score: 0/10)**
- No .claude/ directory, no agent config

**Dimension 8: Quality Checklist (Score: 8/10)**
- Definition of Done exists
- 5 items: type check, tests, linting, no security warnings, API docs
- Good project-specific items

**Total: 46/80 = D (Poor)**

**Top 3 Improvements:**
1. **Context Layers: Add Standards section** (5-10 min)
   - Add specific patterns for error responses, pagination, validation
2. **Tech Stack: Fix version mismatches and complete table** (5 min)
   - Update Python to 3.10, add versions for key deps, add deployment platform
3. **Reference Implementation: Create and reference** (10-15 min)
   - Point to a well-structured endpoint file, describe its patterns

**Quick Wins:**
- [ ] Update Python version in Tech Stack from 3.11 to 3.10
- [ ] Add FastAPI==0.104.1 to Tech Stack table
- [ ] Add `mypy src/ --strict` to Commands section
- [ ] Update sprint goal in Context:Current to current quarter
- [ ] Add P2 item: "Prefer composition over inheritance"

<commentary>
This example shows how scoring reveals gaps. The project isn't terrible (D grade, not F), but it's incomplete: missing reference example, missing API standards, stale information. The audit points directly to fixes without requiring the human to hunt for problems. The "quick wins" are actionable and can be done in parallel before tackling bigger improvements.
</commentary>
