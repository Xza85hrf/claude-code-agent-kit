#!/bin/bash
# Hook: Capability pipeline tracker
# PostToolUse hook (matcher: mcp__gemini__|mcp__openai__)
# Note: DeepSeek is now CLI-backed via mcp-cli.sh (no longer MCP)
#
# When the agent uses Gemini/OpenAI MCP tools, this:
# 1. Creates/refreshes .capability-pipeline-token (60-min TTL)
# 2. Logs the step to .capability-pipeline-log (JSONL)
# 3. Emits advisory context about next pipeline step
#
# Token validity: 3600 seconds (60 min) — generous for design sessions.
# One MCP call unlocks design file writes for an hour.

# Skip in ollama-primary mode (no MCP pipeline)
if [ -z "${LAUNCH_MODE:-}" ]; then
  for _lm_dir in "${CLAUDE_PROJECT_DIR:-.}" "$(git rev-parse --show-toplevel 2>/dev/null)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" "$HOME"; do
    [ -n "$_lm_dir" ] && [ -f "$_lm_dir/.claude/.launch-mode" ] && { LAUNCH_MODE=$(cat "$_lm_dir/.claude/.launch-mode" 2>/dev/null); break; }
  done
fi
[ "${LAUNCH_MODE:-opus}" = "ollama" ] && exit 0

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL_NAME" ] && exit 0

TOKEN_BASE="${CLAUDE_PROJECT_DIR:-.}/.claude"
TOKEN_DIR="$TOKEN_BASE/.tokens"
TOKEN_FILE="$TOKEN_DIR/capability-pipeline.token"
LEGACY_FILE="$TOKEN_BASE/.capability-pipeline-token"
LOG_FILE="$TOKEN_BASE/.capability-pipeline-log"

# Create/refresh token (both locations for backward compat)
mkdir -p "$TOKEN_DIR" 2>/dev/null
date +%s > "$TOKEN_FILE" 2>/dev/null
echo "${CAPABILITY_TOKEN_TTL:-3600}" > "$TOKEN_DIR/capability-pipeline.ttl" 2>/dev/null
date +%s > "$LEGACY_FILE" 2>/dev/null

# Classify the step
STEP=""
case "$TOOL_NAME" in
  mcp__gemini__gemini-query|mcp__gemini__gemini-analyze-code)
    STEP="gemini_design" ;;
  mcp__gemini__gemini-generate-image)
    STEP="gemini_image" ;;
  mcp__gemini__gemini-generate-video)
    STEP="gemini_video" ;;
  mcp__gemini__gemini-*)
    STEP="gemini_other" ;;
  mcp__openai__openai_chat)
    STEP="openai_polish" ;;
  mcp__openai__*)
    STEP="openai_other" ;;
  *)
    STEP="other_mcp" ;;
esac

# Log step
if [ -d "$TOKEN_DIR" ]; then
  echo "{\"step\":\"$STEP\",\"tool\":\"$TOOL_NAME\",\"ts\":\"$(date -Iseconds)\"}" \
    >> "$LOG_FILE" 2>/dev/null
fi

# Emit advisory about pipeline progress
NEXT_MSG=""
case "$STEP" in
  gemini_design)
    NEXT_MSG="Gemini design complete. Next: OpenAI for code quality, or mcp-cli.sh deepseek for UX review, or integrate directly." ;;
  openai_polish)
    NEXT_MSG="OpenAI polish complete. Next: integrate directly, or use mcp-cli.sh deepseek for UX review." ;;
  gemini_image)
    NEXT_MSG="Design mockup generated (Nano Banana 2). Show to user for approval. If approved → creative brief (Gemini Pro) or direct code gen (OpenAI GPT-5.2)." ;;
  gemini_video)
    NEXT_MSG="Video generated. Consider Skill(\"remotion-video\") for programmatic composition." ;;
esac

if [ -n "$NEXT_MSG" ]; then
  jq -n --arg msg "✅ Pipeline step: $STEP — $NEXT_MSG" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $msg
    }
  }'
fi

exit 0
