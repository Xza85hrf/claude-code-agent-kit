---
name: using-tmux-for-interactive-commands
description: Interactive CLI tools (vim, REPL). Use when running text editors, interactive REPLs, interactive git commands, or full-screen terminal apps that need a real terminal.
argument-hint: "Use tmux to run the dev server in background while I work on the API"
allowed-tools: Bash
model: inherit
department: workflow
user-invocable: false
references: []
thinking-level: low
---

# Using tmux for Interactive Commands

Interactive CLI tools that need real terminals cannot work through standard bash. tmux provides detached sessions controlled programmatically via `send-keys` and `capture-pane`.

**Core principle:** Use tmux sessions for any command requiring terminal interaction.

## When to Use

**Use tmux:**
- Text editors (vim, nano)
- Interactive REPLs (Python, Node, etc.)
- Interactive git commands (`git rebase -i`, `git add -p`)
- Full-screen terminal apps (htop, etc.)

**Don't use for:**
- Simple non-interactive commands (use Bash tool)
- Commands accepting input via stdin redirection
- One-shot commands

## Quick Reference

| Task | Command |
|------|---------|
| Start session | `tmux new-session -d -s <name> <command>` |
| Send input | `tmux send-keys -t <name> 'text' Enter` |
| Capture output | `tmux capture-pane -t <name> -p` |
| Stop session | `tmux kill-session -t <name>` |
| List sessions | `tmux list-sessions` |
| Set working dir | `-c /path/to/dir` flag |

## The Process

### 1. Create Detached Session

```bash
tmux new-session -d -s my-session -c /path/to/repo 'vim file.txt'
```

### 2. Wait for Initialization

```bash
sleep 0.3  # Commands need 100-500ms to start
```

### 3. Send Input

```bash
tmux send-keys -t my-session 'iHello World'
tmux send-keys -t my-session Escape
tmux send-keys -t my-session ':wq' Enter
```

### 4. Capture Output

```bash
tmux capture-pane -t my-session -p
```

### 5. Terminate Session

```bash
tmux kill-session -t my-session  # Always clean up
```

## Special Keys Reference

| Key | tmux Name |
|-----|-----------|
| Enter | `Enter` |
| Escape | `Escape` |
| Ctrl+C | `C-c` |
| Ctrl+X | `C-x` |
| Space | `Space` |
| Backspace | `BSpace` |
| Tab | `Tab` |
| Arrows | `Up`, `Down`, `Left`, `Right` |

## Common Patterns

### Python REPL

```bash
tmux new-session -d -s python-repl 'python3'
sleep 0.2
tmux send-keys -t python-repl 'x = 42' Enter
tmux send-keys -t python-repl 'print(x * 2)' Enter
sleep 0.1
tmux capture-pane -t python-repl -p
tmux send-keys -t python-repl 'exit()' Enter
tmux kill-session -t python-repl
```

### Vim Editing

```bash
tmux new-session -d -s vim-edit -c /project 'vim src/file.py'
sleep 0.3
tmux send-keys -t vim-edit '/function_name' Enter
tmux send-keys -t vim-edit 'n'
tmux send-keys -t vim-edit 'ciw'
tmux send-keys -t vim-edit 'new_name' Escape
tmux send-keys -t vim-edit ':wq' Enter
tmux kill-session -t vim-edit
```

### Interactive Git Rebase

```bash
tmux new-session -d -s git-rebase -c /repo 'git rebase -i HEAD~3'
sleep 0.5
tmux send-keys -t git-rebase 'j'
tmux send-keys -t git-rebase 'ciw'
tmux send-keys -t git-rebase 'squash' Escape
tmux send-keys -t git-rebase ':wq' Enter
sleep 0.3
tmux capture-pane -t git-rebase -p
tmux kill-session -t git-rebase
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Not waiting after start | Add `sleep 0.1-0.5` after session creation |
| Forgetting Enter key | Explicitly send `Enter` after commands |
| Using wrong key names | Use tmux names: `Enter`, not `\n` |
| Not cleaning up | Always `kill-session` when done |
| Wrong working directory | Use `-c /path` when creating session |

## Session Management

1. Use unique, descriptive session names
2. Check if session exists before creating
3. Set appropriate working directory
4. Wait for command initialization
5. Capture output to verify state
6. Always terminate sessions when done
7. Use try/finally pattern for cleanup

## Checking Session State

```bash
tmux list-sessions
tmux has-session -t my-session 2>/dev/null && echo "exists"
tmux display-message -t my-session -p '#{session_name}: #{pane_current_command}'
```

## Limitations

- Requires tmux installed
- Timing-sensitive (may need adjustment for slow systems)
- Screen capture is text-only (no graphics)
- Session names must be unique
