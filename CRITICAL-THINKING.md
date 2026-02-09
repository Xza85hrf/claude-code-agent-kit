# Critical Thinking & Problem Solving for Coding Agents

> Advanced frameworks for analysis, debugging, architecture decisions, and creative problem solving.

---

## Part 1: Analytical Frameworks

### The Analytical Mindset

```
"The formulation of a problem is often more essential than its solution."
— Albert Einstein

Before solving, ensure you understand:
1. What is the ACTUAL problem? (not the symptom)
2. Why does this problem exist?
3. Who is affected and how?
4. What would "solved" look like?
5. What constraints exist?
```

### Socratic Questioning Method

Use these question types to deeply understand any problem:

```
CLARIFYING QUESTIONS
├── What do you mean by...?
├── Can you give me an example?
├── How does this relate to...?
└── What is the main issue here?

PROBING ASSUMPTIONS
├── What are we assuming here?
├── Why would someone assume this?
├── What would happen if we assumed the opposite?
└── Is this always the case?

PROBING REASONS/EVIDENCE
├── What evidence supports this?
├── How do we know this is true?
├── What are the sources?
└── Could there be alternative explanations?

EXPLORING IMPLICATIONS
├── What are the consequences of this?
├── How does this affect...?
├── What are the implications if we're wrong?
└── What would this lead to?

QUESTIONING THE QUESTION
├── Why is this question important?
├── Is this the right question to ask?
├── What other questions should we ask?
└── What does this assume?
```

### Root Cause Analysis

#### The 5 Whys (Extended)

```
EXAMPLE: Users report slow page loads

Why 1: Why are pages slow?
→ API responses take 5+ seconds

Why 2: Why are API responses slow?
→ Database queries are slow

Why 3: Why are database queries slow?
→ Full table scans on large tables

Why 4: Why are there full table scans?
→ Missing indexes on frequently queried columns

Why 5: Why are indexes missing?
→ No database review in the development process

ROOT CAUSE: Process gap (no DB optimization review)

IMMEDIATE FIX: Add indexes
SYSTEMIC FIX: Add DB review to PR checklist
```

#### Fishbone Diagram (Ishikawa)

```
                    ┌─────────────────────────────────────┐
                    │          PROBLEM                    │
                    └─────────────────────────────────────┘
                              ▲
    ┌─────────────────────────┼─────────────────────────┐
    │                         │                         │
PEOPLE                    PROCESS                   TECHNOLOGY
├── Training              ├── Documentation         ├── Infrastructure
├── Communication         ├── Workflow              ├── Dependencies
├── Expertise             ├── Testing               ├── Configuration
└── Workload              └── Review                └── Compatibility

DATA                      ENVIRONMENT               TOOLS
├── Quality               ├── Production            ├── IDEs
├── Availability          ├── Staging               ├── CI/CD
├── Format                ├── Development           ├── Monitoring
└── Volume                └── Network               └── Debugging
```

### Systems Thinking

#### Identify System Components

```
For any problem, map:

1. INPUTS
   └── What enters the system?
   └── Where does data come from?
   └── What triggers actions?

2. PROCESSES
   └── What transformations occur?
   └── What decisions are made?
   └── What validations exist?

3. OUTPUTS
   └── What results are produced?
   └── Who consumes the outputs?
   └── What side effects occur?

4. FEEDBACK LOOPS
   └── How do outputs affect inputs?
   └── What cycles exist?
   └── Where are reinforcing loops?

5. BOUNDARIES
   └── What's inside vs outside the system?
   └── What can we control?
   └── What are dependencies?
```

#### Trace the Data Flow

```
REQUEST LIFECYCLE:

User Action
    ↓
Frontend Validation
    ↓
API Request
    ↓
Authentication/Authorization
    ↓
Input Sanitization
    ↓
Business Logic
    ↓
Database Operation
    ↓
Response Formation
    ↓
Frontend Update
    ↓
User Feedback

At each stage ask:
□ What can go wrong?
□ What data is transformed?
□ What state changes?
□ What's logged?
```

---

## Part 2: Decision-Making Frameworks

