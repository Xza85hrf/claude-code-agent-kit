# Gemini Design Prompts — Battle-Tested Templates

> Copy-paste-adapt these prompts for `gemini-query` (model: "pro") and `gemini-generate-image`. Each has been tested and refined for high visual quality output.

---

## Page Generation Prompts (gemini-query)

### Landing Page — SaaS Product

```
You are an expert frontend engineer and visual designer specializing in SaaS products.

Create a complete, production-quality landing page for [PRODUCT_NAME]: [ONE_SENTENCE_DESCRIPTION].

REQUIREMENTS:
- Single HTML file with embedded CSS and minimal JS
- Mobile-first responsive design (320px to 2560px)
- No external dependencies (no CDN, no frameworks, inline everything)
- Dark mode support via prefers-color-scheme
- Smooth scroll-triggered animations using IntersectionObserver
- Semantic HTML5 with ARIA attributes

SECTIONS (in order):
1. Navigation — sticky, glassmorphism blur on scroll, logo + 4 nav links + CTA button
2. Hero — large headline with word-level stagger animation, subheadline, dual CTA buttons, abstract gradient background
3. Social proof — logo bar (use CSS shapes as placeholders), "Trusted by X+ companies"
4. Features — 3-4 features with icons (CSS-only), asymmetric grid layout (NOT a symmetric 3-column grid)
5. How it works — 3-step process with numbered steps and connecting lines
6. Pricing — 3 tiers with highlighted recommended plan, toggle for monthly/annual
7. Testimonials — 2-3 quotes with attribution and subtle card design
8. CTA — final conversion section with gradient background
9. Footer — 4-column links, social icons, legal

DESIGN DIRECTION:
- Style: [AESTHETIC — e.g., "Apple-like minimalism", "Stripe-inspired tech", "Linear dark elegance"]
- Colors: [PRIMARY_COLOR] as accent, dark/light neutrals derived from it
- Typography: Use CSS @font-face with system font fallback. Display: [FONT], Body: [FONT]
- Distinctive: [SPECIFIC_UNIQUENESS — e.g., "grain texture overlay", "gradient mesh backgrounds", "kinetic typography"]

ANTI-SLOP: Do NOT use Inter font, purple gradients on white, symmetric 3-column grids, or generic placeholder text. Use real-sounding content for [PRODUCT_NAME].
```

### Dashboard — Analytics/Admin

```
You are an expert frontend engineer specializing in data-dense admin interfaces.

Create a complete analytics dashboard for [APP_NAME]: [DESCRIPTION].

REQUIREMENTS:
- Single HTML file with embedded CSS and JS
- Mobile-responsive (sidebar collapses to bottom nav on mobile)
- Dark theme primary, light theme secondary
- No external dependencies
- Realistic mock data (not lorem ipsum)

LAYOUT:
- Left sidebar: logo, nav icons (6-8 items), user avatar at bottom
- Top bar: search, notifications bell, user dropdown
- Main content: grid of metric cards + charts

COMPONENTS:
1. Metric cards (4) — title, large number, trend arrow (+/-%), sparkline
2. Main chart — line/area chart showing 7-day trend (CSS-only or SVG)
3. Activity feed — recent events with timestamps and user avatars
4. Table — sortable data table with pagination, row hover states
5. Quick actions — floating action button with radial menu

DESIGN:
- Glassmorphism cards on dark background (backdrop-filter: blur)
- Accent color: [COLOR] for active states, charts, CTAs
- Monospace font for numbers (font-variant-numeric: tabular-nums)
- Subtle grid lines on charts, smooth hover tooltips
- 8px spacing grid, consistent shadow scale
```

### Portfolio — Developer/Designer

```
You are an expert frontend engineer creating a portfolio that would win design awards.

Create a complete portfolio page for [NAME], a [ROLE — e.g., "senior frontend engineer"].

REQUIREMENTS:
- Single HTML file, embedded CSS+JS, no dependencies
- Mobile-first, fluid responsive (no breakpoint jumps)
- Smooth scroll with section snap
- Dark mode primary with light mode support
- Performance: no layout shifts, instant interactions

SECTIONS:
1. Hero — name in large display type, role subtitle, one-line tagline, scroll indicator
2. About — brief bio (3 sentences), photo placeholder (CSS gradient), key stats (years exp, projects, clients)
3. Work — 4-6 project cards with hover reveal (image placeholder + title + tech tags + link)
4. Skills — visual skill representation (NOT progress bars — use something creative: constellation, tag cloud, grid)
5. Contact — email CTA, social links, available for work badge

DESIGN DIRECTION:
- Style: [e.g., "Brutalist with refined type", "Japanese minimalism", "Retro-futuristic terminal"]
- Must feel like a PERSON designed this, not a template
- At least 3 of the 7 Awwwards layers: custom easing, texture, fluid type, premium hover states, stagger animations, strict grid, light effects
- Cursor: custom cursor or cursor-reactive elements

ANTI-SLOP: No Inter font, no purple gradients, no "Hi, I'm [Name]" hero, no symmetric grids.
```

### E-Commerce — Product Page

```
You are an expert frontend engineer specializing in conversion-optimized e-commerce.

Create a product detail page for [PRODUCT]: [DESCRIPTION], priced at [PRICE].

REQUIREMENTS:
- Single HTML file, embedded CSS+JS, no dependencies
- Mobile-first (60%+ traffic is mobile for e-commerce)
- Focus on conversion: CTA always visible, minimal friction
- Image gallery with zoom (CSS-only or minimal JS)

LAYOUT (Mobile):
1. Image carousel (swipeable via CSS scroll-snap)
2. Product title + price (sticky on scroll)
3. Variant selector (size, color) with visual swatches
4. Add to cart button (sticky bottom bar on mobile)
5. Description accordion
6. Reviews summary (stars + count)
7. Related products carousel

LAYOUT (Desktop):
1. Left: image gallery (thumbnail strip + main image)
2. Right: sticky product info panel (title, price, variants, CTA, shipping)
3. Below: tabs for description, specs, reviews

DESIGN:
- Clean, minimal — product is the hero
- Photography-first (use gradient placeholders that represent product images)
- Trust signals: shipping badge, return policy, secure checkout
- Micro-animations: add-to-cart button transforms, quantity stepper, swatch selection
```

