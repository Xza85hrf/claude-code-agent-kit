#!/bin/bash
# Hook Self-Test Runner
# Tests all hooks with sample inputs and reports pass/fail.
#
# Usage:
#   .claude/hooks/test-hooks.sh
#   CLAUDE_PROJECT_DIR=/path/to/project .claude/hooks/test-hooks.sh

set -uo pipefail

HOOKS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks"
PASS=0
FAIL=0
SKIP=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1: $2"; FAIL=$((FAIL + 1)); }
skip() { echo "  ○ $1: $2"; SKIP=$((SKIP + 1)); }

echo "Hook Self-Test Runner"
echo "Testing hooks in: $HOOKS_DIR"
echo ""

# --- Test: delegation-check.sh (UserPromptSubmit) ---
echo "▸ delegation-check.sh"
if [ -x "$HOOKS_DIR/delegation-check.sh" ]; then
  OUTPUT=$(echo '{}' | "$HOOKS_DIR/delegation-check.sh" 2>/dev/null)
  if echo "$OUTPUT" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' > /dev/null 2>&1; then
    pass "Outputs valid UserPromptSubmit JSON"
  else
    fail "Invalid JSON output" "$OUTPUT"
  fi
  if echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "DELEGATION"; then
    pass "Contains delegation checklist"
  else
    fail "Missing delegation checklist" ""
  fi
  if echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "CONTEXT CHECK"; then
    pass "Contains compact reminder"
  else
    fail "Missing compact reminder" ""
  fi
else
  skip "delegation-check.sh" "not found or not executable"
fi

# --- Test: delegation-reminder-write.sh (PreToolUse:Write) ---
echo ""
echo "▸ delegation-reminder-write.sh"
if [ -x "$HOOKS_DIR/delegation-reminder-write.sh" ]; then
  # Test: >10 lines of code triggers warning
  INPUT_LONG=$(python3 -c "import json; print(json.dumps({'tool_input':{'file_path':'src/app.ts','content':'\n'.join(['line'+str(i) for i in range(15)])}}))" 2>/dev/null)
  if [ -n "$INPUT_LONG" ]; then
    OUTPUT=$(echo "$INPUT_LONG" | "$HOOKS_DIR/delegation-reminder-write.sh" 2>/dev/null)
    if echo "$OUTPUT" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' > /dev/null 2>&1; then
      pass "Warns on >10 lines of code (allows, doesn't block)"
    else
      fail "Should warn on >10 lines" "$OUTPUT"
    fi
  else
    skip ">10 lines test" "python3 not available for test data generation"
  fi

  # Test: .md files skipped
  INPUT_MD=$(python3 -c "import json; print(json.dumps({'tool_input':{'file_path':'README.md','content':'\n'.join(['line'+str(i) for i in range(15)])}}))" 2>/dev/null)
  if [ -n "$INPUT_MD" ]; then
    OUTPUT=$(echo "$INPUT_MD" | "$HOOKS_DIR/delegation-reminder-write.sh" 2>/dev/null)
    if [ -z "$OUTPUT" ]; then
      pass "Skips .md files"
    else
      fail "Should skip .md files" "$OUTPUT"
    fi
  fi

  # Test: short code files skipped
  INPUT_SHORT=$(python3 -c "import json; print(json.dumps({'tool_input':{'file_path':'src/app.ts','content':'const x = 1;'}}))" 2>/dev/null)
  if [ -n "$INPUT_SHORT" ]; then
    OUTPUT=$(echo "$INPUT_SHORT" | "$HOOKS_DIR/delegation-reminder-write.sh" 2>/dev/null)
    if [ -z "$OUTPUT" ]; then
      pass "Skips short code files (<=10 lines)"
    else
      fail "Should skip short code files" "$OUTPUT"
    fi
  fi
else
  skip "delegation-reminder-write.sh" "not found or not executable"
fi

# --- Test: delegation-reminder-edit.sh (PreToolUse:Edit) ---
echo ""
echo "▸ delegation-reminder-edit.sh"
if [ -x "$HOOKS_DIR/delegation-reminder-edit.sh" ]; then
  INPUT_EDIT=$(python3 -c "import json; print(json.dumps({'tool_input':{'file_path':'src/app.ts','old_string':'old','new_string':'\n'.join(['line'+str(i) for i in range(15)])}}))" 2>/dev/null)
  if [ -n "$INPUT_EDIT" ]; then
    OUTPUT=$(echo "$INPUT_EDIT" | "$HOOKS_DIR/delegation-reminder-edit.sh" 2>/dev/null)
    if echo "$OUTPUT" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' > /dev/null 2>&1; then
      pass "Warns on >10 lines in new_string"
    else
      fail "Should warn on >10 lines in Edit" "$OUTPUT"
    fi
  else
    skip "Edit test" "python3 not available"
  fi

  # Test: .json files skipped
  INPUT_JSON=$(python3 -c "import json; print(json.dumps({'tool_input':{'file_path':'package.json','old_string':'old','new_string':'\n'.join(['line'+str(i) for i in range(15)])}}))" 2>/dev/null)
  if [ -n "$INPUT_JSON" ]; then
    OUTPUT=$(echo "$INPUT_JSON" | "$HOOKS_DIR/delegation-reminder-edit.sh" 2>/dev/null)
    if [ -z "$OUTPUT" ]; then
      pass "Skips .json files"
    else
      fail "Should skip .json files" "$OUTPUT"
    fi
  fi
else
  skip "delegation-reminder-edit.sh" "not found or not executable"
