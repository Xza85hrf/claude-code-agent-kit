# Architecture & Complexity Management

## Managing Complexity

### Essential vs Accidental Complexity

- **Essential Complexity** - Inherent to the problem domain. Cannot be removed, only managed. (Business rules, domain logic, user requirements)
- **Accidental Complexity** - Introduced by our solutions. CAN and SHOULD be minimized. (Poor abstractions, unnecessary indirection, framework ceremony, technical debt)

**Goal: Minimize accidental complexity while clearly expressing essential complexity.**

### Detecting Complexity

| Symptom | Description | Cause |
|---------|-------------|-------|
| **Change Amplification** | Small changes require touching many files | Scattered responsibilities, poor abstraction boundaries |
| **Cognitive Load** | Code requires understanding 10 other classes | Tight coupling, hidden dependencies, unclear naming |
| **Unknown Unknowns** | Changing one thing breaks unrelated things | Global state, hidden dependencies, implicit contracts |

### KISS - Keep It Simple

```typescript
// Over-engineered
class UserServiceFactoryProvider {
  private static instance: UserServiceFactoryProvider;
  static getInstance(): UserServiceFactoryProvider { ... }
  createFactory(): UserServiceFactory { ... }
}

// KISS
class UserService {
  getUser(id: string): User { ... }
}
```

### YAGNI - You Aren't Gonna Need It

Warning signs: "We might need this later", "Just in case", "For future extensibility"

```typescript
// YAGNI violation
class User {
  middleName?: string;
  secondaryEmail?: string;
  faxNumber?: string;
  linkedinProfile?: string;
}

// YAGNI: Only what's needed NOW
class User {
  name: string;
  email: Email;
}
```

### DRY + Rule of Three

**Don't extract duplication until you see it THREE times.** The wrong abstraction is worse than duplication.

```typescript
// First time - leave it
function processUserOrder(order) {
  validate(order); calculateTax(order); save(order);
}

// Second time - note similarity, leave it
function processGuestOrder(order) {
  validate(order); calculateTax(order); save(order);
  sendGuestEmail(order);
}

// Third time - NOW extract
function processOrder(order: Order, postProcessing: (o: Order) => void) {
  validate(order); calculateTax(order); save(order);
  postProcessing(order);
}
```

### Separation of Concerns

```typescript
// BAD: Mixed concerns
class OrderProcessor {
  process(order: Order) {
    if (!order.items.length) throw new Error('Empty');  // Validation
    let total = 0;                                       // Business logic
    for (const item of order.items) { total += item.price * item.quantity; }
    const db = new Database();                           // Persistence
    db.query(`INSERT INTO orders...`);
    const email = new EmailClient();                     // Notification
    email.send(order.customer.email, 'Order confirmed');
  }
}

// GOOD: Separated concerns
class OrderProcessor {
  constructor(
    private validator: OrderValidator,
    private calculator: OrderCalculator,
    private repository: OrderRepository,
    private notifier: OrderNotifier
  ) {}

  process(order: Order): ProcessResult {
    this.validator.validate(order);
    const total = this.calculator.calculateTotal(order);
    const savedOrder = this.repository.save(order);
    this.notifier.notifyConfirmation(savedOrder);
    return ProcessResult.success(savedOrder);
  }
}
```

### The Boy Scout Rule

> "Leave the code better than you found it."

Every time you touch code: improve one name, extract one method, add one missing test. Pay down debt when it's in your path, blocking features, or causing bugs. Don't refactor code that works and won't change, is being replaced soon, or lacks tests.

---

## Architectural Principles

### 1. Vertical Boundaries (Features/Slices)

Organize by **feature**, not by technical layer.

```
GOOD: Feature-first
src/
  users/
    UserController.ts
    UserService.ts
    UserRepository.ts
  orders/
    OrderController.ts
    OrderService.ts
    OrderRepository.ts
```

**Why:** Changes to "users" feature stay in `users/`. High cohesion within features.

### 2. Horizontal Boundaries (Layers)

