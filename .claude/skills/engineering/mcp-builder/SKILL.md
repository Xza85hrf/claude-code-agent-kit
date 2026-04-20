---
name: mcp-builder
description: Build Model Context Protocol (MCP) servers that expose tools, resources, and prompts to AI assistants. Use when creating custom integrations.
argument-hint: "Build an MCP server that exposes a GitHub issue search tool and a create-issue tool"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: high
---

# MCP Server Builder

Build Model Context Protocol (MCP) servers that expose tools, resources, and prompts to AI assistants.

## Architecture

MCP follows client-server architecture:

| Component | Role |
|-----------|------|
| **Host** | Claude Code or AI assistant |
| **Client** | Embedded in host, communicates with servers |
| **Server** | Your custom implementation |

**Capabilities:**
- **Tools**: Executable functions with JSON schema inputs
- **Resources**: Read-only data (files, API responses, state)
- **Prompts**: Pre-defined templates

## TypeScript Server

Initialize:

```bash
mkdir github-mcp && cd github-mcp
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D typescript @types/node
npx tsc --init
```

Define tools in `src/index.ts`:

```typescript
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';

const SearchIssuesArgs = z.object({
  repo: z.string().describe("Repository in 'owner/repo' format"),
  query: z.string().describe("Search query for issues"),
  state: z.enum(['open', 'closed', 'all']).default('open'),
  max_results: z.number().min(1).max(100).default(10),
});

const CreateIssueArgs = z.object({
  repo: z.string(),
  title: z.string().min(1),
  body: z.string().optional(),
  labels: z.array(z.string()).optional(),
});

async function searchIssues(args: SearchIssuesArgs) {
  const { repo, query, state, max_results } = args;
  return {
    items: [{ number: 1, title: `Issue about ${query}`, state, repo }],
    total_count: 1,
  };
}

async function createIssue(args: CreateIssueArgs) {
  return { number: 42, title: args.title, state: 'open' };
}

const server = new Server(
  { name: 'github-mcp', version: '1.0.0' },
  { capabilities: { tools: {}, resources: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'search_issues',
      description: 'Search GitHub issues in a repository',
      inputSchema: {
        type: 'object',
        properties: {
          repo: { type: 'string', description: "Repository in 'owner/repo' format" },
          query: { type: 'string', description: 'Search query' },
          state: { type: 'string', enum: ['open', 'closed', 'all'], default: 'open' },
          max_results: { type: 'number', default: 10 },
        },
        required: ['repo', 'query'],
      },
    },
    {
      name: 'create_issue',
      description: 'Create a new GitHub issue',
      inputSchema: {
        type: 'object',
        properties: {
          repo: { type: 'string' },
          title: { type: 'string' },
          body: { type: 'string' },
          labels: { type: 'array', items: { type: 'string' } },
        },
        required: ['repo', 'title'],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === 'search_issues') {
      const result = await searchIssues(SearchIssuesArgs.parse(args));
      return { content: [{ type: 'text', text: JSON.stringify(result) }] };
    }
    if (name === 'create_issue') {
      const result = await createIssue(CreateIssueArgs.parse(args));
      return { content: [{ type: 'text', text: JSON.stringify(result) }] };
    }
    throw new Error(`Unknown tool: ${name}`);
  } catch (error) {
    return {
      content: [{ type: 'text', text: `Error: ${error}` }],
      isError: true,
    };
  }
});

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    { uri: 'github://rate-limit', name: 'GitHub API Rate Limit', mimeType: 'application/json' },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  if (request.params.uri === 'github://rate-limit') {
    return { contents: [{ mimeType: 'application/json', text: '{"remaining": 4997}' }] };
  }
  throw new Error(`Unknown resource: ${request.params.uri}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

Build and configure:

```bash
npx tsc
```

Add to `package.json`:

```json
{
  "bin": { "github-mcp": "dist/index.js" },
  "type": "module"
}
```

## Python Server

Install:

```bash
pip install "mcp[cli]" httpx
```

Server implementation using decorators:

```python
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
from pydantic import BaseModel
import httpx
import os

class SearchIssuesInput(BaseModel):
    repo: str
    query: str
    state: str = "open"
    max_results: int = 10

class CreateIssueInput(BaseModel):
    repo: str
    title: str
    body: str | None = None
    labels: list[str] | None = None

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
app = Server("github-mcp")

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="search_issues",
            description="Search GitHub issues",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string"},
                    "query": {"type": "string"},
                    "state": {"type": "string", "enum": ["open", "closed", "all"]},
                    "max_results": {"type": "number"},
                },
                "required": ["repo", "query"],
            },
        ),
        Tool(
            name="create_issue",
            description="Create a GitHub issue",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string"},
                    "title": {"type": "string"},
                    "body": {"type": "string"},
                    "labels": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["repo", "title"],
            },
        ),
    ]

@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    headers = {"Authorization": f"token {GITHUB_TOKEN}"} if GITHUB_TOKEN else {}

    if name == "search_issues":
        args = SearchIssuesInput(**arguments)
        url = f"https://api.github.com/search/issues?q={args.query}+repo:{args.repo}+state:{args.state}"
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=headers)
            return [TextContent(type="text", text=resp.text)]

    if name == "create_issue":
        args = CreateIssueInput(**arguments)
        url = f"https://api.github.com/repos/{args.repo}/issues"
        async with httpx.AsyncClient() as client:
            resp = await client.post(url, json={
                "title": args.title,
                "body": args.body,
                "labels": args.labels,
            }, headers=headers)
            return [TextContent(type="text", text=resp.text)]

    raise ValueError(f"Unknown tool: {name}")

async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
```

## Tool Design Patterns

| Pattern | Implementation |
|---------|-----------------|
| **Validation** | Use Zod (TS) or Pydantic (Python) with try/catch |
| **Error Handling** | Return `isError: true` with readable message |
| **Authentication** | Use environment variables, never hardcode |
| **Pagination** | Support cursor-based with optional limit (max 100) |

## Testing

**MCP Inspector** (development):

```bash
npx @modelcontextprotocol/inspector node dist/index.js
```

**JSON-RPC Protocol Test**:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js
```

**Integration Tests**:

```typescript
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

async function test() {
  const transport = new StdioClientTransport({
    command: 'node',
    args: ['dist/index.js'],
  });
  const client = new Client({ name: 'test', version: '1.0.0' }, {});
  await client.connect(transport);

  const result = await client.callTool({
    name: 'search_issues',
    arguments: { repo: 'facebook/react', query: 'bug', state: 'open' },
  });
  console.log(result);
}
```

## Publishing

**npm (TypeScript)**:

```bash
npm publish
# Users install: npm install -g github-mcp
```

**PyPI (Python)**:

```bash
pip install build
python -m build
twine upload dist/*
```

**Claude Code Configuration**: Add to `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "github-mcp": {
      "command": "github-mcp",
      "env": { "GITHUB_TOKEN": "ghp_xxx" }
    }
  }
}
```

Or use npx for version pinning:

```json
{
  "mcpServers": {
    "github-mcp": {
      "command": "npx",
      "args": ["-y", "github-mcp@1.0.0"]
    }
  }
}
```

## Common Patterns

| Pattern | Purpose |
|---------|---------|
| **REST API Wrapper** | Map API endpoints to tools. Use Zod for method/path/body |
| **Database Query Tool** | Enforce SELECT-only, never allow DELETE/DROP |
| **File System Tool** | Safe read operations with encoding/line limits |
| **Best Practice** | 3-5 focused tools, not dozens of generic ones |

## Programmatic Tool Calling (PTC)

Design tools PTC-ready:

1. **Return structured JSON** (not prose) with complete schema
2. **Document output schema** in description (field names, types)
3. **Make tools idempotent**: Read operations safe; writes use idempotency keys
4. **Keep responses concise**: Return only needed fields
5. **Future PTC support** will add `allowed_callers` field

See `Skill("programmatic-tool-calling")` for full architecture.
