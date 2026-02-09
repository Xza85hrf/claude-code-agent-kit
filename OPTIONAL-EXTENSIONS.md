# Optional Extensions

> Additional resources from the community that can enhance the kit.

---

## On-Demand MCP Note

Advanced MCPs listed in this file are **on-demand** - they're not always-on by default to save context tokens. To enable any of these:

1. See [MCP-CATALOG.md](MCP-CATALOG.md) for enable instructions
2. Add to `.claude/settings.local.json` for project-specific MCPs
3. Or add to `~/.claude/settings.json` for global MCPs

---

## From `everything-claude-code`

**Repository:** https://github.com/affaan-m/everything-claude-code

### Continuous Learning v2 System

A sophisticated learning system that observes your sessions and creates "instincts" - small learned behaviors with confidence scoring.

**Features:**
- Hooks capture prompts + tool use during sessions
- Background agent (Haiku) detects patterns
- Atomic instincts with confidence scoring (0.3-0.9)
- Instincts cluster and evolve into skills/commands/agents

**Commands:**
- `/learn` - Create instinct from current session
- `/instinct-status` - View all instincts
- `/instinct-import` / `/instinct-export` - Share instincts
- `/evolve` - Cluster instincts into skills

**Integration:**
```bash
# Clone the repo
git clone https://github.com/affaan-m/everything-claude-code.git

# Copy continuous-learning skill
cp -r everything-claude-code/skills/continuous-learning-v2 .claude/skills/

# Copy related commands
cp everything-claude-code/commands/learn.md .claude/commands/
cp everything-claude-code/commands/evolve.md .claude/commands/
cp everything-claude-code/commands/instinct-*.md .claude/commands/
```

### Additional Skills Available

| Skill | Purpose | Copy From |
|-------|---------|-----------|
| `backend-patterns` | API, database, caching approaches | `skills/backend-patterns` |
| `frontend-patterns` | React, Next.js conventions | `skills/frontend-patterns` |
| `coding-standards` | Language best practices | `skills/coding-standards` |
| `golang-patterns` | Go idioms and practices | `skills/golang-patterns` |
| `python-patterns` | Python best practices | `skills/python-patterns` |
| `postgres-patterns` | PostgreSQL optimization | `skills/postgres-patterns` |
| `django-tdd` | Django TDD workflow | `skills/django-tdd` |

### Additional Agents

| Agent | Purpose | Copy From |
|-------|---------|-----------|
| `architect` | System design decisions | `agents/architect.md` |
| `database-reviewer` | Database query review | `agents/database-reviewer.md` |
| `refactor-cleaner` | Dead code removal | `agents/refactor-cleaner.md` |
| `e2e-runner` | Playwright test execution | `agents/e2e-runner.md` |

### Additional Commands

| Command | Purpose | Copy From |
|---------|---------|-----------|
| `/plan` | Implementation planning | `commands/plan.md` |
| `/build-fix` | Build error resolution | `commands/build-fix.md` |
| `/e2e` | E2E test generation | `commands/e2e.md` |
| `/orchestrate` | Multi-agent workflows | `commands/orchestrate.md` |

---

## From `claude-context` (Zilliz)

**Repository:** https://github.com/zilliztech/claude-context

Semantic code search with vector embeddings.

**Benefits:**
- ~40% token reduction with equivalent retrieval quality
- Hybrid search (BM25 + dense vectors)
- Natural language queries across codebase

**Requirements:**
- Node.js 20-23 (not 24+)
- OpenAI API key (for embeddings)
- Milvus/Zilliz token (vector database)

**Setup:**
```json
{
  "mcpServers": {
    "claude-context": {
      "command": "npx",
      "args": ["-y", "@zilliz/claude-context-mcp@latest"],
      "env": {
        "OPENAI_API_KEY": "${OPENAI_API_KEY}",
        "MILVUS_TOKEN": "${MILVUS_TOKEN}"
      }
    }
  }
}
```

**Tools Provided:**
- `index_codebase` - Index directory for search
- `search_code` - Natural language code search
- `clear_index` - Remove project index
- `get_indexing_status` - Check progress

---

## From `pal-mcp-server` (Beehive)

**Repository:** https://github.com/BeehiveInnovations/pal-mcp-server

Multi-model orchestration for collaborative AI.

