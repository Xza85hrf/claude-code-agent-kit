# Distributed Patterns Reference

> Load this file when designing complex distributed interactions: sagas, CQRS, event-driven systems, API gateways, or service migration strategies.

## Saga Patterns

### Choreography (event-driven, decoupled)

Each service publishes events and reacts to others. No central coordinator.

```
Order Service              Payment Service           Inventory Service
     │                           │                         │
     ├── OrderCreated ──────────►│                         │
     │                           ├── PaymentProcessed ────►│
     │                           │                         ├── InventoryReserved
     │                           │                         │
     │◄── OrderConfirmed ────────┼─────────────────────────┤
```

**Compensation (rollback):**
```
If InventoryReserved fails:
  Inventory Service publishes → ReservationFailed
  Payment Service reacts     → RefundPayment
  Order Service reacts       → CancelOrder
```

**When to use:** Few services (2-4), simple flow, teams prefer independence.
**Watch out for:** Hard to track end-to-end flow, no single place to see status, cyclic event dependencies.

### Orchestration (centralized coordinator)

A saga orchestrator tells each service what to do and handles compensations.

```
                    Saga Orchestrator
                          │
           ┌──────────────┼──────────────┐
           │              │              │
           ▼              ▼              ▼
    1. Create Order  2. Process Pay  3. Reserve Stock
           │              │              │
           │    failure?   │              │
           │◄──────────────┤              │
           │                              │
           ├──── Compensate: Cancel ──────┤
```

```typescript
class OrderSaga {
  async execute(order: Order): Promise<SagaResult> {
    const steps: SagaStep[] = [
      {
        action: () => this.orderService.create(order),
        compensate: (result) => this.orderService.cancel(result.orderId),
      },
      {
        action: (prev) => this.paymentService.charge(prev.orderId, order.amount),
        compensate: (result) => this.paymentService.refund(result.paymentId),
      },
      {
        action: (prev) => this.inventoryService.reserve(order.items),
        compensate: (result) => this.inventoryService.release(result.reservationId),
      },
    ];

    const completed: SagaStepResult[] = [];
    for (const step of steps) {
      try {
        const result = await step.action(completed.at(-1)?.result);
        completed.push({ step, result });
      } catch (error) {
        // Compensate in reverse order
        for (const done of completed.reverse()) {
          await done.step.compensate(done.result);
        }
        throw new SagaFailedError(error, completed);
      }
    }
    return { status: 'completed', steps: completed };
  }
}
```

**When to use:** Complex flows (5+ steps), need visibility, central error handling.
**Watch out for:** Orchestrator is a single point of failure, can become a god service.

## CQRS (Command Query Responsibility Segregation)

Separate the write model (commands) from the read model (queries). Different data shapes optimized for each.

```
Write Side (Commands)              Read Side (Queries)
┌──────────────────┐              ┌──────────────────┐
│  Command Handler │              │   Query Handler   │
│  ┌────────────┐  │    Events    │  ┌────────────┐  │
│  │ Domain     │──┼──────────────┼─►│ Read Model │  │
│  │ Model      │  │              │  │ (denorm.)  │  │
│  └────────────┘  │              │  └────────────┘  │
│  Write DB        │              │  Read DB          │
│  (normalized)    │              │  (optimized views)│
└──────────────────┘              └──────────────────┘
```

**When to use:**
- Read and write patterns are very different (few writes, many complex reads)
- Need different scaling for reads vs writes
- Read model needs denormalized views for performance

**When NOT to use:**
- Simple CRUD (most apps!)
- Team < 5 developers (complexity not justified)
- Strong consistency required everywhere

**Eventual consistency tradeoff:** Read model lags behind write model by milliseconds to seconds. Mitigations:
- After write, read from write DB for the user who wrote (read-your-own-writes)
- Show optimistic UI updates
- Display "updating..." indicators on eventually-consistent views

## Event-Driven Architecture

### Domain Events vs Integration Events

| Aspect | Domain Events | Integration Events |
|--------|--------------|-------------------|
| Scope | Within a bounded context | Between services |
| Schema | Can change freely | Must be versioned |
| Transport | In-process or local queue | Message broker |
| Coupling | Low (same team) | Must be minimal |
| Example | `OrderItemAdded` | `OrderPlaced` |

### Event Schema Evolution

```json
// v1: Original event
{ "type": "OrderPlaced", "version": 1, "orderId": "123", "total": 50.00 }

// v2: Added field (backward compatible - consumers ignore unknown fields)
{ "type": "OrderPlaced", "version": 2, "orderId": "123", "total": 50.00, "currency": "USD" }

// v3: BREAKING - renamed field (requires new event type or version routing)
{ "type": "OrderPlacedV3", "version": 3, "orderId": "123", "amount": { "value": 50.00, "currency": "USD" } }
```

**Rules:**
- Add fields freely (backward compatible)
- Never remove or rename fields without versioning
- Use a schema registry for enforcement (Avro, Protobuf, JSON Schema)
- Consumers must tolerate unknown fields

