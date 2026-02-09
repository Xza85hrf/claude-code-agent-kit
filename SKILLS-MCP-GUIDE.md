# Skills & MCP Integration Guide

> Leverage external tools, stay up-to-date, and create custom capabilities.

---

## Part 1: MCP Servers (Model Context Protocol)

### What Are MCP Servers?

MCP servers extend Claude Code with external capabilities:
- **Documentation access** (Context7)
- **Service integration** (GitHub, Supabase, Stripe)
- **Browser automation** (Playwright)
- **Project management** (Linear, Notion)

### On-Demand MCP Architecture

To optimize context tokens, MCPs are split into:

| Category | MCPs | Token Usage |
|----------|------|-------------|
| **Always-On Core** | context7, github, serena | ~25K base |
| **On-Demand Services** | Notion, Sentry, Figma, etc. | +5-21K each |

**Workflow for Service MCPs:**
1. User needs Sentry → asks Claude
2. Claude checks if sentry MCP is available (via ToolSearch)
3. If not available → Claude tells user to enable in `.claude/settings.local.json`
4. After restart → Claude uses ToolSearch to load specific tools

See [MCP-CATALOG.md](MCP-CATALOG.md) for full list with enable instructions.

### Loading MCP Tools

MCP tools are deferred (not loaded by default). Load them using ToolSearch:

```
# Direct selection (when you know the tool name)
ToolSearch
query: "select:mcp__github__create_pull_request"

# Search by keyword (when unsure)
ToolSearch
query: "github pull request"
```

### On-Demand MCP Pattern

When a user asks about a service that might not be enabled:

```
User: "Help me debug this Sentry issue"

Step 1: Check if MCP is available
ToolSearch
query: "sentry"

Step 2a: If tools found → Use them
mcp__plugin_sentry_sentry__get_issue_details
issue_id: "12345"

Step 2b: If no tools found → Tell user to enable
"The Sentry MCP isn't enabled. To enable it:
1. Add to .claude/settings.local.json:
   { "enabledPlugins": { "sentry@claude-plugins-official": true } }
2. Restart Claude Code
See MCP-CATALOG.md for details."
```

### Essential MCP Servers

#### Ollama - Worker Pool (Local + Cloud Models)

**Purpose:** Delegate tasks to local/cloud models for massive token savings. Opus orchestrates, workers execute.

**Requires Ollama v0.14.0+** (native Anthropic Messages API support).

```
# Quick setup for Claude Code compatibility
ollama launch claude

# List available models
ollama_list

# Complex coding task (RL-trained specialist)
ollama_chat
model: "qwen3-coder-next:latest"
messages: [{ role: "user", content: "Implement a REST API with validation for user registration" }]

# Fast boilerplate generation
ollama_generate
model: "glm-4.7-flash"
prompt: "Generate a TypeScript CRUD scaffold for users"

# Agent swarm + vision-based code gen
ollama_chat
model: "kimi-k2.5:cloud"
messages: [{ role: "user", content: "Generate React component from this UI", images: ["base64..."] }]

# Long context analysis (1M tokens)
ollama_chat
model: "gemini-3-pro-preview"
messages: [{ role: "user", content: "Analyze this entire codebase for patterns: [full repo]" }]

# Create embeddings for search
ollama_embed
model: "nomic-embed-text"
input: "function to validate email addresses"
```

**Worker Model Roles:**

| Model | Role | When to Use |
|-------|------|-------------|
| `qwen3-coder-next:cloud` | **Primary Coder (Cloud)** | Complex coding tasks, full precision (cloud-first, needs OLLAMA_API_KEY) |
| `qwen3-coder-next:latest` | **Primary Coder (Local)** | Complex coding tasks, agentic workflows (80B MoE/3B active, 256K ctx) |
| `kimi-k2.5:cloud` | **Swarm Agent + Vision** | Multi-step sub-tasks, tool calling, vision-based code gen (256K ctx) |
| `glm-4.7-flash` | **Fast Coder** | Boilerplate, CRUD, quick generation (30B MoE/3B active, 198K ctx) |
| `gemini-3-pro-preview` | **Long Context Analyst** | Whole-repo analysis, multimodal processing (1M ctx) |
| `devstral-small-2` | **Agentic SWE Coder** | Multi-file editing, tool calling, SWE-bench 65.8% (15 GB) |
| `deepcoder` | **Code Reasoning** | Algorithmic tasks, o3-mini level reasoning (9 GB) |

**Token Savings:** Delegating a 1000-line file review saves ~98% tokens (50 vs 4000).

