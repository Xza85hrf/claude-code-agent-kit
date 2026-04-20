# Particle Systems Reference

tsParticles is the industry standard for web particle effects with a lightweight, framework-agnostic core. Use `@tsparticles/slim` for minimal bundle size in production.

## Setup

### React

```bash
npm install @tsparticles/react @tsparticles/slim
```

```tsx
import { useCallback } from "react";
import Particles from "@tsparticles/react";
import { loadSlim } from "@tsparticles/slim";
import type { Engine } from "@tsparticles/engine";

function ParticleBackground({ options }) {
  const particlesInit = useCallback(async (engine: Engine) => {
    await loadSlim(engine);
  }, []);

  return <Particles id="tsparticles" init={particlesInit} options={options} />;
}
```

### Vanilla JS

```bash
npm install @tsparticles/engine @tsparticles/slim
```

```js
import { tsParticles } from "@tsparticles/engine";
import { loadSlim } from "@tsparticles/slim";

await loadSlim(tsParticles);
await tsParticles.load({ id: "tsparticles", options: { /* config */ } });
```

## Ready-to-Use Configs

### 1. Ambient Floating

Subtle background dots for hero sections and dark themes.

```json
{
  "fpsLimit": 60,
  "particles": {
    "color": { "value": "#ffffff" },
    "number": { "value": 40 },
    "size": { "value": { "min": 1, "max": 3 } },
    "opacity": { "value": { "min": 0.2, "max": 0.5 } },
    "move": { "enable": true, "speed": 0.8, "direction": "none", "outModes": { "default": "out" } },
    "links": { "enable": false }
  },
  "detectRetina": true
}
```

### 2. Network Graph

Connected nodes with hover repulse for tech/SaaS pages.

```json
{
  "fpsLimit": 60,
  "particles": {
    "color": { "value": "#6366f1" },
    "number": { "value": 70 },
    "size": { "value": 2 },
    "opacity": { "value": 0.6 },
    "move": { "enable": true, "speed": 0.5, "outModes": { "default": "bounce" } },
    "links": { "enable": true, "distance": 150, "opacity": 0.3, "color": "#6366f1" }
  },
  "interactivity": { "events": { "onHover": { "enable": true, "mode": "repulse" } } },
  "detectRetina": true
}
```

### 3. Snow/Confetti

Falling particles for seasonal and celebration effects.

```json
{
  "fpsLimit": 60,
  "particles": {
    "color": { "value": "#ffffff" },
    "number": { "value": 50 },
    "size": { "value": { "min": 2, "max": 6 } },
    "opacity": { "value": 0.8 },
    "move": { "enable": true, "speed": 2, "direction": "bottom", "outModes": { "default": "out" } },
    "links": { "enable": false }
  },
  "detectRetina": true
}
```

### 4. Starfield

Deep space with opacity animation for dark cinematic themes.

```json
{
  "background": { "color": "#0a0a0f" },
  "fpsLimit": 60,
  "particles": {
    "color": { "value": "#ffffff" },
    "number": { "value": 150 },
    "size": { "value": { "min": 0.5, "max": 2 } },
    "opacity": { "value": 0.8, "animation": { "enable": true, "speed": 0.5, "sync": false } },
    "move": { "enable": true, "speed": 0.3, "outModes": { "default": "out" } },
    "links": { "enable": false }
  },
  "detectRetina": true
}
```

### 5. Interactive Burst

Click to spawn with hover grab for interactive pages.

```json
{
  "fpsLimit": 60,
  "particles": {
    "color": { "value": "#f472b6" },
    "number": { "value": 20 },
    "size": { "value": 3 },
    "opacity": { "value": 0.7 },
    "move": { "enable": true, "speed": 1, "outModes": { "default": "out" } },
    "links": { "enable": false }
  },
  "interactivity": {
    "events": { "onHover": { "enable": true, "mode": "grab" }, "onClick": { "enable": true, "mode": "push" } },
    "modes": { "push": { "quantity": 4 }, "grab": { "distance": 140, "links": { "opacity": 0.5 } } }
  },
  "detectRetina": true
}
```

## Performance Rules

| Rule | Guideline |
|------|-----------|
| Particle count | Max 150 mobile, 300 desktop |
| Frame rate | Always `fpsLimit: 60` |
| Retina | `detectRetina: true` |
| Reduced motion | Disable particles or `move.speed: 0` when `prefers-reduced-motion` |
| Bundle | Slim only (`loadSlim`) — saves ~40KB vs full |
| Layer | `z-index: -1`, `position: fixed`, `pointer-events: none` |

## Anti-Patterns

| Pattern | Why It Fails | Instead Do |
|---------|--------------|------------|
| >200 particles on mobile | Kills frame rate | Cap at 150, use `number.density` |
| Links on mobile | GPU-heavy canvas ops | Disable via media query |
| Bright/opaque particles | Competes with content | Keep opacity 0.2-0.6 |
| No reduced-motion support | Accessibility violation | Check `prefers-reduced-motion` |
| Full bundle | 40KB wasted | Use slim with `loadSlim()` |

## Integration Pattern

```css
#tsparticles {
  position: fixed;
  top: 0; left: 0;
  width: 100%; height: 100%;
  z-index: -1;
  pointer-events: none;
}
```

```js
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const options = prefersReducedMotion
  ? { particles: { move: { enable: false } } }
  : { /* your config */ };
```
