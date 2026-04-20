#!/bin/bash
# worker-status.sh — Show worker orchestration status
# Usage: bash .claude/scripts/worker-status.sh
set -uo pipefail

LOG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/worker-performance.log"
PID_DIR="/tmp/claude-orchestrator-pids"

echo "=== Worker Orchestrator Status ==="
echo ""

# Running workers
if [ -d "$PID_DIR" ] && [ "$(ls -A "$PID_DIR" 2>/dev/null)" ]; then
  echo "RUNNING WORKERS:"
  for pidfile in "$PID_DIR"/*.pid; do
    PID=$(cat "$pidfile" 2>/dev/null)
    NAME=$(basename "$pidfile" .pid)
    if kill -0 "$PID" 2>/dev/null; then
      ELAPSED=$(( $(date +%s) - $(stat -c %Y "$pidfile" 2>/dev/null || echo "$(date +%s)") ))
      echo "  [$NAME] PID=$PID running for ${ELAPSED}s"
    else
      echo "  [$NAME] PID=$PID finished"
      rm -f "$pidfile"
    fi
  done
else
  echo "RUNNING WORKERS: none"
fi

echo ""

# Recent completions (last 10 from performance log)
if [ -f "$LOG_FILE" ] && command -v jq &>/dev/null; then
  echo "RECENT COMPLETIONS (last 10):"
  tail -20 "$LOG_FILE" | jq -r '
    select(.tier == "tier1" or .tier == "pipeline")
    | "  [\(.ts)] \(.model) | \(.status) | \(.elapsed_s // "?")s | \(.task[:60] // .task)"
  ' 2>/dev/null | tail -10

  echo ""

  # Success rate (excluding test_skip and gate entries from denominator)
  TOTAL=$(jq -s '[.[] | select((.tier == "tier1" or .tier == "pipeline") and .model != "gate" and .status != "test_skip")] | length' "$LOG_FILE" 2>/dev/null || echo "0")
  SUCCESS=$(jq -s '[.[] | select((.tier == "tier1" or .tier == "pipeline") and (.status == "success" or .status == "review_pass" or .status == "fix_applied"))] | length' "$LOG_FILE" 2>/dev/null || echo "0")
  if [ "$TOTAL" -gt 0 ]; then
    RATE=$(( SUCCESS * 100 / TOTAL ))
    echo "SUCCESS RATE: $SUCCESS/$TOTAL ($RATE%)"
  fi
else
  echo "RECENT COMPLETIONS: no log data"
fi
