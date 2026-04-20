# Battle-Tested Premium Patterns (AKORD v4 Redesign)

Patterns validated in production on a Polish accounting firm website redesign.
All patterns passed build + 250 tests + visual review.

---

## The 6-Layer Motion Hierarchy

Premium sites animate at different frequencies and triggers — never all at once.

| Layer | Trigger | Speed | Examples | Implementation |
|-------|---------|-------|----------|----------------|
| 1. CSS persistent | Always | Slow 3-8s | Breathing glows, marquee, shimmer, float | CSS `@keyframes` with `infinite` |
| 2. Scroll-driven | Scroll position | Continuous | Parallax images, progress bar | `useScroll` + `useTransform` / `useSpring` |
| 3. Viewport-triggered | Enter viewport | Once, 0.5-0.9s | Spring scale-in, clip-reveal | `useInView` + `animate={inView ? ... : {}}` |
| 4. Staggered entrance | Enter viewport | Sequential | Word-by-word, feature lists, CTA cascade | `variants` with `staggerChildren` |
| 5. Hover interactions | User hover | Instant spring | Card lift, icon rotate, image scale | `whileHover` with spring physics |
| 6. Structural rhythm | Static | N/A | Gold dividers, accent bars, separators | Pure CSS/HTML decorative elements |

**Rule**: Lower layers = slower/subtler. Higher layers = faster/more responsive.

---

## Spring Physics Constants (Framer Motion)

Always use `type: "spring"` for hover. Linear/ease-out feels robotic.

```tsx
// Cards and containers
whileHover={{ y: -6, transition: { type: "spring", stiffness: 300, damping: 20 } }}

// Icons and small elements
whileHover={{ scale: 1.15, rotate: 5, transition: { type: "spring", stiffness: 300, damping: 15 } }}

// Entrance animations (viewport-triggered)
transition={{ duration: 0.5, delay: 0.3, type: "spring", stiffness: 200 }}

// Scroll progress bar (physics-smoothed)
const scaleX = useSpring(scrollYProgress, { stiffness: 100, damping: 30, restDelta: 0.001 })
```

---

## Clip-Path Image Reveals

Curtain-style reveals look cinematic. Simple opacity fades look amateur.

```tsx
// Curtain from left (default) or right (reversed)
<motion.div
  initial={{ opacity: 0, clipPath: reversed ? "inset(0 0 0 100%)" : "inset(0 100% 0 0)" }}
  animate={inView ? { opacity: 1, clipPath: "inset(0 0 0 0)" } : {}}
  transition={{ duration: 0.9, delay: 0.1, ease: [0.25, 0.46, 0.45, 0.94] }}
>
```

The cubic bezier `[0.25, 0.46, 0.45, 0.94]` gives smooth deceleration.

---

## Staggered CTA Cascade

Don't animate the entire CTA as one unit. Stagger 4 elements for a waterfall effect:

```tsx
// 1. Gold divider draws in
<motion.div initial={{ opacity: 0, scaleX: 0 }} animate={inView ? { opacity: 1, scaleX: 1 } : {}}
  transition={{ duration: 0.8, ease: "easeOut" }} />

// 2. Heading slides up (delay 0.2)
<motion.h2 initial={{ opacity: 0, y: 30 }} animate={inView ? { opacity: 1, y: 0 } : {}}
  transition={{ duration: 0.6, delay: 0.2 }} />

// 3. Paragraph slides up (delay 0.35)
<motion.p initial={{ opacity: 0, y: 20 }} animate={inView ? { opacity: 1, y: 0 } : {}}
  transition={{ duration: 0.6, delay: 0.35 }} />

// 4. Button springs in (delay 0.5)
<motion.div initial={{ opacity: 0, scale: 0.9 }} animate={inView ? { opacity: 1, scale: 1 } : {}}
  transition={{ duration: 0.5, delay: 0.5, type: "spring", stiffness: 200 }} />
```

---

## Word-by-Word Headline Reveal

```tsx
const headlineContainer: Variants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.08, delayChildren: 0.2 } },
}

const wordReveal: Variants = {
  hidden: { opacity: 0, y: 20, filter: "blur(4px)" },
  visible: { opacity: 1, y: 0, filter: "blur(0px)", transition: { duration: 0.5, ease: "easeOut" } },
}

<motion.h1 variants={headlineContainer} initial="hidden" animate="visible">
  {title.split(" ").map((word, i) => (
    <motion.span key={i} variants={wordReveal} className="inline-block mr-[0.3em]">
      {word}
    </motion.span>
  ))}
</motion.h1>
```

