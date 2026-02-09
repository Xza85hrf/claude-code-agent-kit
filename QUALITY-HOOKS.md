# Quality Hooks System

> Automated quality checks that run during agent operations.
> Prevents common mistakes and enforces standards.

---

## Overview

Hooks intercept agent actions and can:
- **Block** dangerous operations
- **Warn** about potential issues
- **Enhance** with additional context
- **Log** for audit trails

---

## Quick Setup

### 1. Copy Hooks Directory

```bash
cp -r portable-kit/hooks .claude/hooks
chmod +x .claude/hooks/*.sh
```

### 2. Add to Settings

Use the provided `settings.local.json` which includes all 22 hooks pre-configured:

```bash
# Automated setup (recommended)
cd /path/to/portable-kit && ./setup.sh /path/to/your/project

# Manual setup
cp portable-kit/settings.local.json .claude/settings.local.json
```

The full hooks configuration registers hooks across 5 event types:

| Event | Hooks | Purpose |
|-------|-------|---------|
| `UserPromptSubmit` | 1 hook | Delegation & skill check reminders |
| `Stop` | 1 hook | Completion verification checklist |
| `SessionStart` | 2 hooks | Session guidance + Ollama model check |
| `PreToolUse` | 10 hooks | Safety gates, delegation enforcement (incl. Serena), parallel safety |
| `PostToolUse` | 5 hooks | Secret detection, security, tests, delegation token (incl. Serena) |
| `PostToolUseFailure` | 1 hook | Recovery guidance when tools fail |
| `TeammateIdle` | 1 hook | Checks for unclaimed tasks before idle |
| `TaskCompleted` | 1 hook | Blocks completion on merge conflicts |

**Important notes:**
- `timeout` is in **seconds** (not milliseconds)
- Use `"$CLAUDE_PROJECT_DIR"` for portable paths
- Each hook needs the nested `hooks` array with `type: "command"`
- See `settings.local.json` for the complete configuration

---

## Included Hooks (22)

### UserPromptSubmit Hooks (Before User Message Processing)

| Hook | Purpose |
|------|---------|
| `delegation-check.sh` | Injects delegation and skill check reminders as context before every user message |

### Session Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `session-start.sh` | SessionStart | Provides guidance and active hooks reminder |
| `check-ollama-models.sh` | SessionStart | Reports available/missing Ollama worker models |

### PreToolUse Hooks (Before Execution)

| Hook | Matcher | Purpose |
|------|---------|---------|
| `block-dangerous-git.sh` | Bash | Blocks destructive git operations (force push, reset --hard, etc.) |
| `validate-commit.sh` | Bash | Validates conventional commit message format |
| `validate-github-url.sh` | WebFetch | Warns about potentially incorrect GitHub paths |
| `verify-before-explore.sh` | WebFetch | Suggests verifying repo structure before fetching |
| `check-file-size.sh` | Write | Warns when creating large files (>500 lines) |
| `delegation-reminder-write.sh` | Write | Blocks writing >10 lines of code without delegation (allows with token or if Ollama down) |
| `delegation-reminder-edit.sh` | Edit | Blocks inserting >10 lines of code without delegation (allows with token or if Ollama down) |
| `prevent-common-mistakes.sh` | WebFetch, Edit, Write | Catches common agent errors before they happen |
| `safe-parallel-bash.sh` | Bash | Auto-appends `|| true` to diff commands, preventing sibling cancellation |
| `serena-write-guard.sh` | Serena write tools | Blocks Serena tools from bypassing delegation enforcement (same 3-tier logic) |

### Stop Hooks (Before Completing)

| Hook | Purpose |
|------|---------|
| `stop-skill-check.sh` | Injects verification checklist ensuring skills were invoked and work was verified |

### PostToolUse Hooks (After Execution)

| Hook | Matcher | Purpose |
|------|---------|---------|
| `handle-fetch-error.sh` | WebFetch | Provides recovery guidance when fetch fails |
| `check-secrets.sh` | Write, Edit, Serena write tools | Detects potential secrets/credentials in code |
| `security-check.sh` | Write, Edit, Serena write tools | Checks for SQL injection, command injection, etc. |
| `test-reminder.sh` | Edit, Serena edit tools | Reminds to run tests after code changes |
| `delegation-token.sh` | ollama_chat, ollama_generate | Creates time-limited token after worker delegation |

