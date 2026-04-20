---
name: system-architecture
description: Distributed systems, microservices, API design, database design, scalability. Use when designing multi-service systems or data models.
argument-hint: "Design the database schema for a multi-tenant SaaS with row-level security"
allowed-tools: Read, Grep, Glob
model: opus
effort: high
context: fork
agent: Plan
department: architecture

references: []
thinking-level: high
---

# System Architecture

Network boundary = failure boundary. Service boundary = team boundary.

**Use `solid` for single-service.** Use THIS when crossing process boundaries (multiple services, APIs, DBs, queues, caches).

**Principle:** "Don't distribute. If you must, start monolith, extract when forced."

## When to Use
- Multi-service systems
- Communication patterns (sync/async/event)
- API design (REST, GraphQL, gRPC)
- Database schema decisions
- Scale/resilience planning
- Service boundaries
- Architecture Decision Records

## 1. Service Boundary Decision Tree

```
"Should this be a separate service?"
    │
    ├── Does it need independent deployment? ──────── Yes → Candidate
    ├── Does it scale differently from the rest? ──── Yes → Candidate
    ├── Does a different team own it? ─────────────── Yes → Candidate
    ├── Does it have its own data store? ──────────── Yes → Strong candidate
    │
    └── None of the above? → KEEP IT IN THE MONOLITH
        │
        └── "But microservices are modern!"
            └── No. Microservices are a solution to organizational scaling,
                not a default architecture. Monoliths are fine.
```

**Data coupling test:** Services needing each other's data = one service. Merge them.

**Bounded context check:** Single business capability per service. Can't name in 3 words = boundary wrong.

## 2. Communication Patterns Router

| Pattern | When | Tradeoff |
|---------|------|----------|
| **Sync REST/gRPC** | Request needs immediate response, simple CRUD | Tight coupling, cascading failures |
| **Async message queue** | Work can be deferred, needs guaranteed delivery | Eventual consistency, harder debugging |
| **Event/pub-sub** | Multiple consumers, decoupled reactions | Event schema evolution, ordering challenges |
| **Saga (orchestration)** | Multi-service transaction, central control | Orchestrator is single point of failure |
| **Saga (choreography)** | Multi-service transaction, loose coupling | Hard to track, distributed debugging |
| **Request-reply (async)** | Need response but can wait, load leveling | Complexity of correlation IDs |

**Default:** Start sync. Move to async only with evidence:
- Timeout cascades under load
- Work doesn't need immediate completion
- Multiple services react to same event

## 3. API Design Checklist

### REST (default for most APIs)

```
RESOURCE DESIGN:
├── Resources are NOUNS, not verbs (/users, not /getUsers)
├── Use plural nouns (/users/123, not /user/123)
├── Nest for ownership (/users/123/orders)
├── Max 2 levels of nesting (deeper = separate resource)
└── Actions on resources: POST /orders/123/cancel (exceptional)

HTTP METHODS:
├── GET    - Read (idempotent, cacheable)
├── POST   - Create (not idempotent)
├── PUT    - Full replace (idempotent)
├── PATCH  - Partial update (idempotent)
└── DELETE - Remove (idempotent)

RESPONSES:
├── 200 OK (with body), 201 Created (with Location header)
├── 204 No Content (successful DELETE/PUT)
├── 400 Bad Request (validation errors)
├── 401 Unauthorized (no/invalid auth)
├── 403 Forbidden (valid auth, insufficient permissions)
├── 404 Not Found, 409 Conflict, 422 Unprocessable
├── 429 Too Many Requests (with Retry-After header)
└── 500 Internal Server Error (NEVER expose stack traces)

PAGINATION: cursor-based for large/changing datasets, offset for small/static
VERSIONING: URL path (/v1/users) or Accept header — pick one, be consistent
ERRORS: RFC 7807 Problem Details format (type, title, status, detail, instance)
```

### REST vs GraphQL vs gRPC

| Factor | REST | GraphQL | gRPC |
|--------|------|---------|------|
| Best for | Simple CRUD, public APIs | Complex queries, frontend flexibility | Internal service-to-service |
| Learning curve | Low | Medium | High |
| Caching | HTTP caching built-in | Complex (persisted queries) | Manual |
| Type safety | OpenAPI/Swagger | Schema-first | Protobuf (strong) |
| Over/under-fetching | Common problem | Solved | N/A |
| Streaming | SSE, WebSocket | Subscriptions | Bidirectional built-in |

## 4. Database Design Patterns

