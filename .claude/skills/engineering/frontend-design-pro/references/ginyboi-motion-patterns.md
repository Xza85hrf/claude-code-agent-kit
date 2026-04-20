# ginyboi Motion Design Patterns — Frontend Implementation Guide

> Extracted from @ginyboi Instagram (183 Reels). Gin Lee's specialty: premium motion graphics
> with tactile textures, collage aesthetics, cinematic typography, and 3D-inspired web effects.
> Every pattern includes CSS/Framer Motion/GSAP implementation.

---

## Pattern 1: Digital Collage Animation (Cutout Parallax)

**What:** Layered 2D photo cutouts with rough edges creating a "pop-up book" depth effect.
Each layer moves at different speeds on scroll (multi-plane parallax).

**Visual signature:** Paper texture backgrounds, visible "cut" edges, scale distortion
(giant person next to tiny landmark), surrealist composition.

**Frontend implementation:**

```jsx
// Framer Motion parallax layers
const { scrollYProgress } = useScroll()
const bgY = useTransform(scrollYProgress, [0, 1], ["0%", "10%"])
const midY = useTransform(scrollYProgress, [0, 1], ["0%", "-15%"])
const fgY = useTransform(scrollYProgress, [0, 1], ["0%", "-30%"])

<div className="relative overflow-hidden">
  <motion.div style={{ y: bgY }} className="absolute inset-0">
    {/* Background texture layer */}
  </motion.div>
  <motion.div style={{ y: midY }} className="absolute inset-0">
    {/* Mid-ground cutout elements */}
  </motion.div>
  <motion.div style={{ y: fgY }} className="relative z-10">
    {/* Foreground subject */}
  </motion.div>
</div>
```

**CSS cutout effect:**
```css
.cutout-element {
  filter: drop-shadow(5px 5px 0px white); /* Sticker outline */
  clip-path: polygon(5% 10%, 90% 2%, 98% 90%, 5% 95%); /* Rough edges */
}
```

---

## Pattern 2: Tactile Data Visualization (Animated Bar Comparisons)

**What:** Pricing/comparison bars with stop-motion texture. "Red = expensive" grows first,
then "Green = affordable" appears much shorter. Bars have fuzzy/marker edges on paper grid.

**Visual signature:** Crumpled paper grid background, crayon-edge bars, spring overshoot,
sticker-style price labels that pop in after bars grow.

**Frontend implementation:**

```jsx
// Framer Motion spring bar growth
<motion.div
  initial={{ height: 0 }}
  whileInView={{ height: "300px" }}
  transition={{ type: "spring", stiffness: 100, damping: 15, delay: 0.2 }}
  className="bg-red-700 rounded-sm"
  style={{ filter: "url(#rough-edge)" }}
/>

// GSAP staggered bars + labels
gsap.from(".bar", {
  height: 0, duration: 1.2,
  ease: "back.out(1.7)", // Overshoot bounce
  stagger: 0.3,
})
gsap.from(".label", {
  scale: 0, opacity: 0, delay: 1, duration: 0.5,
  ease: "elastic.out(1, 0.3)"
})
```

**Paper texture overlay:**
```css
.texture-overlay {
  position: absolute; inset: 0;
  background: url('/textures/grain.png');
  mix-blend-mode: overlay;
  opacity: 0.3;
  pointer-events: none;
}
```

---

## Pattern 3: Mixed-Media Collage Layout

**What:** Newspaper/editorial background with overlaid photos, speech bubbles,
and graphic stickers. Heterogeneous layering with asymmetrical balance.

**Visual signature:** Vintage newsprint texture, cut-out photos with rough masks,
comic-style callout boxes, receipts/documents as props.

**Frontend implementation:**

```css
.collage-container {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  grid-template-rows: repeat(10, 1fr);
  background-image: url('newspaper-texture.jpg');
}

.item-primary {
  grid-column: 4 / 9;
  grid-row: 3 / 9;
  z-index: 10;
  transform: rotate(-5deg); /* Messy collage feel */
}

.receipt-image {
  mix-blend-mode: multiply; /* Blends with background texture */
  opacity: 0.9;
}
```

---

## Pattern 4: Claymorphism / Toymorphism

**What:** Isometric 3D perspective with soft pastel colors and "clay/toy" materiality.
Objects look squishy, rounded, warm — like a miniature diorama.

**Visual signature:** High border-radius (20-40px), no pure blacks, layered inset shadows,
HSL pastels (S:60-80%, L:80-90%), global illumination lighting.

**Frontend implementation:**