### PostToolUseFailure Hooks (After Tool Failure)

| Hook | Matcher | Purpose |
|------|---------|---------
| `handle-tool-failure.sh` | Any tool | Provides recovery guidance (sibling cancellation, delegation tokens) |

---

## Hook Details

### 1. Block Dangerous Git (`block-dangerous-git.sh`)

**Blocks these patterns:**
```
git push --force / git push -f
git reset --hard
git checkout .
git restore .
git clean -f / -fd
git branch -D
git stash drop / clear
git push origin :main / :master
```

**Why:** These commands can cause data loss and require explicit user approval.

### 2. Validate GitHub URL (`validate-github-url.sh`)

**Checks for:**
- Wrong path patterns (e.g., `/prompts/skills/` instead of `/skills/`)
- Non-standard branch names
- Using `github.com/blob` instead of `raw.githubusercontent.com`

**Why:** Prevents 404 errors from guessed/incorrect paths.

### 3. Verify Before Explore (`verify-before-explore.sh`)

**Reminds to:**
- Use `gh api repos/owner/repo/contents` to verify structure
- Not guess at deep file paths

**Why:** Many 404 errors come from assuming repo structure without verification.

### 4. Prevent Common Mistakes (`prevent-common-mistakes.sh`)

**Catches:**
- WebFetch: Deep URL paths that are likely guessed
- WebFetch: Common assumption folders (prompts/, templates/, examples/)
- Edit: Very short old_string that might match multiple locations
- Write: Overwriting important config files without reading first

**Why:** These are common agent mistakes that waste tokens and time.

### 5. Handle Fetch Error (`handle-fetch-error.sh`)

**When WebFetch fails, provides:**
- GitHub-specific recovery guidance
- Common fixes checklist
- Alternative approaches (gh api)

**Why:** Helps agent recover quickly from fetch failures.

### 6. Check Secrets (`check-secrets.sh`)

**Detects:**
- API keys, tokens, passwords
- AWS credentials
- Private keys
- Database connection strings with credentials
- JWT tokens

**Why:** Prevents accidentally committing credentials.

### 7. Security Check (`security-check.sh`)

**Detects:**
- SQL injection patterns (string concatenation in queries)
- Command injection (shell execution with user input)
- Disabled SSL verification
- Hardcoded localhost in non-config files
- Debug mode enabled

**Why:** Catches common security vulnerabilities early.

### 8. Check File Size (`check-file-size.sh`)

**Limits:**
- Code files: 500 lines
- Markdown/docs: 1000 lines
- Test files: 800 lines

**Why:** Large files are harder to maintain and review.

### 9. Validate Commit (`validate-commit.sh`)

**Enforces:**
- Conventional commit format: `type(scope): description`
- Valid types: feat, fix, refactor, docs, test, chore, style, perf, ci, build, revert

**Why:** Consistent commit history and automated changelog generation.

### 10. Test Reminder (`test-reminder.sh`)

**After editing code:**
- Checks if corresponding test file exists
- Reminds to run tests if it does
- Suggests adding tests if it doesn't

**Why:** Encourages test-driven development.

### 11. Session Start (`session-start.sh`)

**At session start:**
- Lists active quality hooks
- Provides best practices reminder
- Sets expectations for the session

**Why:** Helps agent operate with awareness of quality checks.

### 12. Delegation Check (`delegation-check.sh`)

**Before every user message:**
- Injects a structured delegation checklist as `additionalContext`
- Reminds agent to classify work type (tool-dependent vs content generation)
- Lists delegation rules (>10 lines, boilerplate, multi-file swarm)
- Lists skill invocation requirements (skills require explicit `Skill("name")` calls)

**Why:** CLAUDE.md's delegation and skill rules were purely advisory text with no enforcement. This hook bridges the gap between "rules written as text" and "rules enforced by hooks," ensuring the agent sees the checklist before every response.

### 13. Delegation Enforcement Write (`delegation-reminder-write.sh`)

