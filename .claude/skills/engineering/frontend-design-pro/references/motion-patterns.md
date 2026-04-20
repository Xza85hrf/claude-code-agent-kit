# Motion Pattern Library

## Core Animation Properties (GPU-Safe Only)
Always animate: `transform`, `opacity`
Never animate: `width`, `height`, `top`, `left`, `margin`, `padding` (triggers layout)

---

## Easing Reference

```css
/* Cinematic ease-out — element decelerates naturally */
--ease-cinematic: cubic-bezier(0.16, 1, 0.3, 1);

/* Elastic / spring feel */
--ease-elastic: cubic-bezier(0.34, 1.56, 0.64, 1);

/* Quick snappy */
--ease-snap: cubic-bezier(0.4, 0, 0.2, 1);

/* Smooth sustained */
--ease-smooth: cubic-bezier(0.25, 0.46, 0.45, 0.94);

/* Premium deceleration */
--ease-premium: cubic-bezier(0.22, 1, 0.36, 1);
```

---

## Pattern: Fade + Rise (Universal Entry)

```css
@keyframes fadeRise {
  from { opacity: 0; transform: translateY(24px); }
  to   { opacity: 1; transform: translateY(0); }
}
.animate-in {
  animation: fadeRise 0.7s var(--ease-cinematic) both;
}
```

## Pattern: Blur Reveal (High-End Feel)

```css
@keyframes blurReveal {
  from { opacity: 0; filter: blur(8px); transform: scale(0.97); }
  to   { opacity: 1; filter: blur(0); transform: scale(1); }
}
.blur-reveal {
  animation: blurReveal 0.9s var(--ease-cinematic) both;
}
```

## Pattern: Slide In From Left/Right

```css
@keyframes slideInLeft {
  from { opacity: 0; transform: translateX(-32px); }
  to   { opacity: 1; transform: translateX(0); }
}
@keyframes slideInRight {
  from { opacity: 0; transform: translateX(32px); }
  to   { opacity: 1; transform: translateX(0); }
}
```

## Pattern: Scale Pop (CTAs, Cards)

```css
.card {
  transition: transform 0.25s var(--ease-elastic), box-shadow 0.25s ease;
}
.card:hover {
  transform: translateY(-4px) scale(1.01);
  box-shadow: 0 24px 48px rgba(0,0,0,0.25);
}
```

## Pattern: Glassmorphism

```css
.glass {
  background: rgba(255,255,255,0.06);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 16px;
}
/* Dark glass variant */
.glass-dark {
  background: rgba(0,0,0,0.3);
  backdrop-filter: blur(24px);
  border: 1px solid rgba(255,255,255,0.06);
}
```

## Pattern: Gradient Glow (Premium Accent)

```css
.glow-accent {
  position: relative;
}
.glow-accent::after {
  content: '';
  position: absolute;
  inset: -2px;
  background: linear-gradient(135deg, #7c3aed, #06b6d4);
  border-radius: inherit;
  z-index: -1;
  filter: blur(12px);
  opacity: 0.6;
  transition: opacity 0.3s ease;
}
.glow-accent:hover::after {
  opacity: 1;
}
```

## Pattern: Text Gradient

```css
.gradient-text {
  background: linear-gradient(135deg, #a78bfa 0%, #38bdf8 50%, #34d399 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
```

## Pattern: Shimmer Loading

```css
@keyframes shimmer {
  from { background-position: -200% 0; }
  to   { background-position: 200% 0; }
}
.shimmer {
  background: linear-gradient(90deg,
    rgba(255,255,255,0.0) 0%,
    rgba(255,255,255,0.08) 50%,
    rgba(255,255,255,0.0) 100%
  );
  background-size: 200% 100%;
  animation: shimmer 2s infinite;
}
```

## Pattern: Parallax Layers (Pure CSS)

```css
.parallax-container {
  perspective: 1000px;
  height: 100vh;
  overflow-y: scroll;
}
.layer-back   { transform: translateZ(-200px) scale(1.2); }
.layer-mid    { transform: translateZ(-100px) scale(1.1); }
.layer-front  { transform: translateZ(0); }
```

## Pattern: Number Counter (JS)

```js
function animateCounter(el, target, duration = 2000) {
  const start = performance.now();
  const update = (time) => {
    const progress = Math.min((time - start) / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3); // ease-out-cubic
    el.textContent = Math.floor(eased * target).toLocaleString();
    if (progress < 1) requestAnimationFrame(update);
  };
  requestAnimationFrame(update);
}
```

## Pattern: Framer Motion Stagger (React)

```jsx
import { motion } from 'framer-motion';

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08, delayChildren: 0.1 }
  }
};
const item = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.16,1,0.3,1] } }
};

<motion.ul variants={container} initial="hidden" animate="show">
  {items.map(i => <motion.li key={i} variants={item}>{i}</motion.li>)}
</motion.ul>
```

## Pattern: Framer Motion Page Transition (React)

```jsx
<AnimatePresence mode="wait">
  <motion.div
    key={location.pathname}
    initial={{ opacity: 0, y: 16 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, y: -16 }}
    transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
  >
    {children}
  </motion.div>
</AnimatePresence>
```

## Pattern: GSAP ScrollTrigger Reveal

```js
gsap.utils.toArray('.reveal').forEach(el => {
  gsap.from(el, {
    opacity: 0,
    y: 40,
    duration: 0.9,
    ease: 'power3.out',
    scrollTrigger: {
      trigger: el,
      start: 'top 85%',
      toggleActions: 'play none none reverse'
    }
  });
});
```

## Accessibility: Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```
