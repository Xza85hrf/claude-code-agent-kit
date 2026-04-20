# Database Design Reference

> Load this file when making database schema decisions, optimizing queries, choosing between SQL/NoSQL, planning migrations, or implementing caching strategies.

## Schema Design

### Normalization Levels (When to Stop)

| Level | What It Eliminates | Stop Here When |
|-------|-------------------|----------------|
| **1NF** | Repeating groups, multi-value columns | Never — always do at least 1NF |
| **2NF** | Partial dependencies on composite keys | Most apps should reach 2NF |
| **3NF** | Transitive dependencies | Default target for OLTP |
| **BCNF** | Remaining anomalies | Complex domains with overlapping keys |
| **Denormalized** | Nothing (adds redundancy) | Read performance justifies maintenance cost |

**When to denormalize:**
- Read-heavy queries that join 4+ tables regularly
- Reports/dashboards that need pre-computed aggregates
- Data that changes rarely but is read frequently
- After profiling proves the join is the bottleneck (not before)

### Constraints (Use Them Aggressively)

```sql
CREATE TABLE orders (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  status      VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
  total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
  item_count  INTEGER NOT NULL CHECK (item_count > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_dates CHECK (updated_at >= created_at)
);

-- Partial unique index (no duplicate pending orders per user)
CREATE UNIQUE INDEX idx_one_pending_per_user
  ON orders(user_id) WHERE status = 'pending';
```

**Rules:**
- Every foreign key gets an index (prevents slow deletes/joins)
- Use `NOT NULL` by default, nullable by exception
- Use `CHECK` constraints for business rules the DB can enforce
- Use partial indexes for conditional uniqueness

### Indexing Strategy

```
INDEX WHEN:
├── Column appears in WHERE clauses frequently
├── Column appears in JOIN conditions
├── Column is used for ORDER BY on large tables
├── Column has high cardinality (many distinct values)
└── Query EXPLAIN shows sequential scan on large table

DO NOT INDEX WHEN:
├── Table has <1000 rows (full scan is fine)
├── Column has low cardinality (boolean, status with 3 values)
├── Table is write-heavy and reads are rare
├── Index would duplicate the primary key
└── You haven't measured the query performance first
```

**Index types:**
| Type | Use Case | Example |
|------|----------|---------|
| B-tree (default) | Equality, range, sorting | `WHERE age > 30`, `ORDER BY name` |
| Hash | Equality only (faster than B-tree) | `WHERE email = 'x@y.com'` |
| GIN | Full-text, JSONB, arrays | `WHERE tags @> '{"urgent"}'` |
| GiST | Geometric, range types | `WHERE location <-> point(x,y)` |
| Partial | Conditional queries | `WHERE status = 'active'` (index only active rows) |
| Covering | Queries answered by index alone | `INCLUDE (name, email)` — no table lookup |

**Composite index ordering:** Put the most selective column first, equality before range.
```sql
-- Good: equality on status, range on created_at
CREATE INDEX idx_orders_status_date ON orders(status, created_at);

-- This index also serves: WHERE status = 'pending' (prefix match)
-- But NOT: WHERE created_at > '2024-01-01' (not a prefix)
```

## SQL Patterns

### Solving N+1

```sql
-- PROBLEM: N+1 queries
SELECT * FROM orders WHERE user_id = 1;
-- Then for EACH order:
SELECT * FROM order_items WHERE order_id = ?;  -- N queries!

-- SOLUTION 1: JOIN
SELECT o.*, oi.*
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.user_id = 1;

-- SOLUTION 2: Subquery with IN
SELECT * FROM order_items
WHERE order_id IN (SELECT id FROM orders WHERE user_id = 1);

-- SOLUTION 3: Lateral join (top-N per group)
SELECT o.*, li.*
FROM orders o
CROSS JOIN LATERAL (
  SELECT * FROM order_items WHERE order_id = o.id
  ORDER BY created_at DESC LIMIT 3
) li
WHERE o.user_id = 1;
```

### Window Functions

```sql
-- Running total
SELECT date, amount,
  SUM(amount) OVER (ORDER BY date) as running_total
FROM transactions;

-- Rank within groups
SELECT name, department, salary,
  RANK() OVER (PARTITION BY department ORDER BY salary DESC) as dept_rank
FROM employees;

-- Moving average (last 7 entries)
SELECT date, value,
  AVG(value) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as moving_avg
FROM metrics;

-- Previous/next row values
SELECT date, revenue,
  LAG(revenue) OVER (ORDER BY date) as prev_day,
  revenue - LAG(revenue) OVER (ORDER BY date) as daily_change
FROM daily_revenue;
```

### CTEs (Common Table Expressions)

```sql
-- Readable multi-step queries
WITH active_users AS (
  SELECT id, name FROM users WHERE status = 'active'
),
user_orders AS (
  SELECT u.id, u.name, COUNT(o.id) as order_count, SUM(o.total) as total_spent
  FROM active_users u
  JOIN orders o ON o.user_id = u.id
  WHERE o.created_at > NOW() - INTERVAL '30 days'
  GROUP BY u.id, u.name
)
SELECT * FROM user_orders WHERE order_count > 5 ORDER BY total_spent DESC;

-- Recursive CTE (org chart, category tree)
WITH RECURSIVE org_tree AS (
  SELECT id, name, manager_id, 0 as depth
  FROM employees WHERE manager_id IS NULL

  UNION ALL

  SELECT e.id, e.name, e.manager_id, t.depth + 1
  FROM employees e
  JOIN org_tree t ON e.manager_id = t.id
)
SELECT * FROM org_tree ORDER BY depth, name;
```

