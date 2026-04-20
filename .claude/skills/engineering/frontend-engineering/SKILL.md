---
name: frontend-engineering
description: Functional UI — components, state management, accessibility, responsive layouts. Use for forms, data tables, dashboards, routing, a11y.
argument-hint: "Build a responsive data table component with sortable columns and keyboard navigation"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "mcp__gemini__*"]
model: inherit
department: engineering
references:
  - references/design-system-guide.md
  - references/gemini-design-prompts.md
  - references/gemini-fallback-prompts.md
  - references/premium-design-patterns.md
  - references/component-patterns.md
  - references/accessibility-guide.md
  - references/web-performance.md
  - references/component-polish.md
thinking-level: medium
---

# Frontend Engineering — Expert Designer System

## Overview

**Expert UI/UX designer AND frontend architect.** Combine **Gemini's visual generation** with **architectural rigor**. Use Gemini for visual work, Ollama for logic.

See `using-antigravity` for Gemini reference, `solid` for code quality, `security-review` for input handling.

## When to Use

**ALWAYS use this skill when:**
- Building UI components or pages
- Choosing CSS/styling approaches
- Making state management decisions
- Implementing responsive layouts
- Reviewing frontend code quality
- Starting any user-facing feature

## 1. Expert Designer Mindset

Before writing ANY UI code, commit to **bold aesthetic direction**. Safe defaults produce forgettable interfaces.

Ask:
- **PURPOSE:** What is this UI trying to accomplish?
- **AUDIENCE:** Developers vs. consumers vs. enterprise?
- **TONE:** Playful/professional/minimal/bold/luxurious?
- **CONSTRAINT:** Mobile-first? Desktop-only? Kiosk?
- **DIFFERENTIATOR:** What makes this NOT look AI-generated?
- **REFERENCE:** Name a specific site/product with the right vibe

### Quality Test Checklist

| Test | Question | Fail Signal |
|------|----------|-------------|
| **Squint** | Hierarchy survives blur? | Everything same-weight |
| **Screenshot** | Portfolio-quality? | Generic/template-like |
| **5-Second** | Stranger knows what this does? | Unclear purpose/CTA |
| **Thumb** | One-handed mobile? | Critical buttons at edges |
| **Dark Room** | Dark mode feels designed? | Colors washed out |

## 2. Generation Router (Gemini First)

| Task | Tool | Notes |
|------|------|-------|
| Full page / landing page | Gemini Pro (thinkingLevel: "high") | See gemini-design-prompts.md |
| Image assets | gemini-generate-image (4K) | Includes iteration via image-edit |
| Design brainstorm | gemini-brainstorm (maxRounds: 3) | Multi-round exploration |
| Code review (CSS/HTML) | gemini-analyze-code (focus: "quality") | Structural/visual regression check |
| Functional component (no design) | Ollama worker (minimax-m2.7:cloud) | Form logic, data tables, state hooks |
| Complex multi-page app | Antigravity IDE | See using-antigravity skill |
| Architecture/state decision | This skill (sections 4-5) | Design system patterns |
| Gemini unavailable | Claude Opus + fallback prompts | See gemini-fallback-prompts.md |

**Key:** Gemini generates visual layer. Opus handles architecture, state, accessibility, integration.

### What NOT to Delegate to Ollama

Design-heavy pages, CSS animations, image/video assets, design systems — use Gemini or Claude

## 3. Anti-Slop Rules

| Never | Instead |
|-------|---------|
| Inter, Roboto, Arial | 2 distinctive fonts (display + body) |
| Purple/blue gradient | Whitespace + asymmetric layout |
| Uniform cards, 8px radius | Cohesive color + ONE sharp accent |
| Stock photos / SVG | Intentional motion micro-interactions |
| Left-aligned default | Layout serves content (asymmetric OK) |
| Generic #6366f1 | Designed dark mode (not inverted) |
| "Welcome to [App]" | 3x+ size jumps between heading levels |
| Symmetric 3-col grid | -0.02em to -0.03em headline tracking |
| Lorem ipsum | Fluid typography with clamp() |
| border-radius: 8px | SVG grain texture (3-4% opacity) |

**Premium:** Stagger reveals, cursor-responsive elements, custom scrollbar

### Visual Quality Scoring

Rate every output 1-10 on these axes. **Minimum to ship: 7 average.**

| Axis | 1-3 (Reject) | 4-6 (Iterate) | 7-10 (Accept) |
|------|-----|-----|-----|
| **Typography** | Default fonts, uniform sizes | Good fonts, decent hierarchy | Distinctive, fluid, tight tracking |
| **Color** | Generic palette, low contrast | Cohesive but predictable | Bold accent, designed dark mode |
| **Layout** | Symmetric grid, boxy | Clean but conventional | Asymmetric, whitespace as design |
| **Motion** | None or gratuitous | Functional transitions | Micro-interactions, stagger, easing |
| **Polish** | Missing states, no details | Complete but standard | Grain, glow, custom cursors, depth |

## 4. Component Design Decision Tree

