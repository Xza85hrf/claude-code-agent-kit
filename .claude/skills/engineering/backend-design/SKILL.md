---
name: backend-design
description: Backend services, error handling, middleware, caching, logging, observability. Use when building APIs, designing middleware, or adding logging.
argument-hint: "Design the error handling middleware with structured logging and correlation IDs"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references:
  - references/error-handling-patterns.md
  - references/observability-patterns.md
  - references/rag-endpoint.md
thinking-level: high
---

# Backend Design

Pipeline: **receive → validate → authorize → process → persist → respond.** Every stage needs error handling, logging, and can fail. Happy path = prototype. Graceful failure = production.

**Related:** Use `solid` for code quality, `security-review` for auth/sanitization/secrets, `system-architecture` for multi-service design.

## When to Use

API endpoints, error handling, middleware, caching, logging, background jobs, performance optimization, webhooks, event handlers.

## 1. Request Pipeline Pattern

Every request flows through a predictable pipeline. Order matters.

```
Request arrives
    │
    ├── 1. Request logging (correlation ID, method, path, timestamp)
    ├── 2. Rate limiting (per IP, per user, per API key)
    ├── 3. Authentication (who are you? → 401 if invalid)
    ├── 4. Authorization (can you do this? → 403 if no)
    ├── 5. Input validation (is the data valid? → 400 if no)
    ├── 6. Route handler (business logic)
    ├── 7. Response serialization
    ├── 8. Response logging (status, duration, response size)
    └── 9. Error handler (catches anything uncaught → 500)
```

**Critical:** Logging wraps everything. Auth before validation. Error handler last, catches all.

## 2. Error Handling Strategy

### Error Classification

| Type | Example | Handle How | Log Level |
|------|---------|-----------|-----------|
| **Validation** | Missing field, wrong format | 400 + specific message | WARN |
| **Authentication** | Expired token, bad credentials | 401 + generic message | WARN |
| **Authorization** | Insufficient permissions | 403 + generic message | WARN |
| **Not Found** | Resource doesn't exist | 404 + specific message | INFO |
| **Conflict** | Duplicate entry, version conflict | 409 + specific message | WARN |
| **Operational** | DB timeout, service unavailable | 503 + retry guidance | ERROR |
| **Programming** | Null reference, type error | 500 + generic message | ERROR + alert |

### Error Response Format (RFC 7807)

```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation Error",
  "status": 400,
  "detail": "The 'email' field must be a valid email address",
  "instance": "/users/signup",
  "errors": [
    { "field": "email", "message": "Invalid email format" }
  ]
}
```

### Rules

```
NEVER:
├── Swallow errors silently (catch + ignore)
├── Expose stack traces to clients
├── Return generic "Something went wrong" without logging details
├── Use HTTP 200 for errors (REST anti-pattern)
├── Throw strings instead of typed errors
└── Catch broadly without re-throwing unknown errors

ALWAYS:
├── Create typed error hierarchy (AppError → ValidationError, NotFoundError, etc.)
├── Include correlation ID in error responses
├── Log full error details server-side, return safe message client-side
├── Use consistent error format across all endpoints (RFC 7807)
├── Distinguish between "retry will help" (503) and "don't retry" (400)
└── Add context as errors propagate up the stack
```

> **See:** `references/error-handling-patterns.md` for typed error hierarchies, retry strategies, graceful degradation, and validation patterns.

## 3. Middleware Patterns

| Middleware | Purpose | Order |
|-----------|---------|-------|
| **Request ID** | Generate/extract correlation ID | First |
| **Request logging** | Log method, path, start time | Early |
| **Rate limiting** | Throttle by IP/user/key | Before auth |
| **Authentication** | Validate token/session → set user | Before authorization |
| **Authorization** | Check permissions for route/resource | After auth |
| **Body parsing** | Parse JSON/form/multipart | Before validation |
| **Validation** | Validate request body/params/query | Before handler |
| **Compression** | gzip/brotli response | Late |
| **CORS** | Cross-origin headers | Early (preflight) |
| **Response logging** | Log status, duration | Late |
| **Error handler** | Catch all, format error response | Last |

**Each middleware does ONE thing.** If auth also validates, split it.

## 4. Caching Strategy

```
"Should I cache this?"
    │
    ├── Rarely changes + expensive to compute → Aggressive cache
    │   (config, feature flags, reference data → TTL: minutes-hours)
    │
    ├── User-specific + changes occasionally → Short TTL
    │   (user profile, preferences → TTL: 30-300 seconds)
    │
    ├── Expensive query + tolerates staleness → Cache-aside
    │   (reports, aggregations → TTL: minutes + background refresh)
    │
    ├── Consistency-critical → Cache-aside with explicit invalidation
    │   (inventory, pricing → invalidate on write)
    │
    └── Changes every request → Don't cache
        (real-time data, nonces, OTP)

CACHE LAYERS:
├── In-process (Map/LRU) — Fastest, per-instance, lost on restart
├── Distributed (Redis/Memcached) — Shared, survives restarts
├── CDN — Edge caching for static + semi-static content
└── HTTP caching — Cache-Control, ETag, Last-Modified headers

PROTECTION:
├── Stampede: Mutex/lock on cache miss (one rebuilder, others wait)
├── Thundering herd: Stagger TTLs with jitter
├── Cold start: Warm cache on deployment
└── Invalidation: Prefer TTL over explicit invalidation when possible
```