**Benefits:**
- Coordinate with Gemini, GPT-4, O3, 50+ models
- Extended thinking with specialized models
- CLI-to-CLI bridge for subagents
- Context preservation across tools

**Tools (Default Enabled):**
| Tool | Purpose |
|------|---------|
| `chat` | Multi-model conversations |
| `thinkdeep` | Extended reasoning |
| `planner` | Multi-perspective planning |
| `consensus` | Get model consensus |
| `codereview` | Cross-model code review |
| `precommit` | Pre-commit checks |
| `debug` | Collaborative debugging |
| `apilookup` | API documentation search |
| `challenge` | Devil's advocate mode |

**Tools (Default Disabled):**
| Tool | Purpose |
|------|---------|
| `analyze` | Deep code analysis |
| `refactor` | Refactoring suggestions |
| `testgen` | Test generation |
| `secaudit` | Security audit |
| `docgen` | Documentation generation |

**Setup:**
```bash
# Quick install
git clone https://github.com/BeehiveInnovations/pal-mcp-server.git
cd pal-mcp-server
./run-server.sh

# Or via uvx (no local install)
# Add to .mcp.json:
```

```json
{
  "mcpServers": {
    "pal": {
      "command": "uvx",
      "args": ["--from", "pal-mcp-server", "pal-server"],
      "env": {
        "GEMINI_API_KEY": "${GEMINI_API_KEY}",
        "OPENAI_API_KEY": "${OPENAI_API_KEY}",
        "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}"
      }
    }
  }
}
```

---

## From Official Plugin Directory

**Repository:** https://github.com/anthropics/claude-plugins-official

### Plugins Worth Installing

| Plugin | Purpose | Install |
|--------|---------|---------|
| `code-review` | Confidence-scored PR review | `/plugin install code-review@claude-plugin-directory` |
| `agent-sdk-dev` | Claude Agent SDK projects | `/plugin install agent-sdk-dev@claude-plugin-directory` |
| `hookify` | Create behavior-preventing hooks | `/plugin install hookify@claude-plugin-directory` |
| `ralph-loop` | Autonomous task loops | `/plugin install ralph-loop@claude-plugin-directory` |
| `learning-output-style` | Educational explanations | `/plugin install learning-output-style@claude-plugin-directory` |

### External Plugins

| Plugin | Purpose | Install |
|--------|---------|---------|
| `context7` | Live documentation | `/plugin install context7@claude-plugin-directory` |
| `serena` | Semantic code editing | `/plugin install serena@claude-plugin-directory` |
| `greptile` | Cross-repo code search | `/plugin install greptile@claude-plugin-directory` |
| `playwright` | Browser automation | `/plugin install playwright@claude-plugin-directory` |

---

## Custom MCP Server Development

**Guide:** https://gist.github.com/RaiAnsar/b542cf25cbd4a1c36e9408849c5a5bcd

Key points for building custom MCPs:

1. **Protocol Basics:**
   - JSON-RPC 2.0 over stdio
   - Must implement: `initialize`, `tools/list`, `tools/call`

2. **Configuration Scope:**
   ```
   ⚠️ Configuration scope is the #1 source of MCP issues
   Always use --scope user for global accessibility
   ```

3. **Basic Structure (Python):**
   ```python
   import asyncio
   import json
   import sys

   async def handle_request(request):
       method = request.get("method")
       if method == "initialize":
           return {"capabilities": {"tools": {}}}
       elif method == "tools/list":
           return {"tools": [...]}
       elif method == "tools/call":
           # Execute tool
           pass
   ```

4. **Testing:**
   ```bash
   # Test server directly
   echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | python server.py
   ```

---

## Selection Guide

| Need | Best Option | On-Demand? |
|------|-------------|------------|
| Live library docs | Context7 plugin (already in kit) | Always-on |
| Semantic code search | claude-context MCP | Yes |
| Multi-model collaboration | PAL MCP server | Yes |
| Automatic pattern learning | continuous-learning-v2 | Skill-based |
| PR reviews | code-review plugin | Plugin |
| Autonomous loops | ralph-loop plugin | Plugin |
| Service integrations | See [MCP-CATALOG.md](MCP-CATALOG.md) | Yes |

---

*Part of the Agent Enhancement Kit*
