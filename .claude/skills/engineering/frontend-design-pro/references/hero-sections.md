# Hero Section Formulas & Scroll Storytelling

## The Modern SaaS Hero Formula

A premium hero section (2026 standard) combines:

1. **Cinematic background** — 3D scene, gradient mesh, or animated environment
2. **Strong typographic anchor** — display font, expressive hierarchy
3. **Interactive or animated demo element** — showing the product in motion
4. **Subtle scroll cue** — not cheesy; a quiet affordance

---

## Hero Pattern A: Gradient + Blur Glass (Fast, Beautiful)

```html
<section class="hero">
  <div class="hero-bg"></div>
  <div class="hero-content">
    <p class="eyebrow">Tagline here</p>
    <h1>Headline that<br><span class="accent">changes everything</span></h1>
    <p class="sub">Supporting copy, one short idea.</p>
    <div class="cta-group">
      <button class="btn-primary">Get started</button>
      <button class="btn-ghost">See how it works ↓</button>
    </div>
  </div>
  <div class="hero-visual"><!-- product demo / 3D / image --></div>
</section>
```

```css
.hero {
  min-height: 100vh;
  display: grid;
  place-items: center;
  position: relative;
  overflow: hidden;
}
.hero-bg {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(ellipse 80% 60% at 20% 40%, rgba(120,80,255,0.15) 0%, transparent 70%),
    radial-gradient(ellipse 60% 80% at 80% 60%, rgba(0,200,150,0.1) 0%, transparent 70%),
    #050508;
  z-index: 0;
}
.hero-content {
  position: relative;
  z-index: 1;
  animation: heroReveal 1.2s cubic-bezier(0.16,1,0.3,1) both;
}
@keyframes heroReveal {
  from { opacity: 0; transform: translateY(32px); }
  to   { opacity: 1; transform: translateY(0); }
}
```

---

## Hero Pattern B: Split Layout (Left Text / Right Visual)

Works for: SaaS dashboards, dev tools, B2B products

```
[Typography block]          [Animated product screenshot / mockup]
Eyebrow                     ┌─────────────────────────────────┐
H1 Headline                 │  [Product UI with motion]        │
                            │                                  │
Supporting copy             │                                  │
                            └─────────────────────────────────┘
[CTA buttons]               Subtle glow / shadow beneath
```

Key motion: right visual enters with slight delay (0.3s) + upward drift
Typography: stagger each line 0.05s apart

---

## Hero Pattern C: Full-Width Cinematic (Video/3D Background)

```css
.hero-cinematic {
  height: 100vh;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
}
.hero-cinematic video,
.hero-cinematic canvas {
  position: absolute;
  inset: 0;
  width: 100%; height: 100%;
  object-fit: cover;
  opacity: 0.4; /* darken so text reads */
}
.hero-text {
  position: relative;
  z-index: 2;
  /* Large display type — 6rem+ */
}
```

---

## Scroll Storytelling: GSAP ScrollTrigger Pattern

For "Apple AirPods"-style scroll-driven animation:

```js
// Pin a section, animate content as user scrolls through it
gsap.timeline({
  scrollTrigger: {
    trigger: ".story-section",
    start: "top top",
    end: "+=200%",      // pin for 3 viewport heights
    pin: true,
    scrub: 1,           // smooth scrub (1 = 1s lag behind scroll)
  }
})
.from(".story-headline", { opacity: 0, y: 60 })
.from(".story-feature-1", { opacity: 0, x: -40 }, "+=0.2")
.from(".story-feature-2", { opacity: 0, x: 40 }, "<0.1")
.to(".story-headline", { opacity: 0, y: -40 }, "+=0.5")
.from(".story-product", { scale: 0.8, opacity: 0 });
```

### Frame Scrubbing (Video as Scroll Animation)
```js
// Extract frames from product video, scrub via scroll
const canvas = document.querySelector('canvas');
const ctx = canvas.getContext('2d');
const frames = []; // preloaded image objects

ScrollTrigger.create({
  trigger: ".frame-section",
  start: "top top",
  end: "bottom bottom",
  scrub: true,
  onUpdate: (self) => {
    const frameIndex = Math.floor(self.progress * (frames.length - 1));
    ctx.drawImage(frames[frameIndex], 0, 0);
  }
});
```

---

## Stagger Reveal System (CSS-only)

```css
.reveal-group > * {
  opacity: 0;
  transform: translateY(20px);
  animation: revealUp 0.7s cubic-bezier(0.16,1,0.3,1) forwards;
}
.reveal-group > *:nth-child(1) { animation-delay: 0.1s; }
.reveal-group > *:nth-child(2) { animation-delay: 0.2s; }
.reveal-group > *:nth-child(3) { animation-delay: 0.3s; }
.reveal-group > *:nth-child(4) { animation-delay: 0.4s; }

@keyframes revealUp {
  to { opacity: 1; transform: translateY(0); }
}
```

For scroll-triggered version, add `intersection-observer` to add `.is-visible` class, then trigger `animation` on `.is-visible .reveal-group > *`.
