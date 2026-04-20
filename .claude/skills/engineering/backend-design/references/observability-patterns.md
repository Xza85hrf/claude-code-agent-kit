# Observability Patterns Reference

> Load this file when setting up structured logging, correlation IDs, metrics, distributed tracing, alerting, or dashboards.

## Structured Logging Setup

### Node.js (Pino)

```typescript
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  serializers: {
    err: pino.stdSerializers.err,
    req: (req) => ({
      method: req.method,
      url: req.url,
      correlationId: req.headers['x-correlation-id'],
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
  redact: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.token'],
});

// Child logger with request context
function createRequestLogger(req: Request) {
  return logger.child({
    correlationId: req.headers['x-correlation-id'],
    userId: req.user?.id,
    path: req.path,
    method: req.method,
  });
}
```

### Python (structlog)

```python
import structlog

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

logger = structlog.get_logger()

# Bind context for a request
request_logger = logger.bind(
    correlation_id=request.headers.get("x-correlation-id"),
    user_id=current_user.id,
    path=request.path,
)

request_logger.info("order_created", order_id="123", total=50.00)
```

### Go (slog — stdlib)

```go
import "log/slog"

logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))

reqLogger := logger.With(
    slog.String("correlationId", r.Header.Get("X-Correlation-ID")),
    slog.String("path", r.URL.Path),
    slog.String("method", r.Method),
)

reqLogger.Info("order created",
    slog.String("orderId", order.ID),
    slog.Float64("total", order.Total),
)
```

## Correlation ID Implementation

### Middleware Pattern

```typescript
import { randomUUID } from 'crypto';
import { AsyncLocalStorage } from 'async_hooks';

const correlationStorage = new AsyncLocalStorage<string>();

function correlationMiddleware(req: Request, res: Response, next: NextFunction) {
  const correlationId = req.headers['x-correlation-id'] as string || randomUUID();
  res.setHeader('x-correlation-id', correlationId);
  req.correlationId = correlationId;
  correlationStorage.run(correlationId, () => next());
}

// Access from anywhere (no req object needed)
function getCorrelationId(): string {
  return correlationStorage.getStore() || 'unknown';
}
```

### Propagation Across Services

```typescript
async function callOrderService(userId: string): Promise<Order[]> {
  const correlationId = getCorrelationId();
  return fetch('https://orders-api.internal/orders', {
    headers: {
      'x-correlation-id': correlationId,
      'Authorization': `Bearer ${serviceToken}`,
    },
  });
}
```

### Propagation in Message Queues

```typescript
// Producer
await queue.publish('order.created', {
  headers: { 'x-correlation-id': getCorrelationId() },
  body: { orderId: '123', userId: 'abc' },
});

// Consumer
queue.subscribe('order.created', (message) => {
  const correlationId = message.headers['x-correlation-id'] || randomUUID();
  correlationStorage.run(correlationId, () => {
    processOrder(message.body);
  });
});
```

## Metrics

### RED Method (Request-oriented — for services)

| Metric | What | Implementation |
|--------|------|---------------|
| **Rate** | Requests per second | Counter: `http_requests_total` |
| **Errors** | Error percentage | Counter: `http_errors_total` / `http_requests_total` |
| **Duration** | Latency distribution | Histogram: `http_request_duration_seconds` |

```typescript
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path'],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});

function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const end = httpRequestDuration.startTimer({ method: req.method, path: req.route?.path || req.path });
  res.on('finish', () => {
    httpRequestsTotal.inc({ method: req.method, path: req.route?.path || req.path, status: res.statusCode });
    end();
  });
  next();
}
```

### USE Method (Resource-oriented — for infrastructure)

| Metric | What | Examples |
|--------|------|---------|
| **Utilization** | % time resource is busy | CPU %, memory %, disk I/O % |
| **Saturation** | Work queued beyond capacity | Queue depth, thread pool backlog |
| **Errors** | Error count | Disk errors, network errors, OOM kills |

### Metric Types

| Type | Use For | Example |
|------|---------|---------|
| **Counter** | Things that only go up | Total requests, errors, bytes sent |
| **Gauge** | Values that go up and down | Current connections, queue size |
| **Histogram** | Distribution of values | Request duration, response size |
| **Summary** | Pre-computed percentiles | Similar to histogram, client-side |

**Naming conventions:**
- Use snake_case: `http_requests_total`
- Include unit: `_seconds`, `_bytes`, `_total`
- Counter suffix: `_total`
- Use labels for dimensions: `method="GET"`, `status="200"`

## OpenTelemetry Setup

### Basic Tracing

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';
import { ExpressInstrumentation } from '@opentelemetry/instrumentation-express';
import { PgInstrumentation } from '@opentelemetry/instrumentation-pg';

const sdk = new NodeSDK({
  serviceName: 'order-service',
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
  }),
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
    new PgInstrumentation(),
  ],
});

