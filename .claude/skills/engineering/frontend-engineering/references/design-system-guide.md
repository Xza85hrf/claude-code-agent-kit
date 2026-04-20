# Design System Guide

> Deep reference for typography, color theory, spacing, motion, and dark mode. Load when designing visual foundations.

---

## Typography System

### Scale Calculator (Major Third — 1.25 ratio)

| Token | Size | Use | Line Height | Tracking |
|-------|------|-----|-------------|----------|
| `text-xs` | 0.75rem (12px) | Captions, footnotes | 1.5 | 0 |
| `text-sm` | 0.875rem (14px) | Labels, metadata | 1.5 | 0 |
| `text-base` | 1rem (16px) | Body text | 1.6 | 0 |
| `text-lg` | 1.125rem (18px) | Lead paragraphs | 1.5 | 0 |
| `text-xl` | 1.25rem (20px) | Card titles | 1.4 | -0.01em |
| `text-2xl` | 1.563rem (25px) | Section headers | 1.3 | -0.015em |
| `text-3xl` | 1.953rem (31px) | Page titles | 1.2 | -0.02em |
| `text-4xl` | 2.441rem (39px) | Hero subheads | 1.1 | -0.025em |
| `text-5xl` | 3.052rem (49px) | Hero headlines | 1.05 | -0.03em |
| `text-6xl` | 3.815rem (61px) | Display/splash | 1.0 | -0.035em |

**Fluid implementation:**
```css
/* Hero text: 2.5rem at 320px, scales to 5rem at 1440px */
.hero-text {
  font-size: clamp(2.5rem, 1rem + 5vw, 5rem);
  letter-spacing: -0.03em;
  line-height: 1.05;
}

/* Section header: fluid mid-range */
.section-title {
  font-size: clamp(1.5rem, 0.8rem + 2vw, 2.5rem);
  letter-spacing: -0.02em;
  line-height: 1.2;
}
```

### Font Pairing Strategies

| Aesthetic | Display Font | Body Font | Example Vibe |
|-----------|-------------|-----------|--------------|
| **Tech/Modern** | Space Grotesk, JetBrains Mono | Inter, Geist | GitHub, Vercel |
| **Luxury/Editorial** | Playfair Display, Cormorant | Source Serif 4, Lora | Luxury brands |
| **Bold/Startup** | Satoshi, Cabinet Grotesk | DM Sans, Plus Jakarta Sans | Stripe, Linear |
| **Playful/Creative** | Fraunces, Crimson Pro | Work Sans, Nunito | Creative agencies |
| **Minimal/Japanese** | Noto Serif JP, Zen Kaku | Noto Sans, IBM Plex Sans | Muji, Uniqlo vibe |
| **Brutalist/Raw** | Space Mono, Fragment Mono | System UI stack | Developer tools |

**Rules:**
- Variable fonts (wght axis) for performance — one file, all weights.
- Display fonts can be expressive. Body fonts must be legible at 14-16px.
- Never use more than 2 font families. Use weight/style variations instead.
- Test at 14px on mobile — if body font is hard to read, it's wrong.

### OpenType Features Worth Enabling

```css
.typography {
  font-feature-settings:
    "kern" 1,     /* Kerning pairs */
    "liga" 1,     /* Standard ligatures (fi, fl) */
    "calt" 1,     /* Contextual alternates */
    "tnum" 1,     /* Tabular numbers (for data) */
    "ss01" 1;     /* Stylistic set 1 (font-specific) */

  /* For code/data: force monospaced numbers */
  font-variant-numeric: tabular-nums;
}
```

---

## Color Theory — The 60/30/10 Rule

### Palette Structure

```
60% — Background/surface (neutral)
  Light: #fafafa → #ffffff
  Dark:  #0a0a0a → #141414

30% — Secondary elements (muted variant of brand)
  Cards, borders, inactive states, dividers
  Light: brand at 5-10% opacity
  Dark:  brand at 8-12% opacity on dark surface

10% — Accent/brand (the color people remember)
  CTAs, active states, key highlights, links
  Light: full saturation
  Dark:  slightly desaturated (-10-15% saturation)
```

### Building a Color System from One Accent

Start with ONE accent color, derive everything else:

```css
:root {
  /* Base accent — the ONE color */
  --accent-h: 220;  /* Hue */
  --accent-s: 85%;  /* Saturation */
  --accent-l: 55%;  /* Lightness */

  /* Derived scale */
  --accent-50:  hsl(var(--accent-h), 90%, 97%);
  --accent-100: hsl(var(--accent-h), 85%, 92%);
  --accent-200: hsl(var(--accent-h), 80%, 82%);
  --accent-300: hsl(var(--accent-h), 75%, 70%);
  --accent-400: hsl(var(--accent-h), 80%, 62%);
  --accent-500: hsl(var(--accent-h), var(--accent-s), var(--accent-l));
  --accent-600: hsl(var(--accent-h), 80%, 45%);
  --accent-700: hsl(var(--accent-h), 75%, 35%);
  --accent-800: hsl(var(--accent-h), 70%, 25%);
  --accent-900: hsl(var(--accent-h), 65%, 15%);

  /* Neutral scale (same hue, desaturated) */
  --neutral-50:  hsl(var(--accent-h), 5%, 98%);
  --neutral-100: hsl(var(--accent-h), 5%, 95%);
  --neutral-200: hsl(var(--accent-h), 5%, 85%);
  --neutral-300: hsl(var(--accent-h), 4%, 70%);
  --neutral-400: hsl(var(--accent-h), 4%, 55%);
  --neutral-500: hsl(var(--accent-h), 3%, 40%);
  --neutral-600: hsl(var(--accent-h), 3%, 30%);
  --neutral-700: hsl(var(--accent-h), 4%, 20%);
  --neutral-800: hsl(var(--accent-h), 5%, 12%);
  --neutral-900: hsl(var(--accent-h), 6%, 7%);
}
```

