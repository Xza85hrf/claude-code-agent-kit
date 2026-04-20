---
name: code-refactoring
description: Improve code quality without changing behavior using proven refactoring patterns. Use when cleaning up legacy code, reducing complexity, eliminating duplication, or improving maintainability.
argument-hint: "Refactor the UserService class to reduce complexity and eliminate the 300-line processOrder method"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: medium
---

# Code Refactoring

Change structure. Never behavior. Tests prove it.

## Iron Rule

```
Refactoring changes HOW code works, never WHAT it does.
All tests must pass before AND after every change.
```

Violated this? Revert. Start over.

## Pre-Flight Checklist

- [ ] **Tests exist and pass** — If not, write characterization tests first
- [ ] **Git is clean** — Commit or stash current work
- [ ] **You've read the code** — Understand it before changing it
- [ ] **You know what "done" looks like** — Have a target, don't refactor endlessly

No tests = non-negotiable. You cannot prove behavior is unchanged without tests.

## The Process

```
1. Run tests         → Must pass (baseline)
2. Make ONE change   → Smallest possible refactoring
3. Run tests         → Must still pass
4. Commit            → One refactoring per commit
5. Repeat            → Next change
```

Never batch multiple refactorings. If step 3 fails, you know exactly which change broke it.

## Complexity Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Function length | > 30 lines | Extract Function |
| Nesting depth | > 3 levels | Guard clauses or Extract Function |
| Cyclomatic complexity | > 10 | Decompose |
| Class length | > 300 lines | Extract Class |
| Parameter count | > 3 parameters | Introduce Parameter Object |
| Duplicate blocks | ≥ 3 occurrences | Extract and reuse |

## Refactoring Patterns

### Extract Function

If code has a comment explaining what it does, it should be a named function.

```typescript
// BEFORE
function processOrder(order: Order) {
  // Validate the order
  if (!order.items.length) throw new Error("Empty order");
  if (!order.customer) throw new Error("No customer");
  if (order.total <= 0) throw new Error("Invalid total");

  // Apply discounts
  let discount = 0;
  if (order.total > 100) discount = order.total * 0.1;
  if (order.total > 250) discount = order.total * 0.2;
  if (order.customer.isVIP) discount *= 1.5;
  // ... 200 more lines
}

// AFTER
function processOrder(order: Order) {
  validateOrder(order);
  const discount = calculateDiscount(order);
  // ...
}

function validateOrder(order: Order) {
  if (!order.items.length) throw new Error("Empty order");
  if (!order.customer) throw new Error("No customer");
  if (order.total <= 0) throw new Error("Invalid total");
}

function calculateDiscount(order: Order): number {
  let discount = 0;
  if (order.total > 250) discount = order.total * 0.2;
  else if (order.total > 100) discount = order.total * 0.1;
  if (order.customer.isVIP) discount *= 1.5;
  return discount;
}
```

### Guard Clauses (Reduce Nesting)

```typescript
// BEFORE — arrow code
function getPayment(order: Order) {
  if (order) {
    if (order.isPaid) {
      if (order.payment) {
        return order.payment;
      }
    }
  }
  return null;
}

// AFTER — flat and readable
function getPayment(order: Order) {
  if (!order) return null;
  if (!order.isPaid) return null;
  if (!order.payment) return null;
  return order.payment;
}
```

### Replace Conditional with Polymorphism

```typescript
// BEFORE — type-checking switch
function calculateArea(shape: Shape) {
  switch (shape.type) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "rectangle": return shape.width * shape.height;
    case "triangle": return 0.5 * shape.base * shape.height;
  }
}

// AFTER — each shape knows its own area
interface Shape { area(): number; }

class Circle implements Shape {
  constructor(private radius: number) {}
  area() { return Math.PI * this.radius ** 2; }
}
```

### Rename

If you have to think about what a variable/function means, rename it.

```typescript
// BEFORE
const d = new Date();
const res = await fetch(url);
function proc(u: User) { ... }

// AFTER
const createdAt = new Date();
const userResponse = await fetch(url);
function deactivateUser(user: User) { ... }
```

### Remove Dead Code

If it's not called, delete it. Git remembers.

## Code Smells → Fixes

| Smell | Fix |
|-------|-----|
| Long Method (>30 lines) | Extract Function |
| Large Class (>300 lines) | Extract Class |
| Long Parameter List (>3) | Introduce Parameter Object |
| Duplicated Code (≥3x) | Extract Function |
| Deep Nesting (>3 levels) | Guard Clauses or Extract Function |
| Switch on Type | Replace with Polymorphism |
| Feature Envy | Move Method |
| Data Clumps | Extract Class |
| Primitive Obsession | Value Objects |
| Shotgun Surgery | Move/Inline to consolidate |
| Dead Code | Delete it |
| Comments explaining "what" | Rename or Extract Function |

## When to Stop

Stop when:
- Tests pass
- Complexity is below thresholds
- Names are clear
- Duplication is eliminated
- You've achieved the specific goal

Do not refactor code you're not changing. Do not refactor "while you're in there". Chase thresholds, not perfection.

## Verification

- [ ] All tests pass (same tests, same results)
- [ ] No behavior changed (same inputs → same outputs)
- [ ] Complexity reduced (measure it)
- [ ] Each commit is one atomic refactoring
- [ ] No new features snuck in