**When Write tool is used on code files >10 lines:**
- Counts lines in the content being written
- Skips non-code files (.md, .json, .yaml, .txt, etc.)
- Checks for a valid delegation token (created by `delegation-token.sh` after ollama calls)
- If valid token exists (< 5 min old): **allows** silently (worker output integration)
- If no token + Ollama is up: **blocks** with `permissionDecision: "deny"`
- If no token + Ollama is down: **warns** but allows (graceful fallback)
- Logs violations to `.claude/delegation-violations.log`

**Why:** Blocking hooks prevent the "I'll just do it" trap, but must allow the legitimate workflow: delegate → receive → integrate. The delegation token (created automatically after `ollama_chat`/`ollama_generate` calls) proves the agent went through the authorized path.

### 14. Delegation Enforcement Edit (`delegation-reminder-edit.sh`)

**When Edit tool inserts >10 lines into code files:**
- Same three-tier logic as the Write hook (token → block → warn)
- Counts lines in `new_string`, skips non-code files
- Logs violations to `.claude/delegation-violations.log`

**Why:** Same enforcement pattern as the Write hook, applied to Edit's `new_string`.

### 14b. Delegation Token (`delegation-token.sh`)

**After ollama_chat or ollama_generate calls:**
- Creates `.claude/.delegation-token` with current Unix timestamp
- Token is valid for 300 seconds (5 minutes)
- Time-based (not single-use) so swarm patterns work (multiple ollama calls → multiple writes)

**Why:** The Write/Edit enforcement hooks need to distinguish between self-generated code (block) and worker-integrated code (allow). The token acts as a CSRF-like proof that the agent delegated before writing. Without this, the hooks would block their own intended workflow.

### 14c. Serena Write Guard (`serena-write-guard.sh`)