```css
.clay-card {
  border-radius: 24px;
  background: hsl(350, 70%, 85%); /* Pastel pink */
  box-shadow:
    10px 10px 20px rgba(0,0,0,0.1),        /* Outer soft shadow */
    inset -5px -5px 15px rgba(0,0,0,0.05),  /* Inner depth */
    inset 5px 5px 15px rgba(255,255,255,0.8); /* Inner highlight */
}

/* Hover: "squish" instead of lift */
.clay-card:hover {
  transform: scale(1.05, 0.95);
  transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

/* Isometric perspective */
.scene { perspective: 800px; }
.isometric-object {
  transform: rotateX(45deg) rotateZ(-45deg);
  transform-style: preserve-3d;
}
```

---

## Pattern 5: Kinetic Typography (Staggered Word Reveal)

**What:** Text appears word-by-word with spring physics. Bold keywords vs light context words
create visual hierarchy even during animation.

**Visual signature:** Dark background, centered white text, mixed font weights,
words slide up from below with slight blur, spring damping.

**Frontend implementation:**

```jsx
const headlineContainer = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.1, delayChildren: 0.04 } },
}

const wordReveal = {
  hidden: { opacity: 0, y: 20, filter: "blur(4px)" },
  visible: {
    opacity: 1, y: 0, filter: "blur(0px)",
    transition: { type: "spring", damping: 12, stiffness: 100 },
  },
}

// Bold keywords for hierarchy
const getBold = (word) =>
  ["AI", "business", "partner"].includes(word) ? "font-black" : "font-light"

<motion.h1 variants={headlineContainer} initial="hidden" animate="visible">
  {words.map((word, i) => (
    <motion.span key={i} variants={wordReveal} className={`inline-block mr-3 ${getBold(word)}`}>
      {word}
    </motion.span>
  ))}
</motion.h1>
```

---

## Pattern 6: Chromatic Aberration Typography

**What:** RGB color channel split on text, creating a "broken lens" / glitch effect.
Cyan shifts left, magenta/red shifts right. Optional jitter animation.

**Visual signature:** White base text, colored offset shadows, wide letter-spacing,
subtle blur "bloom", works best on dark backgrounds with atmospheric imagery.

**Frontend implementation (3 approaches):**

```css
/* Quick: text-shadow */
.chroma-text {
  color: white;
  font-weight: 900;
  letter-spacing: 0.15em;
  text-shadow:
    -3px 0px 0px rgba(0, 255, 255, 0.8),  /* Cyan left */
     3px 0px 0px rgba(255, 0, 80, 0.8);   /* Magenta right */
  filter: blur(0.5px) drop-shadow(0 0 10px rgba(255,255,255,0.4)); /* Bloom */
}

/* Pro: pseudo-elements with mix-blend-mode */
.glitch { position: relative; color: white; }
.glitch::before {
  content: attr(data-text);
  position: absolute; left: -2px; top: 0;
  color: cyan;
  mix-blend-mode: screen;
  animation: jitter 3s infinite alternate;
}
.glitch::after {
  content: attr(data-text);
  position: absolute; left: 2px; top: 0;
  color: #ff0050;
  mix-blend-mode: screen;
  animation: jitter 2s infinite alternate-reverse;
}

@keyframes jitter {
  0% { left: -2px; } 20% { left: -4px; transform: skew(1deg); } 100% { left: -1px; }
}
```

---

## Pattern 7: Cinematic Editorial Hero

**What:** 21:9 widescreen "letterboxed" hero with atmospheric photography.
Subject placed on right-third, left side reserved for typography.
Anamorphic lens flares and grain overlay.

**Visual signature:** Black letterbox bars, rule of thirds, high-contrast serif/sans pairing,
"cover reveal" text animations, parallax on scroll.

**Frontend implementation:**

```css
.editorial-hero {
  position: relative;
  background: black;
  display: flex;
  align-items: center;
  height: 100vh;
}

.widescreen-container {
  width: 100%;
  aspect-ratio: 21 / 9; /* Creates letterbox bars */
  position: relative;
  overflow: hidden;
}

.hero-image {
  width: 100%; height: 100%;
  object-fit: cover;
  object-position: 80% center; /* Keep subject on right */
}

/* Lens flare overlay */
.lens-flare {
  position: absolute; inset: 0;
  background: radial-gradient(ellipse at 70% 40%, rgba(255,200,100,0.15), transparent 60%);
  mix-blend-mode: screen;
}

/* Responsive: switch from 21:9 to 4:5 on mobile */
@media (max-width: 768px) {
  .widescreen-container { aspect-ratio: 4 / 5; }
  .hero-image { object-position: center 30%; }
}
```

---

## Pattern 8: Glassmorphism + Neon 3D Geometry

**What:** Frosted glass shapes floating in space with colored glow auras.
Multiple radial gradients create "gradient mesh" backgrounds.
CSS 3D transforms for rotating cubes/diamonds.

**Visual signature:** Low-opacity white backgrounds, backdrop-filter blur, thin white borders,
multi-layered box-shadows for bloom, dark base color, vibrant accent glows.

**Frontend implementation:**

