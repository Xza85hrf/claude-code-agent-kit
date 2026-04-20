# Emil Kowalski — Design Engineering Patterns

Expert animation, motion, and interaction patterns from Emil Kowalski (creator of Sonner, Vaul). Source: [emilkowal.ski](https://emilkowal.ski/skill).

Core philosophy: **Taste is trained, not innate. Unseen details compound. Beauty is leverage.**

---

## The Animation Decision Framework

Before writing ANY animation, answer these in order:

### 1. Should This Animate At All?

| Usage Frequency | Decision |
|----------------|----------|
| 100+ times/day (keyboard shortcuts, cmd palette) | **No animation. Ever.** |
| Tens of times/day (hover, list nav) | Remove or drastically reduce |
| Occasional (modals, drawers, toasts) | Standard animation |
| Rare/first-time (onboarding, celebrations) | Can add delight |

**Never animate keyboard-initiated actions.** Raycast has no open/close animation — optimal for something used hundreds of times daily.

### 2. What Is the Purpose?

Every animation needs a clear "why":
- **Spatial consistency** — toast enters/exits same direction
- **State indication** — morphing feedback button
- **Explanation** — marketing feature demo
- **Feedback** — button scales on press
- **Preventing jarring changes** — elements appearing/disappearing without transition feel broken

If "it looks cool" is the only reason and users see it often → don't animate.

### 3. What Easing?

```
Entering or exiting?
  → ease-out (starts fast, feels responsive)
Moving/morphing on screen?
  → ease-in-out (natural acceleration/deceleration)
Hover/color change?
  → ease
Constant motion (marquee, progress)?
  → linear
Default → ease-out
```

**Critical: use custom curves.** Built-in CSS easings are too weak.

```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);        /* Strong ease-out */
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);     /* Strong ease-in-out */
--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);      /* iOS-like drawer (Ionic) */
```

**Never use ease-in for UI animations.** Starts slow → feels sluggish. A dropdown with `ease-in` at 300ms _feels_ slower than `ease-out` at 300ms because ease-in delays the moment the user watches most closely.

Resources: [easing.dev](https://easing.dev/), [easings.co](https://easings.co/)

### 4. How Fast?

| Element | Duration |
|---------|----------|
| Button press | 100–160ms |
| Tooltips, small popovers | 125–200ms |
| Dropdowns, selects | 150–250ms |
| Modals, drawers | 200–500ms |
| Marketing/explanatory | Can be longer |

**Rule: UI animations stay under 300ms.** Faster spinners make apps feel faster (same load time, different perception).

### Asymmetric Enter/Exit Timing

Press = slow when deliberate (hold-to-delete: 2s linear). Release = always snappy (200ms ease-out). Slow where the user decides, fast where the system responds.

```css
.overlay { transition: clip-path 200ms ease-out; }           /* Release: fast */
.button:active .overlay { transition: clip-path 2s linear; } /* Press: slow */
```

---

## Spring Animations

Springs feel more natural — they simulate real physics with no fixed duration.

### When to Use
- Drag interactions with momentum
- Elements that should feel "alive" (Dynamic Island)
- Gestures that can be interrupted mid-animation
- Decorative mouse-tracking

### Configuration

**Apple-style (recommended — easier to reason about):**
```js
{ type: "spring", duration: 0.5, bounce: 0.2 }
```

**Traditional physics (more control):**
```js
{ type: "spring", mass: 1, stiffness: 100, damping: 10 }
```

Keep bounce subtle (0.1–0.3). Avoid bounce in most UI. Use for drag-to-dismiss and playful interactions.

### Spring Mouse Interactions

```jsx
import { useSpring } from 'framer-motion';
// Without spring: artificial, instant
const rotation = mouseX * 0.1;
// With spring: natural, has momentum
const springRotation = useSpring(mouseX * 0.1, { stiffness: 100, damping: 10 });
```

Only for **decorative** interactions. Functional UIs (banking graphs) → no animation.

### Interruptibility

Springs maintain velocity when interrupted — CSS keyframes restart from zero. Ideal for gestures users might change mid-motion.

---

## clip-path Animation Techniques

`clip-path: inset(top right bottom left)` — rectangular clip. Each value "eats" into the element.

### Hold-to-Delete
```css
.overlay { clip-path: inset(0 100% 0 0); transition: clip-path 200ms ease-out; }
.button:active .overlay { clip-path: inset(0 0 0 0); transition: clip-path 2s linear; }
```
Add `scale(0.97)` on the button for press feedback.

### Tab Color Transitions
Duplicate tab list. Style copy as "active." Clip so only active tab visible. Animate clip on tab change → seamless color transition impossible with individual transitions.

### Image Reveals on Scroll
`clip-path: inset(0 0 100% 0)` → `inset(0 0 0 0)` when entering viewport. Use `IntersectionObserver` or `useInView({ once: true, margin: "-100px" })`.

### Comparison Sliders
Overlay two images. Clip top with `inset(0 50% 0 0)`. Adjust right inset on drag. No extra DOM, fully GPU-accelerated.

---

## CSS @starting-style (Modern Entry Animations)

Replace the `useEffect → setMounted(true)` pattern:

```css
.toast {
  opacity: 1; transform: translateY(0);
  transition: opacity 400ms ease, transform 400ms ease;
  @starting-style { opacity: 0; transform: translateY(100%); }
}
```

Fall back to `data-mounted` attribute when browser support is insufficient.

---

## Blur to Mask Imperfect Transitions

When crossfade feels off despite easing/duration tweaks → add `filter: blur(2px)` during transition. Blends two states so the eye perceives one smooth transformation instead of two objects swapping.

```css
.button-content.transitioning { filter: blur(2px); opacity: 0.7; }
```

Keep blur under 20px. Heavy blur is expensive, especially in Safari.

---

## Stagger Animations

```css
.item { opacity: 0; transform: translateY(8px); animation: fadeIn 300ms ease-out forwards; }
.item:nth-child(1) { animation-delay: 0ms; }
.item:nth-child(2) { animation-delay: 50ms; }
/* ... */
@keyframes fadeIn { to { opacity: 1; transform: translateY(0); } }
```

Keep delays short (30–80ms between items). Never block interaction during stagger.

---

## Performance: Critical Gotchas

### Framer Motion x/y Are NOT Hardware-Accelerated

```jsx
// NOT hardware accelerated (requestAnimationFrame, drops frames under load)
<motion.div animate={{ x: 100 }} />

// Hardware accelerated (GPU-composited, smooth even when main thread busy)
<motion.div animate={{ transform: "translateX(100px)" }} />
```

Vercel's dashboard tab animation dropped frames during page loads with Shared Layout Animations. Switching to CSS animations fixed it.

### CSS Animations Beat JS Under Load

CSS animations run off the main thread. Framer Motion uses `requestAnimationFrame` → drops frames when the browser is busy. Use CSS for predetermined animations; JS for dynamic, interruptible ones.

### Web Animations API (WAAPI)

JavaScript control with CSS performance. Hardware-accelerated, interruptible, no library:

```js
element.animate(
  [{ clipPath: 'inset(0 0 100% 0)' }, { clipPath: 'inset(0 0 0 0)' }],
  { duration: 1000, fill: 'forwards', easing: 'cubic-bezier(0.77, 0, 0.175, 1)' }
);
```

### CSS Variable Inheritance Cost

Changing a CSS variable on a parent recalculates styles for all children. In a drawer with many items, `--swipe-amount` on the container → expensive recalc. Update `transform` directly instead:

```js
// Bad: triggers recalc on all children
element.style.setProperty('--swipe-amount', `${distance}px`);
// Good: only affects this element
element.style.transform = `translateY(${distance}px)`;
```

---

## Review Format (Required)

When reviewing UI code, use a **Before/After/Why markdown table**:

| Before | After | Why |
|--------|-------|-----|
| `transition: all 300ms` | `transition: transform 200ms ease-out` | Specify exact properties; avoid `all` |
| `transform: scale(0)` | `transform: scale(0.95); opacity: 0` | Nothing in the real world appears from nothing |
| `ease-in` on dropdown | `ease-out` with custom curve | `ease-in` feels sluggish at the critical first moment |
| No `:active` state on button | `transform: scale(0.97)` on `:active` | Buttons must feel responsive to press |
| `transform-origin: center` on popover | `transform-origin: var(--radix-popover-content-transform-origin)` | Popovers scale from trigger (modals stay centered) |
| Duration > 300ms on UI | Reduce to 150–250ms | UI animations must feel instant |
| Hover without media query | `@media (hover: hover) and (pointer: fine)` | Touch devices trigger hover on tap |
| Keyframes on rapid element | CSS transitions | Transitions retarget; keyframes restart from zero |
| Same enter/exit speed | Exit faster than enter | Slow where user decides, fast where system responds |
| Elements appear at once | Stagger delay (30–80ms/item) | Cascading feels more natural |

---

## The Sonner Principles (Component Design)

From building Sonner (13M+ weekly npm downloads):

1. **DX over complexity** — No hooks, no context, no setup. `<Toaster />` once, `toast()` anywhere.
2. **Good defaults > options** — Ship beautiful out of the box. Most users never customize.
3. **Naming creates identity** — "Sonner" (French: "to ring") > "react-toast". Memorability over discoverability.
4. **Handle edge cases invisibly** — Pause timers on hidden tabs. Fill gaps between stacked toasts. Capture pointer during drag.
5. **Transitions, not keyframes, for dynamic UI** — Rapid additions (toasts) need smooth retargeting.
6. **Cohesion** — Easing, duration, design, name — everything harmonizes. Match motion to mood.

---

## Debugging Animations

### Slow Motion Testing
Increase duration to 2–5× or use DevTools animation inspector. Look for:
- Colors transitioning smoothly vs. two distinct overlapping states
- Easing starting/stopping abruptly
- Wrong transform-origin
- Coordinated properties out of sync

### Frame-by-Frame
Chrome DevTools → Animations panel → step through frame by frame. Reveals timing issues invisible at full speed.

### Review Next Day
Fresh eyes catch imperfections. Play in slow motion or frame by frame to spot timing issues invisible at full speed.

### Test on Real Devices
Touch interactions require physical devices. Xcode Simulator is fallback but real hardware is better for gesture testing.

---

## Accessibility

### prefers-reduced-motion
Reduced motion = fewer/gentler, not zero. Keep opacity and color transitions. Remove movement and position animations.

```css
@media (prefers-reduced-motion: reduce) {
  .element { animation: fade 0.2s ease; /* No transform motion */ }
}
```

### Touch Device Hover States
```css
@media (hover: hover) and (pointer: fine) {
  .element:hover { transform: scale(1.05); }
}
```

Touch devices trigger hover on tap → false positives. Always gate hover animations behind this query.