| Pattern | When | Tradeoff |
|---------|------|----------|
| **DB per service** | True service independence | Cross-service queries impossible |
| **Shared DB** | Small team, strong consistency needed | Tight coupling, migration coordination |
| **Read replicas** | Read-heavy workloads | Replication lag, eventual consistency |
| **CQRS** | Very different read/write patterns | Complexity, eventual consistency |
| **Event sourcing** | Full audit trail, temporal queries | Storage growth, rebuild time |

**Migrations:** Always backward-compatible. Expand-then-contract:
1. Expand: Add new column/table (nullable or default)
2. Migrate: Backfill, write both old+new
3. Contract: Remove old after consumers updated

**References:** database-design.md (schema, indexing, SQL, NoSQL, caching)

## 5. Resilience Patterns

```
DESIGN FOR FAILURE (everything fails eventually):
├── Circuit breaker — Stop calling failing services (closed→open→half-open)
├── Retry with backoff — Exponential backoff + jitter (never fixed intervals)
├── Bulkhead — Isolate failure domains (separate thread/connection pools)
├── Timeout — Every external call needs a timeout (no exceptions)
├── Fallback — Degrade gracefully (cached data, default response, feature flag)
├── Health checks — Liveness (process alive) vs readiness (can serve traffic)
└── Idempotency — Every operation safe to retry (idempotency keys for writes)
```

**Circuit breaker states:**
- **Closed** (normal): requests pass through, failures counted
- **Open** (tripped): requests fail immediately, no calls to downstream
- **Half-open** (testing): limited requests pass through to test recovery

## 6. Scalability Checklist

```
BEFORE scaling horizontally, verify:
├── Services are stateless (no local session/file storage)
├── Sessions stored externally (Redis, DB, JWT)
├── File uploads go to object storage (S3, GCS), not local disk
├── Background jobs use distributed queue, not in-process
├── Caches are shared (Redis) or tolerate inconsistency
└── Database connections are pooled with limits

CACHE STRATEGY:
├── Static assets → CDN (aggressive TTL)
├── Rarely-changing data → Application cache (long TTL)
├── User-specific data → Short TTL or cache-aside
├── Expensive computations → Background refresh
└── Consistency-critical → Cache-aside with invalidation

OBSERVABILITY:
├── Distributed tracing (OpenTelemetry) across service boundaries
├── Centralized logging with correlation IDs
├── RED metrics per service (Rate, Errors, Duration)
├── Alerting on SLOs, not individual metrics
└── Dependency health dashboards
```

## 7. ADR Template (store in docs/decisions.md)

```markdown
## ADR-XXX: [Title]
- **Date:** YYYY-MM-DD
- **Status:** Proposed | Accepted | Deprecated
- **Context:** What problem?
- **Options:** Option A (pros/cons), Option B (pros/cons)
- **Decision:** What & why
- **Consequences:** What's easier? What's harder?
```

**Write for:** Service boundaries, DB choices, communication patterns, frameworks, security, caching

## 8. MUST DO / MUST NOT DO

```
MUST DO:
├── Start with a monolith unless you have proven scaling needs
├── Define API contracts before implementing (schema-first)
├── Version all APIs from day one
├── Make every operation idempotent (or document why not)
├── Set timeouts on ALL external calls
├── Use correlation IDs across all service boundaries
├── Test failure modes (chaos engineering, fault injection)
├── Document service dependencies and ownership
└── Use backward-compatible database migrations ONLY

MUST NOT DO:
├── Distribute prematurely ("but Netflix does it!")
├── Share databases between services without explicit decision
├── Use synchronous calls for fire-and-forget operations
├── Build distributed transactions (use sagas instead)
├── Ignore network partitions (they WILL happen)
├── Deploy without health checks and readiness probes
├── Design APIs around your database schema
└── Assume zero latency between services
```

## 9. Reference Files

| File | Content |
|------|---------|
| `distributed-patterns.md` | Saga, CQRS, event-driven, API gateway, mesh, consistency (outbox, CDC), migration |
| `database-design.md` | Schema, normalization, indexing, SQL, NoSQL, migrations, caching |

## Red Flags

```
STOP and reconsider if you see:
├── Two services that always deploy together → merge them
├── Distributed transaction across 3+ services → redesign boundaries
├── Service A calls B calls C calls A → circular dependency
├── Every request fans out to 5+ services → API gateway or BFF
├── Shared database with no ownership rules → ticking time bomb
├── No circuit breakers on external calls → cascading failure risk
├── Synchronous chain deeper than 3 services → latency multiplier
├── Microservices with a single developer → organizational mismatch
└── "We need Kubernetes" for 3 services → over-engineering
```

## Integration

- **solid:** SRP/DIP at service level
- **security-review:** Auth between services (mTLS, API keys), rate limiting, validation
- **backend-design:** Service patterns, error handling, observability
- **frontend-engineering:** API contracts, BFF, optimistic updates