### The Decision Matrix

For choosing between options:

```
STEP 1: Define criteria
STEP 2: Weight criteria (1-5)
STEP 3: Score options (1-5)
STEP 4: Calculate weighted scores
STEP 5: Consider qualitative factors

EXAMPLE: Choosing a database

| Criterion       | Weight | PostgreSQL | MongoDB | DynamoDB |
|-----------------|--------|------------|---------|----------|
| Query flexibility | 5    | 5 (25)     | 4 (20)  | 2 (10)   |
| Scalability      | 4     | 3 (12)     | 4 (16)  | 5 (20)   |
| Team expertise   | 4     | 5 (20)     | 2 (8)   | 2 (8)    |
| Cost             | 3     | 4 (12)     | 3 (9)   | 3 (9)    |
| Operational ease | 3     | 3 (9)      | 3 (9)   | 5 (15)   |
|-----------------|--------|------------|---------|----------|
| TOTAL           |        | 78         | 62      | 62       |

WINNER: PostgreSQL (but consider DynamoDB if scale is critical)
```

### Reversibility Assessment

```
REVERSIBLE DECISIONS (Move fast)
├── Code style changes
├── Internal refactoring
├── Feature flags
├── A/B tests
└── → Decide quickly, iterate

IRREVERSIBLE DECISIONS (Move carefully)
├── Database schema in production
├── Public API contracts
├── Security architecture
├── Vendor lock-in choices
└── → Deep analysis, get consensus
```

### Trade-off Analysis

```
COMMON TRADE-OFFS:

Speed ←→ Quality
├── When to favor speed: Prototypes, MVPs, time-sensitive
└── When to favor quality: Core systems, security, public APIs

Simplicity ←→ Flexibility
├── When to favor simplicity: Most cases, start here
└── When to favor flexibility: Known varying requirements

DRY ←→ Coupling
├── When to favor DRY: True duplication, same concept
└── When to favor duplication: Different contexts, may diverge

Performance ←→ Readability
├── When to favor performance: Measured bottlenecks
└── When to favor readability: Almost always

FRAMEWORK:
1. Identify the trade-off explicitly
2. Understand the consequences of each direction
3. Consider: What's easier to change later?
4. Default to the safer option
5. Document the decision and reasoning
```

### SWOT for Technical Decisions

```
             HELPFUL              HARMFUL
           ┌────────────────────┬────────────────────┐
INTERNAL   │    STRENGTHS       │    WEAKNESSES      │
           │ - Team expertise   │ - Technical debt   │
           │ - Existing tools   │ - Skill gaps       │
           │ - Code quality     │ - Documentation    │
           ├────────────────────┼────────────────────┤
EXTERNAL   │  OPPORTUNITIES     │     THREATS        │
           │ - New technologies │ - Security risks   │
           │ - Community growth │ - Vendor changes   │
           │ - Market needs     │ - Competitors      │
           └────────────────────┴────────────────────┘
```

---

## Part 3: Creative Problem Solving

### Constraint Removal

```
TECHNIQUE: Temporarily remove constraints to find creative solutions

Example: "We can't add this feature, our API is too slow"

Remove constraint: "What if the API was infinitely fast?"
→ We'd show real-time updates

Now work backward: "How do we approximate that?"
→ WebSockets, optimistic updates, caching, pagination

The constraint removal reveals the GOAL (real-time feel)
Then we find ALTERNATIVE PATHS to that goal
```

### Inversion

```
TECHNIQUE: Consider the opposite

Instead of: "How do we make this faster?"
Ask: "How could we make this SLOWER?"
→ Add unnecessary database calls
→ Skip caching
→ Process synchronously
→ Fetch more data than needed

Then INVERT: Avoid those things
→ Solution becomes clear
```

### Analogy Mining

```
TECHNIQUE: Find solutions in other domains

Problem: Users abandon long forms

Analogies:
- Video games → Progress bars, achievements, save points
- Travel booking → Multi-step with clear stages
- Conversations → One question at a time

Applied solution:
- Wizard-style steps with progress indicator
- Save draft automatically
- Celebrate completions of sections
```