**Key insight:** Neutrals should carry a hint of the accent hue. Pure grays (#888) look disconnected from the brand. `hsl(accent-hue, 3-5%, lightness)` creates cohesion.

### Contrast Checker Reference

| WCAG Level | Normal Text | Large Text | UI Components |
|-----------|-------------|------------|---------------|
| AA (minimum) | 4.5:1 | 3:1 | 3:1 |
| AAA (enhanced) | 7:1 | 4.5:1 | 4.5:1 |

Large text = 18pt regular or 14pt bold.

---

## Spacing System (8px Grid)

### Token Scale

```css
:root {
  --space-0:   0;
  --space-1:   0.25rem;  /* 4px  — tight inline gaps */
  --space-2:   0.5rem;   /* 8px  — icon gaps, pill padding */
  --space-3:   0.75rem;  /* 12px — input padding, compact lists */
  --space-4:   1rem;     /* 16px — paragraph gaps, card padding */
  --space-6:   1.5rem;   /* 24px — section gaps, form groups */
  --space-8:   2rem;     /* 32px — card gaps, content sections */
  --space-12:  3rem;     /* 48px — major section separators */
  --space-16:  4rem;     /* 64px — hero padding, page margins */
  --space-24:  6rem;     /* 96px — between major page sections */
  --space-32:  8rem;     /* 128px — hero top/bottom spacing */
}
```

### Spacing Rules

| Context | Token | Example |
|---------|-------|---------|
| Inside buttons | `space-2` to `space-3` | `padding: 8px 16px` or `10px 20px` |
| Between form fields | `space-4` to `space-6` | `gap: 16px` or `24px` |
| Card internal padding | `space-4` to `space-6` | `padding: 24px` |
| Between cards | `space-4` to `space-8` | `gap: 16px` to `32px` |
| Section to section | `space-16` to `space-24` | `padding: 64px 0` to `96px 0` |
| Hero padding | `space-24` to `space-32` | `padding: 96px 0` to `128px 0` |

**Anti-pattern:** `padding: 20px`. 20 is not on the 8px grid. Use 16 or 24. Every spacing value should come from the token scale.

---

## Motion Design

### Easing Library

```css
:root {
  /* Standard — most UI transitions */
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);

  /* Overshoot — buttons, toggles, playful elements */
  --ease-overshoot: cubic-bezier(0.34, 1.56, 0.64, 1);

  /* Snappy — dropdowns, tooltips, menus */
  --ease-snappy: cubic-bezier(0.2, 0, 0, 1);

  /* Smooth — scroll-linked, parallax */
  --ease-smooth: cubic-bezier(0.45, 0, 0.55, 1);

  /* Spring — modals, sheets, drawers */
  --ease-spring: cubic-bezier(0.175, 0.885, 0.32, 1.275);

  /* Enter — elements appearing */
  --ease-enter: cubic-bezier(0, 0, 0.2, 1);

  /* Exit — elements disappearing */
  --ease-exit: cubic-bezier(0.4, 0, 1, 1);
}
```

### Duration Guidelines

| Action | Duration | Easing |
|--------|----------|--------|
| Hover color change | 150ms | `--ease-out` |
| Button press | 100ms | `--ease-snappy` |
| Tooltip show | 200ms | `--ease-enter` |
| Tooltip hide | 150ms | `--ease-exit` |
| Dropdown open | 200-250ms | `--ease-snappy` |
| Modal enter | 300ms | `--ease-spring` |
| Modal exit | 200ms | `--ease-exit` |
| Page transition | 300-400ms | `--ease-out` |
| Scroll reveal | 600-800ms | `--ease-out` |
| Word stagger | 40-80ms per word | `--ease-out` |

**Rule:** Exit animations should be 30-50% faster than enter. Users want things to leave quickly.

### Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

---

## Dark Mode Strategy

### Don't Just Invert — Redesign

| Property | Light Mode | Dark Mode | Why |
|----------|-----------|-----------|-----|
| Background | `#ffffff` | `#0a0a0a` to `#121212` | Pure black (#000) causes halation |
| Surface (cards) | `#f5f5f5` | `#1a1a1a` to `#1e1e1e` | Slight elevation from background |
| Elevated surface | `#ffffff` + shadow | `#252525` to `#2a2a2a` | No shadows in dark mode — use lighter bg instead |
| Text primary | `#111111` | `#e5e5e5` | Not pure white — causes eye strain |
| Text secondary | `#666666` | `#999999` | Consistent de-emphasis |
| Accent color | Full saturation | -10-15% saturation | Saturated colors glow on dark backgrounds |
| Borders | `rgba(0,0,0,0.1)` | `rgba(255,255,255,0.08)` | Subtle separation without harsh lines |

### Implementation Pattern

```css
:root {
  color-scheme: light dark;

  /* Light theme (default) */
  --bg: #ffffff;
  --surface: #f5f5f5;
  --text-primary: #111111;
  --text-secondary: #666666;
  --border: rgba(0, 0, 0, 0.1);
  --accent: hsl(220, 85%, 55%);
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0a0a0a;
    --surface: #1a1a1a;
    --text-primary: #e5e5e5;
    --text-secondary: #999999;
    --border: rgba(255, 255, 255, 0.08);
    --accent: hsl(220, 70%, 60%);  /* Reduced saturation */
  }
}
```

### Dark Mode Anti-Patterns

```
NEVER:
+-- Use pure black (#000000) as background
+-- Use pure white (#ffffff) for text
+-- Apply box-shadow in dark mode (use lighter surface instead)
+-- Keep identical saturation levels
+-- Use opacity for dark variants (color shifts unpredictably)
+-- Forget to test images/illustrations on dark backgrounds
```

---

## Responsive Breakpoints

### Standard Scale

```css
/* Mobile-first breakpoints */
--breakpoint-sm: 640px;   /* Large phone / small tablet */
--breakpoint-md: 768px;   /* Tablet portrait */
--breakpoint-lg: 1024px;  /* Tablet landscape / small desktop */
--breakpoint-xl: 1280px;  /* Desktop */
--breakpoint-2xl: 1536px; /* Large desktop */
```

### Container Queries (Component-Level Responsive)

```css
.card-container {
  container-type: inline-size;
  container-name: card;
}

@container card (min-width: 400px) {
  .card { flex-direction: row; }
}

@container card (max-width: 399px) {
  .card { flex-direction: column; }
}
```

**Prefer container queries over media queries for components.** Media queries for page layout, container queries for component layout.

---

*Part of the frontend-engineering skill. Load when designing visual foundations or creating a design system.*
