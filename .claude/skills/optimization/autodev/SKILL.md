---
name: autodev
description: Autonomous code optimization loop — iteratively modify, benchmark, keep improvements for performance gains. Use when optimizing a specific file against a numeric metric (ops/sec, bundle size, latency, throughput) where an overnight benchmark loop makes sense. NOT for correctness bugs (use systematic-debugging), refactors without a metric (use code-refactoring), or multi-file architectural changes (use writing-plans).
argument-hint: "Optimize src/sort.ts — benchmark with 'node bench.js', metric from 'jq .opsPerSec results.json', direction higher"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: opus
department: optimization
references: []
thinking-level: medium
---

# autodev — Autonomous Code Optimization

Karpathy's autoresearch pattern applied to code: one file, one metric, iterate overnight.

## How It Works

```
Loop N times:
  1. LLM generates a hypothesis + code modification
  2. Benchmark runs with fixed time budget
  3. Metric extracted and compared to best
  4. If improved → commit. If not → revert.
  5. History fed back to LLM for next iteration.
```

## Setup

The user must provide:
1. **Target file** — the single file to optimize
2. **Benchmark command** — how to run the benchmark (e.g., `node bench.js`, `python -m pytest --benchmark-only`)
3. **Metric command** — outputs a single number to stdout (e.g., `jq '.mean' results.json`)
4. **Direction** — is `higher` or `lower` better?

Optional:
- **program.md** — research guidance (what to try, constraints, domain knowledge)
- **Budget** — seconds per benchmark run (default: 300)
- **Iterations** — how many experiments (default: 20)

## Execution

```bash
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/autodev.sh" \
  --target TARGET_FILE \
  --bench "BENCHMARK_COMMAND" \
  --metric "METRIC_COMMAND" \
  --direction higher|lower \
  --max-iter 20 \
  --budget 300 \
  --program path/to/program.md
```

### Dry Run First

Always start with `--dry-run` to verify the plan:
```bash
bash "${KIT_ROOT:-${CLAUDE_PLUGIN_ROOT:-.}}/.claude/scripts/autodev.sh" --target ... --bench ... --metric ... --dry-run
```

## Writing a program.md

The program.md guides the LLM's optimization strategy. Example:

```markdown
# Optimize Sort Performance

## Context
This is a comparison sort used on arrays of 10K-100K elements.
Elements are partially sorted in practice (~80% sorted).

## What to Try
- Algorithm swaps: TimSort, IntroSort, BlockSort
- Insertion sort for small partitions (<32 elements)
- Branch prediction hints
- Cache-friendly memory access patterns

## Constraints
- Must remain a stable sort
- Must handle empty arrays and single elements
- No external dependencies
```

## Safety

- Works on a **git branch** (never modifies main)
- Reverts failed experiments automatically
- Commits each improvement with full context
- Trap handler prints summary on Ctrl+C
- Benchmark runs with timeout (no runaway processes)

## After Completion

Review the branch:
```bash
git log --oneline autodev/...   # See what stuck
git diff main                    # Review total change
git checkout main && git merge autodev/...  # Apply if happy
```

## Advanced: Autonomous Experimentation (pi-autoresearch pattern)

For multi-session optimization campaigns (100+ experiments), use persistent state files.

### Persistence Files

| File | Purpose |
|------|---------|
| `.autodev/optimization.jsonl` | Append-only experiment log (one JSON per run) |
| `.autodev/optimization.md` | Living doc: objective, tried, dead ends, insights |
| `.autodev/ideas.md` | Backlog of unexecuted optimization ideas |
| `.autodev/checks.sh` | Backpressure: tests/types that must pass after each keep |

### Experiment Log Format

Each line in `optimization.jsonl`:
```json
{"run": 1, "commit": "a1b2c3d", "metric": 100, "status": "keep", "description": "baseline", "segment": 0, "secondaries": {"memory_mb": 512}}
```

Status values: `keep` (improved, committed) | `discard` (worse, reverted) | `crash` (runtime error) | `checks_failed` (tests broke)

### Living Document Template

```markdown
# Optimization: [Target]

## Objective
[What metric, what direction, what constraints]

## Files in Scope
- src/parser.ts — main target

## What's Been Tried
- ✅ Object pool caching (2% gain) — keep
- ✗ Memoization (memory thrash) — discard

## Dead Ends
- Lazy parsing: slower due to context switching overhead

## Current Best
Run #8: 42.3ms (baseline: 100ms, -57.7%)
```

### Multi-Metric Tracking

Track secondary metrics alongside primary:
- **Primary**: the optimization target (drives keep/discard)
- **Secondary**: everything else (memory, compile time, cache hits) — tracked for awareness, don't affect decisions

### Backpressure Checks

If `.autodev/checks.sh` exists, it runs after every passing benchmark:
```bash
#!/bin/bash
# .autodev/checks.sh — must pass before "keep"
npm run typecheck && npm test
```
If checks fail → status = `checks_failed`, changes reverted. Prevents optimizations that break correctness.

### Segment Isolation

Each `init` call increments the segment counter, enabling:
- Multiple optimization targets in one repo
- Re-baselining when switching targets
- Clear separation without branches

### Cross-Session Resume

A fresh agent reads `.autodev/optimization.md` + last 20 lines of `optimization.jsonl` to resume:
1. Parse "What's Been Tried" → avoid repeating failed approaches
2. Parse "Dead Ends" → skip known bad paths
3. Read `ideas.md` → try structural changes when stuck
4. Continue from current best metric

## When to Use

- Performance optimization (throughput, latency, ops/sec)
- Size optimization (bundle size, memory usage)
- Quality optimization (accuracy, error rate)
- Any scenario with: one file + measurable metric + clear direction