### Transaction Isolation Levels

| Level | Dirty Read | Non-repeatable Read | Phantom Read | Use When |
|-------|-----------|-------------------|--------------|----------|
| **Read Uncommitted** | Yes | Yes | Yes | Never in production |
| **Read Committed** | No | Yes | Yes | Default for most DBs |
| **Repeatable Read** | No | No | Yes | Financial calculations |
| **Serializable** | No | No | No | Critical consistency (rare) |

**Default:** Read Committed. Only escalate when you have evidence of consistency issues.

## NoSQL Decision Guide

| Type | Best For | Examples | NOT For |
|------|----------|---------|---------|
| **Document** | Flexible schemas, nested data, rapid iteration | MongoDB, Firestore, CouchDB | Complex joins, transactions |
| **Key-Value** | Session storage, caching, simple lookups | Redis, DynamoDB, Memcached | Complex queries, relationships |
| **Column-family** | Time-series, analytics, write-heavy | Cassandra, ScyllaDB, HBase | Ad-hoc queries, small datasets |
| **Graph** | Relationships ARE the data (social, recommendations) | Neo4j, Neptune, ArangoDB | Simple CRUD, bulk analytics |
| **Search** | Full-text search, log analytics | Elasticsearch, OpenSearch | Primary data store, transactions |

**Decision tree:**
```
Need transactions + complex queries? → SQL (PostgreSQL)
Need flexible schema + document storage? → Document DB
Need blazing fast key lookups + caching? → Key-Value
Need to model relationships as first-class? → Graph DB
Need full-text search? → Search engine (+ SQL as primary)
Need time-series at scale? → Column-family or TimescaleDB
```

## Migration Strategies

### Zero-Downtime Migrations

**Rule:** Never take an exclusive lock on a large table during peak hours.

```
SAFE migration sequence (expand-contract):

1. EXPAND: Add new column (nullable or with default)
   ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT false;
   -- Instant in PostgreSQL 11+ (no table rewrite)

2. BACKFILL: Populate new column in batches
   UPDATE users SET email_verified = true
   WHERE id IN (SELECT id FROM users WHERE email_verified IS NULL LIMIT 1000);

3. MIGRATE CODE: Update application to write to BOTH columns

4. CONTRACT: Drop old column (after all consumers updated)
   ALTER TABLE users DROP COLUMN old_email_status;
```

### Dangerous Operations (Avoid in Production)

```
NEVER on large tables in production:
├── ALTER TABLE ... ADD COLUMN ... NOT NULL (without default) — rewrites entire table
├── CREATE INDEX ... (without CONCURRENTLY) — locks table for writes
├── ALTER TABLE ... ALTER COLUMN TYPE ... — rewrites entire table
├── LOCK TABLE ... — blocks all access
└── DROP COLUMN on high-traffic table — can be slow

SAFE alternatives:
├── ADD COLUMN with DEFAULT → instant in PostgreSQL 11+
├── CREATE INDEX CONCURRENTLY → no write lock
├── New column + backfill + drop old → zero-downtime type change
├── Advisory locks → application-level locking
└── Schedule during low traffic → if no safe alternative exists
```

## Caching Patterns

### Cache-Aside (Lazy Loading)

```
Read:
1. Check cache → hit → return
2. Cache miss → query DB → store in cache → return

Write:
1. Write to DB
2. Invalidate cache (don't update — race condition risk)
```

```typescript
async function getUser(userId: string): Promise<User> {
  const cached = await cache.get(`user:${userId}`);
  if (cached) return JSON.parse(cached);

  const user = await db.users.findById(userId);
  await cache.set(`user:${userId}`, JSON.stringify(user), { EX: 300 });
  return user;
}

async function updateUser(userId: string, data: Partial<User>): Promise<User> {
  const user = await db.users.update(userId, data);
  await cache.del(`user:${userId}`);  // Invalidate, don't update
  return user;
}
```

### Write-Through

```
Write: cache first → cache writes to DB synchronously → return
Read: always from cache (data is always present)
```

**Use for:** Data read far more often than written (config, feature flags).

### Write-Behind (Write-Back)

```
Write: cache first → return immediately → cache flushes to DB asynchronously
```

**Use for:** High write throughput where slight lag is acceptable.
**Risk:** Data loss if cache crashes before flushing to DB.

### Stampede Protection

When a popular cache key expires, many requests hit the DB simultaneously.

```typescript
async function getWithLock(key: string, fetcher: () => Promise<any>, ttl: number) {
  const cached = await cache.get(key);
  if (cached) return JSON.parse(cached);

  const lockKey = `lock:${key}`;
  const locked = await cache.set(lockKey, '1', { NX: true, EX: 10 });

  if (locked) {
    const data = await fetcher();
    await cache.set(key, JSON.stringify(data), { EX: ttl });
    await cache.del(lockKey);
    return data;
  } else {
    await sleep(100);
    return getWithLock(key, fetcher, ttl);
  }
}
```

### TTL Strategy

| Data Type | TTL | Rationale |
|-----------|-----|-----------|
| Static reference data | 1-24 hours | Rarely changes |
| User profiles | 5-15 minutes | Changes occasionally |
| Session data | Match session timeout | Security requirement |
| Search results | 1-5 minutes | Freshness matters |
| Feature flags | 30-60 seconds | Need quick rollback |
| API rate limit counters | Window size | Must be accurate |
| Computed aggregates | Depends on SLA | Background refresh |

**Add jitter:** `TTL = base_ttl + random(0, base_ttl * 0.1)` — prevents synchronized expiration.