```css
/* Glass surface */
.glass-shape {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(15px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 15px;
}

/* Neon glow bloom (3 layers) */
.neon-glow {
  box-shadow:
    inset 0 0 15px rgba(255, 0, 255, 0.5),  /* Inner glow */
    0 0 20px rgba(255, 0, 255, 0.6),          /* Medium bloom */
    0 0 60px rgba(255, 0, 255, 0.3);           /* Wide aura */
}

/* Gradient mesh background */
.mesh-bg {
  background-color: #1a1a2e;
  background-image:
    radial-gradient(at 20% 30%, rgba(255,0,255,0.4) 0px, transparent 50%),
    radial-gradient(at 80% 70%, rgba(0,255,255,0.4) 0px, transparent 50%),
    radial-gradient(at 50% 10%, rgba(0,255,0,0.3) 0px, transparent 40%);
}

/* 3D rotating cube */
.scene { perspective: 800px; }
.cube {
  transform-style: preserve-3d;
  animation: rotate 10s infinite linear;
}
@keyframes rotate {
  from { transform: rotateX(0) rotateY(0); }
  to { transform: rotateX(360deg) rotateY(360deg); }
}
```

---

## Cross-Cutting Techniques (Used Across All Patterns)

### Noise/Grain Texture Overlay
```css
.noise-overlay::after {
  content: '';
  position: absolute; inset: 0;
  background-image: url("data:image/svg+xml,..."); /* Inline SVG noise */
  opacity: 0.03;
  mix-blend-mode: overlay;
  pointer-events: none;
}
```

### Spring Physics (Framer Motion defaults)
```jsx
transition: { type: "spring", stiffness: 200, damping: 25 }  // Snappy
transition: { type: "spring", stiffness: 100, damping: 15 }  // Bouncy
transition: { type: "spring", stiffness: 50, damping: 10 }   // Floaty
```

### Scroll-Triggered Reveals
```jsx
const { ref, inView } = useInView({ threshold: 0.2, triggerOnce: true })
<motion.div
  ref={ref}
  initial={{ opacity: 0, y: 30 }}
  animate={inView ? { opacity: 1, y: 0 } : {}}
  transition={{ duration: 0.6 }}
/>
```

### Mix-Blend-Mode Cheatsheet
| Mode | Use Case |
|------|----------|
| `multiply` | Blend images into dark textures |
| `screen` | Light effects, lens flares, neon |
| `overlay` | Grain/noise textures |
| `soft-light` | Subtle color tinting |

---

## Pattern 9: 3D Squash & Stretch (Soft-Body Physics)

**What:** 3D objects with rubbery deformation — squash on impact, stretch during motion.
Objects "pop" open into sub-elements that scatter with physics-based trajectories.

**Visual signature:** Pastel high-key lighting, soft ambient occlusion, motion blur on fast
elements, cream/yellow backgrounds, no harsh shadows.

**Frontend implementation:**

```jsx
// GSAP squash-stretch with overshoot
gsap.to(".bouncing-element", {
  y: 0,
  scaleX: 1.2, scaleY: 0.8, // Squash at bottom
  duration: 0.15,
  ease: "power2.in",
  onComplete: () => {
    gsap.to(".bouncing-element", {
      scaleX: 0.85, scaleY: 1.15, // Stretch on rebound
      y: -100,
      duration: 0.3,
      ease: "power2.out",
    })
  }
})

// Particle burst: items scatter from center
gsap.from(".burst-item", {
  scale: 0, opacity: 0,
  x: 0, y: 0, // Start at center
  duration: 0.6,
  ease: "back.out(2)",
  stagger: { each: 0.05, from: "center" },
})
```

```css
/* Pastel high-key styling */
.soft-body-scene {
  background: #FFF8E7; /* Warm cream */
}
.soft-element {
  border-radius: 20px;
  box-shadow:
    0 4px 12px rgba(0,0,0,0.08),      /* Contact shadow */
    inset 0 2px 4px rgba(255,255,255,0.9); /* Inner highlight */
}
```

---

## Pattern 10: Glitch Reveal on Grid

**What:** Text enters with rapid position jitter (digital glitch), then settles.
Background uses a mathematical grid pattern. Clean, "blueprint" aesthetic.

**Visual signature:** Black-on-white high contrast, grid background via CSS gradients,
geometric sans-serif, centered dead-center, glitch lasts <300ms.

**Frontend implementation:**

```css
/* Grid background */
.grid-stage {
  background-color: #f8f8f8;
  background-image:
    linear-gradient(to right, #e0e0e0 1px, transparent 1px),
    linear-gradient(to bottom, #e0e0e0 1px, transparent 1px);
  background-size: 40px 40px;
}

/* Glitch jitter */
@keyframes glitch-jitter {
  0%   { transform: translate(0); }
  20%  { transform: translate(-3px, 2px) skew(0.5deg); }
  40%  { transform: translate(3px, -2px) skew(-0.5deg); }
  60%  { transform: translate(-2px, -1px); }
  80%  { transform: translate(2px, 1px) skew(0.3deg); }
  100% { transform: translate(0); }
}

.glitch-word {
  animation: glitch-jitter 0.15s steps(1) 3; /* 3 rapid cycles */
}
```

