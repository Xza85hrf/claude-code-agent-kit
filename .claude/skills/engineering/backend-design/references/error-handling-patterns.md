# Error Handling Patterns Reference

> Load this file when designing error handling strategies, implementing retry logic, graceful degradation, validation, or transaction patterns.

## Typed Error Hierarchies

### TypeScript

```typescript
// Base application error — all custom errors extend this
class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number,
    public readonly isOperational: boolean = true,
    public readonly details?: Record<string, unknown>
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }

  toResponse(): ProblemDetails {
    return {
      type: `https://api.example.com/errors/${this.code}`,
      title: this.name,
      status: this.statusCode,
      detail: this.message,
      ...(this.details && { ...this.details }),
    };
  }
}

// Specific error types
class ValidationError extends AppError {
  constructor(
    message: string,
    public readonly fieldErrors: Array<{ field: string; message: string }>
  ) {
    super(message, 'validation-error', 400, true, { errors: fieldErrors });
  }
}

class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} '${id}' not found`, 'not-found', 404);
  }
}

class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 'conflict', 409);
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 'unauthorized', 401);
  }
}

class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super(message, 'forbidden', 403);
  }
}

class ExternalServiceError extends AppError {
  constructor(service: string, originalError?: Error) {
    super(
      `External service '${service}' unavailable`,
      'service-unavailable', 503, true,
      { service, originalMessage: originalError?.message }
    );
  }
}

class RateLimitError extends AppError {
  constructor(
    public readonly retryAfter: number
  ) {
    super('Rate limit exceeded', 'rate-limited', 429, true, { retryAfter });
  }
}
```

### Python

```python
class AppError(Exception):
    def __init__(self, message: str, code: str, status_code: int,
                 is_operational: bool = True, details: dict | None = None):
        super().__init__(message)
        self.code = code
        self.status_code = status_code
        self.is_operational = is_operational
        self.details = details or {}

    def to_response(self) -> dict:
        return {
            "type": f"https://api.example.com/errors/{self.code}",
            "title": type(self).__name__,
            "status": self.status_code,
            "detail": str(self),
            **self.details,
        }

class ValidationError(AppError):
    def __init__(self, message: str, field_errors: list[dict]):
        super().__init__(message, "validation-error", 400, details={"errors": field_errors})

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str):
        super().__init__(f"{resource} '{id}' not found", "not-found", 404)

class ConflictError(AppError):
    def __init__(self, message: str):
        super().__init__(message, "conflict", 409)
```

### Error Middleware (Express example)

```typescript
function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  const correlationId = req.headers['x-correlation-id'] as string;

  if (err instanceof AppError) {
    // Known operational error — log and return structured response
    logger.warn({
      correlationId,
      error: err.code,
      message: err.message,
      statusCode: err.statusCode,
      path: req.path,
    });
    return res.status(err.statusCode).json({
      ...err.toResponse(),
      instance: req.path,
      correlationId,
    });
  }

  // Unknown error — programming bug, log full details, return generic message
  logger.error({
    correlationId,
    error: 'internal-error',
    message: err.message,
    stack: err.stack,
    path: req.path,
  });

  res.status(500).json({
    type: 'https://api.example.com/errors/internal',
    title: 'Internal Server Error',
    status: 500,
    detail: 'An unexpected error occurred',
    instance: req.path,
    correlationId,
  });
}
```

## RFC 7807 Problem Details

Standard format for HTTP API error responses.

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 422,
  "detail": "Your account balance of $10.00 is insufficient for a $50.00 purchase",
  "instance": "/accounts/12345/transactions",
  "balance": 10.00,
  "required": 50.00
}
```

**Required fields:** `type` (URI reference), `title` (human-readable), `status` (HTTP status code).
**Optional fields:** `detail` (specific explanation), `instance` (URI of the specific occurrence).
**Extension fields:** Any additional fields relevant to the error type.

**Content-Type:** `application/problem+json`

## Retry Strategies

### Exponential Backoff with Jitter

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  options: {
    maxRetries?: number;
    baseDelay?: number;
    maxDelay?: number;
    retryOn?: (error: Error) => boolean;
  } = {}
): Promise<T> {
  const { maxRetries = 3, baseDelay = 1000, maxDelay = 30000, retryOn } = options;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      const isLastAttempt = attempt === maxRetries;
      const shouldRetry = retryOn ? retryOn(error as Error) : isRetryable(error as Error);

      if (isLastAttempt || !shouldRetry) throw error;

      // Exponential backoff: 1s, 2s, 4s, 8s...
      const exponentialDelay = baseDelay * Math.pow(2, attempt);
      // Add jitter: random 0-100% of the delay
      const jitter = Math.random() * exponentialDelay;
      const delay = Math.min(exponentialDelay + jitter, maxDelay);

      logger.warn({
        message: 'Retrying operation',
        attempt: attempt + 1,
        maxRetries,
        delayMs: Math.round(delay),
        error: (error as Error).message,
      });

      await sleep(delay);
    }
  }
  throw new Error('Unreachable');
}

function isRetryable(error: Error): boolean {
  if (error instanceof AppError) {
    // Retry on 503 (service unavailable), 429 (rate limited)
    // Don't retry on 400, 401, 403, 404, 409 (client errors)
    return [503, 429, 502, 504].includes(error.statusCode);
  }
  // Network errors are retryable
  return ['ECONNRESET', 'ETIMEDOUT', 'ECONNREFUSED'].includes((error as any).code);
}
```

### Retry Budget

