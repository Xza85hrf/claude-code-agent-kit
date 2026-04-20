---
name: finding-duplicate-functions
description: Auditing for LLM-generated duplicates. Use when consolidating codebases, reviewing LLM-generated code for semantic duplicates, or preparing for major refactoring.
argument-hint: "Audit src/ for duplicate utility functions that LLM sessions may have created"
allowed-tools: Read, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: low
---

# Finding Duplicate Functions

Detect semantic duplicates in LLM-generated code using extraction + clustering.

## When to Use
- Auditing for consolidation
- Reviewing LLM code pre-merge
- Preparing major refactor
- Organic growth without architecture
- Multiple developers added similar features

**High-risk areas:** Utilities (string, date), validation, error handling, path ops, API transforms, config parsing

## The Process

### Phase 1: Extract Function Signatures

Extract all exported/public functions with their signatures.

```bash
# JavaScript/TypeScript
grep -rn "export function\|export const.*=.*=>" src/ \
  | grep -v node_modules \
  | grep -v ".test." \
  | grep -v ".spec." \
  > functions.txt

# Python
grep -rn "^def \|^async def " src/ \
  | grep -v __pycache__ \
  | grep -v test_ \
  > functions.txt
```

**Filter out:**
- Internal/private helpers (underscore prefix)
- Test files
- Generated code
- Node modules / vendor directories

### Phase 2: Categorize by Domain (Use Haiku)

Group by domain (validation, formatting, API, data-transform, etc.). Classification task — fast model sufficient.

**Requirement:** Categories must have 3+ functions for analysis.

### Phase 3: Split Into Category Files

```bash
# Create file per category for focused analysis
for category in validation formatting api; do
  grep -f "${category}_funcs.txt" functions.txt > "${category}_analysis.txt"
done
```

### Phase 4: Detect Duplicates (Use Opus)

Use Opus for precise semantic analysis per category.

Duplicates = same goal (different approaches) + consolidatable + differ only in naming/error handling.

Output:
```
DUPLICATE_SET_1:
  - functionA (file:line), functionB (file:line)
  INTENT: [goal]
  KEEP: [choice & why]
  MIGRATE: [how]
```

### Phase 5: Generate Consolidation Report

```markdown
# Duplicate Report
## Summary: X analyzed, Y duplicates, Z lines removable
## High-Confidence [straightforward consolidation]
## Needs Review [choice unclear]
## Actions [consolidation steps + test coverage]
```

## Model Selection Guide

| Phase | Model | Reason |
|-------|-------|--------|
| Categorize | Haiku | Cost-effective, classification is simple |
| Detect | Opus | Precision needed for subtle semantic matches |
| Report | Sonnet | Structured output, moderate complexity |

**Critical:** Haiku is cost-effective for categorization but misses subtle semantic duplicates. Always use Opus for the actual detection phase.

## Common Patterns

| Pattern | Example |
|---------|---------|
| Renamed | `validateEmail()`, `isValidEmailAddress()`, `checkEmailFormat()` all same |
| Implementation variants | `formatDate()` vs `dateToString()` same intent, different code |
| Scope duplicates | `utils/string.js` capitalize vs `components/helpers.js` capitalizeFirst |

## Consolidation Checklist

| Item | Check |
|------|-------|
| Test coverage | Both functions tested |
| Callers | All identified via grep |
| Edge cases | Behavior matches or documented |
| Error handling | Consistent across both |
| Performance | Acceptable |
| Types | Compatible signatures |
| Migration | Path documented |

## Common Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Skip categorization | Overwhelming analysis | Always group first |
| Use Haiku for detection | Miss subtle duplicates | Use Opus for detection |
| Consolidate without tests | Introduce regressions | Require test coverage |
| Extract internal helpers | False positives | Filter private functions |
| Ignore error handling differences | Runtime failures | Document edge cases |

## Automation Script Template

```bash
#!/bin/bash
# find-duplicates.sh

PROJECT_DIR="${1:-.}"
OUTPUT_DIR="./duplicate-analysis"

mkdir -p "$OUTPUT_DIR"

# Phase 1: Extract
echo "Extracting function signatures..."
grep -rn "export function\|export const.*=>.*{" "$PROJECT_DIR/src" \
  | grep -v node_modules \
  | grep -v "\.test\." \
  > "$OUTPUT_DIR/functions.txt"

echo "Found $(wc -l < "$OUTPUT_DIR/functions.txt") functions"

# Phase 2-5: Run with Claude
echo "Run categorization with Haiku, then detection with Opus"
echo "Functions extracted to: $OUTPUT_DIR/functions.txt"
```

## Integration with CI

```yaml
# .github/workflows/duplicate-check.yml
name: Duplicate Function Check
on:
  pull_request:
    paths: ['src/**/*.ts', 'src/**/*.js']

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Extract new functions
        run: |
          git diff --name-only origin/main | \
            xargs grep -l "export function" | \
            xargs grep "export function" > new_functions.txt
      - name: Flag for review if high-risk area
        run: |
          if grep -q "utils\|helpers\|validation" new_functions.txt; then
            echo "::warning::New utility functions added - check for duplicates"
          fi
```

## Real-World Impact

From a real codebase audit:
- **47 functions** analyzed
- **8 duplicate sets** identified
- **~400 lines** of code removable
- **3 subtle bugs** found (inconsistent error handling)
- **Result:** Cleaner codebase, single source of truth