```
New UI element needed?
    ├── Pure display, no state? → Presentational component
    ├── Has internal state? → Stateful component
    │   └── Shared with siblings? → Lift state to parent
    ├── Combines data + display? → Split into Container + Display
    ├── Multiple related parts? → Compound component (e.g., Tabs + Tabs.List)
    └── Component >150 lines? → Extract sub-components
```

**Principles apply across:** React, Vue, Svelte, Angular, web components. See `references/component-patterns.md` for compound components, render props, form architecture, error boundaries.

## 5. State Management Router

| Data | Location | Pattern |
|------|----------|---------|
| Form input | Component-local | useState / ref / signal |
| UI state (open/closed, active tab) | Component-local | useState / ref |
| Shared between siblings | Nearest parent | Lift state up |
| App-wide (theme, auth, locale) | Context / store | Context, Pinia, Svelte stores |
| Server/API data | Query cache | TanStack Query, SWR, Apollo |
| URL-driven state | URL params | Router params, searchParams |
| Complex state machines | State library | XState, Zustand (rarely Redux) |

**Rules:**
- Start simple. Escalate only when pain appears.
- Server state ≠ app state. Use query cache, not Redux.
- Prop drilling 3+ levels deep? Time for context or composition.
- Anything bookmarkable belongs in the URL.

## 6. Design System Essentials

See `references/design-system-guide.md` for full typography scales, color theory, spacing systems, motion design.

**Quick reference:**

| Category | Rules |
|----------|-------|
| **Typography** | 2 fonts max / clamp() fluid sizing / -0.02em headline tracking |
| **Color** | 1 dominant + 1 accent + neutrals / 4.5:1 contrast min |
| **Spacing** | 4/8/12/16/24/32/48/64/96 scale / strict 8px grid |
| **Motion** | cubic-bezier(0.16, 1, 0.3, 1) for premium feel |
| **Dark Mode** | Reduce saturation 10-15% / separate background scale |
| **Framework** | Tailwind CSS default / custom CSS for animations |
| **Layout** | Mobile-first / Grid for 2D, Flexbox for 1D / container queries |

## 7. Accessibility Checklist

EVERY component must:
- Use semantic HTML (button not div, nav not div)
- Be keyboard navigable (Tab, Enter, Escape, Arrows)
- Have visible focus indicators (never outline: none)
- Include alt text for images (alt="" for decorative)
- Label all form inputs (visible or aria-label)
- Meet color contrast minimums (4.5:1 normal, 3:1 large)
- Use ARIA only when semantic HTML insufficient
- Support prefers-reduced-motion and prefers-color-scheme
- Work with screen readers (VoiceOver/NVDA)

See `references/accessibility-guide.md` for ARIA patterns, focus management.

## 8. Component Interaction Polish (Emil Kowalski)

Expert patterns that make components feel right through invisible correctness. See `references/component-polish.md` for full details.

| Pattern | Rule |
|---------|------|
| Button press | `:active { transform: scale(0.97) }` — instant feedback |
| Entry animations | Never `scale(0)` — start from `scale(0.95); opacity: 0` |
| Popover origin | `transform-origin: var(--radix-popover-content-transform-origin)` (modals stay centered) |
| Tooltip delay | First: delay. Subsequent while open: instant, no animation |
| Dynamic UI | CSS transitions (retargetable) over keyframes (restart from zero) |
| Touch hover | Gate with `@media (hover: hover) and (pointer: fine)` |
| Drag dismiss | Velocity-based (`> 0.11`), not just distance threshold |
| Framer Motion | `x`/`y` props are NOT GPU-accelerated — use `transform: "translateX()"` |
| CSS variables | Changing on parent recalcs ALL children — update `transform` directly |

## 9. Performance Patterns

**Measure:** Lighthouse/Web Vitals, bundle analyzer, DevTools profiler, network waterfall

**Optimize:** Memoization, list virtualization (>100 items), lazy loading, image optimization, code-split by route, debounce search (300ms), prefetch navigation, batch DOM operations

## 10. Pre-Delivery Checklist

**Visual (7/10 minimum):**
- [ ] Looks intentional, not AI generic
- [ ] Typography hierarchy clear (squint test)
- [ ] Spacing consistent (uses token scale)
- [ ] Colors meet contrast requirements
- [ ] Dark mode designed (if applicable)

**Interaction:**
- [ ] Loading states for async operations
- [ ] Error states with recovery actions
- [ ] Empty states with guidance
- [ ] Hover/focus/active states on interactive elements
- [ ] Smooth, purposeful transitions (premium easing)

**Responsive:**
- [ ] Works on mobile (320px minimum)
- [ ] No horizontal scrolling
- [ ] Touch targets 44x44px minimum
- [ ] Text readable without zoom

**Accessibility:**
- [ ] Keyboard-only navigation works
- [ ] Screen reader announces content correctly
- [ ] Logical focus order
- [ ] No auto-playing media without controls

**Generation:**
- [ ] Complex pages generated via Gemini
- [ ] Visual assets at appropriate resolution/ratio
- [ ] Generated code reviewed for anti-slop

## 11. Testing Frontend

| What | How |
|------|-----|
| Pure logic | Unit tests |
| Component rendering | Testing Library (by role/label) |
| User flows | E2E (Playwright/Cypress) |
| Visual regression | Screenshot comparison or gemini-analyze-code |

