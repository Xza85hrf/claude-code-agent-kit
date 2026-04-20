---
name: accessibility-audit
description: Audit web applications for WCAG 2.1 compliance and accessibility issues. Use when testing accessibility, fixing a11y bugs, ensuring WCAG compliance, or reviewing UI for screen reader compatibility.
argument-hint: "Audit the checkout page for WCAG 2.1 AA compliance and fix all critical issues"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: quality
references: []
thinking-level: medium
---

# Accessibility Audit

Automated scan (30-40% catch) + manual review = full audit.

**Workflow:** Scan → Manual checklist → Report by severity → Fix critical/serious → Re-verify

## Automated Testing

```bash
npm i -D @axe-core/playwright @playwright/test && npx playwright install
```

```typescript
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("no critical a11y violations", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();

  for (const v of results.violations) {
    console.log(`[${v.impact}] ${v.id}: ${v.description}`);
    for (const node of v.nodes) console.log(`  Fix: ${node.failureSummary}`);
  }

  const critical = results.violations.filter(v => ["critical", "serious"].includes(v.impact));
  expect(critical).toEqual([]);
});

// Scan multiple pages
const pages = ["/", "/login", "/dashboard", "/checkout"];
for (const path of pages) {
  test(`${path} a11y clean`, async ({ page }) => {
    const results = await new AxeBuilder({ page: (await page.goto(path), page) }).analyze();
    const serious = results.violations.filter(v => ["critical", "serious"].includes(v.impact));
    expect(serious).toEqual([]);
  });
}
```

## WCAG 2.1 AA Checklist

### Perceivable

| Check | Details |
|-------|---------|
| Alt text | Informative: `alt="..."`, Decorative: `alt=""` |
| Contrast | ≥ 4.5:1 normal, ≥ 3:1 large text (≥18pt or 14pt bold) |
| Color alone | Pair with icons/text/patterns |
| Text zoom | 200% resize without loss |
| Flashing | Never >3 times/second |

### Operable

| Check | Details |
|-------|---------|
| Keyboard access | Tab through all interactive elements |
| No traps | Always Tab out of components |
| Skip link | First element → skip to main content |
| Focus order | Logical, matches reading order |
| Focus indicator | Never removed without replacement |
| Touch targets | ≥ 44×44px (buttons, links, controls) |

### Understandable

| Check | Details |
|-------|---------|
| Language | `<html lang="en">` |
| Labels | `<label for="id">` + `<input id="id">` or implicit |
| Error messages | Identify field + suggest fix |
| Consistent nav | Same across all pages |

### Robust

| Check | Details |
|-------|---------|
| Valid HTML | No duplicate IDs, proper nesting |
| ARIA | Use only when native HTML insufficient |
| Custom components | Proper roles (tabs, accordions, dialogs) |
| Status messages | Use `aria-live="polite"` + `aria-atomic="true"` |

## Report Format

```markdown
# Accessibility Audit Report
**Page:** /checkout | **Standard:** WCAG 2.1 AA | **Date:** 2026-02-26

| # | Issue | Severity | Element | Fix |
|---|-------|----------|---------|-----|
| 1 | Missing alt text | Critical | `<img>` | Add descriptive alt |
| 2 | Low contrast (2.8:1) | Serious | `.help-text` | Darken to #595959 |
| 3 | Missing label | Serious | `<input id="qty">` | Add `<label for="qty">` |
| 4 | No focus indicator | Serious | `.btn` | Add focus-visible |
| 5 | No skip link | Moderate | `<body>` | Add skip-to-main |

**Summary:** 2 critical, 2 serious, 1 moderate — fix critical/serious before release.
```

## Quick Fixes (Top 5)

| Issue | Fix |
|-------|-----|
| Missing alt | `<img alt="Description">` |
| Missing label | `<label for="field"><input id="field"></label>` |
| Low contrast | Darken text: `color: #333` (was #999) |
| No focus | `:focus-visible { outline: 2px solid #4f46e5; }` |
| No skip link | `<a href="#main" class="sr-only">Skip to content</a>` (first in body) |