The `filter: "blur(4px)"` → `"blur(0px)"` adds a subtle focus pull effect.

---

## Gold Accent System (Limited Palette Strategy)

When working with a constrained palette (3-4 colors), create rhythm through systematic accent placement:

| Element | Implementation | Purpose |
|---------|---------------|---------|
| Hero top bar | `h-1 bg-[var(--accent)]` absolute top | Brand signature |
| Section heading marker | `gold-divider-left` (2px × 3rem gradient) | Vertical rhythm |
| Section separator | Diamond or fade divider component | Visual breathing room |
| CTA buttons | Metallic gradient with hover shift | Consistent call-to-action |
| Background glows | Radial gradient, opacity 20-30% | Depth without distraction |
| Card border accent | `border-l-[3px] border-l-[var(--accent)]` | Subtle hierarchy |
| Text gradient | Extended gradient with `background-size: 200%` for shimmer | Premium typography |

---

## Three Textures for Depth

Flat backgrounds feel cheap. Apply these three techniques systematically:

### 1. Noise Overlay (all dark sections)
```css
.noise-overlay::after {
  content: "";
  position: absolute;
  inset: 0;
  opacity: 0.03;
  background-image: url("data:image/svg+xml,..."); /* SVG noise filter */
  pointer-events: none;
}
```

### 2. Glassmorphism (light cards)
```css
background: rgba(255, 255, 255, 0.5);
backdrop-filter: blur(4px);
border: 1px solid rgba(var(--accent-rgb), 0.1);
```

### 3. Gradient overlay (images)
```tsx
<div className="absolute inset-0 bg-gradient-to-t from-[var(--bg-dark)]/40 to-transparent" />
```

**Rule**: Every dark section gets noise. Every light card gets glass. Every image gets a gradient fade.

---

## Scroll Progress Bar

```tsx
"use client"
import { motion, useScroll, useSpring } from "framer-motion"

export function ScrollProgress() {
  const { scrollYProgress } = useScroll()
  const scaleX = useSpring(scrollYProgress, { stiffness: 100, damping: 30, restDelta: 0.001 })

  return (
    <motion.div
      style={{ scaleX }}
      className="fixed top-0 left-0 right-0 h-[3px] bg-[var(--accent)] origin-left z-[100]"
    />
  )
}
```

---

## Section Divider Component

Three variants for different contexts:

- **gold-fade**: Simple gradient line, animated `scaleX` on viewport entry
- **gold-diamond**: Gradient line with centered diamond accent (spring scale-in)
- **gold-wave**: SVG wave path with subtle stroke

Use diamond between major section transitions, fade between minor ones.

---

## Image Optimization Pipeline

1. Source/generate images
2. Compress with sharp-cli: `sharp input.jpg -resize 1200 -quality 80 -o output.jpg` (~100-150KB)
3. Generate blur placeholder: `sharp input.jpg -resize 8 -blur 5 -toBuffer base64`
4. Store in lookup map: `src/lib/image-blur-data.ts`
5. Use on all `<Image>`: `placeholder="blur" blurDataURL={blurDataURLs["key"]}`

---

## Anti-Patterns (Learned the Hard Way)

1. **Don't use serif fonts for professional services** — Playfair Display looked decorative, not authoritative. Sans-serif (Lato 900, tight tracking) conveys trust.
2. **Don't reuse images across pages** — Maintain separate image pools for hero, services, about.
3. **Don't debug font rendering beyond 3 attempts** — If it's a rendering engine issue (GPU, DPI), swap the font.
4. **Don't animate everything simultaneously** — Sequential stagger (0.1-0.15s between elements) creates order. Simultaneous = chaos.
5. **Don't use cold grays** — `#f5f5f5` feels clinical. `#f7f6f3` (warm off-white) feels premium.
6. **Don't forget test mocks** — Adding `motion.li` or new icon imports breaks tests. Always update framer-motion and icon library mocks.

---

## Accessibility Checklist for Motion-Heavy Sites

```css
@media (prefers-reduced-motion: reduce) {
  .gradient-animated, .gradient-shimmer, .animate-float,
  .text-shimmer-gold, .animate-pulse-subtle {
    animation: none;
  }
}
```

- `aria-hidden="true"` on all decorative elements (glows, dividers, overlays)
- Gold focus rings on interactive elements
- High-contrast mode fallback (solid backgrounds)
- Keyboard navigation support on all interactive cards
