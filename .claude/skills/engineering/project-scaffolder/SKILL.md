---
name: project-scaffolder
description: Scaffold new projects with best-practice structure, tooling, and configuration. Use when starting a new project, setting up a monorepo, or bootstrapping a service from scratch.
argument-hint: "Scaffold a Next.js 15 app with TypeScript, Tailwind, Prisma, and tRPC"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
effort: medium
once: true
department: engineering
references: []
---

# project-scaffolder

## Stack Detection

| Intent | Stack | Flags |
|--------|-------|-------|
| "Next.js", "React", "fullstack web" | Next.js 15 App Router | `--typescript --tailwind --app` |
| "Vite", "React SPA", "frontend only" | Vite + React | `--typescript --tailwind` |
| "Svelte", "SvelteKit" | SvelteKit | `--typescript` |
| "Astro", "static site", "blog" | Astro | `--tailwind` |
| "Express", "Node API", "REST" | Express + TypeScript | `--typescript` |
| "Fastify", "high perf API" | Fastify + TypeScript | `--typescript` |
| "FastAPI", "Python", "ML API" | FastAPI | `--python` |
| "Go", "Gin", "microservice" | Go + Gin | `--minimal` |
| "monorepo", "turborepo" | Turborepo + pnpm | `--workspace` |

Ask clarifying questions if ambiguous. Default to TypeScript.

## Core Scaffolding Checklist

For ALL projects (non-negotiable):

1. **package.json / go.mod** — Name, version, private: true, engines
2. **tsconfig.json** — Strict mode, path aliases (@/*)
3. **Linter** — ESLint with TypeScript config OR Biome (prefer Biome)
4. **Formatter** — Prettier OR Biome (prefer Biome — single tool)
5. **.gitignore** — node_modules, .env*, dist, .next, coverage
6. **Git hooks** — husky + lint-staged (pre-commit hook)
7. **CI workflow** — GitHub Actions: lint, typecheck, test, build
8. **README.md** — Installation, dev commands, architecture diagram
9. **CLAUDE.md** — Project-specific instructions for AI assistants

Execute in order. Failures block subsequent steps.

---

## Next.js 15 Scaffold Example

### Directory Tree

```
my-app/
├── .github/workflows/ci.yml
├── .husky/
├── prisma/
│   └── schema.prisma
├── public/
├── src/
│   ├── app/
│   ├── components/
│   ├── lib/
│   └── server/
├── .env.example
├── .eslintrc.json
├── .gitignore
├── biome.json
├── CLAUDE.md
├── next.config.ts
├── package.json
├── README.md
├── tailwind.config.ts
└── tsconfig.json
```

### package.json (Next.js 15 + tRPC + Prisma + Tailwind)

```json
{
  "name": "my-app",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "db:generate": "prisma generate",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev"
  },
  "dependencies": {
    "@prisma/client": "^6.0.0",
    "@trpc/client": "^11.0.0",
    "@trpc/server": "^11.0.0",
    "next": "15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@biomejs/biome": "^1.9.0",
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "husky": "^9.1.0",
    "lint-staged": "^15.0.0",
    "prisma": "^6.0.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.6.0"
  },
  "lint-staged": {
    "*.{ts,tsx}": ["biome check --write"]
  }
}
```

### biome.json

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "organizeImports": { "enabled": true },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2, "lineWidth": 100 },
  "javascript": { "formatter": { "quoteStyle": "single", "semicolons": false } }
}
```

### CLAUDE.md

```markdown
# Project Context

Stack: Next.js 15, tRPC, Prisma, Tailwind CSS, Biome.

## Commands
- `npm run dev` — Start dev server
- `npm run db:generate` — Generate Prisma client
- `npm run db:push` — Push schema to DB

## Architecture
- `src/app/` — App Router pages
- `src/server/trpc/` — tRPC router and procedures
- `prisma/schema.prisma` — Database schema

## Conventions
- Use Biome for lint/format (not ESLint/Prettier)
- All database access through tRPC procedures
- Zod for runtime validation
```

---

## FastAPI Scaffold Example

### Directory Tree

```
my-api/
├── .github/workflows/ci.yml
├── alembic/
├── src/
│   ├── __init__.py
│   ├── main.py
│   ├── routers/
│   ├── models/
│   ├── schemas/
│   └── database.py
├── tests/
├── .env.example
├── .gitignore
├── pyproject.toml
├── README.md
└── CLAUDE.md
```

### pyproject.toml

```toml
[project]
name = "my-api"
version = "0.1.0"
requires-python = ">=3.12"

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
```

### src/main.py

```python
from fastapi import FastAPI
from src.routers import items

app = FastAPI(title="My API", version="0.1.0")
app.include_router(items.router, prefix="/items", tags=["items"])
```

---

## Monorepo Setup (Turborepo + pnpm)

### Directory Tree

```
my-monorepo/
├── apps/
│   ├── web/          # Next.js app
│   └── api/          # Express/FastAPI service
├── packages/
│   ├── ui/           # Shared React components
│   ├── database/     # Shared Prisma client
│   └── config/       # Shared ESLint, Tailwind configs
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
├── .gitignore
└── README.md
```

### pnpm-workspace.yaml

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**", ".next/**"] },
    "lint": { "dependsOn": ["^lint"] },
    "test": { "dependsOn": ["^test"] },
    "dev": { "cache": false, "persistent": true }
  }
}
```

### Root package.json

```json
{
  "name": "my-monorepo",
  "private": true,
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev",
    "lint": "turbo lint",
    "test": "turbo test"
  },
  "devDependencies": {
    "turbo": "^2.0.0"
  }
}
```

---

## Post-Scaffold Verification

Run before declaring success:

1. **TypeScript**: `npx tsc --noEmit` exits 0
2. **Linter**: `npx biome check .` exits 0
3. **Formatter**: `npx biome format --check .` exits 0
4. **Build**: `npm run build` exits 0, produces output
5. **Dev server**: `npm run dev` starts without errors
6. **CI exists**: `.github/workflows/ci.yml` present with lint/test/build jobs
7. **CLAUDE.md**: Exists and documents project-specific commands

Fix any failures before proceeding. Do not skip verification.