Limit total retries across all requests to prevent retry storms:

```typescript
class RetryBudget {
  private tokens: number;
  private readonly maxTokens: number;
  private readonly refillRate: number; // tokens per second

  constructor(maxTokens: number, refillRate: number) {
    this.maxTokens = maxTokens;
    this.tokens = maxTokens;
    this.refillRate = refillRate;
    setInterval(() => {
      this.tokens = Math.min(this.maxTokens, this.tokens + this.refillRate);
    }, 1000);
  }

  canRetry(): boolean {
    if (this.tokens > 0) {
      this.tokens--;
      return true;
    }
    return false;
  }
}
```

## Graceful Degradation

### Circuit Breaker State Machine

```typescript
class CircuitBreaker {
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private failureCount = 0;
  private lastFailureTime = 0;

  constructor(
    private readonly threshold: number = 5,       // failures before opening
    private readonly resetTimeout: number = 30000, // ms before trying again
    private readonly halfOpenMax: number = 3       // test requests in half-open
  ) {}

  async execute<T>(fn: () => Promise<T>, fallback?: () => T): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = 'half-open';
      } else {
        if (fallback) return fallback();
        throw new Error('Circuit breaker is open');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      if (fallback) return fallback();
      throw error;
    }
  }

  private onSuccess() {
    this.failureCount = 0;
    this.state = 'closed';
  }

  private onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.threshold) {
      this.state = 'open';
    }
  }
}
```

### Feature Flag Fallbacks

```typescript
async function getRecommendations(userId: string): Promise<Recommendation[]> {
  if (!featureFlags.isEnabled('ml-recommendations')) {
    return getPopularItems(); // Fallback to simple algorithm
  }

  try {
    return await mlService.recommend(userId);
  } catch (error) {
    logger.warn({ message: 'ML service unavailable, using fallback', error });
    metrics.increment('recommendations.fallback');
    return getPopularItems();
  }
}
```

## Validation Patterns

### Schema Validation (Zod example)

```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email('Invalid email format'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Must contain uppercase letter')
    .regex(/[0-9]/, 'Must contain a number'),
  name: z.string().min(1, 'Name is required').max(100),
  role: z.enum(['user', 'admin']).default('user'),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;

// In route handler
function createUser(req: Request, res: Response) {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) {
    throw new ValidationError('Invalid input',
      result.error.issues.map(i => ({ field: i.path.join('.'), message: i.message }))
    );
  }
  // result.data is typed and validated
  return userService.create(result.data);
}
```

### Domain vs Input Validation

```
INPUT VALIDATION (at boundary — reject invalid data):
├── Type checking (string, number, boolean)
├── Format validation (email, URL, UUID)
├── Length/range constraints
├── Required vs optional fields
└── Sanitization (trim, normalize)

DOMAIN VALIDATION (in business logic — enforce rules):
├── Business rules (can this user place this order?)
├── State transitions (can an order go from 'shipped' to 'pending'?)
├── Cross-field validation (end_date > start_date)
├── Uniqueness checks (email not already registered)
└── Authorization (does this user own this resource?)
```

**Input validation = fail fast (400).** Domain validation = business error (409, 422).

## Transaction Patterns

### Unit of Work

Group related operations into a single transaction:

```typescript
async function placeOrder(userId: string, items: CartItem[]): Promise<Order> {
  return db.transaction(async (tx) => {
    // All operations in one transaction — all succeed or all rollback
    const order = await tx.orders.create({ userId, status: 'pending' });

    for (const item of items) {
      await tx.orderItems.create({ orderId: order.id, ...item });
      await tx.inventory.decrement(item.productId, item.quantity);
    }

    const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);
    await tx.orders.update(order.id, { totalCents: total });

    return order;
  });
}
```

### Optimistic Locking

Detect concurrent modifications without holding locks:

```typescript
async function updateProduct(id: string, data: Partial<Product>, expectedVersion: number) {
  const result = await db.query(
    `UPDATE products SET name = $1, price = $2, version = version + 1
     WHERE id = $3 AND version = $4
     RETURNING *`,
    [data.name, data.price, id, expectedVersion]
  );

  if (result.rowCount === 0) {
    throw new ConflictError(
      'Product was modified by another user. Please refresh and try again.'
    );
  }
  return result.rows[0];
}
```

### Compensating Transactions

When you can't use a real transaction (cross-service), define explicit undo operations:

```typescript
interface CompensatingAction {
  description: string;
  execute: () => Promise<void>;
}

async function processPayment(order: Order): Promise<void> {
  const compensations: CompensatingAction[] = [];

  try {
    const charge = await paymentGateway.charge(order.amount);
    compensations.push({
      description: 'Refund payment',
      execute: () => paymentGateway.refund(charge.id),
    });

    await inventoryService.reserve(order.items);
    compensations.push({
      description: 'Release inventory',
      execute: () => inventoryService.release(order.items),
    });

    await notificationService.sendConfirmation(order);
    // No compensation needed for notifications

  } catch (error) {
    logger.error({ message: 'Payment processing failed, compensating', error });
    // Compensate in reverse order
    for (const action of compensations.reverse()) {
      try {
        await action.execute();
        logger.info({ message: `Compensated: ${action.description}` });
      } catch (compError) {
        // Compensation failure — needs manual intervention
        logger.error({ message: `Compensation failed: ${action.description}`, error: compError });
        await alertOps(`Manual intervention needed: ${action.description}`);
      }
    }
    throw error;
  }
}
```
