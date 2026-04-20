---
name: i18n
description: Implement internationalization and localization in web applications. Use when adding multi-language support or extracting translatable strings.
argument-hint: "Add i18n support to the React app with English, Spanish, and Japanese locales"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: medium
---

## Framework Detection

| Framework | Library | Check |
|-----------|---------|-------|
| Next.js | next-intl | `next.config.js` |
| React SPA | react-i18next | `i18n.js` or `react-i18next` in deps |
| Vue 3 | vue-i18n | `createI18n` usage |
| Angular | @angular/localize | `$localize` usage |
| Flask | Flask-Babel | `Babel()` in app |

**Default:** react-i18next (React), next-intl (Next.js)

---

## Setup: react-i18next (React SPA)

```bash
npm install i18next react-i18next i18next-http-backend i18next-browser-languagedetector
```

```typescript
// i18n.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import Backend from 'i18next-http-backend';
import LanguageDetector from 'i18next-browser-languagedetector';

i18n.use(Backend).use(LanguageDetector).use(initReactI18next).init({
  fallbackLng: 'en',
  supportedLngs: ['en', 'es', 'ja'],
  interpolation: { escapeValue: false },
  backend: { loadPath: '/locales/{{lng}}/{{ns}}.json' }
});
export default i18n;
```

```typescript
// App.tsx
import './i18n';
import { useTranslation } from 'react-i18next';

function App() {
  const { t, i18n } = useTranslation();
  return (
    <div dir={i18n.language === 'ar' ? 'rtl' : 'ltr'}>
      <h1>{t('welcome')}</h1>
      <button onClick={() => i18n.changeLanguage('es')}>Español</button>
    </div>
  );
}
```

## Setup: next-intl (Next.js App Router)

```bash
npm install next-intl
```

```typescript
// middleware.ts
import createMiddleware from 'next-intl/middleware';
export default createMiddleware({ locales: ['en', 'es', 'ja'], defaultLocale: 'en' });
export const config = { matcher: ['/', '/(es|ja)/:path*'] };
```

```typescript
// app/[locale]/layout.tsx
import { NextIntlClientProvider, useMessages } from 'next-intl';
export default function LocaleLayout({ children, params: { locale } }) {
  return (
    <html lang={locale} dir={locale === 'ar' ? 'rtl' : 'ltr'}>
      <body>
        <NextIntlClientProvider locale={locale} messages={useMessages()}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

---

## ICU MessageFormat Patterns

```json
// locales/en/common.json
{
  "items": "{{count}} item",
  "items_plural": "{{count}} items",
  "greeting": "Hello, {{name}}!",
  "role": "{{role, select,
    admin {Administrator}
    user {Regular User}
    other {Guest}
  }}",
  "price": "{{value, number, currency}}",
  "date": "{{value, date, medium}}",
  "itemsRemaining": "{count, plural,
    =0 {No items left}
    one {# item left}
    other {# items left}
  }"
}
```

```typescript
// Usage with react-intl
<FormattedMessage
  id="itemsRemaining"
  values={{ count: 5 }}
/>
```

---

## String Extraction Workflow

1. Find hardcoded strings: `grep -rn "'[^']*'" src/ --include="*.tsx"`
2. Create `/locales/en/common.json`, add key-value pairs
3. Replace with `t('key')` calls

```bash
# Automated
npx i18next 'src/**/*.{ts,tsx}' --output src/locales --namespace common
```

```json
// locales/en/common.json
{
  "welcome": "Welcome", "login": "Log in", "logout": "Log out",
  "save": "Save changes", "delete": "Delete {{item}}?"
}
```

---

## RTL Layout Support

Use CSS logical properties (not physical):
- `margin-inline-start` (left in LTR, right in RTL)
- `padding-inline-end` (right in LTR, left in RTL)
- `text-align: start` (left in LTR, right in RTL)
- `border-inline-start/end`

```typescript
// Dynamic dir
const direction = ['ar', 'he', 'fa'].includes(i18n.language) ? 'rtl' : 'ltr';

---

## Common Patterns

### Date/Number Formatting

```typescript
import { format } from 'next-intl'; // or react-intl

// Date
format(new Date(), 'long', { locale: 'ja' });  // "2024年1月15日"

// Number
format(1234.56, 'currency', { locale: 'en', currency: 'USD' });  // "$1,234.56"
format(1234.56, 'currency', { locale: 'ja', currency: 'JPY' });  // "¥1,235"
```

### Dynamic Language Switching

```typescript
const languages = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'es', name: 'Español', flag: '🇪🇸' },
  { code: 'ja', name: '日本語', flag: '🇯🇵' }
];

function LanguageSwitcher() {
  const { i18n } = useTranslation();
  return (
    <select
      value={i18n.language}
      onChange={(e) => i18n.changeLanguage(e.target.value)}
    >
      {languages.map(lang => (
        <option key={lang.code} value={lang.code}>
          {lang.flag} {lang.name}
        </option>
      ))}
    </select>
  );
}
```

### SEO with hreflang

```typescript
// app/[locale]/layout.tsx - Next.js
export function generateMetadata({ params }) {
  const locales = ['en', 'es', 'ja'];
  const canonicalUrl = `https://yoursite.com/${params.locale}`;

  return {
    alternates: {
      canonical: canonicalUrl,
      languages: Object.fromEntries(
        locales.map(locale => [locale, `https://yoursite.com/${locale}`])
      )
    }
  };
}
```

---

## Key Principles

| Principle | Details |
|-----------|---------|
| No hardcoding | Always use `t('key')` |
| Namespaces | Separate: `common.json`, `forms.json`, `errors.json` |
| Plurals | Use ICU rules, not `count + 's'` |
| RTL CSS | Logical properties, test Arabic/Hebrew |
| Sorting | Use `localeCompare(b, locale)` |
