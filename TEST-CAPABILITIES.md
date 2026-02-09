# Agent Enhancement Kit - Capability Test

> Copy and paste this entire prompt in a fresh Claude Code terminal to test all capabilities.

---

## Test Instructions

1. Open a new Claude Code terminal
2. Navigate to your project root (where you installed the kit)
3. Start Claude Code: `claude`
4. Copy everything below the line and paste it

---

## TEST PROMPT (Copy from here)

```
Read CLAUDE.md and initialize as the autonomous expert agent. Then run this capability test sequence and report results for each step.

## TEST SEQUENCE (Log everything)

### Test 1: Core Initialization
- Confirm you read CLAUDE.md
- List your decision authority levels (AUTONOMOUS, CONFIRM, ESCALATE)
- Confirm multi-model architecture awareness (Opus = brain, workers = ?)

### Test 2: Hooks System Verification
Test that hooks are working correctly (fixed to use stdin JSON input):

a) **Check settings loaded correctly**
   - Verify no "_comment in enabledPlugins" error on startup
   - Expected: Clean startup without validation errors

b) **Test hook execution** (verify hooks read from stdin, not env vars)
   - Run a simple bash command: `echo "test"`
   - Expected: No "head: invalid option" or "sleep: invalid option" errors
   - The block-dangerous-git.sh hook should pass silently

c) **Test dangerous command blocking**
   - Attempt (but don't run): Describe what would happen if you tried `git push --force`
   - Expected: Hook would return `permissionDecision: "deny"` via hookSpecificOutput

### Test 3: Core MCP Connections (Always-On)
Use ToolSearch to verify core MCPs are available:

a) **Context7 Documentation**
   - Resolve a library:
     ```
     mcp__plugin_context7_context7__resolve-library-id
       libraryName: "react"
       query: "React hooks"
     ```
   - Expected: Returns /vercel/next.js, /facebook/react or similar

b) **Query documentation**
   - Query docs:
     ```
     mcp__plugin_context7_context7__query-docs
       libraryId: "/vercel/next.js"
       query: "app router"
     ```
   - Expected: Returns current Next.js documentation

c) **Serena Semantic Code (if enabled)**
   - Test: `mcp__plugin_serena_serena__list_dir` with relative_path: "." and recursive: false
   - Expected: Returns directory listing

### Test 4: Ollama Worker Delegation
Test the multi-model architecture with actual MCP tool calls:

a) **List available models**
   ```
   ollama_list
   ```
   - Expected: Returns local models like qwen3-coder-next:latest, kimi-k2.5:cloud, glm-4.7-flash, devstral-small-2, deepcoder
   - If OLLAMA_API_KEY set: Also reports cloud models (qwen3-coder-next:cloud, glm-4.7:cloud, etc.)

b) **Model Selection Test** (match task to correct model)
   | Task Type | Correct Model | Role |
   |-----------|---------------|------|
   | Coding/boilerplate | `glm-4.7-flash` | Fast Coder |
   | Multi-step agents | `kimi-k2.5:cloud` | Agent Swarm Leader |
   | Image/vision analysis | `kimi-k2.5:cloud` | Swarm Agent + Vision |
   | Agentic SWE tasks | `devstral-small-2` | Agentic SWE Coder |
   | Code reasoning | `deepcoder` | Code Reasoning |

c) **Delegation test** - Generate code using worker:
   ```
   ollama_generate
     model: "glm-4.7-flash"
     prompt: "Write a Python one-liner that checks if a number is even: is_even = lambda n:"
   ```
   - Expected: Worker returns code like `is_even = lambda n: n % 2 == 0`
   - Opus reviews: Assess if the code is correct

d) **Chat delegation test**:
   ```
   ollama_chat
     model: "kimi-k2.5:cloud"
     messages: [{"role": "user", "content": "What are the SOLID principles? List them briefly."}]
   ```
   - Expected: Worker returns SOLID principles explanation
   - Opus reviews: Verify accuracy

### Test 5: DeepSeek Second Opinion (If Enabled)
Test getting a second opinion on complex logic:

```
deepseek chat_completion
  model: "deepseek-reasoner"
  message: "Is this regex correct for email validation? ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ What edge cases might it miss?"
