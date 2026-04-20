---
name: frontend-design-pro
description: Cinematic, production-grade frontend interfaces with premium motion design. Use for landing pages, hero sections, scroll storytelling, visual polish.
argument-hint: "Build a cinematic SaaS landing page with dark glass UI, scroll storytelling, and stagger reveals"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "mcp__gemini__*", "mcp__openai__*"]
model: inherit
department: engineering
references:
  - references/hero-sections.md
  - references/motion-patterns.md
  - references/premium-effects.md
  - references/saas-components.md
  - references/battle-tested-patterns.md
  - references/ginyboi-motion-patterns.md
  - references/anti-vibe-code.md
  - references/particle-systems.md
  - references/seo-checklist.md
  - references/emil-design-eng.md
thinking-level: high
---

# PRO Frontend Design Skill (2026)

Distinctive, cinematic, production-grade frontend combining premium visual design, motion systems, animation architecture, and AI-age UX philosophy.

## Prerequisites — Auto-Restore Design MCP Servers

**Run this FIRST** before any design work:
```bash
bash .claude/scripts/mcp-profile.sh design
```
This restores: gemini, stitch, 21st-dev-magic, animate-ui, reactbits (from backup if removed). Then `/mcp` to reconnect.

Available design tools after restore:
- **Stitch**: `mcp__stitch__generate_screen_from_text` — mockup-to-code from description
- **21st.dev**: `mcp__21st-dev-magic__21st_magic_component_builder` — premium React components
- **React Bits**: `mcp__reactbits__search_components` — 135+ animated components
- **Animate UI**: `mcp__animate-ui__search_items_in_registries` — animated shadcn/ui
- **Gemini**: `mcp__gemini__gemini-generate-image` — hero images, mockups
- **PinchTab**: Enable separately with `bash .claude/scripts/mcp-profile.sh +pinchtab` for web browsing

---

## Phase 1: Design Thinking

Establish creative direction before coding.

### 1A. Context & Intent
- **Purpose:** Problem solved, user served
- **Emotional goal:** Feeling conveyed (confidence, excitement, trust, delight)
- **Brand tier:** Consumer / SaaS / enterprise / luxury

### 1B. Design Research & Inspiration

Before committing to a direction, research existing implementations:

| Resource | Use For | URL |
|----------|---------|-----|
| **Pageflows** | Real app user flows, onboarding, checkout, settings | pageflows.com |
| **Dribbble** | Visual design inspiration, motion design, UI patterns | dribbble.com |
| **LottieFiles** | Ready-to-use JSON animations (loading, transitions, icons) | lottiefiles.com |
| **Awwwards** | Award-winning web design, interaction design | awwwards.com |
| **Mobbin** | Mobile app design patterns, real screenshots | mobbin.com |

**Workflow:** Browse references → screenshot/bookmark 2-3 that match intent → extract patterns (spacing, color, motion) → inform Phase 2-4.

For animation assets, prefer LottieFiles JSON (lightweight, scalable) over GIFs or videos. Import via `lottie-react` or `@lottiefiles/react-lottie-player`.

### 1C. Commit to an Aesthetic Direction

Pick ONE strong, intentional direction and execute it with precision. Examples:

| Direction | Character |
|-----------|-----------|
| Neo-minimalist | Generous space, warm neutrals, subtle depth, restrained motion |
| Cinematic SaaS | Dark UI, glass layers, gradient glows, scroll storytelling |
| Editorial | Strong typography, asymmetry, bold contrast, static energy |
| Organic/Natural | Soft palettes, tactile textures, fluid shapes, warm lighting |
| Brutalist | Raw structure, high contrast, deliberate imperfection |
| Retro-futuristic | Scan lines, monospace, neon accents, controlled nostalgia |

**AVOID:** generic purple gradients, cyan/teal-on-dark, Inter/Roboto/Arial, cookie-cutter layouts, predictable patterns. Choose warm, distinctive palettes. See `references/anti-vibe-code.md` for the full anti-pattern library.

### 1C. The One Unforgettable Thing
Identify one element someone will remember. Anchor design around it.

---

## Phase 2: Visual Composition System

### Typography
Expressive font pairings. Use typography as design tool. Mix weights/sizes/spacing. Consider animated type in heroes.

### Color & Theme
Dominant palette (2–3 colors max) + one accent. Commit fully. Use CSS custom properties.

