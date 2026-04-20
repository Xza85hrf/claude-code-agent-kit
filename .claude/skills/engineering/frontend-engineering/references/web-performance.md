# Web Performance Optimization Reference

Performance is a feature. Slow sites lose users, SEO ranking, and revenue. Target: all Core Web Vitals green.

## Core Web Vitals

| Metric | Target | What Fails | Fix |
|--------|--------|-----------|-----|
| **LCP** (Largest Contentful Paint) | < 2.5s | Slow server, large images, render-blocking JS/CSS | Optimize hero image, defer non-critical CSS, preconnect to APIs |
| **FID** (First Input Delay) | < 100ms | Heavy JS tasks blocking main thread | Split JS into chunks, use async/defer, move work to web workers |
| **CLS** (Cumulative Layout Shift) | < 0.1 | Ads, fonts, images without size attributes | Set width/height on all images/iframes, use `font-display: swap` |
| **INP** (Interaction to Next Paint) | < 200ms | Slow event handlers, heavy DOM operations | Debounce handlers, use `requestAnimationFrame`, batch DOM updates |

## Image Optimization

```js
// Next.js Image (automatic optimization)
import Image from 'next/image';
<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority // LCP candidate - load ASAP
  placeholder="blur" // blur + LQIP (Low Quality Image Placeholder)
  blurDataURL="data:image/jpeg;base64,..." // generated at build time
/>

// Responsive srcset (non-Next)
<img
  src="/image-md.webp"
  srcset="
    /image-sm.webp 640w,
    /image-md.webp 1024w,
    /image-lg.webp 1920w
  "
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 90vw, 80vw"
  alt="Description"
  loading="lazy"
/>

// Format negotiation
<picture>
  <source srcset="/image.avif" type="image/avif">
  <source srcset="/image.webp" type="image/webp">
  <img src="/image.jpg" alt="">
</picture>
```

- Use WebP (90s era) → AVIF (80% smaller) for modern browsers
- Lazy load non-critical images: `loading="lazy"`
- Compress: imagemin, tinypng, squoosh
- Responsive: match device DPI (1x, 2x). Serve SVG for icons.

## Bundle Optimization

```js
// Code splitting via dynamic import
const HeavyComponent = lazy(() => import('./HeavyComponent'));
<Suspense fallback={<Spinner />}>
  <HeavyComponent />
</Suspense>

// Tree shaking: export only what's used
export { Button }; // ✓
export * from './components'; // ✗ prevents tree shake

// Avoid barrel file anti-pattern
// ✗ src/components/index.js re-exports all (blocks tree shake)
import { Button } from '@/components'; // pulls entire dir

// ✓ Direct import (tree shakeable)
import { Button } from '@/components/Button';
```

Analyze bundles:
- `source-map-explorer` — identify large modules
- `bundlephobia.com` — check dependency size before install
- Lighthouse → Performance tab → unused JS/CSS
- Goal: main bundle < 100KB gzipped, route chunks < 50KB

## Font Loading

```css
/* Prevent invisible text during load */
@font-face {
  font-family: 'Geist';
  src: url('/geist.woff2') format('woff2');
  font-display: swap; /* show fallback, swap when ready */
  /* alternatives: auto (default, hides text), fallback (50ms hide max), optional (no swap) */
}

/* Preload critical font */
<link rel="preload" href="/geist-bold.woff2" as="font" type="font/woff2" crossorigin>

/* Subset fonts (Latin-only for English) */
@font-face {
  src: url('/geist-subset.woff2') format('woff2-variations');
}

/* Variable font (one file = many weights) */
@font-face {
  font-family: 'Geist';
  src: url('/geist-var.woff2') format('woff2-variations');
  font-weight: 100 900; /* supports all weights */
}
```

- Self-host fonts (no DNS lookup, better privacy)
- Preload only critical font weights (e.g., Bold for headings)
- Subset to language/region (google-webfonts-helper)
- Use variable fonts if available (1 file vs 5)

## CSS Performance

