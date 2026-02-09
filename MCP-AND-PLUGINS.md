# MCP Servers & Plugins Guide

> Configure Model Context Protocol servers and plugins to extend Claude Code's capabilities.

---

## On-Demand MCP Loading

> **Context Budget Optimization**: Only core MCPs (context7, github, serena) are always-on (~25K tokens). Service-specific MCPs are enabled per-project to save context.

**See [MCP-CATALOG.md](MCP-CATALOG.md) for:**
- Complete list of on-demand MCPs with token costs
- Enable instructions for each service
- Project templates for common stacks

**Quick Enable**: Add to `.claude/settings.local.json`:
```json
{
  "enabledPlugins": {
    "sentry@claude-plugins-official": true
  }
}
```

---

## Quick Reference

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **MCP Servers** | Connect external services (APIs, databases, tools) | `.mcp.json` in project root |
| **Plugins** | Add skills, commands, agents | `/plugin install` command |
| **Hooks** | Intercept tool calls for validation | `.claude/settings.local.json` |

### Hooks Quick Reference

Hooks receive JSON input via **stdin** and use `jq` to parse. Output uses `hookSpecificOutput`.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/my-hook.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Note:** `timeout` is in **seconds** (not milliseconds). Use `$CLAUDE_PROJECT_DIR` for portable paths.

---

## MCP Server Configuration

### File Location

```
project-root/
└── .mcp.json              # Project-specific MCP servers
```

Or global (user-level):
```
~/.claude.json → mcpServers section
```

### Configuration Scopes

| Scope | File | Use Case |
|-------|------|----------|
| **Project** | `<project>/.mcp.json` | Project-specific services |
| **User** | `~/.claude.json` | Global services (GitHub, memory) |

⚠️ **Critical**: Use `--scope user` when adding global MCPs via CLI to avoid project isolation issues.

---

## Recommended MCP Servers

### Tier 1: Essential (Always-On Core)

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Persistent memory across sessions"
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Chain-of-thought reasoning for complex problems"
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"],
      "description": "Live documentation lookup for any library"
    }
  }
}
```

### Tier 2: Development Tools (Always-On)

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      },
      "description": "GitHub operations - PRs, issues, repos"
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dirs"],
      "description": "Filesystem operations outside project"
    }
  }
}
```

### Tier 3: Cloud & Deployment (On-Demand)

```json
{
  "mcpServers": {
    "vercel": {
      "type": "http",
      "url": "https://mcp.vercel.com",
      "description": "Vercel deployments and projects"
    },
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest", "--project-ref=${SUPABASE_PROJECT_REF}"],
      "description": "Supabase database operations"
    },
    "railway": {
      "command": "npx",
      "args": ["-y", "@railway/mcp-server"],
      "description": "Railway deployments"
    }
  }
}
```

### Tier 4: Cloudflare Suite (On-Demand)

```json
{
  "mcpServers": {
    "cloudflare-docs": {
      "type": "http",
      "url": "https://docs.mcp.cloudflare.com/mcp",
      "description": "Cloudflare documentation search"
    },
    "cloudflare-workers-builds": {
      "type": "http",
      "url": "https://builds.mcp.cloudflare.com/mcp",
      "description": "Cloudflare Workers builds"
    },
    "cloudflare-observability": {
      "type": "http",
      "url": "https://observability.mcp.cloudflare.com/mcp",
      "description": "Cloudflare observability/logs"
    }
  }
}
```

### Tier 5: Advanced Analysis (On-Demand)

```json
{
  "mcpServers": {
    "claude-context": {
      "command": "npx",
      "args": ["-y", "@zilliz/claude-context-mcp@latest"],
      "env": {
        "OPENAI_API_KEY": "${OPENAI_API_KEY}",
        "MILVUS_TOKEN": "${MILVUS_TOKEN}"
      },
      "description": "Semantic codebase search with 40% token reduction"
    },
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "${FIRECRAWL_API_KEY}"
      },
      "description": "Web scraping and crawling"
    },
    "clickhouse": {
      "type": "http",
      "url": "https://mcp.clickhouse.cloud/mcp",
      "description": "ClickHouse analytics queries"
    }
  }
}
```