```jsx
// GSAP precision glitch + stagger
const tl = gsap.timeline()
tl.from(".glitch-word", {
  duration: 0.08,
  opacity: 0,
  x: () => gsap.utils.random(-5, 5),
  y: () => gsap.utils.random(-5, 5),
  repeat: 4,
  yoyo: true,
  ease: "steps(1)",
})
tl.from(".rest-of-text", {
  opacity: 0, duration: 0.5, ease: "power2.out"
}, "-=0.15")
```

---

## Pattern 11: Duotone Cutout with Zine Typography

**What:** Subject treated with monochrome color wash, thick "sticker" outline, placed
in front of ultra-condensed typography that fills the vertical frame.

**Visual signature:** Absolute black background, green/blue/red duotone on subject,
hand-cut jittery outline, text BEHIND subject creating depth, heavy film grain.

**Frontend implementation:**

```css
/* Duotone via CSS filter */
.duotone-subject {
  filter: grayscale(1) sepia(1) hue-rotate(80deg) saturate(5) contrast(1.2);
}

/* Sticker outline via stacked drop-shadows */
.cutout-outline {
  filter:
    drop-shadow(3px 0 0 white) drop-shadow(-3px 0 0 white)
    drop-shadow(0 3px 0 white) drop-shadow(0 -3px 0 white);
}

/* Ultra-condensed text behind subject */
.bg-text {
  font-family: 'Bebas Neue', sans-serif;
  font-size: 30vw;
  position: absolute;
  z-index: 1; /* Behind subject at z-index: 2 */
  color: white;
  letter-spacing: -0.02em;
}

/* Film grain overlay */
.grain::after {
  content: '';
  position: absolute; inset: 0;
  background: url('/textures/grain.png');
  mix-blend-mode: overlay;
  opacity: 0.06;
  pointer-events: none;
}
```

```jsx
// Stop-motion jitter on subject
useEffect(() => {
  const interval = setInterval(() => {
    setJitter({
      x: Math.random() * 4 - 2,
      y: Math.random() * 4 - 2,
      rotate: Math.random() * 2 - 1,
    })
  }, 100) // Update every 100ms for stop-motion feel
  return () => clearInterval(interval)
}, [])
```

---

## Pattern 12: Polaroid Pendulum Physics

**What:** Photos hung on wire/clips with constrained pendulum swing. Depth-of-field
blur on background elements. Iridescent/holographic material on clips.

**Visual signature:** Skeuomorphic (digital objects look physical), warm golden lighting
from photo content, soft bokeh on secondary elements, Blackletter + Modern Serif pairing.

**Frontend implementation:**

```css
/* Pendulum swing anchor */
.polaroid {
  transform-origin: top center;
  animation: pendulum 4s ease-in-out infinite alternate;
}
@keyframes pendulum {
  from { transform: rotate(-2deg); }
  to   { transform: rotate(2deg); }
}

/* Iridescent material */
.holographic-clip {
  background: linear-gradient(120deg, #5de0e6, #004aad, #cb6ce1, #5de0e6);
  background-size: 300% 300%;
  animation: iridescence 5s ease infinite;
}
@keyframes iridescence {
  0%   { background-position: 0% 50%; }
  50%  { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

/* Depth-of-field blur on background elements */
.bg-photo { filter: blur(8px); opacity: 0.6; }
.fg-photo { filter: none; }

/* Warm glow from photo content */
.polaroid-frame {
  filter: drop-shadow(0 10px 30px rgba(255, 140, 0, 0.3));
}
```

```jsx
// GSAP organic sway (better than CSS for natural feel)
gsap.to(".polaroid", {
  rotation: 1.5,
  duration: 3,
  repeat: -1,
  yoyo: true,
  ease: "sine.inOut",
  transformOrigin: "top center",
})
```

---

## Pattern 13: Neon Logo Reveal (Block Masking)

**What:** Logo constructed through internal sliding blocks. Sub-elements translate
horizontally within a clipping mask to "build" the shape. Bloom/glow post-processing.

**Visual signature:** Deep charcoal background, emissive neon colors (purple/blue),
thin grid guidelines, SVG-based construction, light trails along edges.

**Frontend implementation:**