#### DeepSeek - Reasoning Advisor

**Purpose:** Get second opinions on complex logic. DeepSeek R1 is a strong reasoner.

```
# Get second opinion on algorithm
deepseek chat_completion
model: "deepseek-reasoner"  # R1 for deep analysis
message: "Review this algorithm for edge cases: [code]. What am I missing?"

# Quick validation
deepseek multi_turn_chat
model: "deepseek-chat"  # V3 for fast chat
messages: [{ role: "user", content: "Is this regex correct? [pattern]" }]
```

**When to use DeepSeek:**
- Validating complex algorithms
- Getting alternative perspectives
- Reviewing security-sensitive logic
- Sanity checking before committing

**Important:** YOU (Opus) make the final decision. DeepSeek advises, you decide.

#### Context7 - Documentation Access

**Purpose:** Get up-to-date documentation for any library.

```
# Step 1: Resolve library ID
mcp__plugin_context7_context7__resolve-library-id
libraryName: "react"

# Step 2: Query documentation
mcp__plugin_context7_context7__query-docs
context7CompatibleLibraryID: "/npm/react"
topic: "useEffect cleanup"
```

**When to use Context7:**
- Before implementing with unfamiliar library
- When debugging framework-specific issues
- When checking for breaking changes
- When learning best practices

#### GitHub

```
# Search code across repositories
mcp__github__search_code
q: "useState cleanup"
per_page: 10

# Get issue details
mcp__github__get_issue
owner: "facebook"
repo: "react"
issue_number: 12345

# Create pull request
mcp__github__create_pull_request
owner: "username"
repo: "project"
title: "feat: Add feature"
body: "Description..."
head: "feature-branch"
base: "main"

# List pull requests
mcp__github__list_pull_requests
owner: "username"
repo: "project"
state: "open"
```

#### Supabase

```
# List tables
mcp__plugin_supabase_supabase__list_tables
project_id: "your-project-id"

# Execute SQL
mcp__plugin_supabase_supabase__execute_sql
project_id: "your-project-id"
query: "SELECT * FROM users LIMIT 10"

# Apply migration
mcp__plugin_supabase_supabase__apply_migration
project_id: "your-project-id"
name: "add_user_roles"
query: "ALTER TABLE users ADD COLUMN role TEXT"

# Generate TypeScript types
mcp__plugin_supabase_supabase__generate_typescript_types
project_id: "your-project-id"
```

#### Playwright Browser

```
# Navigate
mcp__plugin_playwright_playwright__browser_navigate
url: "https://example.com"

# Take snapshot (get element refs)
mcp__plugin_playwright_playwright__browser_snapshot

# Click element
mcp__plugin_playwright_playwright__browser_click
element: "@e5"

# Fill form
mcp__plugin_playwright_playwright__browser_fill_form
element: "@e3"
value: "user@example.com"

# Screenshot
mcp__plugin_playwright_playwright__browser_take_screenshot
path: "/tmp/screenshot.png"

# Close browser
mcp__plugin_playwright_playwright__browser_close
```

#### Sentry

```
# Search issues
mcp__plugin_sentry_sentry__search_issues
query: "is:unresolved level:error"
project: "my-project"

# Get issue details
mcp__plugin_sentry_sentry__get_issue_details
issue_id: "12345"

# Analyze with AI
mcp__plugin_sentry_sentry__analyze_issue_with_seer
issue_id: "12345"
```

#### Linear

```
# Create issue
mcp__plugin_linear_linear__create_issue
title: "Bug: Login not working"
description: "Users report..."
teamId: "TEAM-123"

# List issues
mcp__plugin_linear_linear__list_issues
filter: {state: {name: {eq: "In Progress"}}}
```

#### Stripe

```
# List customers
mcp__plugin_stripe_stripe__list_customers
limit: 10

# Search documentation
mcp__plugin_stripe_stripe__search_stripe_documentation
query: "subscription webhooks"
```

#### Notion

```
# Search pages
mcp__plugin_Notion_notion__notion-search
query: "project roadmap"

# Create page
mcp__plugin_Notion_notion__notion-create-pages
parentId: "page-id"
title: "New Page"
content: "Page content..."
```

#### Firebase

```
# List projects
mcp__plugin_firebase_firebase__firebase_list_projects

# Get SDK config
mcp__plugin_firebase_firebase__firebase_get_sdk_config
project_id: "my-project"
app_type: "web"

# Initialize Firebase
mcp__plugin_firebase_firebase__firebase_init
features: ["firestore", "auth", "functions"]
```

