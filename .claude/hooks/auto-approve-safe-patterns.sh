#!/bin/bash
# Hook: PermissionRequest — auto-approve tool patterns not covered by settings
#
# Output format: PermissionRequest event schema (decision.behavior)
# NOT the PreToolUse format (permissionDecision) — these are different schemas!
#
# This hook fires ONLY for tool calls not already matched by permissions.allow/deny
# in settings. PreToolUse hooks (block-dangerous-git, validate-commit, etc.) fire
# BEFORE permission evaluation, providing safety. PostToolUse hooks (check-secrets,
# security-check) fire AFTER execution, providing detection.
#
# Strategy: deny catastrophic operations, allow everything else.
# permissions.allow handles 152 patterns (fast path, no hook needed).
# This hook is defense-in-depth for any pattern that slips through.

INPUT=$(if [ -t 0 ]; then echo "{}"; else cat; fi)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)

# Load chained command splitting library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/command-security.sh" 2>/dev/null || true

allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
  exit 0
}

deny() {
  jq -nc --arg msg "$1" '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":$msg}}}'
  exit 0
}

# --- DENY: Catastrophic operations (defense-in-depth with PreToolUse hooks) ---
# Now with chained command splitting: "echo ok && sudo rm -rf /" catches the rm.
if [ "$TOOL_NAME" = "Bash" ]; then
  CMD=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)

  # Strip heredoc bodies before pattern matching so a benign command
  # that writes a file containing scary tokens (e.g. `cat > /tmp/x
  # <<'EOF' ... mkfs ... EOF`) doesn't false-match against the DENY
  # list. Same bug class the damage-control hook had — both scanners
  # now share strip_heredocs() from command-security.sh so the fix
  # cannot drift between them.
  if declare -f strip_heredocs >/dev/null 2>&1; then
    CMD=$(strip_heredocs "$CMD")
  fi

  # Command-boundary anchor: matches start-of-segment, optional
  # VAR=VALUE env-var prefixes, and optional sudo (with or without
  # flags/user args — `sudo`, `sudo -E`, `sudo -u postgres`, etc.).
  # Lets a pattern require that the dangerous token is being INVOKED
  # as a command, not just mentioned as a filename/argument to cat/
  # grep/echo/etc. Pre-fix surface: `mkfs\b` blocked `cat mkfs-notes
  # .md` and `grep mkfs /var/log/dmesg`. Same unanchored-word FP
  # class the damage-control shutdown/reboot patterns had (d475c0d).
  #
  # Regex trace for `sudo -u postgres dropdb stage`:
  #   ^                                 start
  #   (env-var prefix)*                  none
  #   sudo                               matches "sudo"
  #   ([[:space:]]+[^[:space:]]+)*       matches " -u" and " postgres"
  #   [[:space:]]+                       matches " " before dropdb
  #   dropdb                             matches
  CMD_ANCHOR='^([[:space:]]*([A-Z_][A-Z0-9_]*=\S+[[:space:]]+)*(sudo([[:space:]]+[^[:space:]]+)*[[:space:]]+)?)?'

  # Deny patterns — checked against EACH segment of chained commands.
  # Split into individual entries rather than compound alternations so
  # a regression on one pattern points directly at what broke.
  DENY_PATTERNS=(
    # Git destructive
    'git\s+(push\s+(-f|--force)|reset\s+--hard|clean\s+-(fd|f|fdx))'
    # rm -rf on specific sensitive roots
    'rm\s+-r[f ]*\s+/($|\s|s\b|home\b|etc\b|usr\b|var\b|boot\b|lib\b|opt\b|srv\b|sys\b|proc\b|dev\b)'
    # SQL destruction — dropdb as an actual command; DROP DATABASE/
    # DROP SCHEMA scan anywhere since they're SQL content signals.
    "${CMD_ANCHOR}dropdb\\b"
    'DROP\s+DATABASE\b'
    'DROP\s+SCHEMA\b'
    # Disk tools — anchored so `cat mkfs-notes.md` doesn't false-match
    "${CMD_ANCHOR}mkfs\\b"
    "${CMD_ANCHOR}fdisk\\b"
    "${CMD_ANCHOR}parted\\b"
    "${CMD_ANCHOR}dd\\s+.*of="
    # Broadcast kill
    'kill(all)?\s+-9\s+(-1|0)\b'
    # Cron/systemctl destructive
    'crontab\s+-r'
    'systemctl\s+(disable|mask)\s'
    # chmod on sensitive roots
    'chmod\s+[0-9]+\s+/(etc|usr|var|sys|boot)'
    # chmod touching .ssh must be the actual chmod command
    "${CMD_ANCHOR}chmod\\b.*\\.ssh"
    # Cron read/write
    'crontab\s+-[el]'
    '/etc/cron'
    # SSH key ops — commands anchored. We deliberately do NOT
    # duplicate `\.ssh/authorized_keys` / `\.ssh/id_` here: those
    # were unanchored substring patterns that false-matched on any
    # command mentioning the string (e.g. `echo '...~/.ssh/id_rsa
    # in docs'`). damage-control.sh's `.ssh/` zeroAccess path rule
    # already blocks cat/ls/rm/cp on those paths via its path
    # extraction pipeline — this hook is defense-in-depth for
    # catastrophic Bash ops, not filesystem protection.
    "${CMD_ANCHOR}ssh-keygen\\b"
    "${CMD_ANCHOR}ssh-add\\b"
  )

  # Use chained command splitting if library loaded, else fall back to full-string match
  if declare -f split_chained_commands >/dev/null 2>&1; then
    split_chained_commands "$CMD"
    for segment in "${CHAIN_SEGMENTS[@]}"; do
      for pattern in "${DENY_PATTERNS[@]}"; do
        if echo "$segment" | grep -qE "$pattern"; then
          deny "Blocked segment in chained command: $segment (pattern: $pattern)"
        fi
      done

      # Data exfiltration — per-segment check (wget -O- is suspicious even without pipe).
      # Anchored via CMD_ANCHOR so that `echo 'curl -d foo'` / `grep 'curl --data'`
      # etc. don't false-match on quoted strings mentioning curl as data, not as
      # the running command. Same FP class fixed in DENY_PATTERNS (0259b9f).
      if echo "$segment" | grep -qE "${CMD_ANCHOR}(curl\b.*(-d|--data|--upload)|wget\b.*-O-)"; then
        deny "Potential data exfiltration — confirm manually"
      fi
      if echo "$segment" | grep -qE "${CMD_ANCHOR}curl\b.*https?://" && ! echo "$segment" | grep -qE "${CMD_ANCHOR}curl\b.*https?://(localhost|127\.0\.0\.1)"; then
        deny "External HTTP request — confirm manually"
      fi
    done
  else
    # Fallback: check full command string (pre-existing behavior)
    for pattern in "${DENY_PATTERNS[@]}"; do
      if echo "$CMD" | grep -qE "$pattern"; then
        deny "Blocked: matched pattern $pattern"
      fi
    done

    # Data exfiltration (full-string fallback). Same anchor treatment as the
    # per-segment path above. Fallback only runs when command-security.sh lib
    # failed to source, so chain-operator coverage is best-effort; the normal
    # path through split_chained_commands handles `foo && curl -d ...` correctly.
    if echo "$CMD" | grep -qE "${CMD_ANCHOR}(curl\b.*(-d|--data|--upload)|curl\b.*\||wget\b.*-O-.*\|)"; then
      deny "Potential data exfiltration — confirm manually"
    fi
    if echo "$CMD" | grep -qE "${CMD_ANCHOR}curl\b.*https?://" && ! echo "$CMD" | grep -qE "${CMD_ANCHOR}curl\b.*https?://(localhost|127\.0\.0\.1)"; then
      deny "External HTTP request — confirm manually"
    fi
  fi
