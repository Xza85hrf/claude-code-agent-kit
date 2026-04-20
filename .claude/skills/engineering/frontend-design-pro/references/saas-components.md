# SaaS Component Patterns

## Navbar — Sticky Glass

```css
.navbar {
  position: sticky;
  top: 0;
  z-index: 100;
  padding: 12px 32px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: rgba(8, 8, 12, 0.6);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid rgba(255,255,255,0.06);
  transition: background 0.3s ease, border-color 0.3s ease;
}
.navbar.scrolled {
  background: rgba(8, 8, 12, 0.9);
  border-color: rgba(255,255,255,0.1);
}
```

---

## Feature Grid (Bento Style)

```html
<div class="features-grid">
  <div class="feature-card feature-primary">
    <div class="feature-icon">...</div>
    <h3>Primary Feature</h3>
    <p>Description</p>
    <div class="feature-demo"><!-- animated demo --></div>
  </div>
  <div class="feature-card">...</div>
  <div class="feature-card">...</div>
  <div class="feature-card feature-wide">...</div>
</div>
```

```css
.features-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1px; /* hairline gaps between cards */
  background: rgba(255,255,255,0.06); /* gap color */
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 24px;
  overflow: hidden;
}
.feature-card {
  background: #0a0a0f;
  padding: 40px 32px;
  transition: background 0.3s ease;
}
.feature-card:hover { background: #111116; }
.feature-primary { grid-column: span 2; }
.feature-wide { grid-column: span 3; }
```

---

## Pricing Table (Premium)

```css
.pricing-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
  align-items: start;
}
.pricing-card {
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 20px;
  padding: 36px;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}
.pricing-card.featured {
  border-color: rgba(120,80,255,0.5);
  box-shadow: 0 0 0 1px rgba(120,80,255,0.3), 0 32px 64px rgba(120,80,255,0.15);
  transform: scale(1.04);
}
.price {
  font-size: clamp(2.5rem, 5vw, 4rem);
  font-weight: 700;
  letter-spacing: -0.02em;
}
```

---

## Stats / Social Proof Strip

```html
<div class="stats-strip">
  <div class="stat">
    <span class="stat-number" data-target="50000">0</span>
    <span class="stat-label">Active users</span>
  </div>
  <div class="stat-divider"></div>
  <div class="stat">...</div>
</div>
```

```css
.stats-strip {
  display: flex;
  align-items: center;
  gap: 48px;
  padding: 32px 48px;
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 16px;
  background: rgba(255,255,255,0.02);
}
.stat-number {
  font-size: 2.5rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  background: linear-gradient(135deg, #fff 40%, rgba(255,255,255,0.5));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.stat-divider {
  width: 1px;
  height: 48px;
  background: rgba(255,255,255,0.08);
}
```

---

## CTA Section (Final Conversion)

```html
<section class="cta-section">
  <div class="cta-glow"></div>
  <h2>Ready to get started?</h2>
  <p>Supporting line. One sentence max.</p>
  <div class="cta-buttons">
    <button class="btn-primary-lg">Start free trial</button>
    <button class="btn-ghost">Talk to sales →</button>
  </div>
</section>
```

```css
.cta-section {
  position: relative;
  text-align: center;
  padding: 120px 48px;
  overflow: hidden;
}
.cta-glow {
  position: absolute;
  width: 600px; height: 300px;
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  background: radial-gradient(ellipse, rgba(120,80,255,0.2) 0%, transparent 70%);
  pointer-events: none;
}
.btn-primary-lg {
  padding: 16px 40px;
  font-size: 1.1rem;
  font-weight: 600;
  border-radius: 12px;
  background: linear-gradient(135deg, #7c3aed, #6d28d9);
  color: white;
  border: none;
  cursor: pointer;
  transition: all 0.25s cubic-bezier(0.16,1,0.3,1);
  box-shadow: 0 8px 24px rgba(120,80,255,0.35);
}
.btn-primary-lg:hover {
  transform: translateY(-2px);
  box-shadow: 0 16px 40px rgba(120,80,255,0.45);
}
```

---

## Testimonials (Masonry / Quote Cards)

```css
.testimonial-grid {
  columns: 3;
  column-gap: 20px;
}
.testimonial-card {
  break-inside: avoid;
  margin-bottom: 20px;
  border: 1px solid rgba(255,255,255,0.07);
  border-radius: 16px;
  padding: 28px;
  background: rgba(255,255,255,0.03);
}
.testimonial-quote {
  font-size: 0.95rem;
  line-height: 1.65;
  color: rgba(255,255,255,0.8);
  margin-bottom: 20px;
}
.testimonial-author {
  display: flex;
  align-items: center;
  gap: 12px;
}
.author-avatar {
  width: 36px; height: 36px;
  border-radius: 50%;
  object-fit: cover;
}
```

---

## Logo Marquee (Infinite Scroll)

```css
.marquee {
  overflow: hidden;
  position: relative;
  --mask: linear-gradient(to right, transparent, black 10%, black 90%, transparent);
  -webkit-mask: var(--mask);
  mask: var(--mask);
}
.marquee-track {
  display: flex;
  width: max-content;
  animation: marqueeScroll 30s linear infinite;
}
.marquee:hover .marquee-track { animation-play-state: paused; }

@keyframes marqueeScroll {
  from { transform: translateX(0); }
  to { transform: translateX(-50%); }
}
/* Duplicate logos in HTML so the loop is seamless */
```

---

## Accordion (FAQ)

```css
.accordion-item {
  border-bottom: 1px solid rgba(255,255,255,0.07);
}
.accordion-trigger {
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 0;
  background: none;
  border: none;
  color: white;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  text-align: left;
}
.accordion-icon {
  transition: transform 0.3s cubic-bezier(0.16,1,0.3,1);
}
.accordion-item.open .accordion-icon { transform: rotate(45deg); }
.accordion-body {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 0.4s cubic-bezier(0.16,1,0.3,1);
}
.accordion-item.open .accordion-body { grid-template-rows: 1fr; }
.accordion-inner { overflow: hidden; padding-bottom: 20px; }
```
