# Premium Visual Effects Library

## Premium Gradient Backgrounds

### Gradient Mesh (Soft, Warm)
```css
body {
  background:
    radial-gradient(ellipse 60% 50% at 10% 30%, rgba(255,200,100,0.12) 0%, transparent 70%),
    radial-gradient(ellipse 50% 70% at 85% 10%, rgba(200,100,255,0.1) 0%, transparent 70%),
    radial-gradient(ellipse 70% 50% at 60% 80%, rgba(100,200,255,0.08) 0%, transparent 70%),
    #0d0d0f;
}
```

### Animated Gradient (Subtle Drift)
```css
@keyframes gradientDrift {
  0%   { background-position: 0% 50%; }
  50%  { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}
.animated-gradient {
  background: linear-gradient(135deg, #1a0533, #0a1628, #003322, #1a0533);
  background-size: 300% 300%;
  animation: gradientDrift 12s ease infinite;
}
```

### Noise Texture Overlay
```css
.noise::after {
  content: '';
  position: fixed;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  opacity: 0.03;
  pointer-events: none;
  z-index: 9999;
}
```

---

## 3D CSS Effects

### Card 3D Tilt (Mouse Tracking)
```js
document.querySelectorAll('.tilt-card').forEach(card => {
  card.addEventListener('mousemove', (e) => {
    const rect = card.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    card.style.transform = `
      perspective(800px)
      rotateY(${x * 12}deg)
      rotateX(${-y * 12}deg)
      translateZ(8px)
    `;
  });
  card.addEventListener('mouseleave', () => {
    card.style.transform = 'perspective(800px) rotateY(0) rotateX(0) translateZ(0)';
    card.style.transition = 'transform 0.6s cubic-bezier(0.16,1,0.3,1)';
  });
});
```

### CSS Perspective Depth Stack
```css
.depth-stack {
  perspective: 1200px;
  transform-style: preserve-3d;
}
.depth-stack .layer-1 { transform: translateZ(0px); }
.depth-stack .layer-2 { transform: translateZ(20px); }
.depth-stack .layer-3 { transform: translateZ(40px); }
```

---

## Particle Systems (Lightweight JS)

```js
class ParticleField {
  constructor(canvas, count = 60) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.particles = Array.from({ length: count }, () => ({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      vx: (Math.random() - 0.5) * 0.4,
      vy: (Math.random() - 0.5) * 0.4,
      r: Math.random() * 1.5 + 0.5,
      alpha: Math.random() * 0.5 + 0.1,
    }));
    this.animate();
  }
  animate() {
    const { ctx, canvas, particles } = this;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    particles.forEach(p => {
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0) p.x = canvas.width;
      if (p.x > canvas.width) p.x = 0;
      if (p.y < 0) p.y = canvas.height;
      if (p.y > canvas.height) p.y = 0;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(150,120,255,${p.alpha})`;
      ctx.fill();
    });
    requestAnimationFrame(() => this.animate());
  }
}
```

---

## Bento Grid Layout

```css
.bento {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: auto;
  gap: 16px;
  padding: 24px;
}
.bento-card {
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 20px;
  padding: 28px;
  transition: all 0.3s cubic-bezier(0.16,1,0.3,1);
}
.bento-card:hover {
  background: rgba(255,255,255,0.07);
  border-color: rgba(255,255,255,0.15);
  transform: translateY(-2px);
}
.bento-wide { grid-column: span 2; }
.bento-tall { grid-row: span 2; }
```

---

## Advanced Typography Techniques

### Kinetic Text (Word-by-Word Reveal)
```js
function animateWords(el) {
  const words = el.textContent.split(' ');
  el.innerHTML = words.map((w, i) =>
    `<span class="word" style="animation-delay:${i * 0.06}s">${w}</span>`
  ).join(' ');
}
```
```css
.word {
  display: inline-block;
  opacity: 0;
  transform: translateY(16px);
  animation: wordReveal 0.5s cubic-bezier(0.16,1,0.3,1) forwards;
}
@keyframes wordReveal {
  to { opacity: 1; transform: translateY(0); }
}
```

### Scramble Text Effect (JS)
```js
function scrambleText(el, final, duration = 1200) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let start = null;
  const update = (timestamp) => {
    if (!start) start = timestamp;
    const progress = Math.min((timestamp - start) / duration, 1);
    el.textContent = final.split('').map((char, i) =>
      i < Math.floor(progress * final.length)
        ? char
        : chars[Math.floor(Math.random() * chars.length)]
    ).join('');
    if (progress < 1) requestAnimationFrame(update);
  };
  requestAnimationFrame(update);
}
```

---

## Premium Shadow System

```css
:root {
  /* Layered box shadow for depth */
  --shadow-sm: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08);
  --shadow-md: 0 4px 16px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.08);
  --shadow-lg: 0 16px 48px rgba(0,0,0,0.2), 0 4px 16px rgba(0,0,0,0.1);
  --shadow-xl: 0 32px 80px rgba(0,0,0,0.3), 0 8px 32px rgba(0,0,0,0.15);

  /* Color-tinted shadow (premium) */
  --shadow-purple: 0 16px 48px rgba(120,80,255,0.2), 0 4px 16px rgba(120,80,255,0.1);
  --shadow-blue:   0 16px 48px rgba(0,120,255,0.2),  0 4px 16px rgba(0,120,255,0.1);
}
```

---

## CSS Cursor Custom

```css
* { cursor: none; }

.cursor {
  width: 12px; height: 12px;
  background: white;
  border-radius: 50%;
  position: fixed;
  pointer-events: none;
  z-index: 99999;
  transition: transform 0.15s ease, background 0.2s ease;
  transform: translate(-50%, -50%);
}
.cursor-ring {
  width: 36px; height: 36px;
  border: 1px solid rgba(255,255,255,0.4);
  border-radius: 50%;
  position: fixed;
  pointer-events: none;
  z-index: 99998;
  transition: transform 0.35s cubic-bezier(0.16,1,0.3,1), width 0.3s, height 0.3s;
  transform: translate(-50%, -50%);
}
a:hover ~ .cursor, button:hover ~ .cursor {
  transform: translate(-50%, -50%) scale(0);
}
a:hover ~ .cursor-ring, button:hover ~ .cursor-ring {
  width: 60px; height: 60px;
  background: rgba(255,255,255,0.05);
}
```
