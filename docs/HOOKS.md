# Hooks

Hooks are shell scripts that fire on Claude Code lifecycle events. They read JSON from stdin and emit JSON on stdout. This kit ships ~30 of them, organized into two profiles.

## Profiles

| Profile | Hooks | What you get |
|---------|:---:|--------------|
| `minimal` | 10 | Safety only — path protection, git guards, secrets scan, tool-failure handling |
| `standard` | 30 | Everything in minimal, plus delegation enforcement, skill-gate, test reminders, blast-radius, review-gate, capability pipeline |

Switch: `bash .claude/scripts/apply-profile.sh minimal|standard`.

## Events Covered

Standard profile wires into 10 events:

| Event | Why we hook it |
|-------|---------------|
| `SessionStart` | Log startup, check worker availability |
| `UserPromptSubmit` | Inject delegation guidance based on prompt intent |
| `PreToolUse` | Block dangerous ops, enforce delegation/skill gates |
| `PostToolUse` | Secrets scan, test reminders, skill-token minting |
| `PostToolUseFailure` | Explain tool errors with actionable next steps |
| `PermissionRequest` | Auto-approve safe patterns (read-only, tests, dev deps) |
| `PermissionDenied` | Log and suggest alternatives |
| `Stop` | Skill-check before ending turn |
| `SessionEnd` | Capture session state |
| `StopFailure` | Handle API errors, rate limits, auth issues |

## Category Map

| Category | Hooks | What they do |
|----------|-------|-------------|
| **Safety** | `damage-control`, `block-dangerous-git`, `validate-commit`, `safe-parallel-bash`, `check-secrets`, `security-check` | Protect paths, block `rm -rf /`, enforce Conventional Commits, scan for API keys |
| **Delegation** | `delegation-check`, `delegation-reminder`, `delegation-token`, `capability-gate`, `capability-tracker` | Nudge worker delegation based on line count; mint tokens when workers are used |
| **Skills** | `skill-gate`, `skill-token`, `track-skill-invocation`, `proactive-skill-trigger` | Require matching skill loaded for domain writes; suggest skills based on edits |
| **Git workflow** | `blast-radius-check`, `build-before-push`, `review-gate`, `git-push-review` | Preview PR impact before push, run tests, review diff |
| **Quality** | `test-reminder`, `prevent-common-mistakes` | Nudge tests after edits, catch common LLM mistakes |
| **Session** | `session-start`, `session-end`, `stop-skill-check` | Lifecycle logging and state capture |
| **Permissions** | `auto-approve-safe-patterns`, `permission-denied-handler`, `tool-policy-engine` | Smart allow/deny, role-based policies |
| **Failure handling** | `handle-tool-failure`, `handle-stop-failure`, `handle-fetch-error` | Turn errors into actionable guidance |

## Hook Output Contract

Hooks read `{tool_name, tool_input, session_id, ...}` from stdin. They output JSON on stdout per event type:

```json
// PreToolUse — allow / block / ask
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny" | "ask",
    "permissionDecisionReason": "human-readable"
  }
}

// PostToolUse — advisory only
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "message shown to Claude"
  }
}

// Other events (Stop, SessionStart, etc.)
{
  "systemMessage": "status line"
}
```

The shared helper `lib/hook-protocol.sh` provides `hook_signal()` which picks the right schema per event. Prefer it over raw `jq`.

## Signalling Convention

Hooks that want the agent to do something emit structured advice:

```
[HOOK:name] context | DO: next action
```

Example (from `delegation-reminder`):

```
[HOOK:delegation-reminder] File grew to 72 lines without a worker call
| DO: Delegate to glm-5.1:cloud via `bash .claude/scripts/mcp-cli.sh ollama chat ...`
```

Claude reads these and adjusts. If the hook `BLOCK`s:

```
BLOCKED[damage-control]: rm -rf /path/outside/project
| DO: Scope the rm to a subdirectory, or use `bash .claude/scripts/allow-protected.sh rm <path>`
```

## Writing a Custom Hook

1. Create `.claude/hooks/my-hook.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   INPUT="$(cat)"
   TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

   # your logic

   jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow"}}'
   exit 0
   ```

2. Make executable: `chmod +x .claude/hooks/my-hook.sh`.

3. Register in `.claude/profiles/standard.json` (or `minimal.json`):

   ```json
   "PreToolUse": [
     { "matcher": "Write", "script": "my-hook.sh", "timeout": 5 }
   ]
   ```

4. Re-apply the profile: `bash .claude/scripts/apply-profile.sh standard`.

5. Test standalone: `echo '{"tool_name":"Write","tool_input":{"file_path":"test.txt"}}' | .claude/hooks/my-hook.sh`.

## Conditional Hooks

Use `if` to filter before the process spawns (cheap):

```json
{ "matcher": "Bash", "if": "Bash(git *)", "script": "block-dangerous-git.sh", "timeout": 5 }
```

The `if` pattern uses the same syntax as `permissions.allow`/`deny`.

## Async Hooks

Long-running checks that don't need to block:

```json
{ "script": "dashboard-emit.sh", "timeout": 10, "async": true, "statusMessage": "Logging metrics..." }
```

Async hooks cannot deny — they're fire-and-forget observability.

## Debugging

| Problem | Fix |
|---------|-----|
| Hook never fires | Check matcher: `jq '.hooks.<Event>' .claude/settings.local.json` |
| Hook fires but no effect | Its stderr is suppressed by Claude Code — run standalone with test JSON |
| Hook blocks things it shouldn't | Read the block message — it shows which script and which pattern triggered |
| Bypass a block once (emergency only) | `date +%s > .claude/.damage-control-bypass` — 5-minute TTL |

## Reference

All hooks live in `.claude/hooks/`. Each is self-documenting — read the header comment. The profile JSONs in `.claude/profiles/` are the source of truth for which hook fires when.