```
┌──────────────────────────────────────┐
│           Presentation               │  UI, Controllers, CLI
├──────────────────────────────────────┤
│           Application                │  Use Cases, Orchestration
├──────────────────────────────────────┤
│             Domain                   │  Business Logic, Entities
├──────────────────────────────────────┤
│          Infrastructure              │  Database, APIs, External
└──────────────────────────────────────┘
```

### 3. The Dependency Rule

**Dependencies point INWARD.** Inner layers know nothing about outer layers.

```typescript
// Domain defines the interface (inner)
interface UserRepository {
  save(user: User): Promise<void>;
  findById(id: UserId): Promise<User | null>;
}

// Infrastructure implements it (outer)
class PostgresUserRepository implements UserRepository {
  save(user: User): Promise<void> { /* SQL here */ }
}

// Domain service uses the interface
class UserService {
  constructor(private repo: UserRepository) {} // Depends on abstraction
}
```

### 4. Contracts

Interfaces define boundaries between components.

```typescript
interface PaymentGateway {
  charge(amount: Money, card: CardDetails): Promise<ChargeResult>;
  refund(chargeId: string): Promise<RefundResult>;
}

class StripeGateway implements PaymentGateway { }
class PayPalGateway implements PaymentGateway { }
class MockGateway implements PaymentGateway { }  // For tests
```

### 5. Cross-Cutting Concerns

Concerns that span multiple features (logging, auth, validation, error handling). Handle via middleware/interceptors, decorators, or aspect-oriented approaches.

### 6. Conway's Law

> "Organizations design systems that mirror their communication structure."

Team structure affects architecture. Align both intentionally.

---

## Common Architectural Styles

### Hexagonal Architecture (Ports & Adapters)

Domain at center, adapters around edges. **Ports** = interfaces defined by domain. **Adapters** = implementations connecting to the outside world.

```
        ┌─────────────────────┐
        │     HTTP Adapter    │
        └─────────┬───────────┘
                  │
┌─────────────────▼─────────────────┐
│              DOMAIN                │
│   Business Logic + Use Cases       │
└─────────────────┬─────────────────┘
                  │
        ┌─────────▼───────────┐
        │   Database Adapter   │
        └─────────────────────┘
```

### Clean Architecture

Similar to Hexagonal, with explicit layers:
1. **Entities** - Enterprise business rules
2. **Use Cases** - Application business rules
3. **Interface Adapters** - Controllers, Presenters, Gateways
4. **Frameworks & Drivers** - Web, DB, External interfaces

---

## Feature-Driven Structure (Backend)

```
src/
  modules/
    users/
      domain/         User.ts, UserRepository.ts (interface)
      application/    CreateUser.ts, GetUser.ts (use cases)
      infrastructure/ PostgresUserRepo.ts
      presentation/   UserController.ts, UserDTO.ts
    orders/
      domain/ | application/ | infrastructure/ | presentation/
  shared/
    domain/           Shared value objects
    infrastructure/   Shared infra utilities
```

---

## The Walking Skeleton

Start with a minimal end-to-end slice:
1. Thinnest possible feature touching all layers
2. Deployable from day one
3. Proves the architecture works

Example: User can view ONE product (hardcoded) → add to cart → "checkout" (just logs). Then flesh out each feature fully.

---

## Testing Architecture

```
┌────────────────────────────────────────────┐
│            E2E / Acceptance Tests          │  Few, slow, high confidence
├────────────────────────────────────────────┤
│            Integration Tests               │  Some, medium speed
├────────────────────────────────────────────┤
│              Unit Tests                    │  Many, fast, isolated
└────────────────────────────────────────────┘
```

- **Domain:** Unit tests (most tests here)
- **Application:** Integration tests with mocked infra
- **Infrastructure:** Integration tests with real dependencies
- **E2E:** Critical paths only

---

## Red Flags

- Circular dependencies between modules
- Domain depending on infrastructure
- Framework code in business logic
- No clear boundaries between features
- Shared mutable state across modules
- "Util" or "Common" packages that grow forever
- Database schema driving domain model