### The "10x" Approach

```
TECHNIQUE: Imagine a 10x better solution

Current: Users can search products by name
10x: Users can find exactly what they need instantly

What would 10x require?
- Natural language search
- Image search
- Recommendation engine
- Filters and facets
- Instant preview

Then scale back to feasible:
- Enhanced search with filters (2x)
- Add autocomplete (3x)
- Add recommendations (5x)
```

---

## Part 4: Debugging Mastery

### The Scientific Method for Debugging

```
1. OBSERVE
   └── What exactly happens?
   └── When does it happen?
   └── Who is affected?

2. HYPOTHESIZE
   └── What could cause this?
   └── List 3+ hypotheses
   └── Rank by likelihood

3. PREDICT
   └── If hypothesis X is true, what else should we see?
   └── What test would prove/disprove it?

4. EXPERIMENT
   └── Design minimal test
   └── Change ONE variable
   └── Measure results

5. ANALYZE
   └── Did prediction match reality?
   └── If not, update hypothesis
   └── If yes, confirm with more tests

6. CONCLUDE
   └── Document findings
   └── Implement fix
   └── Verify fix
   └── Add regression test
```

### Binary Search Debugging

```
Problem: Something broke between commit A and commit Z

1. Find midpoint commit M
2. Test at M
3. If broken: Problem is between A and M (recurse left)
   If working: Problem is between M and Z (recurse right)
4. Repeat until single commit identified

git bisect automates this:
$ git bisect start
$ git bisect bad              # Current is broken
$ git bisect good abc123      # This commit was working
# Git checks out middle, you test
$ git bisect good/bad         # Based on test
# Repeat until found
```

### Rubber Duck Debugging

```
TECHNIQUE: Explain the code to an inanimate object (or yourself)

Process:
1. State what the code is supposed to do
2. Explain each line in plain language
3. When you can't explain something clearly, you've found the bug

Why it works:
- Forces linear thinking through the code
- Exposes assumptions
- Activates different cognitive processes
- Often solves problems before finishing explanation
```

### The Wolf Fence Algorithm

```
PROBLEM: Bug exists somewhere in large codebase

1. Put a "fence" (breakpoint/log) halfway through the flow
2. Does the bug appear before or after the fence?
3. Move fence to middle of remaining section
4. Repeat until bug is cornered

Example:
- Bug in checkout flow (10 steps)
- Add log after step 5
- Data is correct at step 5 → bug is in steps 6-10
- Add log after step 7
- Data is wrong at step 7 → bug is in steps 6-7
- Add log in step 6
- Found: calculation error in step 6
```

---

## Part 5: Architecture Thinking

### The C4 Model Questions

```
LEVEL 1: CONTEXT
├── What is the system?
├── Who uses it?
├── What does it depend on?
└── What depends on it?

LEVEL 2: CONTAINERS
├── What are the deployable units?
├── How do they communicate?
├── What technology does each use?
└── What are their responsibilities?

LEVEL 3: COMPONENTS
├── What are the major components within each container?
├── How do they interact?
├── What patterns are used?
└── What are the interfaces?

LEVEL 4: CODE
├── How is each component implemented?
├── What are the key classes/functions?
├── What design patterns are used?
└── What are the data structures?
```

### Architecture Decision Records (ADR)

```markdown
# ADR-001: Use PostgreSQL for Primary Database

## Status
Accepted

## Context
We need a database for storing user data, transactions, and product catalog.
Expected scale: 1M users, 10M transactions/month.

## Decision
We will use PostgreSQL as our primary database.

## Consequences
Positive:
- Strong ACID guarantees
- Rich query capabilities
- Team familiarity
- Excellent tooling

Negative:
- Vertical scaling limits
- Need to plan sharding for extreme scale
- Operational complexity vs managed NoSQL

## Alternatives Considered
- MongoDB: More flexible schema, but we have well-defined relations
- DynamoDB: Better scaling, but query limitations
- MySQL: Similar to PostgreSQL, but less feature-rich
```

### Evolutionary Architecture