## 5. Logging & Observability

### Structured Logging

```
EVERY log entry must include:
├── timestamp (ISO 8601)
├── level (ERROR, WARN, INFO, DEBUG)
├── correlationId (request-scoped, propagated across services)
├── service (service name)
├── message (human-readable)
└── context (structured key-value data)

LOG LEVELS:
├── ERROR — Something failed, needs attention (alerts trigger)
├── WARN  — Something unexpected, system handled it (review regularly)
├── INFO  — Normal operations worth recording (request lifecycle)
└── DEBUG — Detailed diagnostics (off in production by default)

NEVER LOG:
├── Passwords, tokens, API keys, secrets
├── Full credit card numbers, SSNs, PII
├── Request/response bodies with sensitive data
├── Health check requests (noise)
└── Expected 404s from crawlers
```

### RED Metrics (per endpoint)

| Metric | What | Alert When |
|--------|------|------------|
| **Rate** | Requests per second | Sudden drop (outage?) or spike (attack?) |
| **Errors** | Error rate (%) | >1% for 5xx, >5% for 4xx |
| **Duration** | p50, p95, p99 latency | p95 >500ms (or SLO threshold) |

### Health Endpoints

```
GET /health (liveness)  → 200 if process is alive (k8s restarts if fails)
GET /ready  (readiness) → 200 if can serve traffic (DB connected, deps healthy)
```

> **See:** `references/observability-patterns.md` for structured logging setup, correlation ID implementation, OpenTelemetry, metrics, alerting strategies, and dashboard design.

## 6. Performance Patterns

```
MEASURE FIRST (never optimize without profiling):
├── APM tool (Datadog, New Relic, or OpenTelemetry)
├── Database: EXPLAIN ANALYZE on slow queries
├── Flame graphs for CPU-bound bottlenecks
├── Memory profiling for leak detection
└── Load testing (k6, Artillery) for capacity planning

COMMON FIXES:
├── N+1 queries → Batch loading / DataLoader / JOIN / eager loading
├── Slow queries → Add indexes (but measure — indexes slow writes)
├── Large payloads → Pagination, field selection, compression
├── Blocking I/O → Async/await, connection pooling
├── CPU-bound in request → Move to background job
├── Too many DB connections → Connection pooling (PgBouncer, pool size limits)
├── Repeated computation → Cache (see Section 4)
└── Large file processing → Streaming (don't load into memory)
```

**Connection pooling:** size = CPUs × 2 + 1. Set connection/idle timeouts. Monitor exhaustion.

## 7. Background Job Patterns

### When to Use Background Jobs

```
USE BACKGROUND JOBS FOR:
├── Email/notification sending
├── Report generation
├── Data import/export
├── Image/file processing
├── Scheduled tasks (cron)
├── Event-driven reactions (order placed → update inventory)
├── Cleanup tasks (expired tokens, old logs)
└── Any work >500ms that doesn't need synchronous response
```

### Requirements for Every Background Job

```
EVERY background job must be:
├── Idempotent — Safe to run twice with same input
├── Retryable — Exponential backoff, max retries, then dead-letter
├── Observable — Logged start/end/error, metrics on queue depth
├── Timeout-bounded — Max execution time, killed if exceeded
└── Independent — No assumptions about order of execution
```

### Patterns

| Pattern | Use When | Example |
|---------|----------|---------|
| **Queue** (Redis, SQS, RabbitMQ) | Reliable async processing | Send email, process payment |
| **Cron** (node-cron, celery beat) | Scheduled recurring tasks | Daily reports, cleanup |
| **Event-driven** (pub/sub) | React to domain events | Order created → send confirmation |
| **Batch** | Process large datasets | Nightly data sync, bulk import |

## 8. MUST DO / MUST NOT DO

**MUST DO:**
Typed error hierarchy (RFC 7807), correlation IDs, timeouts on all external calls, input validation, connection pooling, idempotent/retryable jobs, structured JSON logging, health/readiness endpoints, backward-compatible migrations, profile before optimizing.

**MUST NOT DO:**
Swallow exceptions, expose internal errors, block event loop, disk persistence (breaks scaling), console.log, route-level error handling, unbounded queries, client-side validation alone, no health checks, ignore slow queries.

## 9. Reference Files

| File | Content | Load When |
|------|---------|-----------|
| `references/error-handling-patterns.md` | Typed error hierarchies, RFC 7807 examples, retry strategies, graceful degradation, validation patterns, transaction patterns | Designing error handling or recovery strategies |
| `references/observability-patterns.md` | Structured logging setup, correlation IDs, metrics (RED/USE), OpenTelemetry, alerting strategy, dashboard design | Setting up logging, monitoring, or alerting |

## Red Flags

STOP if seeing: Empty catch blocks, no input validation, N+1 queries, unbounded queries, sync calls without timeout, jobs without retry, sensitive data logging, health endpoint doing work, hard-coded config, no correlation ID propagation.

## Tools & Skills

**Tools:** context7 (framework docs), mcp-cli.sh ollama chat (CRUD generation), mcp-cli.sh deepseek chat (error/caching strategies)

**Integration:** solid (SRP), security-review (input/auth/secrets), system-architecture (boundaries), frontend-engineering (API contracts), test-driven-development (middleware tests)