```css
/* Emissive glow (layered box-shadow) */
.neon-element {
  box-shadow:
    0 0 10px rgba(123, 94, 255, 0.6),   /* Tight glow */
    0 0 30px rgba(123, 94, 255, 0.3),   /* Medium bloom */
    0 0 60px rgba(123, 94, 255, 0.15);  /* Wide aura */
}

/* SVG line-draw reveal */
.logo-path {
  stroke-dasharray: 1000;
  stroke-dashoffset: 1000;
  animation: draw-line 2s ease-out forwards;
}
@keyframes draw-line {
  to { stroke-dashoffset: 0; }
}

/* Block mask slide */
.mask-block {
  clip-path: inset(0 100% 0 0); /* Hidden */
  animation: reveal-block 0.8s cubic-bezier(0.77, 0, 0.175, 1) forwards;
}
@keyframes reveal-block {
  to { clip-path: inset(0 0 0 0); }
}
```

```jsx
// GSAP staggered block reveal
gsap.to(".mask-segment", {
  clipPath: "inset(0 0% 0 0)",
  duration: 0.8,
  stagger: 0.1,
  ease: "expo.inOut",
  repeat: -1,
  repeatDelay: 2,
})
```

---

## Pattern 14: Text-Behind-Subject Depth Layering

**What:** Typography placed between foreground subject and background, creating
a sandwich parallax effect. Subject partially occludes the text.

**Visual signature:** Large bold text at z-index 1, subject PNG at z-index 2,
background at z-index 0. Text uses gradient fills or outline strokes. Subject has
drop-shadow for separation.

**Frontend implementation:**

```html
<div class="depth-hero">
  <img class="bg-layer" src="background.jpg" />
  <h1 class="mid-text">HERO</h1>
  <img class="fg-subject" src="person-transparent.png" />
  <p class="top-text">subtitle here</p>
</div>
```

```css
.depth-hero { position: relative; overflow: hidden; }
.bg-layer   { position: absolute; inset: 0; z-index: 0; object-fit: cover; }
.mid-text   { position: absolute; z-index: 1; font-size: 20vw; font-weight: 900;
              color: transparent; -webkit-text-stroke: 3px white; }
.fg-subject { position: relative; z-index: 2;
              filter: drop-shadow(0 10px 30px rgba(0,0,0,0.4)); }
.top-text   { position: relative; z-index: 3; }
```

```jsx
// Mouse-reactive parallax (text moves slower than subject)
const { scrollYProgress } = useScroll()
const textY = useTransform(scrollYProgress, [0, 1], ["0%", "20%"])
const subjectY = useTransform(scrollYProgress, [0, 1], ["0%", "-10%"])

<motion.h1 style={{ y: textY }} className="mid-text">HERO</motion.h1>
<motion.img style={{ y: subjectY }} className="fg-subject" src="person.png" />
```

---

## Pattern 15: 3D Perspective Card Carousel

**What:** Cards fanned in 3D perspective — center card faces forward at full scale,
side cards rotated away with reduced scale and opacity. Hover/click shifts the active card.

**Visual signature:** CSS `perspective` container, `rotateY` on side cards, scale hierarchy
(center 1.0, sides 0.85), subtle shadow depth, optional reflection below.

**Frontend implementation:**

```css
.carousel { perspective: 1200px; display: flex; justify-content: center; gap: 0; }

.card {
  width: 200px; height: 300px;
  border-radius: 16px;
  transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
  box-shadow: 0 20px 40px rgba(0,0,0,0.3);
}

.card.left  { transform: translateX(40px) rotateY(25deg) scale(0.85); opacity: 0.7; z-index: 1; }
.card.center { transform: rotateY(0deg) scale(1); opacity: 1; z-index: 3; }
.card.right { transform: translateX(-40px) rotateY(-25deg) scale(0.85); opacity: 0.7; z-index: 1; }
```

```jsx
// Framer Motion carousel with drag
const [active, setActive] = useState(1)
const getTransform = (index) => {
  const offset = index - active
  return {
    rotateY: offset * 25,
    scale: offset === 0 ? 1 : 0.85,
    x: offset * 60,
    opacity: offset === 0 ? 1 : 0.7,
    zIndex: offset === 0 ? 3 : 1,
  }
}

{cards.map((card, i) => (
  <motion.div
    key={i}
    animate={getTransform(i)}
    transition={{ type: "spring", stiffness: 200, damping: 25 }}
    onClick={() => setActive(i)}
    className="card"
    style={{ transformStyle: "preserve-3d" }}
  />
))}
```

---

## Pattern 16: Flat-Color Marketing Collage (Product Ad Style)

**What:** Bold flat-color background with desaturated/grayscale cutout imagery,
mixed serif + sans-serif typography, animated dashed-line paths connecting elements.

**Visual signature:** Single saturated bg color (blue, coral, green), grayscale product photos
as cutouts, script/italic font for emotional words + bold condensed for impact words,
SVG dashed paths with `stroke-dashoffset` animation.

**Frontend implementation:**

