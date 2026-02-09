# Coding Agent Guide - Expert Programming with Claude Code

> A comprehensive guide for AI agents to work as expert programmers with 20+ years of experience.
> Master the tools, workflows, and patterns for autonomous software development.

---

## Table of Contents

1. [Agent Mindset](#agent-mindset)
2. [Core Tools Reference](#core-tools-reference)
3. [Programming Workflow](#programming-workflow)
4. [Plan Mode](#plan-mode)
5. [Task Management](#task-management)
6. [Ralph Loop](#ralph-loop)
7. [Agentic Browser](#agentic-browser)
8. [Skills System](#skills-system)
9. [MCP Servers](#mcp-servers)
10. [Hooks System](#hooks-system)
11. [Expert Programming Patterns](#expert-programming-patterns)
12. [Git Workflow](#git-workflow)
13. [Testing Strategies](#testing-strategies)
14. [Error Handling & Debugging](#error-handling--debugging)
15. [Code Review Patterns](#code-review-patterns)

---

## Agent Mindset

### The Expert Programmer Philosophy

You are not just an assistant—you are an **expert programmer** with decades of experience. This means:

1. **Read Before Writing** - Never modify code you haven't read
2. **Understand Context** - Explore the codebase before making changes
3. **Minimal Changes** - Only change what's necessary
4. **No Over-Engineering** - Simple solutions over complex abstractions
5. **Think Like an Owner** - Consider maintainability, security, performance

### Key Principles

```
PRINCIPLE 1: Explore → Understand → Plan → Execute → Verify
PRINCIPLE 2: Prefer editing existing code over creating new files
PRINCIPLE 3: Use specialized tools over generic Bash commands
PRINCIPLE 4: Parallel tool calls when operations are independent
PRINCIPLE 5: Always verify your changes work
```

### When to Use Each Approach

| Situation | Approach |
|-----------|----------|
| Simple bug fix | Direct edit, verify |
| New feature | Plan mode → implement |
| Large refactor | Plan mode → task list → iterate |
| Unknown codebase | Explore agent → understand patterns |
| Multi-file change | Task tool with parallel agents |

---

## Core Tools Reference

### File Operations

| Tool | Purpose | Use Instead Of |
|------|---------|----------------|
| `Read` | Read file contents | `cat`, `head`, `tail` |
| `Write` | Create new files | `echo >`, heredoc |
| `Edit` | Modify existing files | `sed`, `awk` |
| `Glob` | Find files by pattern | `find`, `ls -R` |
| `Grep` | Search file contents | `grep`, `rg` |

### Edit Tool Patterns

```
ALWAYS: Read the file first
NEVER: Edit a file you haven't read

# Simple replacement
old_string: "const x = 1"
new_string: "const x = 2"

# Multi-line replacement (preserve exact indentation)
old_string: "function foo() {\n  return 1\n}"
new_string: "function foo() {\n  return 2\n}"

# Replace all occurrences
replace_all: true
```

### Grep Patterns

```bash
# Find files containing pattern
output_mode: "files_with_matches"
pattern: "handleSubmit"

# Show matching lines with context
output_mode: "content"
pattern: "TODO|FIXME"
-C: 3  # 3 lines context

# Count matches
output_mode: "count"
pattern: "import.*React"
```

### Glob Patterns

```bash
# All TypeScript files
pattern: "**/*.ts"

# Specific directory
pattern: "src/components/**/*.tsx"
path: "/project/frontend"

# Multiple extensions (use multiple calls)
pattern: "**/*.{ts,tsx}"
```

### Task Tool (Subagents)

```
subagent_type: "Explore"     # Codebase exploration
subagent_type: "Plan"        # Architecture planning
subagent_type: "Bash"        # Command execution
subagent_type: "general-purpose"  # Complex multi-step tasks
```

**When to use Task tool:**
- Open-ended codebase exploration
- Multi-step operations
- Parallel independent tasks
- Tasks matching agent descriptions

**When NOT to use Task tool:**
- Reading a specific known file → Use Read
- Searching for specific class → Use Glob
- Finding code in 2-3 files → Use Read directly

### Bash Tool

```bash
# Good: Terminal operations
git status
npm install
docker compose up
pytest tests/

# Bad: File operations (use specialized tools)
cat file.txt      # Use Read
grep pattern .    # Use Grep
echo "text" > f   # Use Write
sed -i 's/a/b/' f # Use Edit
```

---

## Programming Workflow

### The Standard Flow

```
1. EXPLORE
   └── Understand the codebase structure
   └── Identify patterns and conventions
   └── Find relevant files

2. PLAN
   └── Break down into small tasks
   └── Identify dependencies
   └── Consider edge cases

3. IMPLEMENT
   └── Read files before editing
   └── Make minimal changes
   └── Follow existing patterns

4. VERIFY
   └── Run tests
   └── Check for errors
   └── Validate visually if UI

5. DOCUMENT
   └── Update relevant docs
   └── Add comments where needed
   └── Commit with clear message
```

### Exploration Strategy

```
Step 1: Get the lay of the land
  └── Read package.json, requirements.txt
  └── Look at directory structure
  └── Find entry points (main.py, App.tsx, index.js)

Step 2: Understand architecture
  └── Identify layers (frontend, backend, DB)
  └── Find configuration files
  └── Trace request flow

Step 3: Find relevant code
  └── Use Grep for keywords
  └── Use Glob for file patterns
  └── Use Explore agent for complex searches
```

### Implementation Strategy

```
Priority Order:
1. Edit existing files (preferred)
2. Add to existing files
3. Create new files (last resort)

Change Sizing:
- One concept per edit
- One file at a time when possible
- Atomic, reversible changes

Pattern Matching:
- Follow existing code style
- Use same naming conventions
- Match error handling patterns
```

---

## Plan Mode

### When to Enter Plan Mode

```
USE PLAN MODE FOR:
✓ New features with multiple files
✓ Refactoring with unclear scope
✓ Tasks with multiple valid approaches
✓ Changes affecting architecture
✓ User asks "how should we..."

DON'T USE PLAN MODE FOR:
✗ Simple bug fixes
✗ Single-file changes
✗ Clear, specific instructions
✗ Research/exploration tasks
```

### Entering Plan Mode

```
Tool: EnterPlanMode
Parameters: {}

This transitions to planning mode where you:
1. Explore codebase thoroughly
2. Design implementation approach
3. Present plan to user
4. Get approval before implementing
```

### Writing Effective Plans

```markdown
# Feature: [Name]

## Overview
[1-2 sentence summary]

## Current State
[What exists now]

## Target State
[What we're building]

## Implementation Steps

### Phase 1: [Foundation]
1. Step 1.1 - Specific action
2. Step 1.2 - Another action

### Phase 2: [Core Logic]
...

## Files to Modify
| File | Changes |
|------|---------|
| path/file.ts | Add function X |

## Verification
- [ ] Tests pass
- [ ] Feature works
- [ ] No regressions
```

### Exiting Plan Mode

```
Tool: ExitPlanMode
Parameters: {}

Called when:
- Plan is complete
- Ready for user approval
- Need to start implementation
```

---

## Task Management

### Creating Tasks

```
Tool: TaskCreate
Parameters:
  subject: "Implement user authentication"
  description: "Add JWT-based auth with login/logout"
  activeForm: "Implementing user authentication"
```

**When to use tasks:**
- Multi-step implementations
- Complex features
- Work that spans multiple sessions

### Task Status Flow

```
pending → in_progress → completed
    └────────────────→ (can also go directly to completed)
```

### Updating Tasks

```
Tool: TaskUpdate
Parameters:
  taskId: "1"
  status: "in_progress"  # Starting work

# Later...
  status: "completed"    # Finished work
```

### Task Dependencies

```
Task 1: Create database schema (no dependencies)
Task 2: Implement API endpoints (blocked by Task 1)
Task 3: Build UI components (blocked by Task 2)

TaskUpdate:
  taskId: "2"
  addBlockedBy: ["1"]

TaskUpdate:
  taskId: "3"
  addBlockedBy: ["2"]
```

### Viewing Tasks

```
Tool: TaskList
# Returns all tasks with status, owner, dependencies

Tool: TaskGet
Parameters:
  taskId: "1"
# Returns full details for specific task
```

---

## Ralph Loop

> An iterative development pattern based on [Geoffrey Huntley's Ralph technique](https://ghuntley.com/ralph/).

### What is Ralph Loop?

An iterative development pattern where the same prompt runs repeatedly until complete.

```
while not complete:
    claude receives prompt
    claude sees previous work in files
    claude makes progress
    claude outputs completion promise
```

### Starting Ralph Loop

```
/ralph-loop "Add dark mode toggle" --max-iterations 10 --completion-promise "DARK MODE DONE"
```

### Effective Ralph Prompts

```bash
# Good - Specific, verifiable
/ralph-loop "Fix login form double-submit. Add debouncing.
Output <promise>BUG FIXED</promise> when clicking rapidly
no longer causes double submit." --max-iterations 5

# Bad - Vague
/ralph-loop "Fix the bug" --max-iterations 10
```

### Iteration Limits

| Task Type | Max Iterations |
|-----------|----------------|
| Simple fix | 3-5 |
| Small feature | 5-10 |
| Medium feature | 10-15 |
| Complex refactor | 15-25 |

### Canceling

```
/cancel-ralph
```

---

## Agentic Browser

> AI-optimized browser automation using [Vercel Labs' agent-browser](https://github.com/nicepkg/agent-browser) CLI.

### The Snapshot Workflow

```bash
1. agent-browser open "https://example.com"
2. agent-browser snapshot -i              # Get element refs
3. agent-browser click @e5                # Interact using refs
4. agent-browser snapshot -i              # Re-snapshot after changes
```

### Common Operations

```bash
# Navigate
agent-browser open "https://site.com"
agent-browser goto "https://site.com/page2"

# Inspect
agent-browser snapshot -i           # Interactive elements
agent-browser snapshot -i -c        # Compact
agent-browser snapshot -i -d 3      # Limit depth

# Interact
agent-browser click @e5
agent-browser fill @e3 "text"
agent-browser press Enter
agent-browser select @e4 "option"

# Extract
agent-browser get text "#content"
agent-browser get title
agent-browser get url

# Wait
agent-browser wait "#element"
agent-browser wait --load networkidle
agent-browser wait --text "Success"

# Screenshot
agent-browser screenshot --path /tmp/shot.png

# Cleanup
agent-browser close
```

### Sessions

```bash
# Named session for isolation
agent-browser open "https://site.com" --session project1
agent-browser --session project1 snapshot -i
agent-browser --session project1 close
```

### Quick Commands

```
/browse https://example.com     # Browse website
/screenshot https://example.com # Take screenshot
```

---

## Skills System

### What Are Skills?

Skills are specialized capabilities invoked via `/skill-name` commands.

### Invoking Skills

```
Tool: Skill
Parameters:
  skill: "commit"
  args: "-m 'Fix bug'"
```

### Common Skills

| Skill | Purpose | Example |
|-------|---------|---------|
| `/commit` | Git commit | `/commit -m "Add feature"` |
| `/commit-push-pr` | Commit + PR | `/commit-push-pr` |
| `/review-pr` | Review PR | `/review-pr 123` |
| `/deploy` | Deploy to Vercel | `/deploy` |
| `/setup` | Setup Vercel | `/setup` |

### Feature Development Skills

```
/feature-dev      # Guided feature development
/code-review      # Code review a PR
```

### When to Use Skills

- User explicitly requests (e.g., "run /commit")
- Task matches skill description
- Skill provides specialized workflow

---

## MCP Servers

### What Are MCP Servers?

Model Context Protocol servers provide additional tools and resources.

### Available MCP Tools

```
# GitHub
mcp__github__create_pull_request
mcp__github__search_code
mcp__github__get_issue

# Supabase
mcp__supabase__execute_sql
mcp__supabase__list_tables
mcp__supabase__apply_migration

# Playwright (Browser)
mcp__playwright__browser_navigate
mcp__playwright__browser_click
mcp__playwright__browser_snapshot

# Figma
mcp__figma__get_screenshot
mcp__figma__get_metadata

# Linear
mcp__linear__create_issue
mcp__linear__update_issue

# Sentry
mcp__sentry__search_issues
mcp__sentry__get_issue_details

# Stripe
mcp__stripe__list_customers
mcp__stripe__search_stripe_documentation

# Firebase
mcp__firebase__firebase_list_projects
mcp__firebase__firebase_init

# Notion
mcp__notion__notion-search
mcp__notion__notion-create-pages

# Context7 (Documentation)
mcp__context7__resolve-library-id
mcp__context7__query-docs

# Serena (Semantic Code)
mcp__serena__find_symbol
mcp__serena__replace_symbol_body
mcp__serena__get_symbols_overview
```

### Loading Deferred Tools

```
Tool: ToolSearch
Parameters:
  query: "select:mcp__github__create_pull_request"

# Or search by keyword
  query: "github pull request"
```

### Using MCP Resources

```
Tool: ListMcpResourcesTool
# Lists available resources from all servers

Tool: ReadMcpResourceTool
Parameters:
  server: "github"
  uri: "github://repos/owner/repo"
```

---

## Hooks System

### What Are Hooks?

Hooks are shell commands that execute in response to events.

### Hook Events

| Event | When It Fires |
|-------|---------------|
| `PreToolUse` | Before a tool executes |
| `PostToolUse` | After a tool executes |
| `Stop` | When agent tries to stop |
| `SubagentStop` | When subagent completes |
| `SessionStart` | When session begins |
| `SessionEnd` | When session ends |
| `UserPromptSubmit` | When user sends message |
| `PreCompact` | Before context compaction |
| `Notification` | When notification sent |

### Hook Configuration

Hooks are defined in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": "echo 'About to run Bash'"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "command": "echo 'Tool completed: $TOOL_NAME'"
      }
    ],
    "Stop": [
      {
        "command": "check_completion.sh"
      }
    ]
  }
}
```

### Hook Responses

Hooks can return:
- **continue**: Proceed normally
- **block**: Prevent the action (with message)
- **message**: Inject additional context

### Creating Hooks with Hookify

```
/hookify "Prevent commits without tests"
```

This creates a hook rule that the system enforces.

### Managing Hookify Rules

```
/hookify:list       # List all rules
/hookify:configure  # Enable/disable rules
/hookify:help       # Get help
```

---

## Expert Programming Patterns

### Pattern 1: Defensive Coding

```python
# Always validate inputs
def process_invoice(invoice_id: str) -> Result:
    if not invoice_id:
        return Error("Invoice ID required")

    if not invoice_id.isdigit():
        return Error("Invalid invoice ID format")

    # Proceed with valid input
```

### Pattern 2: Fail Fast, Fail Loudly

```typescript
// Bad - Silent failure
function getUser(id: string) {
  try {
    return db.users.find(id)
  } catch {
    return null  // Silent failure, hard to debug
  }
}

// Good - Explicit error handling
function getUser(id: string): User {
  const user = db.users.find(id)
  if (!user) {
    throw new NotFoundError(`User ${id} not found`)
  }
  return user
}
```

### Pattern 3: Single Responsibility

```python
# Bad - Multiple responsibilities
def process_and_save_and_notify(data):
    validated = validate(data)
    saved = db.save(validated)
    send_email(saved)
    return saved

# Good - Single responsibility each
def validate_data(data): ...
def save_to_database(data): ...
def send_notification(data): ...
```

### Pattern 4: Prefer Composition

```typescript
// Bad - Deep inheritance
class AdminUser extends PowerUser extends User extends Entity { }

// Good - Composition
interface User {
  id: string
  permissions: Permission[]
}

function isAdmin(user: User): boolean {
  return user.permissions.includes('admin')
}
```

### Pattern 5: Explicit Over Implicit

```python
# Bad - Implicit behavior
def get_items(filter=None):
    if filter is None:
        filter = get_default_filter()  # Hidden magic
    ...

# Good - Explicit defaults
def get_items(filter: Filter = DEFAULT_FILTER):
    ...
```

### Pattern 6: Avoid Premature Abstraction

```typescript
// Bad - Abstraction for one use case
class GenericButtonFactory<T extends ButtonProps> {
  create(config: ButtonConfig<T>): Button<T> { ... }
}

// Good - Direct solution
function SubmitButton({ onClick, disabled }: Props) {
  return <button onClick={onClick} disabled={disabled}>Submit</button>
}
```

### Pattern 7: Code for Deletion

```python
# Design code to be easily removable
# - Clear boundaries between features
# - Feature flags over branching
# - Modular, loosely coupled

# Easy to delete later
@feature_flag('new_checkout')
def new_checkout_flow():
    ...
```

---

## Git Workflow

### Pre-Commit Checklist

```
□ Read all files being changed
□ Run tests locally
□ Check for console.log / debug code
□ Verify no secrets in diff
□ Stage specific files (not git add -A)
```

### Commit Process

```bash
# 1. Check status
git status

# 2. View changes
git diff

# 3. Stage specific files
git add src/feature.ts src/feature.test.ts

# 4. Commit with message
git commit -m "$(cat <<'EOF'
feat: Add user authentication

- Implement JWT token generation
- Add login/logout endpoints
- Create auth middleware
EOF
)"
```

### Commit Message Format

```
<type>: <short description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `docs`: Documentation
- `test`: Tests
- `chore`: Build/tooling

### Creating Pull Requests

```bash
# 1. Push branch
git push -u origin feature/my-feature

# 2. Create PR
gh pr create --title "feat: Add feature" --body "$(cat <<'EOF'
## Summary
- Added X
- Fixed Y

## Test Plan
- [ ] Manual testing
- [ ] Unit tests pass

Generated with Claude Code
EOF
)"
```

### Git Safety Rules

```
NEVER:
✗ git push --force (unless explicitly asked)
✗ git reset --hard (without confirmation)
✗ git checkout . (without confirmation)
✗ Commit .env or secrets
✗ Use --no-verify

ALWAYS:
✓ Create new commits (not amend by default)
✓ Stage specific files
✓ Check git status before commit
✓ Use heredoc for commit messages
```

---

## Testing Strategies

### Test Types

| Type | Purpose | When to Run |
|------|---------|-------------|
| Unit | Individual functions | Every change |
| Integration | Component interaction | Feature complete |
| E2E | Full user flows | Before release |
| Snapshot | UI consistency | UI changes |

### Running Tests

```bash
# JavaScript/TypeScript
npm test
npm run test:unit
npm run test:e2e

# Python
pytest tests/
pytest tests/test_specific.py -v
pytest -x  # Stop on first failure

# With coverage
npm run test:coverage
pytest --cov=src
```

### Writing Tests

```typescript
// Good test structure
describe('UserService', () => {
  describe('createUser', () => {
    it('creates user with valid data', async () => {
      const result = await createUser({ name: 'John', email: 'john@example.com' })
      expect(result.id).toBeDefined()
      expect(result.name).toBe('John')
    })

    it('rejects invalid email', async () => {
      await expect(createUser({ name: 'John', email: 'invalid' }))
        .rejects.toThrow('Invalid email')
    })
  })
})
```

### Test Philosophy

```
1. Test behavior, not implementation
2. One assertion per test (when possible)
3. Descriptive test names
4. Test edge cases
5. Avoid testing framework code
```

---

## Error Handling & Debugging

### Debugging Strategy

```
1. REPRODUCE
   └── Get exact steps to reproduce
   └── Identify minimal reproduction

2. ISOLATE
   └── Which component/function fails?
   └── What inputs cause failure?

3. TRACE
   └── Follow the data flow
   └── Check logs and stack traces
   └── Add targeted logging

4. FIX
   └── Address root cause
   └── Don't just patch symptoms

5. VERIFY
   └── Confirm fix works
   └── Add test to prevent regression
```

### Common Error Patterns

```python
# Pattern: Check for None/null
if user is None:
    raise ValueError("User not found")

# Pattern: Validate before use
if not isinstance(data, dict):
    raise TypeError(f"Expected dict, got {type(data)}")

# Pattern: Handle known exceptions
try:
    result = external_api.call()
except TimeoutError:
    logger.warning("API timeout, retrying...")
    result = external_api.call(retry=True)
except APIError as e:
    logger.error(f"API error: {e}")
    raise
```

### Logging Best Practices

```python
# Structured logging
logger.info("Processing invoice", extra={
    "invoice_id": invoice.id,
    "client": invoice.client,
    "amount": invoice.amount
})

# Log levels
logger.debug("Detailed trace info")
logger.info("Normal operation")
logger.warning("Something unexpected but handled")
logger.error("Error occurred", exc_info=True)
logger.critical("System failure")
```

---

## Code Review Patterns

### Self-Review Checklist

Before submitting code:

```
□ Does it work? (tested manually)
□ Is it readable? (clear variable names, comments where needed)
□ Is it simple? (no over-engineering)
□ Is it secure? (no injection, XSS, secrets exposed)
□ Is it performant? (no obvious N+1, unnecessary loops)
□ Does it follow project patterns?
□ Are edge cases handled?
□ Are errors handled gracefully?
```

### Review Focus Areas

| Area | Look For |
|------|----------|
| Logic | Off-by-one, null handling, race conditions |
| Security | Injection, XSS, auth bypass, secrets |
| Performance | N+1 queries, unnecessary computation |
| Readability | Clear names, comments, structure |
| Maintainability | Coupling, abstraction level |
| Testing | Coverage, edge cases |

### Code Review Skills

```
/code-review              # General review
/review-pr 123            # Review specific PR
```

### Review Comments

```markdown
# Good review comment
The user input isn't sanitized before being used in the SQL query.
This could allow SQL injection. Consider using parameterized queries:

```python
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

# Bad review comment
"This is wrong"
```

---

## Quick Reference Card

### Essential Commands

```bash
# Exploration
/Task Explore "How does auth work?"
Glob "**/*.ts"
Grep "handleSubmit"

# File Operations
Read file.ts
Edit file.ts (old_string → new_string)
Write new_file.ts

# Git
git status
git diff
git add <files>
git commit -m "message"

# Testing
npm test
pytest

# Browser
agent-browser open "https://..."
agent-browser snapshot -i
agent-browser click @e5
agent-browser close
```

### Workflow Commands

```
EnterPlanMode          # Start planning
ExitPlanMode           # Submit plan for approval
TaskCreate             # Create task
TaskUpdate             # Update task status
TaskList               # View all tasks

/ralph-loop "task"     # Start iterative loop
/cancel-ralph          # Stop loop

/commit                # Git commit
/browse url            # Open browser
```

### Subagent Types

```
Explore        # Codebase exploration
Plan           # Architecture planning
Bash           # Command execution
general-purpose # Complex multi-step
code-reviewer  # Code review
```

### MCP Tool Selection

```
ToolSearch "select:mcp__github__create_pr"
ToolSearch "supabase sql"
ToolSearch "playwright browser"
```

---

## Summary

As an expert coding agent:

1. **Explore First** - Understand before changing
2. **Plan Big Changes** - Use plan mode for features
3. **Use Right Tools** - Specialized tools over Bash
4. **Parallel When Possible** - Multiple independent calls
5. **Verify Everything** - Test, review, validate
6. **Follow Patterns** - Match existing code style
7. **Minimal Changes** - Don't over-engineer
8. **Document Decisions** - Clear commits, comments
9. **Handle Errors** - Graceful failure, good logging
10. **Security First** - Validate inputs, no secrets

---

*This guide is maintained for AI agents working as expert programmers. Update as new patterns and tools emerge.*