### Idempotent Consumers

Every event consumer MUST be idempotent — processing the same event twice produces the same result.

```typescript
async function handleOrderPlaced(event: OrderPlacedEvent) {
  // Check if already processed (idempotency key)
  const existing = await db.processedEvents.findById(event.eventId);
  if (existing) {
    logger.info('Event already processed', { eventId: event.eventId });
    return;
  }

  await db.transaction(async (tx) => {
    await tx.inventory.reserve(event.items);
    await tx.processedEvents.insert({ eventId: event.eventId, processedAt: new Date() });
  });
}
```

## API Gateway Patterns

```
Clients                    API Gateway                 Services
┌──────┐                ┌──────────────┐           ┌──────────┐
│Mobile├───────────────►│              │──────────►│  Users   │
└──────┘                │  - Routing   │           └──────────┘
┌──────┐                │  - Auth      │           ┌──────────┐
│ Web  ├───────────────►│  - Rate Limit│──────────►│  Orders  │
└──────┘                │  - TLS Term  │           └──────────┘
┌──────┐                │  - Logging   │           ┌──────────┐
│ 3rd  ├───────────────►│  - Caching   │──────────►│ Payments │
│Party │                │  - Aggregate │           └──────────┘
└──────┘                └──────────────┘
```

**Gateway responsibilities:**
- **Routing** — Map external URLs to internal services
- **Authentication** — Validate tokens, set user context
- **Rate limiting** — Per client, per endpoint
- **Request aggregation** — Combine multiple service calls (BFF pattern)
- **Protocol translation** — REST externally, gRPC internally
- **Caching** — Cache static/semi-static responses
- **Circuit breaking** — Protect downstream services

**BFF (Backend for Frontend):**
- One gateway per client type (mobile BFF, web BFF)
- Each shapes the API for its client's needs
- Avoids one-size-fits-all API that serves no one well

## Data Consistency Patterns

### Outbox Pattern

Ensures events are published reliably even if the message broker is down.

```
1. Begin transaction
2. Write to business table (orders)
3. Write to outbox table (pending events)
4. Commit transaction

Separate process:
5. Poll outbox table for unpublished events
6. Publish to message broker
7. Mark as published in outbox table
```

```sql
CREATE TABLE outbox (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type  VARCHAR(255) NOT NULL,
  payload     JSONB NOT NULL,
  created_at  TIMESTAMP DEFAULT NOW(),
  published   BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMP
);
```

### Change Data Capture (CDC)

Database changes automatically become events. No application code changes needed.

```
Database (write) ──► CDC Tool (Debezium) ──► Message Broker ──► Consumers
```

**When to use:** Legacy systems that can't be modified, need to replicate data across services without code changes.

## Service Migration Strategies

### Strangler Fig

Gradually replace a monolith by routing requests to new services one feature at a time.

```
Phase 1:  ALL traffic → Monolith
Phase 2:  /users → New Service,  everything else → Monolith
Phase 3:  /users, /orders → New Services,  rest → Monolith
Phase N:  ALL traffic → New Services,  Monolith decommissioned
```

**Implementation:** Use API gateway or reverse proxy to route by path.

### Branch by Abstraction

Introduce an abstraction layer, implement the new version behind it, switch over.

```
1. Create abstraction (interface) over the code to replace
2. Implement new version behind same interface
3. Run both in parallel (shadow mode, compare results)
4. Switch traffic to new implementation
5. Remove old implementation and abstraction
```

### Parallel Run

Run old and new implementations simultaneously, compare results, trust old.

```typescript
async function getUserProfile(userId: string): Promise<UserProfile> {
  const [oldResult, newResult] = await Promise.allSettled([
    legacyService.getUser(userId),
    newService.getUser(userId),
  ]);

  // Compare results (async, don't block response)
  compareResults(oldResult, newResult).catch(logDiscrepancy);

  // Always return old result during migration
  if (oldResult.status === 'fulfilled') return oldResult.value;
  throw oldResult.reason;
}
```

**When to use:** Critical paths where you need confidence the new system behaves identically.

## Service Mesh (When You Actually Need One)

**You probably don't need a service mesh if:** <10 services, single team, no mTLS requirement.

**You might need one if:**
- Many services need mTLS (mutual TLS) between them
- You need fine-grained traffic management (canary, blue-green, fault injection)
- Observability must be consistent across all services without code changes
- Multiple languages/frameworks need the same networking policies

**What a mesh provides:**
- **mTLS** — Encrypted, authenticated service-to-service communication
- **Traffic management** — Canary releases, circuit breaking, retries, timeouts
- **Observability** — Distributed tracing, metrics, access logs — without code changes
- **Policy** — Rate limiting, access control between services

**Options:** Istio (full featured, complex), Linkerd (simpler, lighter), Consul Connect (HashiCorp ecosystem).