### Spatial Composition
Asymmetry, overlap, diagonal flow. Alternate density/breathing room. Layer z-index for depth.

### Backgrounds & Atmosphere
Never solid color. Use gradient meshes, noise, glassmorphism, particles, or 3D backgrounds.

### Shadows & Lighting
Shadow blur = 2–3× Y offset. Soft, directional, realistic.

---

## Phase 3: Motion System Design

Decompose animation into scenes BEFORE generating code. Quality comes from planning, not model capability.

### 3A. The Animation Decision Framework (Emil Kowalski)

Before writing ANY animation, answer in order:

**Should it animate?** → Based on usage frequency:
- 100+/day (keyboard, cmd palette): **No animation. Ever.**
- Tens/day (hover, list nav): Remove or drastically reduce
- Occasional (modals, drawers): Standard animation
- Rare (onboarding, celebrations): Can add delight

**What's the purpose?** Spatial consistency, state indication, feedback, preventing jarring changes. If "looks cool" is the only reason → don't animate.

**What easing?** Entering/exiting → ease-out. Moving on-screen → ease-in-out. Hover/color → ease. Constant → linear. **Never ease-in for UI** (feels sluggish at the critical first moment). Use custom curves — built-in CSS easings are too weak:
```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);  /* iOS drawer */
```

**How fast?** Button: 100–160ms. Tooltip: 125–200ms. Dropdown: 150–250ms. Modal: 200–500ms. **UI under 300ms.** Asymmetric: press slow (2s linear for hold-to-delete), release fast (200ms ease-out).

Full framework with code examples: `references/emil-design-eng.md`

### 3B. Motion Goals
- Guide attention
- Communicate state
- Reinforce brand
- Reduce cognitive load

### 3C. Motion Layers (SaaS Standard)

| Layer | Type | Examples |
|-------|------|---------|
| Ambient | Background atmosphere | gradient drift, subtle particles |
| Structural | Section-level | scroll transitions, hero transforms |
| Functional | UI feedback | hover states, button responses, form feedback |
| Narrative | Storytelling | feature reveals, product demo sequences |

### 3D. Scene-Based Animation Planning

For any significant animation, define each scene:

```
Scene N:
- duration: Xs
- camera/framing: [zoom / wide / close / panning]
- UI state: [what's visible, layout]
- action: [what moves, how]
- transition: [fade / slide / scale / morph]
- effects: [easing type, stagger, parallax, blur, depth]
- triggers: [on-load / scroll / hover / click / delay]
```

**Premium motion keywords to use in prompts/code:**
- `cinematic easing` → cubic-bezier(0.16, 1, 0.3, 1)
- `stagger reveal` → sequential delay (0.05–0.15s per element)
- `layered parallax` → multi-speed scroll layers
- `elastic micro-interaction` → spring physics on hover/tap
- `glass morph transition` → blur + opacity morph
- `depth fade` → opacity + scale + blur combined
- `perspective zoom` → CSS perspective + translateZ
- `progressive reveal` → content entering from blur/offset

### 3E. Motion Pacing by Content Type

| Moment | Speed | Feel |
|--------|-------|------|
| Hero intro | Slow (2–4s) | Cinematic |
| Feature reveals | Medium (0.6–1s) | Clear |
| Micro interactions | Fast (0.15–0.3s) | Snappy |
| CTA feedback | Instant (<0.1s) | Responsive |
| Scroll storytelling | Scroll-relative | Controlled |

### 3F. Motion Hierarchy Rule
- Important elements: move **first** and travel **further**
- Secondary elements: follow **later** with **smaller** motion
- This creates natural visual hierarchy without extra markup

---

## Phase 4: Implementation

### Technology Selection

| Need | Tool |
|------|------|
| React component motion | Framer Motion (declarative, state-tied) |
| Timeline / scroll storytelling | GSAP + ScrollTrigger |
| 3D environments | Three.js / React Three Fiber |
| Smooth scroll physics | Lenis |
| Interactive design prototypes | HTML/CSS/JS |

For **HTML artifacts**: CSS-only animations preferred; JS for scroll triggers.
For **React artifacts**: Framer Motion + Tailwind utility classes.

### GSAP ScrollTrigger + 3D CSS Patterns

For immersive 3D animated landing pages:

