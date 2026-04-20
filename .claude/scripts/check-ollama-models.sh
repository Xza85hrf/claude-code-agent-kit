#!/bin/bash
# check-ollama-models.sh — Check Ollama worker model availability
# Wrapper around session-status.sh (merged hook) for standalone/cron use
# Used by: /monitor command (CronCreate health check)

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
HOOKS_DIR="${SCRIPT_DIR}/../hooks"

# session-status.sh merged check-ollama-models + check-usage-startup + version-check
if [ -f "$HOOKS_DIR/session-status.sh" ]; then
    bash "$HOOKS_DIR/session-status.sh" 2>/dev/null
else
    echo "Error: Hook not found at $HOOKS_DIR/session-status.sh"
    exit 1
fi
