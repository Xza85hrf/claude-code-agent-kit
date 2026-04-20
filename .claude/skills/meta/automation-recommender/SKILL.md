---
name: automation-recommender
description: Analyze codebase for automation opportunities — hooks, scripts, CI/CD improvements for developer workflow.
argument-hint: "Analyze this codebase and recommend automation improvements"
allowed-tools: Read, Grep, Glob, Bash
model: inherit
department: quality
references: []
thinking-level: medium
---

# Automation Recommender

## Purpose

Analyze a codebase to identify automation opportunities — hooks, scripts, CI/CD, quality gates, and workflow improvements that reduce manual work and catch errors earlier.

## Analysis Areas

| Area | Check | Recommend |
|------|-------|-----------|
| **Build & Dev** | Build command, dev server, hot-reload, dependency scripts | Missing build scripts, dev server automation |
| **Testing** | Framework configured, coverage, pre-commit hooks, CI tests | Test automation, coverage gates, pre-commit hooks |
| **Code Quality** | Linter, formatter, type checking, automation | Linters, formatters, type-check automation |
| **Git Workflow** | Commit conventions, branch protection, PR template, git hooks | Git hooks, conventional commits, PR templates |
| **Security** | Secrets management, secrets scanner, dependency auditing, SAST | Secret detection hooks, dependency auditing, SAST |
| **Claude Code** | CLAUDE.md, hooks, skills, worker delegation | Missing hooks, skills, delegation config |
| **CI/CD** | Pipeline, tests/lint/typecheck, deployment, environment configs | Missing CI/CD stages, deployment automation |

## Process

1. **Scan** project structure for config files
2. **Check** each area above
3. **Assess** maturity (1-5 scale per area)
4. **Recommend** by impact/effort
5. **Present** report

## Output Format

```
## Automation Analysis Report

**Project:** [name]
**Overall Maturity:** [1-5] / 5

| Area | Maturity | Key Gap |
|------|----------|---------|
| Build & Dev | X/5 | [gap] |
| Testing | X/5 | [gap] |
| Code Quality | X/5 | [gap] |
| Git Workflow | X/5 | [gap] |
| Security | X/5 | [gap] |
| Claude Code | X/5 | [gap] |
| CI/CD | X/5 | [gap] |

### High-Impact Recommendations

#### 1. [Recommendation Title] (Effort: Low/Med/High)
**Area:** [area]
**Current state:** [what exists now]
**Recommendation:** [specific action]
**Implementation:**
[Concrete steps or code snippet]

#### 2. [Recommendation Title] (Effort: Low/Med/High)
...

#### 3. [Recommendation Title] (Effort: Low/Med/High)
...

### Quick Wins (< 15 min each)
- [ ] [Action item with specific command or file to create]
- [ ] [Action item]
- [ ] [Action item]

### Future Improvements (Nice to Have)
- [Lower priority items]
```

## Key Principles

- Prioritize IMPACT × EASE
- Be SPECIFIC (not "add eslint" but "run `npm init @eslint/config` and add to pre-commit")
- Check what ALREADY EXISTS
- Scale recommendations to project size
- Explain WHY each recommendation prevents problems

## After the Analysis

Suggest:
- `Skill("claude-md-improver")` if CLAUDE.md needs work
- Direct implementation of quick wins (with user permission)
- `Skill("writing-plans")` for complex automation additions

Do NOT create any other files. Do NOT commit.