**When any Serena file-modification tool writes >10 lines to code files:**
- Matches: `create_text_file`, `replace_content`, `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`
- Extracts content from the correct field per tool (`content`, `repl`, or `body`)
- Same three-tier logic as Write/Edit hooks (token → block → warn)
- Uses `relative_path` (Serena's field name) instead of `file_path`
- Logs violations with `SERENA:tool_name` prefix

**Why:** Serena MCP tools can write/edit files through a different code path than Claude Code's native Write/Edit tools, bypassing all PreToolUse hooks registered for those tools. This hook closes that enforcement gap.

**Also covered — PostToolUse hooks updated:**
- `check-secrets.sh`, `security-check.sh`, `test-reminder.sh` now also match Serena tools
- These hooks resolve `relative_path` to absolute path via `$CLAUDE_PROJECT_DIR` when `file_path` is absent

### 15. Stop Skill Check (`stop-skill-check.sh`)

**Before the agent finishes responding:**
- Injects a completion checklist as `additionalContext`
- Asks agent to self-verify: Were skills invoked? Was delegation used? Were changes verified?
- If the agent realizes it missed something, the context causes it to continue working

**Why:** Skills require explicit invocation but the agent may forget. This hook creates a last-chance checkpoint before the agent stops, catching missed skill invocations and unverified work.

### 16. Check Ollama Models (`check-ollama-models.sh`)

**At session start:**
- Pings the Ollama API (`$OLLAMA_HOST` or `localhost:11434`)
- Reports which expected worker models are available vs missing
- Fails gracefully if Ollama is unreachable (reports status, doesn't block)

**Why:** Delegation rules assume worker models are available. If they're not, the agent wastes time trying to delegate to models that don't exist. This check gives the agent awareness of which models are actually available.

### 17. Teammate Idle (`teammate-idle.sh`)

**When a teammate is about to go idle:**
- Reads `team_name` from stdin JSON
- Checks `~/.claude/teams/{team-name}/tasks/` for pending, unclaimed, unblocked tasks
- If unclaimed tasks exist → exit 2 (keeps teammate working with stderr feedback)
- If no tasks or missing directory → exit 0 (allows idle gracefully)

**Exit code behavior:** TeammateIdle hooks use exit codes only, NOT `hookSpecificOutput` JSON. Exit 0 = allow idle, exit 2 = prevent idle (stderr shown as feedback).

**Why:** Prevents teammates from going idle when unclaimed work remains in the shared task pool. Fails open — if no team context is available, allows idle without blocking.

### 18. Task Completed (`task-completed.sh`)

**When a task is about to be marked complete:**
- Reads `task_id` and `task_subject` from stdin JSON
- Checks for unresolved merge conflicts via `git diff --diff-filter=U`
- Scans staged files for leftover conflict markers (`<<<<<<<`, `>>>>>>>`)
- If issues found → exit 2 (blocks completion with stderr feedback)
- If clean → exit 0 (allows completion)

**Exit code behavior:** TaskCompleted hooks use exit codes only, NOT `hookSpecificOutput` JSON. Exit 0 = allow completion, exit 2 = prevent completion (stderr shown as feedback).

**Why:** Agent teams with multiple teammates editing code can produce merge conflicts. This hook prevents tasks from being marked complete when conflicts remain unresolved.

### 19. Safe Parallel Bash (`safe-parallel-bash.sh`)

**When a Bash command contains `diff`:**
- Uses `updatedInput` to append `|| true` to the command
- Prevents diff's non-zero exit code (which indicates "files differ") from being treated as a failure
- Without this, a failed diff cancels all sibling parallel tool calls

**Why:** When multiple Bash commands run in parallel (e.g., `git status`, `git diff`, `git log`), a diff "failure" (exit code 1 = files differ) causes Claude Code to cancel all sibling calls. This hook makes diff commands always succeed, preserving parallel execution.

### 20. Handle Tool Failure (`handle-tool-failure.sh`)

**When any tool fails (PostToolUseFailure):**
- Detects diff false-failures and explains they may not be real errors
- Checks delegation token status (reports if token exists and age)
- Warns about sibling tool call cancellation when parallel calls fail
- Provides targeted recovery guidance based on the failure context

**Why:** Tool failures in parallel execution can cascade — one failed call cancels siblings. This hook provides context-aware recovery guidance so the agent can retry intelligently instead of being confused by cancellations.

---

### Utility: Hook Self-Test Runner (`test-hooks.sh`)

**Not a hook — a testing utility:**
- Tests all hooks with sample inputs
- Reports pass/fail/skip for each hook
- Validates JSON output format
- Run manually: `.claude/hooks/test-hooks.sh`

**Why:** Validates the hook installation is working correctly after setup or updates.

---

## Hook Output Format

Hooks communicate results via **exit code** and **stdout JSON**.

### Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| `0` | Allow - JSON output is processed |
| `2` | Block - stderr is shown as error message |
| Other | Non-blocking error - stderr shown in verbose mode |

### JSON Output for UserPromptSubmit

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Context injected before Claude processes the user message"
  }
}
```

### Plain Text Output for Stop

Stop hooks do **not** support `hookSpecificOutput`. They output plain text to stdout (same pattern as SessionStart). Valid JSON fields for Stop hooks are top-level only:

```json
{
  "continue": true,
  "decision": "approve",
  "reason": "Explanation shown to agent"
}
```

Most Stop hooks simply output plain text and `exit 0` — the text is added as context.

### JSON Output for PreToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "Reason shown to user/Claude",
    "additionalContext": "Context added to Claude",
    "updatedInput": { "field": "modified value" }
  }
}
```

### JSON Output for PostToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Context added to Claude"
  }
}
```

### Legacy Format (Deprecated)

The old format with top-level `decision`/`message` is deprecated:
```json
// Old format - still works but prefer hookSpecificOutput
{"decision": "continue", "message": "Warning text"}
```

---

## Hook Input Format

Hooks receive JSON input via **stdin**. Use `jq` to parse the input.

```bash
# Read JSON input from stdin
INPUT=$(cat)

# Extract fields using jq
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
```

### Common Input Fields

All hooks receive these base fields:

| Field | Description |
|-------|-------------|
| `session_id` | Current session identifier |
| `transcript_path` | Path to conversation JSON |
| `cwd` | Current working directory |
| `permission_mode` | Current permission mode |
| `hook_event_name` | Name of the event that fired |
| `tool_name` | Name of the tool (PreToolUse/PostToolUse) |
| `tool_input` | Tool-specific input parameters |
| `tool_response` | Tool result (PostToolUse only) |

### Tool-Specific Input Fields

| Tool | `tool_input` Fields |
|------|---------------------|
| Bash | `command`, `description`, `timeout` |
| Read | `file_path`, `offset`, `limit` |
| Write | `file_path`, `content` |
| Edit | `file_path`, `old_string`, `new_string`, `replace_all` |
| WebFetch | `url`, `prompt` |
| Glob | `pattern`, `path` |
| Grep | `pattern`, `path`, `glob`, `output_mode` |

---

## Creating Custom Hooks

### Prerequisites

```bash
# Ensure jq is installed (required for JSON parsing)
sudo apt install jq  # Ubuntu/Debian
brew install jq      # macOS
```

### Template

```bash
#!/bin/bash
# Hook: [Description]
# [Event] hook for [Tool]

