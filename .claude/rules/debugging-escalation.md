# Debugging Escalation Rule

## The 3-Attempt Pivot Rule

When debugging a third-party asset issue (font, library, framework behavior):

1. **Attempt 1-2**: Try the obvious CSS/config-level fix
2. **Attempt 3**: Try a deeper fix (binary modification, alternate API, workaround)
3. **After 3 failures**: STOP fixing. Evaluate **replacement**.

## Why This Exists

Real-world case: 9 attempts to fix Syne font clipping on Windows (padding, line-height, overflow, descent-override, font binary patching, text-stroke, text-rendering). Switching to Space Grotesk fixed it in 5 minutes.

## Pivot Signals

Replace the asset instead of continuing to debug when ANY of:
- The bug is in the asset's internals (you can't fix the source)
- The bug is platform-specific (headless testing can't reproduce it)
- Each fix reveals a new manifestation of the same root issue
- The asset's behavior depends on rendering engine internals (GPU rasterization, DirectWrite, etc.)

## Platform-Specific Bug Warning

Headless browsers (Playwright, Puppeteer) use software rendering. They CANNOT catch:
- GPU rasterization differences (Windows DirectWrite vs macOS CoreText)
- DPI scaling artifacts
- Font hinting/anti-aliasing differences
- Subpixel rendering bugs

When a user reports a visual bug you can't reproduce in headless → ask for DevTools screenshots from their actual machine.