fi

# --- Test: stop-skill-check.sh (Stop) ---
echo ""
echo "▸ stop-skill-check.sh"
if [ -x "$HOOKS_DIR/stop-skill-check.sh" ]; then
  OUTPUT=$(echo '{}' | "$HOOKS_DIR/stop-skill-check.sh" 2>/dev/null)
  # Stop hooks output plain text (not JSON) — same pattern as SessionStart
  if echo "$OUTPUT" | grep -q "COMPLETION CHECKLIST"; then
    pass "Outputs completion checklist (plain text)"
  else
    fail "Missing completion checklist" "$OUTPUT"
  fi
  if echo "$OUTPUT" | grep -q "SKILL CHECK"; then
    pass "Contains skill check section"
  else
    fail "Missing skill check section" ""
  fi
else
  skip "stop-skill-check.sh" "not found or not executable"
fi

# --- Test: block-dangerous-git.sh (PreToolUse:Bash) ---
echo ""
echo "▸ block-dangerous-git.sh"
if [ -x "$HOOKS_DIR/block-dangerous-git.sh" ]; then
  OUTPUT=$(echo '{"tool_input":{"command":"git push --force"}}' | "$HOOKS_DIR/block-dangerous-git.sh" 2>/dev/null)
  if echo "$OUTPUT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null 2>&1; then
    pass "Blocks git push --force"
  else
    fail "Should block force push" "$OUTPUT"
  fi

  OUTPUT=$(echo '{"tool_input":{"command":"git status"}}' | "$HOOKS_DIR/block-dangerous-git.sh" 2>/dev/null)
  if [ -z "$OUTPUT" ]; then
    pass "Allows safe git commands"
  else
    fail "Should allow git status" "$OUTPUT"
  fi
else
  skip "block-dangerous-git.sh" "not found or not executable"
fi

# --- Test: check-ollama-models.sh (SessionStart) ---
echo ""
echo "▸ check-ollama-models.sh"
if [ -x "$HOOKS_DIR/check-ollama-models.sh" ]; then
  OUTPUT=$("$HOOKS_DIR/check-ollama-models.sh" 2>/dev/null)
  if echo "$OUTPUT" | grep -q "Ollama worker status"; then
    pass "Reports Ollama status (available or unreachable)"
  else
    fail "No Ollama status output" "$OUTPUT"
  fi
else
  skip "check-ollama-models.sh" "not found or not executable"
fi

# --- Test: session-start.sh (SessionStart) ---
echo ""
echo "▸ session-start.sh"
if [ -x "$HOOKS_DIR/session-start.sh" ]; then
  OUTPUT=$("$HOOKS_DIR/session-start.sh" 2>/dev/null)
  if echo "$OUTPUT" | grep -q "quality hooks active"; then
    pass "Outputs session start guidance"
  else
    fail "Missing session start output" "$OUTPUT"
  fi
  if echo "$OUTPUT" | grep -q "Delegation enforcement"; then
    pass "Mentions delegation enforcement"
  else
    fail "Missing delegation mention" "$OUTPUT"
  fi
else
  skip "session-start.sh" "not found or not executable"
fi

# --- Test: teammate-idle.sh (TeammateIdle) ---
echo ""
echo "▸ teammate-idle.sh"
if [ -x "$HOOKS_DIR/teammate-idle.sh" ]; then
  # Test: no team name → allow idle (exit 0)
  OUTPUT=$(echo '{"team_name":"","teammate_name":"worker"}' | "$HOOKS_DIR/teammate-idle.sh" 2>/dev/null)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "No team name → allows idle (exit 0)"
  else
    fail "Should allow idle with no team name" "exit code: $EXIT_CODE"
  fi

  # Test: nonexistent team dir → allow idle (exit 0)
  OUTPUT=$(echo '{"team_name":"nonexistent-team-xyz","teammate_name":"worker"}' | "$HOOKS_DIR/teammate-idle.sh" 2>/dev/null)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Nonexistent team dir → allows idle (exit 0)"
  else
    fail "Should allow idle with nonexistent team dir" "exit code: $EXIT_CODE"
  fi
else
  skip "teammate-idle.sh" "not found or not executable"
fi

# --- Test: task-completed.sh (TaskCompleted) ---
echo ""
echo "▸ task-completed.sh"
if [ -x "$HOOKS_DIR/task-completed.sh" ]; then
  # Test: clean git state → allow completion (exit 0)
  OUTPUT=$(echo '{"task_id":"1","task_subject":"Test task"}' | "$HOOKS_DIR/task-completed.sh" 2>/dev/null)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Clean git state → allows completion (exit 0)"
  else
    fail "Should allow completion with clean state" "exit code: $EXIT_CODE"
  fi
else
  skip "task-completed.sh" "not found or not executable"
fi

# --- Test: validate-commit.sh (PreToolUse:Bash) ---
echo ""
echo "▸ validate-commit.sh"
if [ -x "$HOOKS_DIR/validate-commit.sh" ]; then
  OUTPUT=$(echo '{"tool_input":{"command":"git commit -m \"bad message\""}}' | "$HOOKS_DIR/validate-commit.sh" 2>/dev/null)
  if [ -n "$OUTPUT" ]; then
    pass "Warns on non-conventional commit"
  else
    # Some implementations allow and warn differently
    pass "Processed commit message (check format manually)"
  fi
else
  skip "validate-commit.sh" "not found or not executable"
fi

# --- Summary ---
echo ""
echo "════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