### Tier 6: Ollama Local Models (On-Demand)

```json
{
  "mcpServers": {
    "ollama": {
      "command": "npx",
      "args": ["-y", "ollama-mcp"],
      "env": {
        "OLLAMA_HOST": "${OLLAMA_HOST:-http://localhost:11434}"
      },
      "description": "Full Ollama SDK - model management, generation, chat, embeddings"
    }
  }
}
```

**Ollama Tools**:
- `ollama_generate` - Text completion
- `ollama_chat` - Multi-turn chat with tool support
- `ollama_embed` - Create embeddings
- `ollama_list/pull/show` - Model management

See [OLLAMA-INTEGRATION.md](OLLAMA-INTEGRATION.md) for full setup guide.

### Tier 7: External AI APIs (On-Demand)

```json
{
  "mcpServers": {
    "deepseek": {
      "command": "npx",
      "args": ["-y", "deepseek-mcp-server"],
      "env": {
        "DEEPSEEK_API_KEY": "${DEEPSEEK_API_KEY}"
      },
      "description": "DeepSeek R1 reasoning + V3 chat"
    },
    "pal": {
      "command": "uvx",
      "args": ["--from", "pal-mcp-server", "pal-server"],
      "env": {
        "GEMINI_API_KEY": "${GEMINI_API_KEY}",
        "OPENAI_API_KEY": "${OPENAI_API_KEY}",
        "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}"
      },
      "description": "Multi-model orchestration (Gemini, GPT, O3, etc.)"
    }
  }
}
```

**PAL Tools**:
- `chat` - Multi-model conversations
- `thinkdeep` - Extended reasoning with other models
- `planner` - Multi-perspective planning
- `consensus` - Get consensus from multiple models
- `codereview` - Cross-model code review
- `debug` - Collaborative debugging
- `clink` - CLI-to-CLI bridge for subagents

---

## Installed Plugins Reference

### By Category

#### Development Workflow
| Plugin | Commands/Skills | Purpose |
|--------|----------------|---------|
| `feature-dev` | `/feature-dev` | Guided feature development |
| `code-review` | `/code-review` | Automated PR review with confidence scoring |
| `pr-review-toolkit` | `/review-pr` | Comprehensive PR review agents |
| `commit-commands` | `/commit`, `/commit-push-pr` | Git commit workflows |

#### Code Quality
| Plugin | Commands/Skills | Purpose |
|--------|----------------|---------|
| `security-guidance` | Auto-active | Security best practices |
| `hookify` | `/hookify` | Create behavior-preventing hooks |
| `plugin-dev` | `/create-plugin` | Plugin development |

#### Frontend/Design
| Plugin | Commands/Skills | Purpose |
|--------|----------------|---------|
| `frontend-design` | `/frontend-design` | Production-grade UI creation |
| `figma` | `/implement-design` | Figma-to-code translation |

#### Cloud Services
| Plugin | Commands/Skills | Purpose |
|--------|----------------|---------|
| `vercel` | `/deploy`, `/logs` | Vercel deployments |
| `supabase` | MCP tools | Database operations |
| `firebase` | MCP tools | Firebase operations |
| `sentry` | `/getIssues`, `/seer` | Error monitoring |

#### AI/ML
| Plugin | Commands/Skills | Purpose |
|--------|----------------|---------|
| `huggingface-skills` | Various | Model training, evaluation |
| `agent-sdk-dev` | `/new-sdk-app` | Claude Agent SDK apps |

#### Documentation
| Plugin | Commands/Skills | Purpose |
|--------|----------------|---------|
| `context7` | MCP tools | Live library documentation |
| `greptile` | MCP tools | Code search across repos |
| `Notion` | `/notion-search` | Notion workspace integration |

#### LSP Integrations
| Plugin | Language |
|--------|----------|
| `typescript-lsp` | TypeScript/JavaScript |
| `pyright-lsp` | Python |
| `gopls-lsp` | Go |
| `rust-analyzer-lsp` | Rust |
| `csharp-lsp` | C# |
| `jdtls-lsp` | Java |
| `php-lsp` | PHP |
| `swift-lsp` | Swift |
| `clangd-lsp` | C/C++ |