# Read JSON input from stdin
INPUT=$(cat)

# Extract fields using jq
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Your logic here
if [condition]; then
  jq -n --arg reason "Reason for blocking" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

# Default: allow (exit 0 with no output)
exit 0
```

### Testing Hooks

```bash
# Run the automated self-test suite (tests all hooks)
.claude/hooks/test-hooks.sh

# Or test individual hooks manually:
echo '{"tool_input": {"command": "git push --force"}}' | ./.claude/hooks/block-dangerous-git.sh
# Expected: {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", ...}}

echo '{}' | ./.claude/hooks/delegation-check.sh | jq .
# Expected: {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", ...}}
```

---

## Delegating Hook Creation to Workers

When delegating hook script creation to Ollama workers, **always include this reference block** in the prompt. Workers cannot generate correct hooks without knowing the exact output format.

### Include in Delegation Prompt

Copy this context block into your `ollama_chat` prompt when asking a worker to write a hook:

```
=== CLAUDE CODE HOOK FORMAT REFERENCE ===

Hooks are bash scripts that read JSON from stdin and output JSON to stdout.

INPUT PATTERN (all hooks):
  INPUT=$(cat)
  FIELD=$(echo "$INPUT" | jq -r '.tool_input.field_name // empty')

Available input fields: tool_name, tool_input (object), tool_response (PostToolUse only)

OUTPUT FORMATS by event type:

PreToolUse (block/allow/modify):
  jq -n --arg reason "Why" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'

PreToolUse (allow with modified input):
  jq -n --arg cmd "modified command" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: { command: $cmd },
      additionalContext: "Explanation of modification"
    }
  }'

PostToolUse / PostToolUseFailure (context injection):
  jq -n --arg ctx "Guidance text" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'

RULES:
- Always exit 0 (even on errors)
- No output = silently allow (PreToolUse) or no context (PostToolUse)
- Use jq -n for JSON generation, jq -r for extraction
- Never use echo for JSON output — always jq
=== END REFERENCE ===
```

### Why This Is Needed

Workers lack context about the `hookSpecificOutput` format. Without the reference block, they will:
- Use wrong JSON structure (flat keys instead of nested `hookSpecificOutput`)
- Miss `permissionDecision` for PreToolUse hooks
- Not know about `updatedInput` for input modification
- Produce invalid bash (mixing JSON output with script structure)

---

## Hookify Integration

Use `/hookify` to create hooks from conversation:

```
/hookify "Always run tests before committing"
/hookify "Never edit package.json directly"
/hookify "Check for console.log before committing"
```

Manage hookify rules:

```
/hookify:list        # List all rules
/hookify:configure   # Enable/disable rules
/hookify:help        # Get help
```

---

## Best Practices

1. **Keep hooks fast** - Use timeout of 5-30 seconds max
2. **Fail open** - If hook fails, default to continue
3. **Be specific** - Use precise matchers to avoid overhead
4. **Warn, don't block** - Reserve blocking for truly dangerous actions
5. **Test thoroughly** - Verify hooks work before relying on them
6. **Log sparingly** - Only warn for real issues

---

## Troubleshooting

### Hook Not Running

1. Check matcher pattern matches the tool name
2. Verify script is executable: `chmod +x .claude/hooks/script.sh`
3. Check script outputs valid JSON
4. Verify path in settings is correct

### Hook Blocking Unexpectedly

1. Test hook manually with expected input
2. Check pattern matching logic
3. Adjust patterns to be more specific

### Hook Timeout

1. Increase timeout in settings (max recommended: 30000ms)
2. Optimize script (avoid network calls, use simple checks)
3. Consider if check is necessary

---

*Part of the Agent Enhancement Kit for world-class coding agents.*