```css
/* Flat color background + grayscale cutout */
.ad-stage { background: #4A7BF7; position: relative; overflow: hidden; }
.cutout-img { filter: grayscale(1); mix-blend-mode: luminosity; }

/* Mixed typography */
.emotional-word { font-family: 'Playfair Display', serif; font-style: italic; color: white; }
.impact-word { font-family: 'Bebas Neue', sans-serif; color: rgba(255,255,255,0.3);
               font-size: 8vw; text-transform: uppercase; }

/* Animated dashed flight path */
.flight-path {
  stroke: white; stroke-width: 2;
  stroke-dasharray: 8 8;
  fill: none;
  animation: dash-flow 2s linear infinite;
}
@keyframes dash-flow {
  to { stroke-dashoffset: -32; } /* Moves dashes along the path */
}
```

```jsx
// SVG animated path with airplane following it
<svg viewBox="0 0 400 300">
  <path d="M50,250 Q200,50 350,150" className="flight-path" />
  <motion.g
    initial={{ offsetDistance: "0%" }}
    animate={{ offsetDistance: "100%" }}
    transition={{ duration: 3, ease: "easeInOut" }}
    style={{ offsetPath: "path('M50,250 Q200,50 350,150')" }}
  >
    <text>✈</text>
  </motion.g>
</svg>
```

---

## When to Use Each Pattern

| Pattern | Best For | Complexity |
|---------|----------|------------|
| Collage Parallax | Hero sections, storytelling | Medium |
| Tactile Data Viz | Pricing, comparisons, stats | Low |
| Mixed-Media Collage | About pages, editorial | High |
| Claymorphism | Cards, CTAs, playful brands | Low |
| Kinetic Typography | Headlines, hero text | Low |
| Chromatic Aberration | Accent text, dark themes | Low |
| Cinematic Editorial | Hero sections, portfolio | Medium |
| Glassmorphism 3D | Backgrounds, hero accents | High |
| 3D Squash & Stretch | Product reveals, playful brands | Medium |
| Glitch Reveal on Grid | Tech brands, SaaS, dev tools | Low |
| Duotone Cutout + Zine | Fashion, music, editorial | Medium |
| Polaroid Pendulum | Photo galleries, about pages | Low |
| Neon Logo Reveal | Brand intros, splash screens | Medium |
| Text-Behind-Subject | Hero sections, personal brands | Medium |
| 3D Card Carousel | Feature showcases, testimonials | Medium |
| Flat-Color Ad Collage | Product marketing, landing CTAs | Low |
| Editorial Poster | Band pages, event promos, press kits | Medium |
| Chromatic Title Card | Dark-theme heroes, cinematic intros | Low |
| Horizontal Parallax | Scroll storytelling, timelines | Medium |
| 3D Gallery Wall | Portfolio, photo showcases, art exhibits | High |

---

## Pattern 17: Editorial Poster Layout
**Source:** C_T6VQtyctK frame 1 — Oasis reunion poster

Noise-textured background with oversized serif display type, B&W photo cutouts overlapping a circular color accent, plus editorial metadata (dates, barcodes, labels). Think concert posters, magazine covers, event landing pages.

**Visual Signature:** Grainy off-white canvas, massive serif headline, single-hue circle behind grayscale subject, micro-type metadata in corners, "DESIGN 01" label.

```css
/* Noise overlay via SVG filter */
.editorial-poster {
  position: relative;
  background: #f5f0eb;
  min-height: 100vh;
  overflow: hidden;
}
.editorial-poster::after {
  content: '';
  position: absolute; inset: 0;
  background: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200'%3E%3Cfilter id='n'%3E%3CfeTurbulence baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.08'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 10;
}

/* Circular color accent behind subject */
.color-accent {
  position: absolute;
  width: 45vw; height: 45vw;
  border-radius: 50%;
  background: #d4a843; /* Gold accent */
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  z-index: 1;
}

/* Oversized serif headline */
.poster-title {
  font-family: 'Playfair Display', serif;
  font-size: clamp(5rem, 15vw, 12rem);
  font-weight: 900;
  letter-spacing: -0.03em;
  color: #1a1a1a;
  z-index: 3;
}

/* B&W cutout subjects */
.subject-cutout {
  filter: grayscale(1) contrast(1.1);
  z-index: 2;
  mix-blend-mode: multiply;
}

/* Corner metadata */
.metadata { font-size: 0.65rem; letter-spacing: 0.15em; text-transform: uppercase; }
```

```jsx
<motion.div className="editorial-poster">
  <motion.h1
    className="poster-title"
    initial={{ y: 80, opacity: 0 }}
    animate={{ y: 0, opacity: 1 }}
    transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
  >
    OASIS
  </motion.h1>
  <motion.div
    className="color-accent"
    initial={{ scale: 0 }}
    animate={{ scale: 1 }}
    transition={{ duration: 0.6, delay: 0.2 }}
  />
  <motion.img
    src="/subject.png"
    className="subject-cutout"
    initial={{ y: 100, opacity: 0 }}
    animate={{ y: 0, opacity: 1 }}
    transition={{ duration: 0.7, delay: 0.3 }}
  />
  <span className="metadata top-left">CREATION RECORDS</span>
  <span className="metadata top-right">27.08.24</span>
  <span className="metadata bottom-left">DESIGN 01</span>
</motion.div>
```

