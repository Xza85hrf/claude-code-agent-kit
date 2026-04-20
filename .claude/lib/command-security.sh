#!/bin/bash
# command-security.sh — Chained command splitting + shell-escape detection
#
# Ported from context-mode's security.ts (MIT/Elastic-2.0).
# Prevents bypass of deny patterns via chained commands (&&, ||, ;, |)
# and detects shell escapes in non-shell code (os.system, subprocess, etc.)
#
# Usage:
#   source .claude/lib/command-security.sh
#   split_chained_commands "echo ok && sudo rm -rf /"  # → array CHAIN_SEGMENTS
#   detect_shell_escapes /path/to/file.py              # → prints found commands

[[ -n "${_COMMAND_SECURITY_LOADED:-}" ]] && return 0
_COMMAND_SECURITY_LOADED=1

# strip_heredocs CMD
# Removes heredoc body lines from a shell command so pattern-matching
# hooks don't scan user content inside `<<WORD` blocks. Handles any
# delimiter word (not just EOF/PYEOF/END), plus <<'WORD', <<"WORD",
# and <<-WORD (tab-indented terminator). Leaves <<<WORD herestrings
# alone — they're single-line and have no body to strip.
#
# Why this exists: hooks like damage-control and auto-approve-safe-
# patterns grep the full Bash command for dangerous tokens. Without
# stripping, a benign `cat > /tmp/test.sh <<'SCRIPT' ... mkfs.ext4 ...
# SCRIPT` gets blocked because the mkfs word inside the script body
# looks like a mkfs invocation to the regex. The opening line is
# preserved so any redirections on the shell command (e.g. `cat <<EOF
# > /dev/sda`) still get scanned. See
# .claude/tests/damage-control-heredoc.test.sh for the full coverage.
#
# Falls through to printing the input unchanged if gawk is missing.
strip_heredocs() {
  printf '%s' "$1" | gawk '
    BEGIN { in_hd = 0; delim = ""; indented = 0 }
    {
      if (in_hd) {
        test_line = $0
        if (indented) sub(/^\t+/, "", test_line)
        if (test_line == delim) in_hd = 0
        print ""  # strip body lines and the terminator
        next
      }
      line = $0
      pos = 1
      while (pos <= length(line)) {
        rest = substr(line, pos)
        idx = index(rest, "<<")
        if (idx == 0) break
        abs_pos = pos + idx - 1
        # Skip <<< herestrings — single-line, no body to strip
        if (substr(line, abs_pos + 2, 1) == "<") {
          pos = abs_pos + 3
          continue
        }
        tail = substr(line, abs_pos + 2)
        if (match(tail, /^-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
          matched = substr(tail, 1, RLENGTH)
          indented = (substr(matched, 1, 1) == "-") ? 1 : 0
          word = matched
          sub(/^-?[ \t]*/, "", word)
          sub(/^["\047]/, "", word)
          delim = word
          in_hd = 1
          break
        }
        pos = abs_pos + 2
      }
      print line
    }
  ' 2>/dev/null || printf '%s' "$1"
}

# split_chained_commands CMD
# Splits a shell command on chain operators (&&, ||, ;, |) while
# respecting single/double quotes and backticks.
# Results stored in global array CHAIN_SEGMENTS.
#
# "echo hello && sudo rm -rf /" → CHAIN_SEGMENTS=("echo hello" "sudo rm -rf /")
split_chained_commands() {
  local cmd="$1"
  CHAIN_SEGMENTS=()

  local current="" in_single=0 in_double=0 in_backtick=0
  local i=0 len=${#cmd}

  while (( i < len )); do
    local ch="${cmd:$i:1}"
    local next="${cmd:$((i+1)):1}"
    local prev=""
    (( i > 0 )) && prev="${cmd:$((i-1)):1}"

    # Quote tracking
    if [[ "$ch" == "'" && $in_double -eq 0 && $in_backtick -eq 0 && "$prev" != "\\" ]]; then
      (( in_single = 1 - in_single ))
      current+="$ch"
    elif [[ "$ch" == '"' && $in_single -eq 0 && $in_backtick -eq 0 && "$prev" != "\\" ]]; then
      (( in_double = 1 - in_double ))
      current+="$ch"
    elif [[ "$ch" == '`' && $in_single -eq 0 && $in_double -eq 0 && "$prev" != "\\" ]]; then
      (( in_backtick = 1 - in_backtick ))
      current+="$ch"
    elif (( in_single == 0 && in_double == 0 && in_backtick == 0 )); then
      # Outside quotes — check for chain operators
      if [[ "$ch" == ";" ]]; then
        local trimmed="${current## }"
        trimmed="${trimmed%% }"
        [[ -n "$trimmed" ]] && CHAIN_SEGMENTS+=("$trimmed")
        current=""
      elif [[ "$ch" == "|" && "$next" == "|" ]]; then
        local trimmed="${current## }"
        trimmed="${trimmed%% }"
        [[ -n "$trimmed" ]] && CHAIN_SEGMENTS+=("$trimmed")
        current=""
        (( i++ ))  # skip second |
      elif [[ "$ch" == "&" && "$next" == "&" ]]; then
        local trimmed="${current## }"
        trimmed="${trimmed%% }"
        [[ -n "$trimmed" ]] && CHAIN_SEGMENTS+=("$trimmed")
        current=""
        (( i++ ))  # skip second &
      elif [[ "$ch" == "|" ]]; then
        # Single pipe — left side is a command too
        local trimmed="${current## }"
        trimmed="${trimmed%% }"
        [[ -n "$trimmed" ]] && CHAIN_SEGMENTS+=("$trimmed")
        current=""
      else
        current+="$ch"
      fi
    else
      current+="$ch"
    fi
    (( i++ ))
  done

  # Flush remaining
  local trimmed="${current## }"
  trimmed="${trimmed%% }"
  [[ -n "$trimmed" ]] && CHAIN_SEGMENTS+=("$trimmed")
}

# check_chain_for_deny CMD DENY_PATTERNS...
# Splits CMD into chain segments and checks each against grep patterns.
# Returns 0 (match found) with MATCHED_SEGMENT and MATCHED_PATTERN set,
# or 1 (no match).
check_chain_for_deny() {
  local cmd="$1"
  shift
  local patterns=("$@")

  split_chained_commands "$cmd"

  for segment in "${CHAIN_SEGMENTS[@]}"; do
    for pattern in "${patterns[@]}"; do
      if echo "$segment" | grep -qE "$pattern"; then
        MATCHED_SEGMENT="$segment"
        MATCHED_PATTERN="$pattern"
        return 0
      fi
    done
  done
  return 1
}

# detect_shell_escapes FILE_PATH
# Scans a file for shell-escape calls in non-shell code.
# Detects os.system(), subprocess.run(), child_process calls, etc.
# Prints each detected command to stdout (one per line).
# Returns 0 if any found, 1 if none.
detect_shell_escapes() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1

  local ext="${file##*.}"
  local found=0
  local results=()

  case "$ext" in
    py)
      # os.system("cmd"), subprocess.run("cmd")
      while IFS= read -r match; do
        [[ -n "$match" ]] && results+=("$match") && found=1
      done < <(grep -oP "(?:os\.system|subprocess\.(?:run|call|Popen|check_output|check_call))\s*\(\s*[\"']([^\"']+)[\"']" "$file" 2>/dev/null | grep -oP "(?<=[\"'])[^\"']+(?=[\"'])")
      ;;
    js|ts|mjs|cjs|tsx|jsx)
      # child_process calls: execSync("cmd"), spawn("cmd"), etc.
      while IFS= read -r match; do
        [[ -n "$match" ]] && results+=("$match") && found=1
      done < <(grep -oP "(?:execSync|execFileSync|spawnSync)\s*\(\s*[\"'\x60]([^\"'\x60]+)[\"'\x60]" "$file" 2>/dev/null | grep -oP "(?<=[\"'\x60])[^\"'\x60]+(?=[\"'\x60])")
      ;;
    rb)
      # system("cmd"), %x{cmd}
      while IFS= read -r match; do
        [[ -n "$match" ]] && results+=("$match") && found=1
      done < <(grep -oP "system\s*\(\s*[\"']([^\"']+)[\"']" "$file" 2>/dev/null | grep -oP "(?<=[\"'])[^\"']+(?=[\"'])")
      ;;
    go)
      # Command::new("cmd")
      while IFS= read -r match; do
        [[ -n "$match" ]] && results+=("$match") && found=1
      done < <(grep -oP "exec\.Command\s*\(\s*[\"']([^\"']+)[\"']" "$file" 2>/dev/null | grep -oP "(?<=[\"'])[^\"']+(?=[\"'])")
      ;;
    php)
      # shell_exec("cmd"), system("cmd"), passthru("cmd")
      while IFS= read -r match; do
        [[ -n "$match" ]] && results+=("$match") && found=1
      done < <(grep -oP "(?:shell_exec|passthru|proc_open)\s*\(\s*[\"']([^\"']+)[\"']" "$file" 2>/dev/null | grep -oP "(?<=[\"'])[^\"']+(?=[\"'])")
      ;;
    rs)
      # Command::new("cmd")
      while IFS= read -r match; do
        [[ -n "$match" ]] && results+=("$match") && found=1
      done < <(grep -oP "Command::new\s*\(\s*[\"']([^\"']+)[\"']" "$file" 2>/dev/null | grep -oP "(?<=[\"'])[^\"']+(?=[\"'])")
      ;;
  esac

  for r in "${results[@]}"; do
    echo "$r"
  done
  (( found )) && return 0 || return 1
}
