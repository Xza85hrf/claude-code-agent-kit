---
name: using-git-worktrees
description: Parallel development needed. Use when setting up isolated workspaces for working on multiple branches simultaneously without switching.
argument-hint: "Set up a worktree for the auth refactor while keeping main stable"
allowed-tools: Bash, Read
model: inherit
department: workflow
disable-model-invocation: true
user-invocable: false
references: []
thinking-level: low
---

# Using Git Worktrees

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Directory Selection

| Priority | Action | Notes |
|----------|--------|-------|
| 1. Existing | Check `.worktrees/` then `worktrees/` | If both exist, `.worktrees` wins |
| 2. CLAUDE.md | `grep -i "worktree.*director" CLAUDE.md` | Use specified preference without asking |
| 3. Ask | Offer `.worktrees/` (hidden) or `~/.config/superpowers/worktrees/` | User choice |

## Safety Verification

**For project-local (.worktrees or worktrees):**
```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

If NOT ignored, fix immediately (per "Fix broken things now"):
1. Add to .gitignore
2. Commit the change
3. Create worktree

**Why critical:** Prevents accidentally committing worktree contents to repository.

## Creation Steps

```bash
# 1. Detect project name
project=$(basename "$(git rev-parse --show-toplevel)")

# 2. Create worktree
case $LOCATION in
  .worktrees|worktrees) path="$LOCATION/$BRANCH_NAME" ;;
  ~/.config/superpowers/worktrees/*) path="~/.config/superpowers/worktrees/$project/$BRANCH_NAME" ;;
esac
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"

# 3. Install dependencies (auto-detect)
[ -f package.json ] && npm install
[ -f Cargo.toml ] && cargo build
[ -f requirements.txt ] && pip install -r requirements.txt
[ -f pyproject.toml ] && poetry install
[ -f go.mod ] && go mod download

# 4. Verify clean baseline (run tests)
npm test || cargo test || pytest || go test ./...
```

**If tests fail:** Report failures, ask before proceeding. If tests pass: Report ready.

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Skip ignore verification | Always use `git check-ignore` before creating |
| Assume directory location | Follow priority: existing > CLAUDE.md > ask |
| Proceed with failing tests | Report failures, get explicit permission |
| Hardcode setup commands | Auto-detect from project files |

## Red Flags

**Never:**
- Create worktree without verifying it's ignored (project-local)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous

**Always:**
- Follow directory priority: existing > CLAUDE.md > ask
- Verify directory is ignored for project-local
- Auto-detect and run project setup
- Verify clean test baseline

## Integration

**Called by:**
- **brainstorming** (Phase 4) - REQUIRED when design approved
- Any skill needing isolated workspace

**Pairs with:**
- **ship** - REQUIRED for cleanup after work complete
