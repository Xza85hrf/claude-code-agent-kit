---
name: brainstorming
description: "Use before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements, and design through structured collaborative dialogue."
---

# Brainstorming Ideas Into Designs

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

**Core principle:** Explore before committing. The best designs emerge from understanding the problem deeply, not from jumping to solutions.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design in small sections (200-300 words), checking after each section whether it looks right so far.

## When to Use

**Activate this skill when:**
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
- Ask questions **one at a time** - don't overwhelm
- Prefer **multiple choice** when possible (easier to answer)
- Open-ended is fine for exploration
- Focus on: purpose, constraints, success criteria

**Key Questions to Explore:**
```
WHO: Who are the users? What's their context?
WHAT: What problem does this solve? What's the core functionality?
WHY: Why now? Why this approach? What's the value?
HOW: Any technical constraints? Integration points?
WHEN: Timeline pressure? Phased delivery possible?
```

### Phase 2: Exploring Approaches

**Always propose 2-3 different approaches** with trade-offs:

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

**Lead with your recommendation** and explain why, but present alternatives so the user can make an informed choice.

### Phase 3: Presenting the Design

Once you believe you understand what to build:

1. **Break into sections** of 200-300 words each
2. **Ask after each section** whether it looks right
3. **Cover all aspects:**
   - Architecture and components
   - Data flow and state management
   - Error handling and edge cases
   - Testing strategy
   - Security considerations
4. **Be ready to revise** - go back and clarify if something doesn't fit

## Structured Thinking Frameworks

### SCAMPER for Feature Design

Use to generate variations on existing patterns:

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

When stuck, examine constraints explicitly:

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

For complex choices with multiple factors:

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

Write the validated design to:
```
docs/plans/YYYY-MM-DD-<topic>-design.md
```

Include:
- Problem statement
- Chosen approach and why
- Rejected alternatives
- Key decisions and rationale
- Open questions
- Success criteria

### Implementation Setup

If continuing to implementation:

1. **Ask:** "Ready to set up for implementation?"
2. **Create workspace:** Use `using-git-worktrees` skill if available
3. **Create plan:** Use `writing-plans` skill for detailed steps
4. **Commit design doc** to git before starting implementation

## Key Principles

```
□ One question at a time - Don't overwhelm
□ Multiple choice preferred - Easier to answer
□ YAGNI ruthlessly - Remove unnecessary features
□ Explore alternatives - Always propose 2-3 approaches
□ Incremental validation - Present design in sections
□ Be flexible - Go back and clarify when needed
□ Document decisions - Future you will thank you
□ Separate design from implementation - Don't code prematurely
```

## Red Flags During Brainstorming

Watch for these warning signs:

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
