---
name: impact-analysis
description: Systematic blast radius review after infrastructure changes. Validate deployment vectors, check cross-references. Use after modifying kit internals (hooks, scripts, libs, profiles, damage-control patterns, plugin.json) to catch broken install-global.sh paths, orphaned references, and plugin/synced-project regressions BEFORE landing. NOT for general code review (use pre-landing-review) or pure app code without infra impact.
argument-hint: "Analyze impact of recent changes to .claude/lib/env-defaults.sh"
allowed-tools: Bash, Read, Grep, Glob
model: inherit
department: quality
references: []
thinking-level: high
---

# Impact Analysis — Blast Radius Review

Systematic review of downstream impacts after kit infrastructure changes.

## When to Use

- After modifying shared libs (`.claude/lib/`)
- After changing deploy scripts (`install-global.sh`)
- After updating profiles, skills registry, or hook configs
- Before committing changes that touch multiple kit components
- When the `blast-radius-check` hook fires an advisory

## Step 1: Identify Changes

```bash
# What changed since main?
git diff --name-only main..HEAD

# Or just staged changes
git diff --cached --name-only
```

## Step 2: Run Blast Radius Analysis

```bash
# Human-readable output for all changed files
git diff --name-only main..HEAD | xargs kit blast-radius.sh

# JSON for programmatic use
git diff --name-only main..HEAD | xargs kit blast-radius.sh --json
```

## Step 3: Verify Each Impact Category

### DEPLOYED BY hits

For each deploy script listed:
1. Check the script handles the changed file type
2. Dry-run if available: `kit install-global.sh --force` (test install)
3. Verify file appears in plugin after install

### SOURCED BY hits

For each dependent script:
1. Validate syntax: `bash -n "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/<script>`"
2. Check the sourced variable/function is still exported with same name
3. If you renamed or removed exports, grep all consumers

### GENERATES hits

For each generated output:
1. Re-run the generator:
   - `skills.yml` → `kit build-skill-index.sh`
   - `profiles/*.json` → `kit generate-hooks-json.sh`
   - `workflows.yml` → `kit build-skill-index.sh`
2. Verify output is valid: `jq empty` for JSON, visual check for Markdown

### IMPORTED BY hits

For each @-importing file:
1. Read the parent file
2. Verify the @-import reference still resolves
3. Check that section headings or anchors haven't changed

### VALIDATE hits

Run each validation command listed in the output:
```bash
jq empty .claude/profiles/full.json
bash -n "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/blast-radius.sh"
```

## Step 4: Cross-Check Deployment Vectors

| Vector | Command | Verify |
|--------|---------|--------|
| Global plugin | `install-global.sh --force` | File count matches |
| New project | `/init-project` | CLAUDE.md + .gitignore created |
| Hooks JSON | `generate-hooks-json.sh` | Hook count correct |
| Skill index | `build-skill-index.sh` | Skill count correct |
| Globals | `setup-globals.sh` | Rules/agents synced |

## Step 4B: Structural Code Analysis

For code changes (not just kit files), analyze call graphs and dependencies to understand blast radius in application code.

### Call Graph Traversal

```bash
# Find all callers of a function (TypeScript/JavaScript)
grep -rn "functionName\|methodName" src/ --include="*.ts" --include="*.tsx" --include="*.js"

# Find all imports of a module
grep -rn "from ['\"].*moduleName" src/ --include="*.ts" --include="*.tsx"

# TypeScript: Use compiler API for precise references
npx ts-prune  # Find unused exports
npx ts-unused-exports tsconfig.json  # More detailed unused export analysis
```

### Dead Code Detection

| Method | Tool | What It Finds |
|--------|------|---------------|
| Unused exports | `ts-prune` | Exported functions/types never imported |
| Unused files | `unimported` | Files not reachable from entry points |
| Unreachable code | TypeScript `noUnusedLocals` | Local vars, parameters never read |
| Dead CSS | `purgecss` | CSS selectors not used in templates |
| Unused dependencies | `depcheck` | npm packages installed but never imported |

```bash
# Quick dead code scan
npx ts-prune | grep -v "used in module"
npx unimported
npx depcheck --ignores="@types/*"
```

### Type Reference Analysis (for Refactoring)

Before renaming or restructuring types:

```bash
# Find all usages of a type/interface
grep -rn "TypeName" src/ --include="*.ts" --include="*.tsx" | grep -v "\.d\.ts"

# Find implementations of an interface
grep -rn "implements TypeName\|extends TypeName" src/ --include="*.ts"

# Find all files that would break if a type changes
# (look for property access patterns)
grep -rn "\.propertyName\b" src/ --include="*.ts" --include="*.tsx"
```

### Blast Radius Depth Groups

When analyzing impact, group by severity:

| Depth | Impact | Action |
|-------|--------|--------|
| **Direct** (depth 1) | Callers that import and use the changed function | **Will break** — must update |
| **Indirect** (depth 2) | Files that import direct callers | **May break** — review |
| **Transitive** (depth 3+) | Files further downstream | **Review** — unlikely but possible |

```bash
# Depth-1: Direct importers
grep -rn "from ['\"].*changed-module" src/ --include="*.ts" -l

# Depth-2: Files importing depth-1 results
for f in $(grep -rn "from ['\"].*changed-module" src/ --include="*.ts" -l); do
  basename="${f%.ts}"
  grep -rn "from ['\"].*${basename##*/}" src/ --include="*.ts" -l
done
```

## Step 5: Semantic Check (Optional)

For deeper analysis, use embedding similarity:
```bash
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/embed-codebase.sh" --related .claude/lib/env-defaults.sh
```

This surfaces files the hardcoded map might miss.

## Completion Gate

All checks pass → safe to commit. Any failure → fix before committing.

Report format:
```
IMPACT ANALYSIS REPORT
======================
Files analyzed: N
Deployment vectors verified: N/N
Source consumers validated: N/N
Generated outputs refreshed: N/N
Cross-references checked: N/N

Overall: [CLEAR / ISSUES FOUND]
```
