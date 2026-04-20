# Third-Party Asset Pivot Rule

## The Problem

When debugging an issue caused by a third-party asset (font, library, framework), the standard "find root cause → fix" loop can become an infinite loop because **you can't fix the asset's internals**.

## Pivot Signals (Replace Instead of Fix)

After **3 failed fix attempts**, evaluate replacement if ANY of these are true:

1. **The bug is in the asset's internals** — You've traced the root cause into the font binary, library source, or framework core. You can work around it but not fix it.

2. **The bug is platform-specific** — Works on macOS but clips on Windows. Works in Chrome but breaks in Safari. Headless tests pass but real devices fail.

3. **Each fix reveals a new manifestation** — You fix clipping at 20px but it reappears at 24px. You fix the bottom but now the top is off. The problem shape-shifts with each attempt.

4. **Fixes require fighting the platform** — CSS descent-override doesn't affect DirectWrite glyph texture allocation. Your fix operates at the wrong abstraction layer.

5. **The asset has known upstream issues** — Check the font's GitHub issues, the library's bug tracker. If others report the same problem with no fix, don't expect to find one yourself.

## Decision Framework

```
After 3 failed fixes on a third-party asset:

Is the root cause in YOUR code?
  YES → Keep debugging (you can fix your own code)
  NO  → Continue ↓

Is there an upstream fix available?
  YES → Apply it (patch, update, config flag)
  NO  → Continue ↓

Is the asset easily replaceable?
  YES → REPLACE IT. Time spent: 5 min vs hours of workarounds.
  NO  → Continue ↓

Is the workaround maintainable?
  YES → Document it thoroughly and accept the tech debt
  NO  → REPLACE IT anyway. The maintenance cost exceeds replacement cost.
```

## The Debugging Hierarchy (Escalation Ladder)

When fixing rendering/display bugs in third-party assets, attempts follow this typical escalation:

```
Level 1: CSS layout fixes (padding, overflow, line-height)     → Fast, often works
Level 2: CSS overrides (font-specific properties)              → Sometimes works
Level 3: Asset modification (binary patching, forking)         → Rarely works, fragile
Level 4: Rendering path changes (text-stroke, GPU hints)       → Platform-dependent
Level 5: Asset replacement                                     → Almost always works
```

**Key insight**: Most developers exhaust Levels 1-4 before considering Level 5. The 3-attempt rule forces you to evaluate Level 5 early.

## Platform-Specific Bugs: Special Handling

### Headless Testing Cannot Catch These

| Bug Type | Why Headless Misses It |
|----------|----------------------|
| GPU rasterization artifacts | Headless uses software rendering |
| DPI scaling issues | Headless uses fixed 1x or 2x DPI |
| Font hinting differences | Platform font engines differ |
| Subpixel rendering bugs | No real display output |
| DirectWrite vs CoreText | OS-level rendering path |

### When User Reports Visual Bug You Can't Reproduce

1. Ask for a screenshot from their **actual machine** (not just browser DevTools)
2. Ask what OS, browser, and display scaling they use
3. Compare against your headless screenshot — differences reveal platform rendering
4. If the bug is font-specific: check the font's vertical metrics (sTypoAscender/Descender, usWinAscent/Descent) for tight clearances

## Worked Example: Syne Font Clipping

**Problem**: Syne font's descenders ("g", "y", "p") clipped on Windows at 20px. Fine on macOS/Linux and in Playwright screenshots.

**Root cause**: Syne's `sTypoDescender: -275` left only 1.5px clearance for "g" at 20px — enough for macOS CoreText but not Windows DirectWrite + GPU rasterization + DPI scaling.

**Attempts that failed**:
1. CSS padding-bottom on text containers
2. CSS line-height increase
3. CSS overflow: visible
4. CSS descent-override
5. Font binary patching (adjusting sTypoDescender)
6. CSS text-stroke
7. CSS text-rendering: geometricPrecision
8. More padding/margin combinations
9. CSS font-feature-settings

**What worked**: Replacing Syne with Space Grotesk (5 minutes).

**Lesson**: CSS `descent-override` only affects the line-box height, not the glyph texture allocation that DirectWrite uses. No amount of CSS can fix a font engine's internal glyph bounds calculation. The fix had to be at the font level or the font had to be replaced.
