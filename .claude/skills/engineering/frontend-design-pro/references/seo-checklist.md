# SEO & Meta Tags Reference

Essential SEO patterns for every page. Missing meta tags = broken social sharing + poor search ranking.

---

## 1. Essential Meta Tags

Every `<head>` must include these baseline tags:

```html
<!-- Character encoding (must be first) -->
<meta charset="UTF-8">

<!-- Viewport for mobile rendering -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<!-- Page title (50-60 chars, keyword first) -->
<title>Product Name | Brand - Key Feature</title>

<!-- Meta description (150-160 chars, CTR driver) -->
<meta name="description" content="Clear value proposition with primary keyword. Unique per page, not generic.">

<!-- Canonical URL (prevent duplicate content penalties) -->
<link rel="canonical" href="https://example.com/path">

<!-- Robots directive -->
<meta name="robots" content="index, follow">

<!-- Language -->
<html lang="en">
```

---

## 2. Open Graph Tags (Social Sharing)

Required for proper rendering on LinkedIn, Facebook, Twitter:

```html
<!-- Page type -->
<meta property="og:type" content="website">

<!-- Exact title for social cards -->
<meta property="og:title" content="Product Name - Your Value Here">

<!-- Social description (max 160 chars) -->
<meta property="og:description" content="What users get by clicking. Different from meta description.">

<!-- Exact URL (no tracking params in og:url) -->
<meta property="og:url" content="https://example.com/exact-path">

<!-- Image: 1200×630px, <100KB, JPG/PNG, no text distortion -->
<meta property="og:image" content="https://example.com/og-image.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">

<!-- Brand name -->
<meta property="og:site_name" content="Brand Name">
```

---

## 3. Twitter Card Tags

Standalone Twitter preview (X still honors these):

```html
<meta name="twitter:card" content="summary_large_image">

<meta name="twitter:title" content="Product Name - Value Prop">

<meta name="twitter:description" content="User-focused benefit statement.">

<!-- Same image as og:image for consistency -->
<meta name="twitter:image" content="https://example.com/og-image.jpg">

<!-- Optional: Force brand attribution -->
<meta name="twitter:site" content="@YourHandle">
<meta name="twitter:creator" content="@AuthorHandle">
```

---

## 4. Structured Data (JSON-LD)

Inject one schema per page type. Crawlers parse this for rich snippets and knowledge panels.

### Organization (Homepage only):

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Company Name",
  "url": "https://example.com",
  "logo": "https://example.com/logo.png",
  "sameAs": [
    "https://twitter.com/handle",
    "https://linkedin.com/company/name"
  ],
  "contactPoint": {
    "@type": "ContactPoint",
    "contactType": "Customer Support",
    "email": "support@example.com"
  }
}
</script>
```

### Article (Blog posts):

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Article Title",
  "description": "Short summary",
  "image": "https://example.com/article-image.jpg",
  "datePublished": "2026-03-15",
  "dateModified": "2026-03-15",
  "author": {
    "@type": "Person",
    "name": "Author Name"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Brand Name",
    "logo": {
      "@type": "ImageObject",
      "url": "https://example.com/logo.png"
    }
  }
}
</script>
```

### Product (E-commerce):

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Product Name",
  "description": "What it does",
  "image": "https://example.com/product.jpg",
  "price": "99.99",
  "priceCurrency": "USD",
  "availability": "https://schema.org/InStock",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.5",
    "reviewCount": "42"
  }
}
</script>
```

### BreadcrumbList (Category/product pages):

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "name": "Home",
      "item": "https://example.com"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "name": "Products",
      "item": "https://example.com/products"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": "Product Name",
      "item": "https://example.com/products/slug"
    }
  ]
}
</script>
```

---

## 5. Technical SEO

### robots.txt (serve at `/.well-known/robots.txt` or `/robots.txt`):

```
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /api/
Disallow: /private/

Sitemap: https://example.com/sitemap.xml
```

### sitemap.xml (generate dynamically; update on deploy):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/page-1</loc>
    <lastmod>2026-03-15</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
  <!-- ... more URLs ... -->
</urlset>
```

### Canonical URL Rules:

- **Homepage**: Self-referential (`<link rel="canonical" href="https://example.com">`)
- **Paginated**: Point first page canonical to `/page1`, alternate pages to themselves
- **Trailing slash**: Decide (example.com vs example.com/) and enforce one via canonical
- **Parameters**: Strip UTM tracking, sort remaining params alphabetically in canonical
- **HTTPS**: Always HTTPS in canonical, never HTTP

---

## 6. Core Web Vitals Impact on SEO

Google Page Experience update: **All are ranking signals.**

| Metric | Target | Why | Impact |
|--------|--------|-----|--------|
| **LCP** (Largest Contentful Paint) | < 2.5s | Hero image/text load time | ~40% of ranking weight |
| **FID** (First Input Delay) | < 100ms | JavaScript blocking main thread | ~20% |
| **CLS** (Cumulative Layout Shift) | < 0.1 | Unexpected layout jumps | ~20% |
| **INP** (Interaction to Next Paint) | < 200ms | Responsiveness to user input | ~20% |

**Quick fixes:**
- LCP: Preload hero image, defer non-critical JS, optimize server TTL
- FID/INP: Break JS into chunks, defer non-critical libraries
- CLS: Set image/video `width` & `height`, use `font-display: swap` for web fonts

---

## 7. Pre-Ship SEO Checklist

- [ ] **Title tag**: 50-60 chars, keyword first, unique per page
- [ ] **Meta description**: 150-160 chars, calls-to-action, unique
- [ ] **Viewport meta**: Present and correct (`width=device-width, initial-scale=1.0`)
- [ ] **Canonical URL**: Present, absolute, no params
- [ ] **og:image**: 1200×630px, <100KB, no text clipping
- [ ] **og:title / og:description**: Match page intent, not boilerplate
- [ ] **twitter:card**: `summary_large_image` for visual pages
- [ ] **Structured data**: One schema per page type (not stacked)
- [ ] **robots.txt**: Deployed and discoverable at root
- [ ] **sitemap.xml**: Generated, includes all public URLs, lastmod accurate
- [ ] **LCP**: < 2.5s (audit with PageSpeed Insights)
- [ ] **No 404 errors**: Check <head> resource loading in DevTools Network
- [ ] **Mobile-first**: Responsive viewport, touch-friendly buttons
- [ ] **No redirect chains**: (max 1 redirect per URL)
- [ ] **Internal links**: Contextual, descriptive anchor text, no orphaned pages

---

**Test**: Run pages through Google Search Console preview tool, Lighthouse, and Social Share Debugger before shipping.
