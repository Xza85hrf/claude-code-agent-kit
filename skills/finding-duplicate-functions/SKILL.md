---
name: finding-duplicate-functions
description: Use when auditing a codebase for semantic duplication - functions that do the same thing but have different names or implementations, especially useful for LLM-generated codebases
---

# Finding Duplicate Functions

## Overview

LLM-generated codebases accumulate semantic duplicates - functions that accomplish identical goals through different implementations. Traditional duplication detection tools miss these because the code looks different even when the intent is the same.

**Core principle:** Combine classical extraction (shell scripts) with LLM-powered clustering to recognize intent-based similarities that pattern matching misses.

## When to Use

**Use this skill when:**
- Auditing codebase for consolidation opportunities
- Reviewing LLM-generated code before merge
- Preparing for major refactoring
- Codebase has grown organically without strict architecture
- Multiple developers (or LLM sessions) added similar functionality

**High-risk areas for duplication:**
- Utility functions (string manipulation, date formatting)
- Validation logic (email, phone, input checks)
- Error formatting and handling
- Path manipulation
- API response transformations
- Configuration parsing

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

Group functions by their likely domain/purpose. This is a classification task - fast model is sufficient.

```
Prompt for Haiku:
"Categorize these function signatures by domain (validation, formatting,
API, data-transformation, etc.). Group similar-intent functions together.
Output as JSON: { "category": ["func1", "func2", ...] }"
```

**Categories must have 3+ functions** to warrant duplicate analysis.

### Phase 3: Split Into Category Files

```bash
# Create file per category for focused analysis
for category in validation formatting api; do
  grep -f "${category}_funcs.txt" functions.txt > "${category}_analysis.txt"
done
```

### Phase 4: Detect Duplicates (Use Opus)

For each category with 3+ functions, use Opus for precise semantic analysis.

```
Prompt for Opus:
"Analyze these functions for semantic duplication. Two functions are
duplicates if they:
1. Accomplish the same goal (even with different approaches)
2. Could be consolidated without loss of functionality
3. Differ only in naming, error handling style, or minor implementation

For each duplicate pair, explain:
- What both functions do
- How they differ
- Which to keep and why
- Migration path for callers

Output format:
DUPLICATE_SET_1:
  - functionA (file:line)
  - functionB (file:line)
  INTENT: [what they both do]
  KEEP: [which one and why]
  MIGRATE: [how to update callers]"
```

### Phase 5: Generate Consolidation Report

```markdown
# Duplicate Function Report

## Summary
- Functions analyzed: X
- Duplicate sets found: Y
- Estimated lines removable: Z

## High-Confidence Duplicates
[Sets where consolidation is straightforward]

## Needs Review
[Sets where the right choice isn't obvious]

## Recommended Actions
1. [Specific consolidation steps]
2. [Test coverage requirements]
```

## Model Selection Guide

| Phase | Model | Reason |
|-------|-------|--------|
| Categorize | Haiku | Cost-effective, classification is simple |
| Detect | Opus | Precision needed for subtle semantic matches |
| Report | Sonnet | Structured output, moderate complexity |

**Critical:** Haiku is cost-effective for categorization but misses subtle semantic duplicates. Always use Opus for the actual detection phase.

## Common Duplicate Patterns

### Pattern 1: Renamed Duplicates
```javascript
// These do the same thing
function validateEmail(email) { ... }
function isValidEmailAddress(addr) { ... }
function checkEmailFormat(input) { ... }
```

### Pattern 2: Implementation Variants
```javascript
// Same intent, different approach
function formatDate(d) { return d.toISOString().split('T')[0]; }
function dateToString(date) { return `${date.getFullYear()}-${...}`; }
```

### Pattern 3: Scope Duplicates
```javascript
// Utilities duplicated in multiple modules
// utils/string.js
function capitalize(s) { ... }

// components/helpers.js
function capitalizeFirst(str) { ... }
```

## Consolidation Checklist

Before removing duplicates:

```
□ Both functions have test coverage
□ All callers identified (grep for function names)
□ Edge case behavior matches (or is documented)
□ Error handling is consistent
□ Performance is acceptable
□ Types/signatures are compatible
□ Migration path documented
```

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
