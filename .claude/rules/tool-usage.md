---
paths: ["**/*"]
---

# Tool Usage Rules

## Priority Order

1. Specialized tool over Bash (Read > cat, Edit > sed, Grep > grep, Glob > find)
2. Parallel calls when independent (3 unrelated files → 3 parallel Read calls)
3. Task tool for complex exploration ("How does auth work?" → Explore agent)
4. CLI wrappers for Ollama/DeepSeek/Firecrawl → `bash .claude/scripts/mcp-cli.sh <service> <command> [args]`
5. MCP tools for remaining services (GitHub → mcp__claude-ide-bridge__github*)

## IDE Tools Priority

| Task | Best Tool | Fallback |
|------|-----------|----------|
| Type errors / diagnostics | `mcp__ide__getDiagnostics` | `tsc --noEmit` |
| Go to definition | Grep for definition | LSP (if ide-bridge enabled) |
| Find references | Grep for usage | LSP (if ide-bridge enabled) |
| Rename symbol | Edit with `replace_all` | LSP (if ide-bridge enabled) |
| Symbol search | Grep / Glob | LSP (if ide-bridge enabled) |
| Git ops | `git` CLI (Bash) | — |
| GitHub ops | Docker Gateway github MCP | `gh` CLI |
| Format code | `prettier` / `biome` CLI | — |
| Run tests | `npx vitest run` / `pytest` | — |

**Default chain**: Built-in tools (Grep, Glob, Read, Edit, Bash, mcp__ide__) → CLI tools (git, tsc, gh).
**Heavy IDE**: `mcp-profile.sh +claude-ide-bridge` adds 124+ tools (~22K tokens) for LSP, debugging, refactoring.

## Context7 (ALWAYS use before)

- Using a library you haven't used recently
- Implementing a feature with framework-specific patterns
- Debugging framework-specific issues
- Upgrading dependencies

## CLI-Backed Services (zero context tokens)

Ollama, DeepSeek, and Firecrawl are accessed via CLI wrappers instead of MCP to save ~28K context tokens.

| Task | Command |
|------|---------|
| Ollama chat | `bash .claude/scripts/mcp-cli.sh ollama chat "model" "prompt" "system" "0.7"` |
| Ollama list | `bash .claude/scripts/mcp-cli.sh ollama list` |
| DeepSeek chat | `bash .claude/scripts/mcp-cli.sh deepseek chat "model" "prompt"` |
| Firecrawl scrape | `bash .claude/scripts/mcp-cli.sh firecrawl scrape "url"` |
| Firecrawl search | `bash .claude/scripts/mcp-cli.sh firecrawl search "query"` |

## Browser / Web Interaction Priority

| Task | Best Tool | Fallback |
|------|-----------|----------|
| Fetch & summarize URL | PinchTab `pinchtab_navigate` + `pinchtab_snapshot` (~800 tokens) | WebFetch (~10K tokens) |
| Fill forms / click buttons | PinchTab `pinchtab_fill` + `pinchtab_click` | Playwright (Docker) |
| Take page screenshot | PinchTab `pinchtab_screenshot` | Playwright (Docker) |
| Authenticated browsing | PinchTab `pinchtab_connect_profile` | Playwright (Docker) |
| Bulk crawl (100+ pages) | `mcp-cli.sh firecrawl crawl "url"` | PinchTab (manual) |
| Structured extraction | `mcp-cli.sh firecrawl extract "url"` | PinchTab `pinchtab_eval` |
| Simple API/static fetch | WebFetch | `mcp-cli.sh ollama web_fetch "url"` |

Enable PinchTab: `bash .claude/scripts/mcp-profile.sh +pinchtab` (on-demand, daemon on :9867).

## Multi-Model Smart Router

See @AGENTS.md → Smart Router section for the full tier routing flowchart.
