---
name: agentic-testing
description: "Ad-hoc disposable testing scripts that mimic manual QA — observation over assertion, screenshots, visual evidence. NOT for permanent test files (use webapp-testing) or structured QA sessions (use qa)"
department: quality
when_to_use: Use this skill when introducing new UI features, debugging complex front-end interactions, replacing flaky E2E tests, or when visual evidence of test execution is required for compliance or review.
thinking-level: medium
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Agentic Manual Testing Patterns

## Overview
Agentic Manual Testing shifts the testing paradigm by allowing coding agents to write and execute "disposable" or ad-hoc test scripts in real-time. Unlike traditional CI/CD automated tests, these scripts are often written specifically to verify a change immediately, mimicking a manual QA engineer but with the speed and precision of code. This approach captures visual artifacts and reduces the maintenance burden of brittle selectors found in long-lived test suites.

## Core Concepts

### 1. Shift from Assertion to Observation
Standard automated tests rely on hard assertions (e.g., `expect(element).toBeVisible()`), which fail upon minor UI changes. Agentic testing prioritizes **observation and documentation**:
- **Action**: The agent performs the action (click, scroll, input).
- **Capture**: The agent captures the state (screenshot, video, DOM snapshot).
- **Artifact**: The result is compiled into a human-readable document (via Showboat) rather than just a pass/fail log.

### 2. Tool Integration
- **Playwright**: The execution engine. It drives the browser.
- **Showboat**: The documentation engine. It consumes test artifacts and outputs structured markdown/video documentation.

## Implementation Patterns

### Phase 1: Playwright Setup for Agentic Execution
Configure Playwright to maximize artifact generation. The agent needs visual proof, not just pass/fail status.

**Configuration (`playwright.config.ts`):**
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    // Generate trace on every test
    trace: 'on',
    // Capture video for every run
    video: 'on',
    // Screenshot at every step
    screenshot: 'on',
    // Base URL for the environment being tested
    baseURL: 'http://localhost:3000',
  },
  // Output directory for artifacts
  outputDir: './test-results/artifacts',
});

### Phase 2: The Test Script Pattern
Agents should write self-contained test scripts that focus on a specific user flow. These scripts act as the "manual test steps."

**Example Test Script (`tests/agent/login-check.ts`):**
import { test } from '@playwright/test';

test('Agent Manual Check: User Login Flow', async ({ page, context }) => {
  // Step 1: Navigate
  await page.goto('/login');
  
  // Step 2: Interact
  await page.fill('#email', 'test-user@example.com');
  await page.fill('#password', 'secure-password');
  await page.click('button[type="submit"]');
  
  // Step 3: Wait for stability
  await page.waitForURL('/dashboard');
  
  // Step 4: Artifact Hook
  // The agent can add specific logic here to capture state for Showboat
  await page.screenshot({ path: `./artifacts/dashboard-state.png` });
});

### Phase 3: Hooks for Showboat Integration
Use Playwright hooks to automate the handoff to Showboat. This ensures every test run produces documentation.

**Setup Script (`tests/setup.ts`):**
import { test as base } from '@playwright/test';

// Extend base test to include custom reporting
export const test = base.extend({
  page: async ({ page }, use) => {
    // Pre-test setup
    console.log("Starting Agentic Test Session...");
    
    await use(page);
    
    // Post-test hook: Send artifacts to Showboat
    // This assumes a hypothetical CLI tool or library interaction
    const tracePath = await page.context().tracing().stop();
    console.log(`Trace saved: ${tracePath}`);
    // Execute Showboat command to build report
    // exec(`npx showboat build-report --trace ${tracePath}`);
  },
});

### Phase 4: Automating Documentation Capture
The agent can use a wrapper script to run a specific test and immediately convert the results into a Markdown artifact.

**Workflow Script (`scripts/run-agentic-test.sh`):**
#!/bin/bash
TEST_NAME=$1

# 1. Run Playwright test
npx playwright test $TEST_NAME --project=chromium

# 2. Locate artifacts
ARTIFACT_PATH="./test-results/artifacts"

# 3. Generate Showboat Documentation
# This command aggregates video, screenshots, and traces into a readable MD file
npx showboat generate \
  --input $ARTIFACT_PATH \
  --output ./docs/test-reports/${TEST_NAME}.md \
  --title "Manual Verification: $TEST_NAME"

## Skills Module Logic

When the user requests a manual verification, the coding agent should:

1.  **Analyze the Feature**: Understand the intended behavior.
2.  **Write the Script**: Create a new Playwright file in a `manual-tests/` directory.
3.  **Execute**: Run the script using the wrapper.
4.  **Verify Artifacts**: Open the generated Showboat report (or the screenshots).
5.  **Report Back**: Provide a summary of the execution based on the visual evidence.

### Example Agent Prompt Flow
> **User**: "Verify that the 'Add to Cart' button updates the cart icon count."

> **Agent**:
> 1. Writes `manual-tests/cart-update.spec.ts`.
> 2. Runs `npm run test:manual cart-update`.
> 3. Reads resulting artifact `docs/test-reports/cart-update.md`.
> 4. Responds: "I executed the manual test. The 'Add to Cart' button successfully updates the count from 0 to 1. See attached screenshot."