#### Serena (Semantic Code)

```
# Get symbol overview
mcp__plugin_serena_serena__get_symbols_overview
relative_path: "src/services/auth.ts"

# Find symbol
mcp__plugin_serena_serena__find_symbol
name_path_pattern: "AuthService/login"
include_body: true

# Replace symbol body
mcp__plugin_serena_serena__replace_symbol_body
name_path: "AuthService/login"
relative_path: "src/services/auth.ts"
new_body: "async login(email: string, password: string) { ... }"

# Find references
mcp__plugin_serena_serena__find_referencing_symbols
name_path: "AuthService"
```

### Multi-Model Architecture: Opus = Brain

```
┌─────────────────────────────────────────────────────────────┐
│                  CLAUDE OPUS (THE BRAIN)                     │
│                                                             │
│   Planning • Complex Reasoning • Final Decisions            │
│   Security Reviews • User Communication • Integration       │
└────────────────────────┬────────────────────────────────────┘
                         │ Delegates & Orchestrates
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   OLLAMA    │  │  DEEPSEEK   │  │   GITHUB    │
│   Workers   │  │  Advisor    │  │   & MCPs    │
│             │  │             │  │             │
│ qwen3-coder-│  │ R1: 2nd     │  │ Repo ops    │
│  next:cloud │  │    opinion  │  │ PR/Issues   │
│ kimi-k2.5   │  │ V3: quick   │  │ Context7    │
│ glm-4.7     │  │    validate │  │             │
│ gemini-3-pro│  │             │  │             │
│ devstral    │  │             │  │             │
│ deepcoder   │  │             │  │             │
└─────────────┘  └─────────────┘  └─────────────┘
  Task Workers    Reasoning Help    External Tools
```

**Key Principle:** Opus decides, workers execute. Always review worker output.

---

## Part 2: Built-in Skills

### Git Skills

```
/commit                    # Create git commit
/commit -m "message"       # Commit with message
/commit-push-pr            # Commit, push, and create PR
```

### Code Review Skills

```
/code-review               # Review current changes
/review-pr 123             # Review specific PR
```

### Deployment Skills

```
/deploy                    # Deploy to Vercel
/setup                     # Setup Vercel project
/logs                      # View deployment logs
```

### Feature Development

```
/feature-dev               # Guided feature development
```

### Stripe Skills

```
/test-cards                # Show test card numbers
/explain-error CARD_DECLINED  # Explain error codes
```

### Notion Skills

```
/notion-search "query"     # Search Notion
/notion-create-task        # Create task
/notion-find "title"       # Find page
```

### Sentry Skills

```
/seer "query"              # Ask about Sentry environment
/getIssues                 # Get recent issues
```

### Plugin Development

```
/create-plugin             # Create new plugin
/skill-development         # Create skills
/agent-development         # Create agents
/hook-development          # Create hooks
```

---

## Part 3: Skills Marketplace (SkillsMP)

### Discovering Community Skills