sdk.start();
```

### Custom Spans

```typescript
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('order-service');

async function processOrder(order: Order): Promise<void> {
  return tracer.startActiveSpan('processOrder', async (span) => {
    try {
      span.setAttribute('order.id', order.id);
      span.setAttribute('order.total', order.total);

      await tracer.startActiveSpan('validateOrder', async (childSpan) => {
        await validateOrder(order);
        childSpan.end();
      });

      await tracer.startActiveSpan('chargePayment', async (childSpan) => {
        childSpan.setAttribute('payment.method', order.paymentMethod);
        await chargePayment(order);
        childSpan.end();
      });

      span.setStatus({ code: SpanStatusCode.OK });
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: (error as Error).message });
      span.recordException(error as Error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

## Alerting Strategy

### SLO-Based Alerting

```
Define SLOs first, alert on burn rate:

SLO: 99.9% of requests succeed within 500ms (over 30 days)
Error budget: 0.1% = ~43 minutes of downtime/month

Alert tiers:
├── Page (wake someone up):
│   Burn rate >14.4x for 2 min AND >14.4x for 5 min
│   (will exhaust budget in 1 hour)
│
├── Ticket (fix during business hours):
│   Burn rate >6x for 30 min AND >3x for 6 hours
│   (will exhaust budget in 5 hours)
│
└── Log (investigate when convenient):
    Burn rate >1x for 3 days
    (trending toward budget exhaustion)
```

### Alert Quality Rules

```
GOOD ALERTS:
├── Actionable — someone can DO something about it
├── Urgent — needs attention NOW (or within hours)
├── Specific — clearly states what's wrong and where
├── Contextualized — includes metrics, runbook link
└── Tested — verified it fires correctly

BAD ALERTS (alert fatigue):
├── "CPU is at 80%" — so what? Is it causing problems?
├── "Disk space at 70%" — too early, alert at 85%+
├── Every 404 response — expected behavior
├── Every retry — retries are normal, alert on exhaustion
└── Flapping alerts — firing/resolving repeatedly
```

### Alert Template

```
Title: [Service] [What's wrong] — [Impact]
Severity: P1/P2/P3/P4
Service: order-service
Environment: production

What: Order processing error rate is 5.2% (SLO: <0.1%)
When: Started 2024-01-15 14:23 UTC (12 minutes ago)
Impact: ~520 orders failing per 10,000 requests
Dashboard: [link]
Runbook: [link]

Recent changes:
- Deploy abc123 at 14:15 UTC (8 min before alert)
```

## Dashboard Design

### Four Golden Signals Dashboard

```
┌─────────────────────────────────────────────────┐
│                 SERVICE: order-api               │
├────────────────────┬────────────────────────────┤
│   LATENCY          │   TRAFFIC                   │
│   p50: 45ms        │   Rate: 1,200 req/s         │
│   p95: 180ms       │   Peak: 2,100 req/s         │
│   p99: 450ms       │   [sparkline graph]          │
│   [histogram]      │                              │
├────────────────────┼────────────────────────────┤
│   ERRORS           │   SATURATION                │
│   5xx: 0.02%       │   CPU: 45%                  │
│   4xx: 2.1%        │   Memory: 68%               │
│   [error rate      │   DB Pool: 12/50            │
│    over time]      │   Queue: 23 pending         │
├────────────────────┴────────────────────────────┤
│   DEPENDENCIES                                   │
│   payment-api: 99.8%  |  p95: 120ms             │
│   user-db:     100%   |  p95:  8ms              │
│   redis:       100%   |  p95:  1ms              │
│   inventory:   98.5%  |  p95: 890ms             │
└─────────────────────────────────────────────────┘
```

### Dashboard Hierarchy

```
Level 1: Service Overview (one page per service)
├── Four golden signals
├── Dependency health
├── Error breakdown by type
└── Deploy markers

Level 2: Deep Dive (linked from overview)
├── Individual endpoint metrics
├── Database query performance
├── Cache hit rates
├── Background job metrics
└── Resource utilization detail

Level 3: Business Metrics (for stakeholders)
├── Orders per minute
├── Revenue (real-time)
├── User signups
├── Feature usage
└── Conversion funnel
```

### Dashboard Rules

```
DO:
├── Show time-series graphs (trends matter more than instant values)
├── Include deploy markers (vertical lines when code deployed)
├── Use percentiles for latency (p50, p95, p99), never averages
├── Show error rates as percentages, not absolute counts
├── Include SLO threshold lines on graphs
├── Link dashboards to runbooks and alerts
└── Keep dashboards focused (one service or one business domain)

DON'T:
├── Show raw CPU/memory without context (what's the limit?)
├── Use pie charts for time-series data
├── Cram everything onto one dashboard
├── Show only last 1 hour (include 24h and 7d views)
├── Rely on color alone to indicate status
└── Create dashboards nobody looks at (review quarterly)
```
