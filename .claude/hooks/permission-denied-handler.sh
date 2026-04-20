#!/bin/bash
# Hook: PermissionDenied — fires after auto mode classifier denials (v2.1.89+)
# Logs denied actions for audit trail. Can return {retry: true} to allow retry.
# Event: PermissionDenied

source "${BASH_SOURCE[0]%/*}/../lib/hook-protocol.sh" 2>/dev/null || true
INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
REASON=$(echo "$INPUT" | jq -r '.reason // "no reason"' 2>/dev/null || echo "no reason")

# Log to audit trail
mkdir -p "$PROJECT_DIR/.claude"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "{\"ts\":\"$TS\",\"event\":\"permission_denied\",\"tool\":\"$TOOL\",\"reason\":\"$REASON\"}" \
  >> "$PROJECT_DIR/.claude/.audit-trail.jsonl" 2>/dev/null

# Advisory message — don't retry by default (safer)
hook_signal "PermissionDenied" "allow" "permission-denied" "Tool '$TOOL' denied by auto mode. Reason: $REASON"