[SkillsMP](https://skillsmp.com/) hosts 71,000+ agent skills compatible with Claude Code using the SKILL.md format.

**Features:**
- Smart search and category filtering
- Quality indicators for vetted skills
- One-command installation for skills with `marketplace.json`
- Compatible with Claude Code, OpenAI Codex CLI, and other tools

### Installing Skills from SkillsMP

```bash
# Skills with marketplace.json can be installed directly
/plugin marketplace add anthropics/skills
/plugin install document-skills@anthropic-agent-skills

# Or manually copy SKILL.md files to your project
```

### Official Anthropic Skills

The official [Anthropic skills repository](https://github.com/anthropics/skills) includes:
- **Document Skills** - DOCX, PDF, PPTX, XLSX manipulation
- **Example Skills** - Templates and patterns

```bash
/plugin marketplace add anthropics/skills
/plugin install example-skills@anthropic-agent-skills
```

### Skill Categories

| Category | Examples |
|----------|----------|
| Creative & Design | Art generation, music, design systems |
| Development | Testing, code review, MCP server generation |
| Enterprise | Business workflows, branding |
| Document | PDF manipulation, spreadsheets, presentations |

### Resources

- [SkillsMP Marketplace](https://skillsmp.com/)
- [Agent Skills Standard](http://agentskills.io)
- [Anthropic Skills Repo](https://github.com/anthropics/skills)
- [Creating Custom Skills](https://support.claude.com/en/articles/12512198-creating-custom-skills)

---

## Part 4: Creating Custom Skills

### Skill File Structure

Create `.claude/skills/my-skill.md`:

```markdown
---
name: my-skill
description: Brief description for when to invoke
---

# My Custom Skill

## Purpose
[What this skill does]

## Steps
1. First step
2. Second step

## Examples
[Usage examples]
```

### Example: Project Setup Skill

**`.claude/skills/setup-project.md`**

```markdown
---
name: setup-project
description: Initialize a new project with best practices
---

# Project Setup Skill

## Purpose
Set up a new project with:
- Git initialization
- Package manager setup
- Linting/formatting configuration
- Testing framework
- CI/CD basics

## Steps

### 1. Determine Project Type
Ask user:
- Language (TypeScript, Python, Go, etc.)
- Framework (React, FastAPI, etc.)
- Package manager preference

### 2. Initialize Repository
```bash
git init
echo "node_modules/\n.env\n.env.local" > .gitignore
```

### 3. Package Setup
For Node.js:
```bash
npm init -y
npm install -D typescript eslint prettier
```

For Python:
```bash
python -m venv venv
pip install ruff pytest
```

### 4. Configuration Files
Create:
- .eslintrc.js or pyproject.toml
- .prettierrc
- tsconfig.json (if TypeScript)

### 5. Testing Setup
Install and configure testing framework.

### 6. Create README
Generate README.md with:
- Project description
- Setup instructions
- Available scripts
```

### Invoking Custom Skills

```
/setup-project
```

---

## Part 5: Staying Up-to-Date

### The Knowledge Refresh Protocol

**Before implementing with any library:**

```
1. CHECK VERSION
   - Read package.json/requirements.txt
   - Note current version

2. QUERY CONTEXT7
   - Resolve library ID
   - Query for relevant topic
   - Check for version-specific docs

3. WEB SEARCH IF NEEDED
   - Recent changes/announcements
   - Security advisories
   - Community best practices

4. IMPLEMENT
   - Use patterns from current docs
   - Avoid deprecated features
```

### Example Workflow

```
Task: Implement form validation with React Hook Form

Step 1: Check version
Read package.json → react-hook-form: ^7.48.0

Step 2: Query Context7
ToolSearch "select:mcp__plugin_context7_context7__resolve-library-id"
→ libraryName: "react-hook-form"
→ Returns: "/npm/react-hook-form"

mcp__plugin_context7_context7__query-docs
→ context7CompatibleLibraryID: "/npm/react-hook-form"
→ topic: "form validation register"
→ Returns: Current API documentation

Step 3: Implement using current patterns
```

### Deprecation Checking

```
When Context7 or web search reveals deprecation:

1. Note the deprecated API
2. Find the replacement
3. Update implementation
4. Add comment explaining migration if partial
```

---

## Part 6: Agent Development

### Creating Custom Agents

**`.claude/agents/database-optimizer.md`**

```markdown
---
name: database-optimizer
description: Analyze and optimize database performance
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Database Optimizer Agent

## Purpose
Analyze database queries and suggest optimizations.

## System Prompt
You are a database optimization expert. Your task is to:
1. Find slow queries in the codebase
2. Analyze query patterns
3. Suggest indexes
4. Identify N+1 problems
5. Recommend query rewrites

## Process
1. Search for database query files
2. Analyze query patterns
3. Check for missing indexes
4. Look for N+1 patterns
5. Generate optimization report
```

### Invoking Agents via Task Tool

```
Task tool:
  subagent_type: "general-purpose"
  prompt: "Analyze the database queries in this project and suggest optimizations"
```

---

## Part 7: MCP Server Configuration

### Adding MCP Servers

In `.mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server"],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
      }
    }
  }
}
```

### Environment Variables

Create `.env` for tokens (don't commit!):

```
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
SUPABASE_ACCESS_TOKEN=sbp_xxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxx
```

---

## Quick Reference

### MCP Tool Selection

```
Documentation  → Context7
Git operations → GitHub MCP or gh CLI
Database       → Supabase, Firebase
Payments       → Stripe
Monitoring     → Sentry
PM Tools       → Linear, Notion
Browser        → Playwright
Code Analysis  → Serena
```

### Skill Invocation

```
/skill-name           # Run skill
/skill-name args      # With arguments
```

### Context7 Pattern

```
1. ToolSearch "select:mcp__plugin_context7_context7__resolve-library-id"
2. Call with libraryName
3. ToolSearch "select:mcp__plugin_context7_context7__query-docs"
4. Call with ID and topic
```

---

*Part of the Agent Enhancement Kit for world-class coding agents.*