```css
/* Critical CSS: inline styles needed for paint */
<style>
  body { font-family: -apple-system, sans-serif; }
  .hero { background: url(hero.jpg); }
</style>
<link rel="stylesheet" href="critical.css">

/* Defer non-critical CSS */
<link rel="stylesheet" href="non-critical.css" media="print" onload="this.media='all'; this.onload=null;">

/* Content-visibility: skip rendering for off-screen content */
.card-list > div {
  content-visibility: auto;
  contain-intrinsic-size: auto 200px; /* hints layout engine */
}

/* Layout containment: isolate element from layout recalculation */
.sidebar {
  contain: layout style paint;
}
```

- Avoid layout thrashing (read-then-write to DOM)
  ```js
  // ✗ Forces reflows
  for (const el of elements) {
    const height = el.offsetHeight; // read
    el.style.transform = `translateY(${height}px)`; // write
  }

  // ✓ Batch updates
  const updates = elements.map(el => ({
    el,
    height: el.offsetHeight
  }));
  updates.forEach(({ el, height }) => {
    el.style.transform = `translateY(${height}px)`;
  });
  ```

## JavaScript Performance

```js
// Defer/async for non-critical scripts
<script src="analytics.js" async></script> <!-- load async, execute ASAP -->
<script src="heavy.js" defer></script>   <!-- load async, execute after DOM -->

// Task scheduling
requestIdleCallback(() => {
  // Run after browser is idle (< 50ms tasks)
  expensiveComputation();
});

// Move heavy work to web worker
// main.js
const worker = new Worker('/compute.worker.js');
worker.postMessage({ data: largeArray });
worker.onmessage = (e) => console.log('Result:', e.data);

// compute.worker.js
self.onmessage = (e) => {
  const result = expensiveCalculation(e.data);
  self.postMessage(result);
};

// Avoid long tasks (> 50ms blocks interaction)
// ✗ Blocks for 100ms
function process(items) {
  items.forEach(item => heavyCompute(item));
}

// ✓ Break into chunks
async function processAsync(items) {
  for (const item of items) {
    await new Promise(resolve => {
      setTimeout(() => {
        heavyCompute(item);
        resolve();
      }, 0);
    });
  }
}
```

## Caching

```js
// HTTP Headers (set on server)
// Cache forever if content hash changes
Cache-Control: public, max-age=31536000, immutable

// Revalidate every hour
Cache-Control: public, max-age=3600

// Service Worker (offline-first strategy)
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request).then((resp) => {
        caches.open('v1').then((cache) => cache.put(event.request, resp));
        return resp.clone();
      });
    })
  );
});

// Versioned assets (hash in filename)
<link rel="stylesheet" href="/styles.abc123.css"> <!-- cache forever -->
```

Strategy patterns:
- **Cache-first**: Assets (images, fonts, CSS/JS with hashes)
- **Network-first**: API calls, HTML pages
- **Stale-while-revalidate**: APIs (serve cached, fetch fresh in background)

## Measurement

```js
// web-vitals library (minimal, accurate)
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

getCLS(console.log); // { name: 'CLS', value: 0.05, rating: 'good' }
getLCP(console.log);

// Performance Observer API (real user monitoring)
const observer = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log(`${entry.name}: ${entry.duration}ms`);
  }
});
observer.observe({ entryTypes: ['measure', 'navigation', 'resource'] });

// Lighthouse CI (automated testing in CI/CD)
// lighthouserc.json
{
  "ci": {
    "collect": {
      "numberOfRuns": 3,
      "urls": ["https://example.com"],
      "staticDistDir": "./dist"
    },
    "upload": {
      "target": "temporary-public-storage"
    },
    "assert": {
      "preset": "lighthouse:recommended",
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.9 }]
      }
    }
  }
}
```

Monitor:
- Lighthouse (lab testing)
- web-vitals library (field data)
- Sentry, DataDog (RUM — Real User Monitoring)
- CrUX (Google Chrome User Experience Report — aggregate data)

---

**Remember:** Measure first, optimize second. Profile in DevTools (Performance tab) before guessing. Test on slow networks (Chrome DevTools → 4G throttle) and low-end devices.