---

## Pattern 18: Chromatic Aberration Title Card
**Source:** C_T6VQtyctK frame 2 — "STARS" cinematic poster

RGB channel-split text glowing over a dark cinematic scene with atmospheric fog, reflective surfaces, and editorial metadata. Ideal for dark-theme hero sections, film/music promos, or dramatic brand intros.

**Visual Signature:** Dark atmospheric background, large chromatic-aberration text, thin spaced metadata in corners, warm practical lighting (headlights/glow), low-angle composition.

```css
/* Chromatic aberration text via layered text-shadows */
.chromatic-title {
  font-size: clamp(4rem, 12vw, 10rem);
  font-weight: 800;
  color: white;
  text-shadow:
    -3px 0 rgba(255, 0, 0, 0.7),
     3px 0 rgba(0, 100, 255, 0.7),
     0 0 20px rgba(255, 255, 255, 0.3);
  letter-spacing: 0.05em;
}

/* Animated chromatic split */
@keyframes chromatic-pulse {
  0%, 100% {
    text-shadow:
      -3px 0 rgba(255, 0, 0, 0.7),
       3px 0 rgba(0, 100, 255, 0.7),
       0 0 20px rgba(255, 255, 255, 0.3);
  }
  50% {
    text-shadow:
      -5px 0 rgba(255, 0, 0, 0.9),
       5px 0 rgba(0, 100, 255, 0.9),
       0 0 40px rgba(255, 255, 255, 0.5);
  }
}
.chromatic-title:hover {
  animation: chromatic-pulse 2s ease-in-out infinite;
}

/* Cinematic dark card */
.cinematic-card {
  position: relative;
  background: #0a0a0a;
  overflow: hidden;
  min-height: 100vh;
}

/* Atmospheric fog gradient from bottom */
.cinematic-card::before {
  content: '';
  position: absolute;
  bottom: 0; left: 0; right: 0;
  height: 60%;
  background: linear-gradient(to top, rgba(10,10,10,0.95), transparent);
  z-index: 2;
}

/* Metadata row */
.card-meta {
  display: flex; justify-content: space-between;
  font-size: 0.6rem; letter-spacing: 0.25em; text-transform: uppercase;
  color: rgba(255,255,255,0.5);
  padding: 1.5rem;
}
```

```jsx
<motion.div className="cinematic-card">
  <img src="/scene.jpg" style={{ objectFit: 'cover', width: '100%', height: '100%' }} />
  <div className="card-meta">
    <span>VULTURES VOL.1</span>
    <span>¥$</span>
    <span>09 FEB 2024</span>
  </div>
  <motion.h1
    className="chromatic-title"
    initial={{ scale: 1.2, opacity: 0, filter: 'blur(10px)' }}
    animate={{ scale: 1, opacity: 1, filter: 'blur(0px)' }}
    transition={{ duration: 1, ease: [0.16, 1, 0.3, 1] }}
  >
    STARS
  </motion.h1>
  <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '0.8rem', maxWidth: '40ch' }}>
    Body text appears below the title with a gentle fade.
  </p>
  <span className="card-meta" style={{ position: 'absolute', bottom: '1.5rem' }}>
    DESIGN 02 — CREATED BY GIN
  </span>
</motion.div>
```

---

## Pattern 19: Horizontal Parallax Cityscape
**Source:** DF6kLmhRNL- frame 1 — Miami sunset drive

Multi-layer flat-vector scene where each depth layer scrolls at a different speed. Background (sky/buildings) barely moves, midground (road/palm trees) scrolls medium, foreground (car/exhaust) scrolls fastest. Creates cinematic depth from 2D art.

**Visual Signature:** Sunset gradient sky, flat-colored silhouette buildings, parallax palm trees, animated vehicle with exhaust particles, road with lane markings.

```css
/* Parallax container with perspective */
.parallax-scene {
  height: 100vh;
  overflow: hidden;
  perspective: 1px;
  perspective-origin: center center;
}

/* Layer depth via translateZ + scale compensation */
.layer-sky {
  transform: translateZ(-3px) scale(4);
  z-index: 1;
}
.layer-buildings {
  transform: translateZ(-2px) scale(3);
  z-index: 2;
}
.layer-road {
  transform: translateZ(-0.5px) scale(1.5);
  z-index: 3;
}
.layer-car {
  transform: translateZ(0);
  z-index: 4;
}

/* Sunset gradient background */
.sunset-sky {
  background: linear-gradient(
    to bottom,
    #4a1a6b 0%,    /* Deep purple top */
    #8b3a8f 25%,   /* Purple-pink */
    #e85d4a 50%,   /* Warm orange-red */
    #f4a534 75%,   /* Golden orange */
    #f8d76e 100%   /* Yellow horizon */
  );
}

/* Road lane animation */
@keyframes road-scroll {
  from { transform: translateX(0); }
  to { transform: translateX(-200px); }
}
.lane-markings {
  background: repeating-linear-gradient(
    90deg, #f4a534 0px, #f4a534 40px, transparent 40px, transparent 80px
  );
  height: 3px;
  animation: road-scroll 0.5s linear infinite;
}
```

