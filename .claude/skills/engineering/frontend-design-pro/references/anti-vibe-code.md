# Anti-Vibe-Code Reference

Anti-patterns extracted from 500 vibe-coded websites. AI agents must avoid these when generating frontend code.

## Visual Anti-Patterns

| Pattern | Why It Fails | Instead Do |
|---------|--------------|------------|
| Purple gradients without brand justification | Looks generic, signals "AI default" | Use brand colors or intentional gradients tied to visual hierarchy |
| Sparkle emoji/icons scattered everywhere | Distracts from content, feels unprofessional | Use sparingly for actual highlights or achievements |
| Aggressive hover effects (lift, rotate, scale) | Breaks alignment, disorients users | Subtle transforms (scale 1.02, translateY -2px) with smooth easing |
| Emojis as UI elements (icons, bullets, headings) | Inconsistent rendering, accessibility issues | Use SVG icons from a consistent set (Lucide, Heroicons) |
| Fake testimonials (AI faces, generic names) | Destroys trust immediately | Use real customers or remove testimonials until you have them |
| Dead social links (# or 404) | Signals incomplete, unprofessional work | Link only to active profiles or omit entirely |
| Massive icons with tiny text | Inverted hierarchy confuses users | Icons support text at 1:1 or 1.5:1 ratio max |
| Generic font combos (Inter/Poppins) with no system | No visual identity, looks templated | Define type scale with weights, sizes, and line heights as a system |
| Semi-transparent headers on scroll | Text becomes unreadable over content | Blur background (backdrop-blur) with sufficient opacity or solid header |
| Bad animations (no easing, stuttering) | Feels broken, causes motion sickness | Use ease-out for entrances, ease-in for exits, 150-300ms duration |

## Structural Anti-Patterns

| Pattern | Why It Fails | Instead Do |
|---------|--------------|------------|
| No loading states | Users think app is broken | Add skeleton loaders, button spinners, progress bars |
| Inconsistent component placement | Users can't predict interface | Define layout patterns and repeat across pages |
| Misaligned grids, uneven spacing | Feels sloppy, unpolished | Use 8px spacing system (8, 16, 24, 32, 48, 64, 96) |
| Mixed border radiuses (4px, 12px, 32px) | Visual inconsistency, no design system | Pick 2-3 values (sm: 4px, md: 8px, lg: 16px) and apply consistently |
| Slow server actions with no feedback | User clicks repeatedly, causes errors | Show loading state immediately, disable buttons, add progress indicator |

## Content Anti-Patterns

| Pattern | Why It Fails | Instead Do |
|---------|--------------|------------|
| Generic taglines ("Build your dreams") | Says nothing unique about the product | Write specific value props tied to real user problems |
| Wrong/sloppy copyright text | Legal issues, looks abandoned | Use current year, proper entity name, auto-update |
| Overloaded hero sections | Users scan, don't read walls | One headline, one subhead, one CTA max |
| Buzzword stacking with no value prop | Sounds like every other startup | Remove jargon, use plain language, lead with benefits |

## Technical Anti-Patterns

| Pattern | Why It Fails | Instead Do |
|---------|--------------|------------|
| Missing meta tags (OG, description, title) | Poor social sharing, bad SEO | Add complete meta set for every page |
| Broken mobile responsiveness | 60%+ users on mobile | Test at 320px, 375px, 768px, 1024px breakpoints |
| Non-functional interactive elements | User frustration, broken trust | Build real toggles, carousels, accordions with proper state |
| Placeholder text in production | Signals incomplete, untrustworthy | Use real copy or hide incomplete sections |
| No favicon | Browser tab looks broken | Generate all sizes (16, 32, 180, 192, 512) from one source |

## Pre-Ship Checklist

**Design System**
- [ ] Spacing uses consistent multiples (8px base)
- [ ] Border radius consistent across components
- [ ] Font sizes follow defined scale
- [ ] Colors limited to palette with purpose

**Interactions**
- [ ] All buttons have hover, focus, active states
- [ ] Loading states present for async actions
- [ ] Animations use proper easing (no bounce overshoot, no stutter)
- [ ] No broken links or dead ends

**Content**
- [ ] No placeholder text visible
- [ ] Headlines are specific, not generic filler
- [ ] Testimonials are real or removed entirely
- [ ] Copyright year and entity correct

**Technical**
- [ ] Mobile tested at multiple breakpoints
- [ ] All interactive elements functional
- [ ] Favicon present
- [ ] Meta tags complete (title, description, OG image)

## The Premium Standard

- **Consistency** — Every spacing value, radius, and type size comes from a defined system
- **Intentionality** — Design decisions are made, not defaulted to AI habits
- **Working interactions** — Every button, toggle, and form does what it promises
- **Real content** — No placeholders, no Lorem ipsum, no fake testimonials
- **Complete meta** — Every page has title, description, and social preview
- **Responsive confidence** — Works beautifully at 320px and 1920px alike