```javascript
// Pin section and animate 3D elements on scroll
gsap.to(".hero-3d", {
  scrollTrigger: {
    trigger: ".hero-section",
    start: "top top",
    end: "+=200%",
    pin: true,
    scrub: 1,
  },
  rotateY: 360,
  z: 200,
  ease: "none",
});

// Parallax depth layers
gsap.utils.toArray(".depth-layer").forEach((layer, i) => {
  gsap.to(layer, {
    scrollTrigger: { trigger: layer, scrub: true },
    y: -(i + 1) * 100,
    ease: "none",
  });
});
```

```css
/* 3D perspective container */
.scene-3d {
  perspective: 1200px;
  perspective-origin: 50% 50%;
}
.scene-3d > * {
  transform-style: preserve-3d;
  backface-visibility: hidden;
}

/* Scroll-driven 3D card tilt */
.card-3d {
  transform: rotateX(calc(var(--scroll) * 15deg)) rotateY(calc(var(--scroll) * -10deg));
  transition: transform 0.1s ease-out;
}
```

**Performance rules:**
- Use `will-change: transform` only on actively animating elements
- Prefer `transform` + `opacity` (GPU-composited) over `top`/`left`/`width`
- Set `scrub: 1` (1 second lag) instead of `scrub: true` (instant) for smoother feel
- Test on mobile — `perspective` is expensive on low-end GPUs
- **Framer Motion `x`/`y`/`scale` shorthand is NOT hardware-accelerated** — uses `requestAnimationFrame` on main thread. Use `animate={{ transform: "translateX(100px)" }}` for GPU compositing
- CSS animations beat JS under load (off main thread). Use CSS for predetermined, JS for dynamic/interruptible
- Use Web Animations API (WAAPI) for programmatic CSS-performance animations without libraries
- Changing CSS variables on a parent triggers style recalc on ALL children — update `transform` directly instead

### Code Quality Standards
- CSS custom properties for all design tokens
- Semantic HTML
- Meaningful naming
- Accessible motion (`prefers-reduced-motion`)
- GPU-accelerated properties only: `transform`, `opacity`

### Premium UI Patterns

**Glassmorphism:**
```css
background: rgba(255,255,255,0.08);
backdrop-filter: blur(16px) saturate(180%);
border: 1px solid rgba(255,255,255,0.12);
```

**Stagger reveal (CSS):**
```css
.item:nth-child(1) { animation-delay: 0s; }
.item:nth-child(2) { animation-delay: 0.08s; }
/* etc. */
```

**Cinematic easing:**
```css
transition: all 0.7s cubic-bezier(0.16, 1, 0.3, 1);
```

**Premium gradient background:**
```css
background: radial-gradient(ellipse at 20% 50%, #1a1a2e 0%, transparent 60%),
            radial-gradient(ellipse at 80% 20%, #16213e 0%, transparent 60%),
            #0a0a0f;
```

---

## Phase 5: Specific Component Recipes

For detailed implementation patterns, read the appropriate reference:

- **`references/hero-sections.md`** → Hero section formulas, scroll storytelling, cinematic intros
- **`references/motion-patterns.md`** → Full animation pattern library with code
- **`references/saas-components.md`** → Feature grids, pricing tables, testimonials, navbars
- **`references/premium-effects.md`** → Glassmorphism, gradients, shadows, 3D CSS, particle systems
- **`references/battle-tested-patterns.md`** → Production-validated patterns: 6-layer motion hierarchy, spring physics, clip-path reveals
- **`references/ginyboi-motion-patterns.md`** → 183 motion design patterns with CSS/Framer Motion/GSAP implementations
- **`references/anti-vibe-code.md`** → Anti-patterns from 500 vibe-coded sites, pre-ship checklist, premium standard
- **`references/particle-systems.md`** → tsParticles setup, 5 ready-to-use configs, performance rules, anti-patterns
- **`references/emil-design-eng.md`** → Emil Kowalski's animation decision framework, custom easing curves, spring config, clip-path techniques, WAAPI, @starting-style, review format, Sonner principles

---

## Anti-Vibe-Code Guardrails

Based on analysis of 500 vibe-coded websites. Run this check before declaring any frontend work complete.

