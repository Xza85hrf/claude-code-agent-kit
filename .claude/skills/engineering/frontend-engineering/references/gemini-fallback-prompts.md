# Gemini Fallback Prompts — When Gemini is Unavailable

When Gemini MCP is down or unavailable, use these prompts to generate decent frontend output directly with Claude. These reference the design-system-guide.md foundations to maintain quality.

## Fallback Decision

```
Gemini unavailable?
    |
    +-- Full page needed? --> Use Claude with Page Template below
    |   (Will be good but not Gemini-quality visuals)
    |
    +-- Component needed? --> Use Claude with Component Template below
    |   (Claude is strong at component architecture)
    |
    +-- Image assets needed? --> STOP. Cannot generate images without Gemini.
    |   Use placeholder services: placehold.co, unsplash source URLs
    |
    +-- Design brainstorm? --> Use Claude directly (good at reasoning)
```

## Page Generation Template

Copy and adapt this prompt when generating a full page without Gemini:

```
Generate a complete, production-ready HTML page for: [DESCRIPTION]

DESIGN REQUIREMENTS (non-negotiable):
- Typography: Use a distinctive Google Font pairing (NOT Inter, Roboto, or Arial)
  - Display: [suggest a bold/distinctive font]
  - Body: [suggest a readable complementary font]
  - Headlines: clamp(1.5rem, 4vw, 3rem) with letter-spacing: -0.02em
  - Body: clamp(0.95rem, 1.5vw, 1.125rem) with line-height: 1.6
- Color: Pick ONE sharp accent color (not #6366f1) + neutral scale
  - Follow 60/30/10 rule: 60% neutral, 30% secondary, 10% accent
  - All text meets 4.5:1 contrast minimum
- Spacing: Use 8px grid tokens only: 4/8/12/16/24/32/48/64/96
- Motion: Use cubic-bezier(0.16, 1, 0.3, 1) for transitions
  - Add word-level stagger reveals on scroll (IntersectionObserver)
  - Micro-interactions on hover (scale, shadow shift, glow)
- Dark mode: Include prefers-color-scheme media query
  - Reduce saturation 10-15%, no pure black (#000) backgrounds
  - Use separate elevated surface colors

ANTI-SLOP RULES:
- NO symmetric 3-column feature grids
- NO purple/blue gradient heroes on white
- NO uniform border-radius on everything
- NO "Welcome to [App]" hero text
- Layout MUST have intentional asymmetry somewhere
- Include SVG grain texture overlay on dark backgrounds (0.03 opacity)
- Custom scrollbar styling

STRUCTURE:
- Semantic HTML (header, nav, main, section, footer)
- Mobile-first responsive (min-width breakpoints)
- Accessible: keyboard nav, ARIA labels, focus indicators
- Single HTML file with embedded <style> (no external deps except fonts)

TARGET QUALITY: This should look like a premium SaaS marketing page,
not a Bootstrap template.
```

## Component Generation Template

```
Generate a [COMPONENT TYPE] component for: [DESCRIPTION]

FRAMEWORK: [React/Vue/Svelte/vanilla]

DESIGN TOKEN SCALE:
- Spacing: 4/8/12/16/24/32/48/64/96 (8px grid)
- Font sizes: 0.75/0.875/1/1.125/1.25/1.5/2/2.5/3rem
- Border radius: 4/6/8/12/16/9999 (pill)
- Shadows: sm(0 1px 2px), md(0 4px 6px), lg(0 10px 15px), xl(0 20px 25px)

INTERACTION REQUIREMENTS:
- Hover: transform + box-shadow transition (200ms, cubic-bezier(0.16, 1, 0.3, 1))
- Focus: visible ring (2px offset, accent color, never outline:none without replacement)
- Active: slight scale-down (0.98)
- Loading state with skeleton/shimmer (not spinner)
- Error state with recovery action
- Empty state with guidance text

ACCESSIBILITY:
- Semantic HTML element (button not div, etc.)
- Keyboard navigable (Tab, Enter, Escape, Arrows as appropriate)
- ARIA attributes only where semantic HTML is insufficient
- Screen reader announcements for dynamic content (aria-live)

QUALITY: Component should feel custom-built, not from a UI library.
Use the design tokens above for ALL spacing, sizing, and shadow values.
```

## Image Placeholder Strategy

When Gemini is unavailable for image generation:

```html
<!-- Hero background: use CSS gradient + grain instead -->
<div class="hero" style="
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
  position: relative;
  overflow: hidden;
">
  <!-- SVG grain texture overlay -->
  <svg style="position:absolute;inset:0;width:100%;height:100%;opacity:0.04">
    <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.65"/></filter>
    <rect width="100%" height="100%" filter="url(#grain)"/>
  </svg>
</div>

<!-- Product shots: use placehold.co with brand colors -->
<img src="https://placehold.co/800x600/1a1a2e/e2e8f0?text=Product+Preview"
     alt="Product preview" width="800" height="600" loading="lazy">

<!-- Avatars: use boring-avatars (SVG, no API key needed) -->
<img src="https://source.boringavatars.com/beam/120/username?colors=264653,2a9d8f,e9c46a"
     alt="User avatar" width="48" height="48">

<!-- Icons: use Lucide (MIT, tree-shakeable) -->
<script src="https://unpkg.com/lucide@latest"></script>
```

## Quality Checklist (Fallback Mode)

When NOT using Gemini, apply extra scrutiny:

```
[] Does the page pass the Squint Test? (hierarchy visible when blurred)
[] Are there at least 2 custom cubic-bezier curves?
[] Is there intentional layout asymmetry?
[] Does dark mode use SEPARATE colors (not CSS invert)?
[] Are all spacing values from the 8px grid token scale?
[] Is there at least one micro-interaction (hover glow, magnetic pull)?
[] Does typography use clamp() for fluid sizing?
[] Is the color palette cohesive with ONE accent?
[] Would this look good as a portfolio piece?
```

**Honest assessment:** Claude-generated HTML/CSS will score 6-8/10 on the Visual Quality Scale. Gemini typically scores 7-9/10. The fallback is good but not as visually polished — focus on strong architecture, accessibility, and interaction design to compensate.