---

## Adding New Plugins

### From Official Directory

```bash
# Browse available plugins
/plugin > Discover

# Install specific plugin
/plugin install {plugin-name}@claude-plugin-directory
```

### Local Plugin Development

```
project/.claude-plugin/
├── plugin.json          # Required: metadata
├── .mcp.json           # Optional: MCP servers
├── commands/           # Optional: slash commands
├── agents/             # Optional: agent definitions
├── skills/             # Optional: skill definitions
└── hooks.json          # Optional: hook definitions
```

---

## MCP Server Best Practices

### 1. Context Budget Management

```
Context Budget Guide:
├── Minimal (~25K tokens): Core only (context7, github, serena)
├── Standard (~40-50K): Core + 1-2 service MCPs
└── Full (~80K+): Core + all service MCPs (not recommended)

⚠️ Stay under 50K tokens for optimal performance
```

Each MCP server consumes context tokens. See [MCP-CATALOG.md](MCP-CATALOG.md) for token costs per plugin.

Disable unused servers per-project:

```json
{
  "disabledMcpServers": ["cloudflare-docs", "railway"]
}
```

### 2. Use Environment Variables

Never hardcode credentials:

```json
{
  "env": {
    "API_KEY": "${MY_API_KEY}"
  }
}
```

Set in shell profile:
```bash
export MY_API_KEY="your-actual-key"
```

### 3. Validate Before Production

Test MCP servers in a sandbox project first:

```bash
# Create test project
mkdir ~/mcp-test && cd ~/mcp-test
claude

# Test MCP connection
> Can you list available tools from the memory MCP?
```

### 4. HTTP vs Command MCPs

| Type | Pros | Cons |
|------|------|------|
| `type: http` | No local install, always updated | Requires internet, potential latency |
| `command: npx` | Works offline, controllable version | Needs Node.js, version management |
| `command: uvx` | Python-based, lightweight | Needs Python/uv |

---

## Troubleshooting

### MCP Server Not Connecting

1. Check if command exists:
   ```bash
   npx -y @modelcontextprotocol/server-memory --help
   ```

2. Verify environment variables:
   ```bash
   echo $GITHUB_TOKEN
   ```

3. Check Claude's MCP status:
   ```
   /mcp
   ```

### Plugin Not Loading

1. Verify installation:
   ```
   /plugin list
   ```

2. Check plugin directory:
   ```bash
   ls ~/.claude/plugins/cache/
   ```

3. Reinstall:
   ```
   /plugin uninstall {name}
   /plugin install {name}@claude-plugin-directory
   ```

### Context Window Issues

If Claude seems slow or forgetful:

1. Check active MCPs:
   ```
   /mcp
   ```

2. Disable non-essential servers in project config

3. Use `disabledMcpServers` array

---

## Security Considerations

### Credential Management

```
✅ DO:
- Use environment variables
- Store secrets in ~/.bashrc or secret manager
- Rotate tokens regularly

❌ DON'T:
- Hardcode tokens in .mcp.json
- Commit .mcp.json with credentials
- Share MCP configs without sanitizing
```

### Plugin Trust

```
⚠️ Plugins can execute arbitrary code
- Only install from trusted sources
- Review plugin code before installing
- Use project-scoped plugins for untrusted code
```

### MCP Server Access

```
Each MCP server has access to:
- Environment variables you provide
- Network (for HTTP-based)
- Filesystem (if configured)

Review what each server does before enabling.
```

---

## Quick Setup Template

For new projects, copy this to `.mcp.json`:

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "description": "Persistent memory"
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"],
      "description": "Live docs lookup"
    }
  },
  "_comments": {
    "usage": "Add more servers as needed",
    "disable": "Use disabledMcpServers array to disable per-project"
  }
}
```

---

## Resources

- [MCP Protocol Spec](https://modelcontextprotocol.io)
- [Official Plugin Directory](https://github.com/anthropics/claude-plugins-official)
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- [claude-context (Zilliz)](https://github.com/zilliztech/claude-context)
- [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server)

---

*Part of the Agent Enhancement Kit*