---

## Component Prompts (gemini-query)

### Data Table

```
Create a responsive data table component in HTML/CSS/JS.

Features: sortable columns (click header), row selection (checkbox), pagination (10/25/50 per page), search filter, responsive (horizontal scroll on mobile with sticky first column).

Design: clean borders, zebra striping, hover highlight, selected row accent, sort indicator arrows. Use tabular-nums for number columns.
```

### Form with Validation

```
Create a multi-step form (3 steps) with inline validation.

Steps: 1) Personal info (name, email, phone) 2) Preferences (checkboxes, radio, select) 3) Review & submit.

Features: progress indicator, step navigation, inline validation messages, error shake animation, success state.

Design: floating labels, custom styled inputs (not browser defaults), accessible focus states, smooth step transitions.
```

### Navigation — Mega Menu

```
Create a responsive navigation with mega menu dropdown.

Desktop: horizontal nav bar, hover reveals mega menu with columns. Mega menu has categories, featured links, and a CTA.

Mobile: hamburger icon, full-screen overlay menu with accordion sections.

Design: glassmorphism mega menu, smooth open/close transitions, keyboard navigable (arrow keys + escape), focus trap when open.
```

---

## Image Generation Prompts (gemini-generate-image)

### Hero Backgrounds

```
Abstract geometric background for a tech product website.
Style: Low-poly mesh gradient transitioning from [COLOR_1] to [COLOR_2].
Composition: Asymmetric, denser detail in bottom-right corner fading to clean space in top-left.
Lighting: Soft ambient glow from center, subtle light particles.
Mood: Professional, innovative, trustworthy.
Aspect ratio: 21:9, Size: 4K
```

```
Dark gradient mesh background for SaaS dashboard.
Style: Smooth organic gradients, aurora-borealis inspired flowing colors.
Colors: Deep navy (#0a1628) base, [ACCENT] and teal accent glows.
Composition: Flowing bands of color across the frame, subtle noise texture.
Size: 4K, Aspect: 16:9
```

### App Icons

```
Minimalist app icon for [APP_NAME], a [DESCRIPTION].
Style: Flat design with subtle gradient, geometric shapes.
Symbol: [CORE_CONCEPT — e.g., "interconnected nodes", "upward arrow", "shield with check"].
Colors: [PRIMARY] to [SECONDARY] gradient on [BACKGROUND].
Grid: 1024x1024 with safe area margins. Square with 20% corner radius.
Size: 1K, Aspect: 1:1
```

### UI Mockup Screenshots

```
High-fidelity screenshot of a [TYPE] application interface.
Style: Modern, clean, [AESTHETIC].
Layout: [DESCRIBE — e.g., "sidebar navigation, main content area with data cards, top search bar"].
Color scheme: [COLORS].
Device: [Desktop/Mobile/Tablet].
Details: Realistic data, proper typography hierarchy, subtle shadows.
Size: 4K, Aspect: 16:9
```

### Social Media / Marketing

```
Social media graphic for [PRODUCT/EVENT].
Style: Bold, eye-catching, [AESTHETIC].
Content: [HEADLINE TEXT] in large type, [SUBTITLE], [LOGO/BRAND] placement.
Colors: [BRAND_COLORS].
Composition: Text-safe area in center, decorative elements at edges.
Size: 2K, Aspect: 1:1 (Instagram) / 16:9 (Twitter) / 9:16 (Stories)
```

---

## Multi-Turn Image Editing Prompts

Use `gemini-start-image-edit` then `gemini-continue-image-edit`:

### Refinement Sequence

```
Turn 1 (start): Generate base image with overall composition
Turn 2 (continue): "Refine the [SPECIFIC_AREA]. Make it more [QUALITY]."
Turn 3 (continue): "Adjust the color palette. Replace [OLD_COLOR] with [NEW_COLOR]."
Turn 4 (continue): "Add [DETAIL] to the [LOCATION]. Ensure it blends naturally."
Turn 5 (end): gemini-end-image-edit
```

### Common Refinements

```
"Make the lighting more dramatic — add a stronger directional light from the top-left"
"Reduce visual clutter in the background, make it cleaner"
"Increase contrast between foreground and background elements"
"Add a subtle glow effect around the [ELEMENT]"
"Make the composition more asymmetric — shift the focal point to the left third"
"Add texture — subtle noise grain at 3-5% opacity"
"Warm up the color temperature slightly"
```

---

## Prompt Engineering Tips for Gemini

1. **Be specific about what NOT to do.** "No generic gradients" is more useful than "make it unique."
2. **Name reference designs.** "Apple.com minimalism" or "Linear dark dashboard aesthetic" gives Gemini a visual target.
3. **Describe emotion, not just features.** "Should feel expensive and trustworthy" guides aesthetic decisions.
4. **Include anti-patterns.** "NOT a 3-column feature grid" prevents the most common generic output.
5. **Iterate, don't regenerate.** Use multi-turn image editing to refine, not start over.
6. **Model choice matters.** Use `pro` for complex pages, `flash` for quick components and iterations.
7. **thinkingLevel: "high"** for architecture-heavy pages. Default for simple components.

---

*Part of the frontend-engineering skill. Load when generating any frontend with Gemini MCP.*