```
- Expected: DeepSeek R1 provides analysis of regex edge cases
- Opus reviews: Make final assessment

### Test 6: On-Demand MCP Pattern
Verify the on-demand workflow works:

a) **Check for non-enabled MCP**
   - Run: ToolSearch "notion" (or another on-demand MCP)
   - If NOT enabled: Should return no tools (this is expected!)
   - Agent should suggest enable instructions:
     ```json
     // Add to .claude/settings.local.json
     {
       "enabledPlugins": {
         "Notion@claude-plugins-official": true
       }
     }
     ```

b) **Verify on-demand saves context**
   - Note: Core MCPs only use ~25K tokens
   - Each service MCP adds 5-21K tokens
   - Enabling all would use ~80K+ tokens

### Test 7: Skills Awareness
- Skills require EXPLICIT invocation via Skill("name") — they do NOT auto-activate.
- List 5 skills and their invocations:
  1. Skill("test-driven-development") — implementing features or fixing bugs
  2. Skill("systematic-debugging") — errors and debugging
  3. Skill("solid") — writing or reviewing code
  4. Skill("security-review") — handling user input, auth, APIs
  5. Skill("verification-before-completion") — before declaring work complete

- Verify the delegation-check hook reminds which skill to invoke per task type
- Confirm: Forgetting to invoke a skill = missing quality guardrails

### Test 8: Quality Hooks Deep Test
Verify all hook categories work:

a) **PreToolUse hooks** (run before tool executes)
   - block-dangerous-git.sh: Blocks force push, reset --hard, clean -f
   - validate-commit.sh: Enforces conventional commit format
   - check-file-size.sh: Warns when creating files >500 lines

b) **PostToolUse hooks** (run after tool executes)
   - check-secrets.sh: Detects API keys, passwords in written files
   - security-check.sh: Detects SQL injection, command injection patterns
   - test-reminder.sh: Reminds to run tests after code changes

c) **Hook input/output format verification**
   - Input: JSON via stdin, parsed with `jq`
   - Output: `hookSpecificOutput` with `permissionDecision` for PreToolUse
   - Timeout: In seconds (not milliseconds)
   - Paths: Use `$CLAUDE_PROJECT_DIR` for portability

### Test 9: Context Management
Check context usage and verify awareness of /compact command:
- Report: Current tokens used, percentage of context window
- Verify agent knows: At 70% context, should suggest running /compact
- Note the context savings from on-demand MCP architecture (~25K vs ~80K+)

### Test 10: End-to-End Workflow
Simulate a real task using multiple capabilities:

1. **Use Context7** to look up React hooks best practices
2. **Delegate to Ollama** to generate a simple useEffect example
3. **Review the output** (Opus assesses worker result)
4. **Note that hooks** would run if we wrote/edited files

## OUTPUT FORMAT

=== CAPABILITY TEST RESULTS ===

TEST 1: Core Initialization
✅/❌ CLAUDE.md read: [yes/no]
✅/❌ Decision authority: [AUTONOMOUS/CONFIRM/ESCALATE listed]
✅/❌ Multi-model awareness: [Opus = brain, Ollama/DeepSeek = workers]

TEST 2: Hooks System
✅/❌ Clean startup (no _comment error): [yes/no]
✅/❌ No "invalid option" errors: [yes/no]
✅/❌ Hook format correct (stdin JSON + hookSpecificOutput): [yes/no]

TEST 3: Core MCP Connections
✅/❌ Context7 resolve-library-id: [library ID returned]
✅/❌ Context7 query-docs: [docs returned]
✅/❌ Serena (if enabled): [tools available or N/A]

TEST 4: Ollama Worker Delegation
✅/❌/⏭️ ollama_list: [models listed or SKIPPED]
✅/❌/⏭️ Model selection correct: [used glm-4.7-flash for coding]
✅/❌/⏭️ ollama_generate: [code generated + Opus review]
✅/❌/⏭️ ollama_chat: [response + Opus review]

TEST 5: DeepSeek Second Opinion
✅/❌/⏭️ deepseek chat_completion: [analysis returned or SKIPPED]
✅/❌/⏭️ Opus final assessment: [made decision based on advice]

TEST 6: On-Demand MCP Pattern
✅/❌ Non-enabled MCP returns no tools: [yes/no]
✅/❌ Suggested enable instructions: [yes/no]
✅/❌ Context savings noted: [~25K base vs ~80K+ full]

TEST 7: Skills Awareness
✅/❌ 5 skills listed with Skill("name") invocations: [list them]
✅/❌ Explicit invocation confirmed (NOT auto-activate): [yes/no]

TEST 8: Quality Hooks
✅/❌ PreToolUse hooks listed: [block-dangerous-git, validate-commit, etc.]
✅/❌ PostToolUse hooks listed: [check-secrets, security-check, etc.]
✅/❌ Hook format knowledge: [stdin JSON, hookSpecificOutput, seconds timeout]

TEST 9: Context Management
✅/❌ Context usage checked: [X tokens / Y% of window]
✅/❌ Knows /compact at 70%: [yes/no]
✅/❌ On-demand savings: [~25K base noted]

TEST 10: End-to-End Workflow
✅/❌ Context7 lookup: [completed]
✅/❌ Ollama delegation: [completed with review]
✅/❌ Workflow integration: [all pieces work together]

=== SUMMARY ===
Total Tests: 10
Passed: [X]/10
Failed: [Y]/10
Skipped: [Z]/10

=== END TEST ===

Run all tests now and output the results in the format above.
```

