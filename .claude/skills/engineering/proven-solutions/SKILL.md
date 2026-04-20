---
name: proven-solutions
description: Maintain and leverage a curated collection of proven code solutions, POCs, and patterns as reusable building blocks that dramatically improve code generation relevance and reliability.
department: engineering
when_to_use: Use when starting new features, encountering familiar problem patterns, onboarding to new codebases, or when you need battle-tested implementations rather than generating from scratch.
thinking-level: low
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Code Solution Hoarding for Coding Agents

## Core Philosophy

Simon Willison's insight: **Coding agents perform significantly better when they have access to proven solutions rather than generating from scratch.** A well-maintained hoard of working code acts as a "contextual memory" that grounds agent outputs in practical, tested patterns.

## Why This Matters

- **Reduces hallucination**: Agents reference working code instead of inventing solutions
- **Speed**: Skip the exploration phase for solved problems
- **Consistency**: Projects share proven patterns across teams
- **Knowledge preservation**: Solutions survive beyond individual contributors
- **Iteration baseline**: Start from "works" rather than "maybe works"

## Repository Structure

~/code-hoard/
├── index.yaml                 # Master catalog with tags/keywords
├── patterns/
│   ├── authentication/
│   │   ├── jwt-refresh-token/
│   │   │   ├── code.py
│   │   │   ├── metadata.yaml
│   │   │   └── test.py
│   │   └── session-management/
│   ├── database/
│   │   ├── connection-pooling/
│   │   ├── migrations-alembic/
│   │   └── transaction-handling/
│   ├── api/
│   │   ├── rate-limiting/
│   │   ├── pagination-cursor/
│   │   └── error-handling/
│   └── concurrency/
│       ├── async-task-queue/
│       └── background-workers/
├── pocs/                      # Proof of concepts
│   ├── llm-integration/
│   └── third-party-webhooks/
└── templates/                 # Prompt templates for injection
    └── feature-template.md

## Metadata Schema (metadata.yaml)

name: jwt-refresh-token
version: 1.2.0
created: 2024-01-15
last_used: 2024-12-01
proven_in:
  - project-alpha
  - auth-service-v2
tags:
  - authentication
  - security
  - jwt
  - token-refresh
  - stateless
language: python
framework: fastapi
dependencies:
  - pyjwt>=2.8.0
  - python-dateutil
complexity: medium
testing: full  # full | partial | none
context_requirements:
  - user-model
  - secret-management
prompt_keywords:
  - "refresh token"
  - "jwt rotation"
  - "auth flow"
  - "token expiry"

## Index Structure (index.yaml)

entries:
  - path: patterns/authentication/jwt-refresh-token
    tags: [authentication, security, jwt, tokens]
    keywords: [refresh, rotation, expiry, session]
    
  - path: patterns/database/connection-pooling
    tags: [database, performance, scaling]
    keywords: [pool, connections, postgresql, async]
    
  - path: patterns/api/rate-limiting
    tags: [api, security, reliability]
    keywords: [rate limit, throttle, requests, sliding-window]

## Prompt Template Design

### Template: feature-with-hoard.md

## Task
Implement: {{TASK_DESCRIPTION}}

## Relevant Proven Solutions
{{#HOARDED_SOLUTIONS}}
### {{SOLUTION_NAME}}
Path: {{SOLUTION_PATH}}
Context: {{SOLUTION_CONTEXT}}
Key Code:
{{SOLUTION_CODE}}
{{/HOARDED_SOLUTIONS}}

## Instructions
1. Reference the proven solutions above for patterns
2. Adapt to current requirements while preserving what works
3. Maintain compatibility with: {{COMPATIBILITY_REQUIREMENTS}}
4. Include tests following: {{TEST_PATTERN}}

## Output
- Implementation following proven patterns
- Deviations clearly documented with rationale

## Retrieval Strategy

### Tag-Based Retrieval
def retrieve_solutions(task_description: str, max_results: int = 3) -> list[Solution]:
    """Retrieve most relevant proven solutions based on task."""
    keywords = extract_keywords(task_description)
    tags = classify_task(task_description)
    
    candidates = []
    for entry in index.entries:
        score = calculate_relevance(entry, keywords, tags)
        if score > THRESHOLD:
            candidates.append((entry, score))
    
    return sorted(candidates, key=lambda x: x[1], reverse=True)[:max_results]

### Scoring Heuristics
- Exact tag match: +10
- Keyword in prompt_keywords: +5
- Similar framework/language: +3
- Recently used: +2
- Proven in multiple projects: +1 per project

## Best Practices

### Building the Hoard

1. **After successful implementation**: Extract the core pattern
2. **Strip context-specifics**: Keep only reusable core
3. **Add comprehensive tests**: Tests prove it works
4. **Document context requirements**: What must exist for this to work
5. **Tag thoroughly**: Future-you won't remember exact names

### Using the Hoard

1. **Query before generating**: Always check hoard first
2. **Inject 2-3 solutions max**: Too many examples overwhelm
3. **Cite the source**: Note which proven pattern was used
4. **Feed back improvements**: Update hoard when you find better solutions

### Maintaining the Hoard

# Weekly maintenance
code-hoard audit          # Check for broken tests
code-hoard update-tags    # Suggest new tags based on usage
code-hoard prune          # Remove outdated patterns
code-hoard stats          # Usage analytics

## Integration with Claude Code

### Pre-Task Hook
Before starting any implementation task:
1. Parse task description
2. Query hoard index with task keywords
3. Retrieve top 2-3 relevant solutions
4. Inject solutions into context as examples
5. Note: "The following proven patterns may be relevant..."

### Example Injection

## Proven Solutions Available

### Rate Limiting (Sliding Window)
- Source: patterns/api/rate-limiting
- Proven in: api-gateway, payment-service
- Use when: Need to limit requests per user/IP over time windows
- Key insight: Use Redis sorted sets for O(log n) operations

## Metrics to Track

- **Hoard hit rate**: % of tasks that find relevant solutions
- **Reuse count**: How often each solution is referenced
- **Time saved**: Estimated vs actual implementation time
- **Bug reduction**: Comparing hoard-derived vs fresh code bugs

## Anti-Patterns to Avoid

1. **Hoarding everything**: Curate, don't collect
2. **No metadata**: Unindexed code is lost code
3. **No tests**: Unproven solutions are liabilities
4. **Over-genericizing**: Keep solutions specific enough to be useful
5. **Stale patterns**: Regularly update or remove outdated approaches

## Quick Start

# Initialize hoard
mkdir -p ~/code-hoard/{patterns,pocs,templates}
touch ~/code-hoard/index.yaml

# Add first solution
code-hoard add ./my-working-solution --tags="auth,jwt" --name="jwt-auth-pattern"

# Query hoard
code-hoard search "implement user authentication"
# Returns: jwt-auth-pattern (score: 0.92)

## The Meta-Pattern

This skill itself should be hoarded. The structure of maintaining proven solutions, indexing them, and injecting them contextually is itself a proven pattern for improving agent performance across all domains, not just code.