```jsx
// Scroll-driven parallax with Framer Motion
const { scrollYProgress } = useScroll();
const skyY = useTransform(scrollYProgress, [0, 1], [0, -50]);
const buildingsY = useTransform(scrollYProgress, [0, 1], [0, -150]);
const roadX = useTransform(scrollYProgress, [0, 1], [0, -400]);
const carX = useTransform(scrollYProgress, [0, 1], [0, -600]);

<div className="parallax-scene">
  <motion.div className="layer-sky sunset-sky" style={{ y: skyY }} />
  <motion.div className="layer-buildings" style={{ y: buildingsY }}>
    {/* SVG silhouette buildings */}
  </motion.div>
  <motion.div className="layer-road" style={{ x: roadX }}>
    <div className="lane-markings" />
  </motion.div>
  <motion.div className="layer-car" style={{ x: carX }}>
    {/* Car SVG + exhaust particle emitter */}
  </motion.div>
</div>
```

---

## Pattern 20: 3D Gallery Wall
**Source:** DGfGuCINFzW frame 1 — Übermensch art gallery

Physical prints clipped to strings on a textured brick wall, with real-world lighting, depth-of-field on background pieces, and blackletter typography overlaying the art. Creates museum/exhibition atmosphere for portfolio or showcase sections.

**Visual Signature:** Brick/concrete wall texture, binder-clip hanging mechanism, white-border polaroid frames, selective depth-of-field blur, warm directional lighting, blackletter/fraktur type overlay.

```css
/* Brick wall texture background */
.gallery-wall {
  background:
    url('/textures/brick-dark.jpg') center/cover,
    #2a1a1a;
  min-height: 100vh;
  perspective: 800px;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 3rem;
}

/* Physical print frame */
.gallery-print {
  background: white;
  padding: 0.8rem 0.8rem 2.5rem;
  box-shadow:
    0 8px 32px rgba(0,0,0,0.4),
    0 2px 8px rgba(0,0,0,0.2);
  transform: rotate(var(--tilt, 0deg));
  transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.gallery-print:hover {
  transform: rotate(0deg) scale(1.05) translateZ(20px);
}

/* Clip mechanism */
.gallery-print::before {
  content: '';
  position: absolute;
  top: -12px; left: 50%;
  width: 24px; height: 12px;
  background: linear-gradient(135deg, #666 0%, #999 50%, #555 100%);
  border-radius: 2px 2px 0 0;
  transform: translateX(-50%);
}

/* String/wire */
.gallery-print::after {
  content: '';
  position: absolute;
  top: -60px; left: 50%;
  width: 1px; height: 60px;
  background: #555;
  transform: translateX(-50%);
}

/* Depth-of-field on background items */
.gallery-print.background {
  filter: blur(2px) brightness(0.7);
  transform: scale(0.6) translateZ(-100px);
}

/* Blackletter overlay */
.gallery-title {
  font-family: 'UnifrakturMaguntia', cursive;
  color: white;
  font-size: 2rem;
  text-shadow: 0 2px 8px rgba(0,0,0,0.6);
  position: absolute;
  z-index: 5;
}
```

```jsx
// Interactive gallery with Framer Motion
const prints = [
  { src: '/art1.jpg', tilt: -3, depth: 'foreground' },
  { src: '/art2.jpg', tilt: 2, depth: 'foreground' },
  { src: '/art3.jpg', tilt: -1, depth: 'background' },
];

<div className="gallery-wall">
  {prints.map((print, i) => (
    <motion.div
      key={i}
      className={`gallery-print ${print.depth}`}
      style={{ '--tilt': `${print.tilt}deg` }}
      initial={{ y: -100, opacity: 0, rotateX: 15 }}
      whileInView={{ y: 0, opacity: 1, rotateX: 0 }}
      transition={{
        type: 'spring', stiffness: 80, damping: 15,
        delay: i * 0.15
      }}
      whileHover={{ scale: 1.08, rotateZ: 0 }}
    >
      <img src={print.src} alt="" />
      <motion.span className="gallery-title">
        Übermensch
      </motion.span>
      <span style={{ fontSize: '0.7rem', color: '#999' }}>2025.02.25</span>
    </motion.div>
  ))}
</div>
```
