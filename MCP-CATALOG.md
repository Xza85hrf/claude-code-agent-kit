# MCP Server Catalog

> Reference for on-demand MCP loading. Read this to determine which MCPs to enable for a task.

---

## Currently Enabled (Global)

These MCPs are always available:

| Plugin | Purpose | Tools |
|--------|---------|-------|
| `context7` | Live documentation lookup | resolve-library-id, query-docs |
| `github` | GitHub operations | PRs, issues, repos, actions |
| `serena` | Semantic code analysis | Symbol search, code navigation |

---

## On-Demand MCPs (Enable Per-Project)

### External Services

| Plugin | Enable When | Token Cost | Key Tools |
|--------|-------------|------------|-----------|
| `Notion` | Managing Notion pages/databases | ~21K | notion-search, notion-create-pages, notion-fetch |
| `sentry` | Error tracking, debugging production | ~16K | search_issues, get_issue_details, analyze_issue |
| `figma` | Design-to-code workflows | ~7K | get_screenshot, get_design_context, get_metadata |
| `linear` | Linear project management | ~5K | list_issues, create_issue, update_issue |
| `stripe` | Payment integrations | ~4K | test-cards, explain-error |
| `supabase` | Supabase backend | ~6K | execute_sql, list_tables, apply_migration |
| `firebase` | Firebase backend | ~5K | firebase_get_project, firebase_init |
| `greptile` | Code search across repos | ~4K | search_custom_context, list_pull_requests |
| `gitlab` | GitLab operations | ~5K | Similar to github tools |
| `vercel` | Vercel deployments | ~3K | deploy, logs, setup |
| `playwright` | Browser automation/testing | ~8K | browser_navigate, browser_click, browser_screenshot |

### Development Tools

| Plugin | Enable When | Token Cost | Key Tools |
|--------|-------------|------------|-----------|
| `frontend-design` | Building UI components | ~2K | Design skill |
| `laravel-boost` | Laravel PHP projects | ~3K | Laravel-specific tools |
| `huggingface-skills` | ML/AI model work | ~4K | Model training, datasets |

### LSP Servers (Zero MCP overhead - safe to keep enabled)

| Plugin | Language |
|--------|----------|
| `typescript-lsp` | TypeScript/JavaScript |
| `pyright-lsp` | Python |
| `gopls-lsp` | Go |
| `rust-analyzer-lsp` | Rust |
| `csharp-lsp` | C# |
| `jdtls-lsp` | Java |
| `php-lsp` | PHP |
| `clangd-lsp` | C/C++ |
| `swift-lsp` | Swift |

---

## How to Enable On-Demand

### Option 1: Project-Specific (Recommended)

Create `.claude/settings.local.json` in your project:

```json
{
  "enabledPlugins": {
    "sentry@claude-plugins-official": true,
    "figma@claude-plugins-official": true
  }
}
```

### Option 2: Temporary Global Enable

Edit `~/.claude/settings.json` to add the plugin, then restart Claude Code.

### Option 3: Ask Claude

Tell Claude: "I need to work with [Notion/Sentry/Figma/etc]"
Claude will tell you which plugin to enable.

---

## Project Templates

### Web App with Sentry + Vercel
```json
{
  "enabledPlugins": {
    "sentry@claude-plugins-official": true,
    "vercel@claude-plugins-official": true,
    "playwright@claude-plugins-official": true
  }
}
```

### Design-to-Code with Figma
```json
{
  "enabledPlugins": {
    "figma@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true
  }
}
```

### Notion + Linear Project Management
```json
{
  "enabledPlugins": {
    "Notion@claude-plugins-official": true,
    "linear@claude-plugins-official": true
  }
}
```

### Full-Stack with Supabase
```json
{
  "enabledPlugins": {
    "supabase@claude-plugins-official": true,
    "stripe@claude-plugins-official": true
  }
}
```

### ML/AI Development
```json
{
  "enabledPlugins": {
    "huggingface-skills@claude-plugins-official": true
  }
}
```

---

## Context Budget Guide

| Budget | Plugins Enabled | Approx Tokens |
|--------|-----------------|---------------|
| Minimal | Core only (context7, github, serena) | ~25K |
| Standard | Core + 1-2 service MCPs | ~40-50K |
| Full | Core + all service MCPs | ~80K+ |

**Recommendation**: Stay under 50K for optimal performance.

---

*Part of the Agent Enhancement Kit*