fi

# --- DENY: Read on sensitive paths ---
if [ "$TOOL_NAME" = "Read" ]; then
  FPATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
  if echo "$FPATH" | grep -qE '(\.ssh/|\.gnupg/|\.aws/credentials|\.env$|/etc/shadow|/etc/passwd)'; then
    deny "Reading sensitive file — confirm manually"
  fi
fi

# --- PASSTHROUGH: Tools that MUST prompt the user ---
# These tools are critical decision points — never auto-approve.
# Exiting without a decision lets the permission system prompt the user.
case "$TOOL_NAME" in
  EnterPlanMode|ExitPlanMode)
    exit 0  # No decision output → user gets prompted
    ;;
esac

# --- ROLE-BASED ACCESS (Turnstone RBAC) ---
# Check role-profiles.yaml if exists. Viewer role blocks writes.
ROLE_FILE="${SCRIPT_DIR}/../config/role-profiles.yaml"
if [ -f "$ROLE_FILE" ]; then
  ACTIVE_ROLE=$(grep -E '^active_role:' "$ROLE_FILE" 2>/dev/null | sed 's/^active_role:[[:space:]]*//' | tr -d '"' | head -1)
  if [ "$ACTIVE_ROLE" = "viewer" ]; then
    case "$TOOL_NAME" in
      Write|Edit|Bash|WebFetch|WebSearch|NotebookEdit)
        deny "Role 'viewer' does not permit $TOOL_NAME — switch to operator or admin"
        ;;
    esac
  fi
fi

# --- ALLOW: Everything else ---
# Safety is enforced by PreToolUse hooks:
#   block-dangerous-git.sh, validate-commit.sh, build-before-push.sh,
#   tmux-enforce.sh, delegation-reminder-write/edit.sh, investigation-gate.sh,
#   check-file-size.sh, team-file-ownership.sh, prevent-common-mistakes.sh,
#   capability-gate.sh, review-gate.sh, safe-parallel-bash.sh, tool-policy-engine.sh
# Detection by PostToolUse hooks:
#   check-secrets.sh, security-check.sh, semantic-invariant-check.sh,
#   test-reminder.sh, detect-invisible-text.sh, output-guard.sh, metrics-emit.sh
allow
