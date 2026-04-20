---
name: webapp-testing
description: "Write permanent Playwright TEST FILES for your test suite — page objects, assertions, CI-ready specs. NOT for ad-hoc QA sessions (use qa) or disposable manual-like testing (use agentic-manual-testing)"
argument-hint: "Write Playwright tests for the login flow including error states and redirect"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: medium
---

# Web App Testing

Browser-based testing with Playwright. Test what users see and do.

```bash
npm init playwright@latest  # New project
npm i -D @playwright/test && npx playwright install  # Existing project
```

## Decision Tree

```
Need to test a web app?
│
├─ Static HTML file?
│  └─ Read HTML → identify selectors → write tests
│
├─ Dynamic webapp, server NOT running?
│  └─ Configure webServer in playwright.config.ts
│     then write tests normally
│
└─ Dynamic webapp, server IS running?
   └─ Navigate → screenshot → identify selectors → test
```

### Auto-Start Server

```typescript
// playwright.config.ts
export default defineConfig({
  webServer: {
    command: "npm run dev",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

## Core Patterns

### Selectors — Use Accessible Locators

| Type | Good | Bad |
|------|------|-----|
| Role | `page.getByRole("button", { name: "Submit" })` | `.btn-primary` |
| Label | `page.getByLabel("Email")` | `#submit-btn` |
| Text | `page.getByText("Welcome")` | `div > form > button:nth-child(2)` |
| Placeholder | `page.getByPlaceholder("Search...")` | |
| TestId | `page.getByTestId("form")` | |

**Principle:** User-facing, resilient to refactors. Avoid brittle class/ID selectors.

## Navigation, Actions, Assertions

| Task | Code |
|------|------|
| Navigate | `await page.goto("/dashboard"); await page.waitForLoadState("networkidle");` |
| Wait element | `await page.getByRole("heading", { name: "Dashboard" }).waitFor();` |
| Wait API | `await page.waitForResponse("**/api/user");` |
| Fill form | `await page.getByLabel("Email").fill("user@example.com");` |
| Click | `await page.getByRole("button", { name: "Sign In" }).click();` |
| Select | `await page.getByLabel("Country").selectOption("US");` |
| Check | `await page.getByLabel("Remember me").check();` |
| Upload | `await page.getByLabel("Avatar").setInputFiles("photo.png");` |
| Assert title | `await expect(page).toHaveTitle("Dashboard");` |
| Assert visible | `await expect(page.getByRole("alert")).toBeVisible();` |
| Assert text | `await expect(page.getByRole("alert")).toHaveText("Success!");` |
| Screenshot | `await expect(page).toHaveScreenshot("dashboard.png");` |

## Test Structure

### Basic Test

```typescript
import { test, expect } from "@playwright/test";

test("user can sign in", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("user@test.com");
  await page.getByLabel("Password").fill("password123");
  await page.getByRole("button", { name: "Sign In" }).click();

  await expect(page).toHaveURL("/dashboard");
  await expect(page.getByText("Welcome back")).toBeVisible();
});
```

### Page Object Model

```typescript
// pages/login.ts
export class LoginPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto("/login");
  }

  async signIn(email: string, password: string) {
    await this.page.getByLabel("Email").fill(email);
    await this.page.getByLabel("Password").fill(password);
    await this.page.getByRole("button", { name: "Sign In" }).click();
  }
}

// tests/login.spec.ts
test("sign in", async ({ page }) => {
  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.signIn("user@test.com", "password123");
  await expect(page).toHaveURL("/dashboard");
});
```

### Auth Fixture (Reuse Login State)

```typescript
// auth.setup.ts
import { test as setup, expect } from "@playwright/test";

setup("authenticate", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("admin@test.com");
  await page.getByLabel("Password").fill("admin123");
  await page.getByRole("button", { name: "Sign In" }).click();
  await page.waitForURL("/dashboard");
  await page.context().storageState({ path: ".auth/user.json" });
});

// playwright.config.ts — use storage state
{
  name: "authenticated",
  use: { storageState: ".auth/user.json" },
  dependencies: ["setup"],
}
```

## Common Scenarios

### API Mocking

```typescript
test("shows error on API failure", async ({ page }) => {
  await page.route("**/api/users", (route) =>
    route.fulfill({ status: 500, body: "Server Error" })
  );
  await page.goto("/users");
  await expect(page.getByRole("alert")).toHaveText("Failed to load users");
});
```

### Responsive Testing

```typescript
test("mobile nav shows hamburger", async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 667 });
  await page.goto("/");
  await expect(page.getByRole("button", { name: "Menu" })).toBeVisible();
  await expect(page.getByRole("navigation")).toBeHidden();
});
```

### Accessibility with axe-core

```typescript
import AxeBuilder from "@axe-core/playwright";

test("page has no a11y violations", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

### Screenshot for Debugging

```typescript
test("debug failing test", async ({ page }) => {
  await page.goto("/broken-page");
  await page.screenshot({ path: "debug.png", fullPage: true });
  // Inspect debug.png to understand the page state
});
```

## Running Tests

| Command | Purpose |
|---------|---------|
| `npx playwright test` | Run all |
| `npx playwright test login.spec.ts` | Specific file |
| `--headed` | See browser |
| `--ui` | Interactive UI |
| `--project=chromium` | Specific browser |
| `--debug` | Step through |
| `npx playwright codegen <url>` | Generate from actions |

## Integration
- **TDD**: Test first (RED), implement (GREEN), refactor
- **CI/CD**: Add `npx playwright test` to workflow, upload artifacts
- **a11y**: Use axe-core for automated accessibility checks