**Rules:** Test behavior not implementation; query by role/label; mock APIs not components

## 12. Awwwards Gap — 7 Layers

| Layer | Good | Award-Winning |
|-------|------|---------------|
| **Easing** | ease-in-out | Custom cubic-bezier per element |
| **Texture** | Flat | SVG grain 3-5% opacity |
| **Typography** | Breakpoint sizes | clamp() fluid + -0.02em tracking |
| **Hover** | Color change | Magnetic pull, glow, scale+shadow |
| **Scroll** | Block fade | Word stagger + IntersectionObserver |
| **Spacing** | "Looks OK" | Strict 8px grid, all tokens |
| **Light** | Flat colors | Radial glow, gradient borders |

See `references/premium-design-patterns.md` for implementation.

## Red Flags

Stop and reconsider if you see:

| Flag | Fix |
|------|-----|
| Hand-coding full page | Use Gemini to generate, then refine |
| Component >200 lines with mixed concerns | Extract sub-components |
| State library for <5 shared pieces | Lift state to parent |
| CSS classes named .container, .wrapper, .box | Use semantic class names |
| Inline styles mixed with utility classes | Standardize on one approach |
| useEffect for derived/computed values | Use computed/derived |
| Re-renders on every keystroke | Add debounce (300ms) |
| No loading/error states on data fetching | Implement proper states |
| Fixed pixel widths | Use responsive units |
| Disabled form validation without replacement | Provide custom validation UX |
| aria-label on elements with visible text | Remove redundant labels |
| Visual quality score below 7 | Regenerate with Gemini |
| Using Ollama for CSS-heavy UI | Use Gemini or Claude instead |

## Tools & Decision Framework

**Available Tools:**
- `gemini-query (Pro)` — Primary frontend generation engine
- `gemini-generate-image` — UI assets, heroes, icons at 4K
- `gemini-analyze-code` — CSS/HTML quality review
- `gemini-brainstorm` — Multi-round design exploration
- `context7` — Current docs for frameworks/libraries
- `mcp-cli.sh ollama chat` — Functional component logic only
- `sequential-thinking` — Complex state design

**Decision Framework:**
- New page → Generate with Gemini Pro, refine architecture/state
- Gemini unavailable → Claude + fallback prompts
- New component → Start HTML structure, then styles, then interactivity
- Visual bug → Inspect computed styles first, trace CSS cascade
- Performance issue → Profile: re-renders, bundle size, network
- Accessibility issue → Test keyboard nav first, then screen reader
- Responsive issue → Start mobile, expand outward
- Low design quality → Regenerate Gemini with specific prompts

## Known Pitfalls (Production-Tested)

**Animation + Routing:**
- AnimatePresence `mode="wait"` + wouter `Switch` breaks navigation after 2-3 clicks. Exiting page re-renders with new URL, triggering Suspense mid-exit, corrupting framer-motion state. Fix: Remove AnimatePresence or freeze route content during exit.
- Lenis smooth scroll doesn't reset on client-side navigation. Manual fix: `getLenis()?.scrollTo(0, { immediate: true })` in `useEffect([location])`.

**Font Rendering:**
- Tight descenders clip on Windows (DirectWrite GPU rasterization). CSS `descent-override`, `padding-bottom`, `line-height`, `overflow:visible` all fail. Fix: Choose fonts with generous bounds (Space Grotesk > Syne).
- Headless Chromium uses software rendering — can NEVER reproduce GPU rasterization bugs. Don't iterate blindly on font issues in headless tests.
- After 3 failed CSS fixes on rendering issues, likely engine-level. Evaluate replacing the asset.

**Performance:**
- Static imports of heavy packages (Vite, drizzle-zod) cause ESM deadlock. Use dynamic `await import()`.
- WebGL components (SplashCursor, Three.js) must wrap in `<Suspense lazy()>`. Never block initial page load.

**State Management:**
- `@db/schema` pulls server-only dependencies into client bundle. Import from `@db/zod-schemas` instead.

## Useful External Resources

| Resource | URL | Use Case |
|----------|-----|----------|
| **useHooks** | usehooks.com | 50+ reusable React hooks (useDebounce, useLocalStorage, useIntersectionObserver, useFetch, useMediaQuery). Install: `npm i @uidotdev/usehooks` |
| **Bundlephobia** | bundlephobia.com | Check npm package size before adding. Prevents bundle bloat. Shows lighter alternatives. |
| **context7** | MCP plugin | Always check framework docs before implementing patterns: `resolve-library-id` then `query-docs` |

## Integration with Other Skills

- **`using-antigravity`** — Gemini reference, image/video generation
- **`solid`** — SRP, ISP for components; dependency injection
- **`security-review`** — XSS prevention, CSP headers, sanitizing HTML
- **`test-driven-development`** — Component tests before implementation
- **`backend-design`** — API contracts, error formats, caching
- **`app-store-screenshots`** — Generate App Store marketing assets from Next.js
- **`uncodixfy`** — Anti-AI UI constraints for human-designed aesthetics
