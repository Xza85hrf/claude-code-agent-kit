# Component Interaction Polish

Expert component interaction patterns from Emil Kowalski (Sonner, Vaul). These patterns make software feel right through invisible correctness.

---

## Button Press Feedback

Every pressable element needs `:active` feedback. Instant confirmation the UI heard the user.

```css
.button { transition: transform 160ms ease-out; }
.button:active { transform: scale(0.97); }
```

Scale range: 0.95–0.98. Subtle but tangible. `scale()` scales children proportionally — this is a feature.

---

## Never Animate From scale(0)

Nothing in the real world disappears completely. `scale(0)` entries look like they come from nowhere.

```css
/* Bad */
.entering { transform: scale(0); }
/* Good — barely visible initial shape, like a balloon */
.entering { transform: scale(0.95); opacity: 0; }
```

---

## Origin-Aware Popovers

Popovers must scale from their trigger, not from center. **Exception: modals stay centered** (no trigger anchor).

```css
/* Radix UI */
.popover { transform-origin: var(--radix-popover-content-transform-origin); }
/* Base UI */
.popover { transform-origin: var(--transform-origin); }
```

---

## Tooltip Delay Skip

First tooltip: delay before appearing (prevent accidental activation). Subsequent tooltips while one is open: **instant, no animation**. Feels faster without defeating the initial delay's purpose.

```css
.tooltip {
  transition: transform 125ms ease-out, opacity 125ms ease-out;
  transform-origin: var(--transform-origin);
}
.tooltip[data-starting-style], .tooltip[data-ending-style] {
  opacity: 0; transform: scale(0.97);
}
.tooltip[data-instant] { transition-duration: 0ms; }
```

---

## CSS Transitions Over Keyframes for Dynamic UI

Transitions retarget mid-animation. Keyframes restart from zero. For anything triggered rapidly (toasts, toggles), transitions are smoother.

```css
/* Interruptible — good */
.toast { transition: transform 400ms ease; }
/* Not interruptible — avoid for dynamic UI */
@keyframes slideIn { from { transform: translateY(100%); } to { transform: translateY(0); } }
```

---

## Gesture & Drag Patterns

### Momentum-Based Dismissal

Don't require dragging past a threshold. Calculate velocity — a quick flick should dismiss.

```js
const timeTaken = new Date().getTime() - dragStartTime.current.getTime();
const velocity = Math.abs(swipeAmount) / timeTaken;
if (Math.abs(swipeAmount) >= SWIPE_THRESHOLD || velocity > 0.11) { dismiss(); }
```

### Damping at Boundaries

When dragging past natural limits, apply increasing friction. Real things don't suddenly stop — they slow down.

### Pointer Capture

Once dragging starts, capture all pointer events on the element. Ensures drag continues even when pointer leaves bounds.

### Multi-Touch Protection

Ignore additional touch points after initial drag. Without this, switching fingers causes the element to jump.

```js
function onPress() { if (isDragging) return; /* Start drag... */ }
```

### Friction Over Hard Stops

Allow overscroll with increasing friction instead of preventing it. Feels more natural than hitting an invisible wall.

---

## Performance Gotchas

### CSS Variable Inheritance

Changing a CSS variable on a parent recalculates styles for **all children**. In a drawer with many items, updating `--swipe-amount` on the container → expensive style recalc.

```js
// Bad: triggers recalc on all children
element.style.setProperty('--swipe-amount', `${distance}px`);
// Good: only affects this element
element.style.transform = `translateY(${distance}px)`;
```

### Only Animate transform and opacity

These skip layout and paint, running on the GPU. Animating `padding`, `margin`, `height`, `width` triggers all three rendering steps.

### Framer Motion Shorthand Is Not GPU-Accelerated

`x`, `y`, `scale` props use `requestAnimationFrame` (main thread). For hardware acceleration:

```jsx
// Drops frames under load
<motion.div animate={{ x: 100 }} />
// GPU-composited, smooth
<motion.div animate={{ transform: "translateX(100px)" }} />
```

---

## Touch Device Hover Gates

Touch devices trigger hover on tap → false positive hover states. Gate hover animations:

```css
@media (hover: hover) and (pointer: fine) {
  .element:hover { transform: scale(1.05); }
}
```

---

## translateY Percentages

`translate()` percentages are relative to the element's own size. Use `translateY(100%)` to move by own height regardless of actual dimensions.

```css
.drawer-hidden { transform: translateY(100%); }  /* Works at any height */
.toast-enter { transform: translateY(-100%); }
```

Prefer percentages over hardcoded pixels — less error-prone, adapts to content.
