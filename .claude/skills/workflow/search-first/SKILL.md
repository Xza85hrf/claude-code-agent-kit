---
name: search-first
description: Before writing code, search for existing solutions — tools, libraries, patterns, or MCP servers.
argument-hint: "Search for existing auth libraries and caching patterns before building custom"
department: workflow
thinking-level: low
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Search-First — Research Before Code

## When to Activate
- Starting any new feature or capability
- Encountering common problems (auth, caching, validation, UI)
- Needing external integration (APIs, services, databases)
- Facing complex logic with established patterns
- Uncertain whether custom code is required

## Workflow

Need Analysis → Parallel Search → Evaluate → Decide → Implement

## Decision Matrix

| Signal | Action |
|--------|--------|
| Exact match, well-maintained, MIT/Apache | **Adopt** — install and use directly |
| Partial match, extensible | **Extend** — install + thin wrapper |
| Multiple tools cover parts | **Compose** — combine 2-3 packages |
| No match, unique requirement | **Build** — custom, informed by research |

## Search Checklist

1. **In-repo**: `rg` through utilities, helpers, prior art
2. **Package managers**: npm, PyPI, crates.io
3. **MCP servers**: check `~/.claude/settings.json`, search modelcontextprotocol.io
4. **Existing skills**: check `~/.claude/skills/`
5. **GitHub**: code search, trending, awesome lists
6. **Context7**: `resolve-library-id` → `query-docs` for up-to-date docs

## Integration

- **With planner**: Research BEFORE Phase 1 (Architecture Review)
- **With architect**: Consult for technology stack decisions
- **With iterative-retrieval**: Combine for progressive discovery

## Anti-Patterns
- Writing custom code without searching first (NIH syndrome)
- Selecting tools without evaluating community health/maintenance
- Installing massive packages for one small feature
- Skipping search based on "it probably doesn't exist" assumption
