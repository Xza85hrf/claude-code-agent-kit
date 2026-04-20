---
name: backend-endpoint
description: Create REST or GraphQL API endpoints with validation, error handling, and tests. Use when adding API endpoints, building CRUD operations, or implementing API routes.
argument-hint: "Create a REST endpoint for user registration with email validation and password hashing"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: medium
---

# Backend Endpoint

Detect framework → build endpoint → validate inputs → handle errors → test.

## Framework Detection

| File | Framework | Router |
|------|-----------|--------|
| `next.config.*` | Next.js | App Router (`app/api/`) or Pages Router (`pages/api/`) |
| `express` in package.json | Express.js | `app.get/post/put/delete()` |
| `fastify` in package.json | Fastify | `fastify.route()` |
| `hono` in package.json | Hono | `app.get/post()` |
| `fastapi` in requirements | FastAPI | `@app.get/post()` |
| `django` in requirements | Django REST | `urlpatterns` + ViewSets |
| `go.mod` | Go | `net/http` or Gin |

## REST Conventions

| Method | Path | Action | Success | Error |
|--------|------|--------|---------|-------|
| GET | `/resources` | List all | 200 | 500 |
| GET | `/resources/:id` | Get one | 200 | 404 |
| POST | `/resources` | Create | 201 | 400 |
| PUT | `/resources/:id` | Replace | 200 | 404, 400 |
| PATCH | `/resources/:id` | Update | 200 | 404, 400 |
| DELETE | `/resources/:id` | Remove | 204 | 404 |

## Standard Response Format

| Type | Format |
|------|--------|
| Success | `{ "data": {...}, "meta": { "requestId": "..." } }` |
| List | `{ "data": [...], "meta": { "page": 1, "limit": 20, "total": 42 } }` |
| Error | `{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [...] } }` |

**Rule:** Never expose stack traces, internal paths, or DB errors to clients.

## Endpoint Creation Workflow

```
1. Detect framework (check project files)
2. Define route, method, request/response types
3. Write validation schema
4. Implement handler: parse → validate → business logic → respond
5. Add error handling
6. Write tests
7. Update API docs (if OpenAPI spec exists)
```

## Implementation — Next.js App Router

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const CreateUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  password: z.string().min(8),
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const input = CreateUserSchema.parse(body);

    // Business logic
    const user = await createUser(input);

    return NextResponse.json({ data: user }, { status: 201 });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid input",
          details: error.errors.map((e) => ({
            field: e.path.join("."),
            message: e.message,
          })),
        },
      }, { status: 400 });
    }
    return NextResponse.json({
      error: { code: "INTERNAL_ERROR", message: "Something went wrong" },
    }, { status: 500 });
  }
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const page = parseInt(searchParams.get("page") || "1");
  const limit = Math.min(parseInt(searchParams.get("limit") || "20"), 100);

  const { users, total } = await listUsers({ page, limit });

  return NextResponse.json({
    data: users,
    meta: { page, limit, total },
  });
}
```

## Implementation — Express.js

```typescript
import { Router, Request, Response, NextFunction } from "express";
import { z } from "zod";

const router = Router();

const CreateUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  password: z.string().min(8),
});

router.post("/users", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = CreateUserSchema.parse(req.body);
    const user = await createUser(input);
    res.status(201).json({ data: user });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid input",
          details: error.errors,
        },
      });
      return;
    }
    next(error);
  }
});

export default router;
```

## Implementation — FastAPI (Python)

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr

app = FastAPI()

class CreateUserRequest(BaseModel):
    name: str
    email: EmailStr
    password: str  # min_length=8 via Field()

class UserResponse(BaseModel):
    id: int
    name: str
    email: str

@app.post("/users", response_model=dict, status_code=201)
async def create_user(request: CreateUserRequest):
    user = await save_user(request)
    return {"data": UserResponse.model_validate(user)}

@app.get("/users")
async def list_users(page: int = 1, limit: int = 20):
    users, total = await get_users(page=page, limit=min(limit, 100))
    return {"data": users, "meta": {"page": page, "limit": limit, "total": total}}
```

## Testing

Test endpoint behavior, not implementation details:

```typescript
import { describe, it, expect } from "vitest";

describe("POST /api/users", () => {
  it("creates user with valid input", async () => {
    const res = await fetch("/api/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: "Alice",
        email: "alice@example.com",
        password: "secure123",
      }),
    });
    expect(res.status).toBe(201);
    const { data } = await res.json();
    expect(data.name).toBe("Alice");
    expect(data.email).toBe("alice@example.com");
    expect(data).not.toHaveProperty("password");
  });

  it("rejects invalid email", async () => {
    const res = await fetch("/api/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Bob", email: "not-email", password: "secure123" }),
    });
    expect(res.status).toBe(400);
    const { error } = await res.json();
    expect(error.code).toBe("VALIDATION_ERROR");
  });

  it("rejects short password", async () => {
    const res = await fetch("/api/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Carol", email: "c@e.com", password: "short" }),
    });
    expect(res.status).toBe(400);
  });
});
```

## Security Checklist

| Check | Details |
|-------|---------|
| Input validation | Use Zod/Pydantic at boundary |
| Output sanitization | Never return raw DB objects |
| Rate limiting | Required for auth/write endpoints |
| Auth middleware | Protect non-public endpoints |
| CORS | Only allow known origins |
| Error responses | No stack traces exposed |
| Passwords | Hash with bcrypt/argon2, never plain |
| SQL | Always parameterized, never interpolated |