```
PRINCIPLE: Build for change, not perfection

1. DELAY IRREVERSIBLE DECISIONS
   └── Use abstractions that hide implementation
   └── Example: Repository pattern hides database choice

2. BUILD SMALL, DEPLOY OFTEN
   └── Smaller changes, easier rollback
   └── Feature flags for gradual rollout

3. PLAN FOR FAILURE
   └── Circuit breakers
   └── Graceful degradation
   └── Retry with backoff

4. MEASURE EVERYTHING
   └── What gets measured gets improved
   └── A/B testing for decisions
   └── Observability for debugging
```

---

## Part 6: Cognitive Biases to Avoid

### Common Traps

```
ANCHORING
└── First solution seems best
└── Fix: Generate 3+ alternatives before deciding

CONFIRMATION BIAS
└── Seeking evidence for what we believe
└── Fix: Actively try to disprove your hypothesis

SUNK COST FALLACY
└── Continuing because of past investment
└── Fix: Evaluate based only on future value

PREMATURE OPTIMIZATION
└── Optimizing before measuring
└── Fix: Profile first, optimize bottlenecks only

NIH (Not Invented Here)
└── Rejecting external solutions
└── Fix: Evaluate libraries/services objectively

BIKESHEDDING
└── Focusing on trivial aspects
└── Fix: Time-box discussions, use conventions

COMPLEXITY BIAS
└── Preferring complex solutions
└── Fix: Default to simplest solution that works

AVAILABILITY HEURISTIC
└── Using recent examples as typical
└── Fix: Gather broader data before deciding
```

### Mitigation Strategies

```
1. SLOW DOWN
   └── Take time before major decisions
   └── Sleep on it for irreversible choices

2. SEEK DISSENT
   └── Ask: "What could go wrong?"
   └── Assign devil's advocate role

3. USE CHECKLISTS
   └── Systematic evaluation beats intuition

4. DOCUMENT REASONING
   └── Forces explicit thinking
   └── Enables review and learning

5. GET EXTERNAL PERSPECTIVE
   └── Fresh eyes see blind spots
   └── Explain to someone unfamiliar
```

### Get Second Opinion (Multi-Model Pattern)

When dealing with complex reasoning, use DeepSeek R1 for a second opinion:

```
WHEN TO GET A SECOND OPINION:
├── Complex algorithm design
├── Edge case analysis
├── Security-sensitive logic
├── Performance trade-offs
├── Architectural decisions
└── When you're uncertain

HOW TO USE DEEPSEEK R1:

deepseek chat_completion
model: "deepseek-reasoner"  # R1 for deep reasoning
message: "Review this approach: [details]. What edge cases am I missing?"

IMPORTANT:
├── DeepSeek ADVISES, YOU DECIDE
├── Compare their reasoning with yours
├── Use their perspective to improve, not replace your judgment
├── Don't blindly accept - evaluate critically
└── Document why you agree/disagree
```

**Example workflow:**

```
You (Opus): "This caching algorithm handles invalidation, but I want to verify."
  → Ask DeepSeek R1: "What edge cases could break this cache invalidation logic?"
  → DeepSeek suggests: "Consider concurrent writes during invalidation window"
  → You evaluate: "Good point. I'll add a distributed lock."
  → You decide: Implement the lock (YOUR decision, not DeepSeek's)
```

---

## Quick Reference Card

```
ANALYSIS:
□ 5 Whys for root cause
□ Fishbone for factor mapping
□ Systems thinking for flows

DECISIONS:
□ Decision matrix for options
□ Reversibility check
□ Trade-off explicit

CREATIVITY:
□ Constraint removal
□ Inversion thinking
□ Analogy mining
□ 10x imagination

DEBUGGING:
□ Scientific method
□ Binary search
□ Rubber duck
□ Wolf fence

ARCHITECTURE:
□ C4 model questions
□ ADR documentation
□ Evolutionary design

BIASES:
□ Generate alternatives
□ Seek contradicting evidence
□ Future value only
□ Default to simple
```

---

*Part of the Agent Enhancement Kit for world-class coding agents.*
