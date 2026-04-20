---
paths: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"]
---

# TypeScript Rules (extends common rules)

## Type Safety
- Strict mode always (`strict: true` in tsconfig)
- No `any` — use `unknown` + type guards
- Prefer `interface` for objects, `type` for unions/intersections
- Use `as const` for literal types, `satisfies` for validation

## Patterns
- Prefer `Map`/`Set` over plain objects for dynamic keys
- Use discriminated unions for state machines
- `readonly` arrays/objects by default
- Exhaustive switch with `never` check

## Anti-Patterns
- No `@ts-ignore` — use `@ts-expect-error` with reason
- No non-null assertions (`!`) unless provably safe
- No `enum` — use `as const` objects or union types
- No `Function` type — spell out signature
