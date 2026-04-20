---
name: brainstorming
description: Starting new features. Use when exploring ideas, refining unclear requirements, evaluating multiple approaches, or turning ideas into fully formed designs through collaborative dialogue.
argument-hint: "Brainstorm 5 approaches to implementing real-time collaboration in our editor"
allowed-tools: Read, Grep, Glob
model: inherit
department: architecture
references: []
thinking-level: high
---

# Brainstorming Ideas Into Designs

## Overview

Turn ideas into fully formed designs and specs through collaborative dialogue. Explore before committing — the best designs emerge from deep problem understanding, not jumping to solutions.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it.
</HARD-GATE>

## When to Use

**Activate when:**
- Starting a new feature or component
- User has an idea but unclear requirements
- Multiple valid approaches exist
- Trade-offs need exploration
- Scope needs definition

**Skip when:**
- Bug fix with clear cause
- Implementing well-defined spec
- Minor UI tweaks
- Following existing patterns exactly

## The Process

### Phase 1: Understanding the Idea

**Project Context First:**
- Check current project state (files, docs, recent commits)
- Understand existing patterns and constraints
- Note relevant technical debt or limitations

**Question Guidelines:**
- Ask questions one at a time
- Use multiple choice when possible (easier to answer)
- Focus on: purpose, constraints, success criteria

**Key Questions:**
```
WHO: Who are the users? What's their context?
WHAT: What problem does this solve? What's the core functionality?
WHY: Why now? Why this approach? What's the value?
HOW: Any technical constraints? Integration points?
WHEN: Timeline pressure? Phased delivery possible?
```

### Phase 2: Exploring Approaches

**Propose 2-3 different approaches with trade-offs:**

```
Approach A: [Name]
├── How it works: [Brief description]
├── Pros: [Benefits]
├── Cons: [Drawbacks]
└── Best when: [Ideal conditions]

Approach B: [Name]
├── How it works: [Brief description]
├── Pros: [Benefits]
├── Cons: [Drawbacks]
└── Best when: [Ideal conditions]

Recommendation: [Which and why]
```

Lead with your recommendation but present alternatives for informed choice.

### Phase 3: Presenting the Design

Once you understand what to build:

1. **Break into sections** of 200-300 words each
2. **Ask after each section** whether it looks right
3. **Cover all aspects:**
   - Architecture and components
   - Data flow and state management
   - Error handling and edge cases
   - Testing strategy
   - Security considerations
4. **Be ready to revise** when something doesn't fit

## Structured Thinking Frameworks

### SCAMPER for Feature Design

| Letter | Question | Example |
|--------|----------|---------|
| **S**ubstitute | What can be replaced? | Different auth provider? |
| **C**ombine | What can be merged? | Combine create/edit flows? |
| **A**dapt | What can be borrowed? | Copy pattern from X? |
| **M**odify | What can be changed? | Larger/smaller scope? |
| **P**ut to other use | What else could this do? | Reuse for admin panel? |
| **E**liminate | What can be removed? | Skip feature Y for MVP? |
| **R**everse | What if we flip it? | User pulls vs system pushes? |

### Constraint Analysis

```
MUST HAVE (non-negotiable):
├── [Constraint 1]
└── [Constraint 2]

SHOULD HAVE (important but flexible):
├── [Preference 1]
└── [Preference 2]

COULD HAVE (nice to have):
├── [Optional 1]
└── [Optional 2]

WON'T HAVE (explicit exclusions):
├── [Out of scope 1]
└── [Out of scope 2]
```

### Decision Matrix

| Criterion | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| Simplicity | 25% | 8 | 6 | 9 |
| Performance | 20% | 7 | 9 | 5 |
| Maintainability | 25% | 9 | 6 | 7 |
| Security | 20% | 8 | 8 | 6 |
| Time to build | 10% | 6 | 4 | 9 |
| **Weighted Score** | | **7.8** | **6.7** | **7.1** |

## Visual Thinking Tools

### Component Diagram

```
┌─────────────────────────────────────────┐
│              [System Name]              │
├─────────────────────────────────────────┤
│  ┌─────────┐    ┌─────────┐            │
│  │ UI      │───▶│ Service │            │
│  └─────────┘    └────┬────┘            │
│                      │                  │
│                      ▼                  │
│                ┌─────────┐              │
│                │   DB    │              │
│                └─────────┘              │
└─────────────────────────────────────────┘
```

### State Flow

```
[Initial] ──▶ [Loading] ──▶ [Ready]
                │              │
                ▼              ▼
            [Error]       [Processing]
                              │
                              ▼
                          [Complete]
```

### Data Flow

```
Input ──▶ Validate ──▶ Transform ──▶ Store ──▶ Response
            │
            ▼
          [Error]
```

## After the Design

### Documentation

Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`

Include:
- Problem statement
- Chosen approach and why
- Rejected alternatives
- Key decisions and rationale
- Open questions
- Success criteria

### Implementation Setup

The terminal state of brainstorming is invoking `writing-plans`. Do NOT invoke frontend-engineering, backend-design, or other implementation skills directly.

1. **Ask:** "Ready to set up for implementation?"
2. **Create workspace:** Use `using-git-worktrees` skill if available
3. **Create plan:** Use `writing-plans` skill for detailed steps
4. **Commit design doc** to git before starting implementation

## Key Principles

- One question at a time — avoid overwhelming
- Multiple choice preferred — easier to answer
- YAGNI ruthlessly — remove unnecessary features
- Explore alternatives — always propose 2-3 approaches
- Incremental validation — present design in sections
- Be flexible — clarify when needed
- Document decisions — future reference
- Separate design from implementation — don't code prematurely

## Red Flags During Brainstorming

| Red Flag | Indicates | Action |
|----------|-----------|--------|
| "It should just..." | Hidden complexity | Probe for edge cases |
| No constraints mentioned | Missing requirements | Ask about limitations |
| One obvious solution | Possible blind spot | Force alternative exploration |
| "We'll figure it out later" | Unresolved dependency | Address now or mark as risk |
| Scope keeps growing | Feature creep | Revisit MoSCoW priorities |
| Technical terms assumed | Misalignment risk | Clarify definitions |

## Templates

### Feature Design Template

```markdown
# Feature: [Name]

## Problem
[What problem does this solve?]

## Users
[Who benefits? What's their context?]

## Proposed Solution
[High-level approach]

## Alternatives Considered
1. [Alternative A] - Rejected because...
2. [Alternative B] - Rejected because...

## Design Details
### Components
### Data Flow
### Error Handling
### Security Considerations

## Success Criteria
- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]

## Open Questions
- [ ] [Unresolved item]

## Implementation Notes
[Any guidance for implementation phase]
```

### Quick Decision Template

```markdown
## Decision: [Topic]

**Context:** [Why this decision is needed]

**Options:**
1. [Option A] - [Pros/Cons summary]
2. [Option B] - [Pros/Cons summary]

**Decision:** [Chosen option]

**Rationale:** [Why this choice]

**Consequences:** [What this means going forward]
```

## Tools

- **context7**: Fetch current docs and patterns on unfamiliar frameworks
- **sequential-thinking**: Use extended reasoning for complex architectural brainstorming
- **deepseek-reasoner**: Get alternative perspectives on architecture trade-offs