**Automatic disqualifiers** (any one = revise before shipping):
- Purple/neon gradients with no brand justification
- Sparkle emojis or emojis as UI elements
- Generic taglines ("Build your dreams", "Launch faster")
- Fake testimonials or placeholder content
- Non-functional interactive elements (dead links, broken toggles)
- Mixed border radiuses or inconsistent spacing

**Required for premium output:**
- 4pt or 8pt spacing system applied everywhere
- One font pair with defined type ramp
- Loading states for all async actions
- Complete meta tags (title, description, OG image, favicon)
- Mobile-tested at 320px, 375px, 768px, 1024px

Full anti-pattern library: `references/anti-vibe-code.md`

---

## 2026 Design Philosophy

Premium = restraint + finish, not flashiness. Slow motion. Micro-detail. Purposeful 3D. Warm minimalism. Performance = aesthetic.

**Mental Model:** Emotion → Narrative → System → Motion → Performance → Adaptivity

---

## Step -1: Design Token Extraction (Dembrandt)

When a user provides a **reference URL**, extract design tokens before generating mockups.

### Flow

1. Run: `kit extract-design-tokens.sh "<URL>"`
2. Review extracted tokens (colors, fonts, spacing) with user
3. Feed token summary into Step 0 prompt (palette + typography guidance)
4. Pass full token JSON to Steps 1-4 as design constraints

### Token-Informed Mockup Prompt (Step 0)

Include in the Gemini image prompt:
> Use these colors from the reference: Primary {hex}, Accent {hex}, Background {hex}.
> Typography: {display_font} for headings, {body_font} for body text.

### Integration

| Step | Token Usage |
|------|------------|
| 0 (Mockup) | Colors + fonts guide visual direction |
| 1 (Brief) | Full token JSON as design constraints |
| 2 (Code) | CSS variables generated from exact token values |
| 3 (Review) | Validates CSS references match token definitions |
| 4 (Opus) | Final check: all values sourced from tokens |

Tokens cached per domain (24h TTL) in `.claude/.design-tokens-cache/`.
Use `--force` to re-extract. **Skip this step if no reference URL provided.**

---

## Figma Make — Editable Motion Graphics

For animated explainers where editability matters more than AI video generation speed:

**Why Figma Make over AI video gen:** AI video tools (Sora, Runway) produce non-editable outputs — changing one word means regenerating the entire video. Figma Make generates code-based motion graphics that remain fully editable.

### Workflow

1. **Prompt + reference image** → Figma Make generates editable motion graphic
2. **Review and tweak** — adjust timing, colors, text directly in the design
3. **Export** — as video, GIF, or Lottie JSON for web embedding

### Integration with Kit

```
Figma Make (editable motion) → Export frames/Lottie → Remotion (compose with audio + transitions) → MP4
```

Use `mcp__claude_ai_Figma__get_design_context` to pull Figma designs into code. For motion graphics specifically, Figma Make preserves editability that pure AI video gen sacrifices.

**Decision:** Use Figma Make for explainers, tutorials, product demos. Use AI video gen (Gemini/LTX-2) for cinematic/realistic footage where editability isn't needed.

---

## Execution Pipeline (Opus-First)

**Default:**
1. Design Thinking (Phase 1-4)
2. Workers generate code
3. Opus integrates

**Optional MCP tools (use when adding value):**
- `gemini-generate-image` — 4K mockup (~$0.01)
- `openai_chat` — Code quality ($1.75/$14 per M)
- `chat_completion` — UX reasoning ($0.14/$0.42 per M)

Use when: user wants visual preview, second opinion helps, design is complex.

### When to Generate a Mockup First

Use `mcp__gemini__gemini-generate-image` (4K, 16:9) when:
- Building a completely new design with no reference
- User hasn't specified a clear aesthetic direction
- User explicitly asks for a preview

Skip the mockup when:
- User has a reference URL or existing design
- User wants speed over visual preview
- Iterating on an existing page

## Quick-Start Patterns

| Pattern | Approach |
|---------|----------|
| Static landing page | Phase 1-4 design thinking, workers gen code, Opus integrates |
| Animated product demo | Plan scenes first (Phase 3C), implement layer by layer |
| React component | Framer Motion + Tailwind + unique visual identity |
| Scroll storytelling | GSAP ScrollTrigger, pinned sections, timeline per scene |

**Quality lever:** Scene decomposition → Motion hierarchy → Precise timing/easing → Single strong aesthetic
