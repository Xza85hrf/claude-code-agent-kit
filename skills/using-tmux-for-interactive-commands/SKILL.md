---
name: using-tmux-for-interactive-commands
description: Use when you need to run interactive CLI tools (vim, git rebase -i, Python REPL, etc.) that require real-time input/output - provides tmux-based approach for controlling interactive sessions
---

# Using tmux for Interactive Commands

## Overview

Interactive CLI tools that need real terminals cannot work through standard bash. tmux provides detached sessions that can be controlled programmatically via `send-keys` and `capture-pane`.

**Core principle:** Use tmux sessions for any command requiring terminal interaction - editors, REPLs, interactive git, full-screen apps.

## When to Use

**Use tmux when:**
- Running vim, nano, or other text editors programmatically
- Controlling interactive REPLs (Python, Node, etc.)
- Handling interactive git commands (`git rebase -i`, `git add -p`)
- Working with full-screen terminal apps (htop, etc.)
- Commands that require terminal control codes or readline

**Don't use for:**
- Simple non-interactive commands (use regular Bash tool)
- Commands that accept input via stdin redirection
- One-shot commands that don't need interaction

## Quick Reference

| Task | Command |
|------|---------|
| Start session | `tmux new-session -d -s <name> <command>` |
| Send input | `tmux send-keys -t <name> 'text' Enter` |
| Capture output | `tmux capture-pane -t <name> -p` |
| Stop session | `tmux kill-session -t <name>` |
| List sessions | `tmux list-sessions` |
| Set working dir | `-c /path/to/dir` flag when creating |

## The Process

### 1. Create Detached Session

```bash
# Start interactive command in background
tmux new-session -d -s my-session -c /path/to/repo 'vim file.txt'
```

### 2. Wait for Initialization

```bash
# Commands need time to start (100-500ms)
sleep 0.3
```

### 3. Send Input

```bash
# Send keystrokes
tmux send-keys -t my-session 'iHello World'
tmux send-keys -t my-session Escape
tmux send-keys -t my-session ':wq' Enter
```

### 4. Capture Output

```bash
# See current screen state
tmux capture-pane -t my-session -p
```

### 5. Terminate Session

```bash
# Always clean up when done
tmux kill-session -t my-session
```

## Special Keys Reference

| Key | tmux Name |
|-----|-----------|
| Enter/Return | `Enter` |
| Escape | `Escape` |
| Ctrl+C | `C-c` |
| Ctrl+X | `C-x` |
| Space | `Space` |
| Backspace | `BSpace` |
| Tab | `Tab` |
| Up Arrow | `Up` |
| Down Arrow | `Down` |
| Left Arrow | `Left` |
| Right Arrow | `Right` |

## Common Patterns

### Python REPL

```bash
# Start Python
tmux new-session -d -s python-repl 'python3'
sleep 0.2

# Execute code
tmux send-keys -t python-repl 'x = 42' Enter
tmux send-keys -t python-repl 'print(x * 2)' Enter
sleep 0.1

# Capture result
tmux capture-pane -t python-repl -p

# Exit
tmux send-keys -t python-repl 'exit()' Enter
tmux kill-session -t python-repl
```

### Vim Editing

```bash
# Open file
tmux new-session -d -s vim-edit -c /project 'vim src/file.py'
sleep 0.3

# Navigate and edit
tmux send-keys -t vim-edit '/function_name' Enter  # Search
tmux send-keys -t vim-edit 'n'                      # Next match
tmux send-keys -t vim-edit 'ciw'                    # Change word
tmux send-keys -t vim-edit 'new_name' Escape        # Type and exit insert

# Save and quit
tmux send-keys -t vim-edit ':wq' Enter
tmux kill-session -t vim-edit
```

### Interactive Git Rebase

```bash
# Start rebase
tmux new-session -d -s git-rebase -c /repo 'git rebase -i HEAD~3'
sleep 0.5

# Change 'pick' to 'squash' on line 2
tmux send-keys -t git-rebase 'j'           # Move down
tmux send-keys -t git-rebase 'ciw'         # Change word
tmux send-keys -t git-rebase 'squash' Escape

# Save and continue
tmux send-keys -t git-rebase ':wq' Enter

# Capture any conflicts or prompts
sleep 0.3
tmux capture-pane -t git-rebase -p

tmux kill-session -t git-rebase
```

## Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Not waiting after start | Command hasn't initialized | Add `sleep 0.1-0.5` after session creation |
| Forgetting Enter key | Command typed but not executed | Explicitly send `Enter` after commands |
| Using wrong key names | `\n` doesn't work | Use tmux names: `Enter`, not `\n` |
| Not cleaning up | Sessions accumulate | Always `kill-session` when done |
| Wrong working directory | File not found | Use `-c /path` when creating session |

## Session Management Best Practices

```
1. Use unique, descriptive session names
2. Always check if session exists before creating
3. Set appropriate working directory
4. Wait for command initialization
5. Capture output to verify state
6. Always terminate sessions when done
7. Use try/finally pattern for cleanup
```

## Checking Session State

```bash
# List all sessions
tmux list-sessions

# Check if session exists
tmux has-session -t my-session 2>/dev/null && echo "exists"

# Get session info
tmux display-message -t my-session -p '#{session_name}: #{pane_current_command}'
```

## Real-World Impact

- **Enables** programmatic control of vim/nano for file editing
- **Automates** interactive git workflows (rebase, add -p, commit --amend)
- **Supports** REPL-based testing and debugging
- **Removes** need for custom PTY management code
- **Works** where standard bash input redirection fails

## Limitations

- Requires tmux installed on the system
- Timing-sensitive (may need adjustment for slow systems)
- Screen capture is text-only (no graphics)
- Session names must be unique