---

## Expected Results

### Test 1: Core Initialization
- CLAUDE.md should be read successfully
- Three authority levels: AUTONOMOUS, CONFIRM FIRST, ESCALATE
- 4-tier model: Opus 4.6 = brain, Ollama workers (Tier 1), Subagents (Tier 2), Agent Teams (Tier 3)

### Test 2: Hooks System
- **Clean startup**: No "_comment in enabledPlugins" validation error
- **No invalid option errors**: Hooks now read from stdin JSON, not environment variables
- **Hook format**: Uses `hookSpecificOutput` with `permissionDecision` for PreToolUse

### Test 3: Core MCP Connections
- **Context7**: Should resolve "react" and return documentation
- **Serena**: Should show directory listing if enabled

### Test 4: Ollama Worker Delegation
- **Model selection**: Use `glm-4.7-flash` for fast coding, `devstral-small-2` for SWE tasks, `deepcoder` for algorithmic reasoning
- **ollama_generate**: Worker should return valid Python code
- **ollama_chat**: Worker should return SOLID principles
- **Opus reviews**: Agent assesses all worker output (brain pattern)

### Test 5: DeepSeek Second Opinion
- **deepseek-reasoner**: Should analyze regex edge cases
- **Opus decides**: Makes final call based on DeepSeek's advice

### Test 6: On-Demand MCP Pattern
- Non-enabled MCPs return no tools (expected behavior)
- Agent suggests enabling via settings.local.json
- Context savings: ~25K tokens (core) vs ~80K+ (all enabled)

### Test 7: Skills
- Should list: Skill("test-driven-development"), Skill("systematic-debugging"), Skill("solid"), Skill("security-review"), Skill("verification-before-completion")
- Skills require EXPLICIT Skill("name") invocation — they do NOT auto-activate
- The delegation-check hook enforces skill reminders on every user message

### Test 8: Hooks
- **PreToolUse**: block-dangerous-git, validate-commit, check-file-size
- **PostToolUse**: check-secrets, security-check, test-reminder
- **Format**: stdin JSON parsed with jq, timeout in seconds, $CLAUDE_PROJECT_DIR paths

### Test 9: Context Management
- Agent should check /cost or /status
- Agent should know to run /compact at ~70%
- Should note: ~25K base vs ~80K+ with all MCPs

### Test 10: End-to-End
- All capabilities work together in a realistic workflow

---

## Troubleshooting

### Hooks Errors
```bash
# If you see "head: invalid option" or "sleep: invalid option"
# The hooks are using old environment variable format
# Fix: Update hooks to read from stdin using jq

# Test a hook manually:
echo '{"tool_input": {"command": "git status"}}' | .claude/hooks/block-dangerous-git.sh
```

### Ollama Not Connecting
```bash
# Standard (Ollama running locally)
curl http://localhost:11434/api/tags

# WSL (Ollama running on Windows host)
curl http://host.docker.internal:11434/api/tags

# If using WSL, update .mcp.json:
# "OLLAMA_HOST": "http://host.docker.internal:11434"
```

### DeepSeek Not Connecting
- Verify API key in .mcp.json
- Check if key is valid at platform.deepseek.com
- Ensure deepseek-mcp-server package is available

### Context7 Not Working
- Context7 is a public service, should work without auth
- May have rate limits
- Try different library names

### Settings Validation Error
```bash
# If you see "enabledPlugins._comment: Invalid input"
# Remove the _comment key from enabledPlugins in settings.local.json
# Only plugin names with boolean values are allowed
```

---

## Quick Verification Commands

```bash
# Check if jq is installed (required for hooks)
jq --version

# Check if Ollama is running
curl -s http://localhost:11434/api/tags | jq '.models[].name'

# Test a hook manually
echo '{"tool_input": {"command": "echo test"}}' | .claude/hooks/block-dangerous-git.sh

# Check hooks are executable
ls -la .claude/hooks/*.sh
```

---

*Part of the Agent Enhancement Kit*
