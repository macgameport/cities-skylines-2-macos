# R4 — Bugzilla submission draft

**Status: DRAFTED, NOT FILED.** Filing is a public post; James's call, same as the dxmt comments.

- **Product:** Wine · **Component:** winemac.drv · **Version:** 11.16 · **Platform:** macOS
- **Attach:** `scripts/frameless-window-repro.c` and `~/cs2-patch/evidence/repro-stock.png`
- Searched Bugzilla via the REST API 2026-08-31: 69 bugs in `winemac.drv` (confirmed with
  `limit=0`), 26 open, none covering this. Broad quicksearches across all components: 0 open hits.
  So this is a new report, not a comment on an existing one.

---

## Summary

winemac.drv draws a macOS title bar on a window that reclaimed its caption area via
`WM_NCCALCSIZE`, and the resulting geometry displaces all mouse input by the caption height.

## Steps to reproduce

1. Build the attached 60-line reproducer:
   `x86_64-w64-mingw32-gcc -O2 -o frameless-repro.exe frameless-window-repro.c -lgdi32`
2. `wine frameless-repro.exe`

It creates a `WS_OVERLAPPEDWINDOW` and, in `WM_NCCALCSIZE`, reserves a 5px border on the left,
right and bottom and **zero** on the top — the frameless-but-resizable pattern used by Electron and
CEF apps. `SWP_FRAMECHANGED` is applied after creation so the change takes effect.

## Expected

`dx=5 dy=0` (border kept, caption reclaimed) and **no** title bar — the application declined the
caption and draws its own chrome there.

## Actual

The window reports `dx=5 dy=0` as expected, and winemac draws a macOS title bar with traffic lights
anyway. Applications that draw their own title bar therefore show **two**.

The knock-on effect is worse than cosmetic: the Cocoa content view ends up ~28pt shorter than the
client rect Win32 reports, so `ScreenToClient` subtracts a window origin ~56px above where the
NSWindow actually is. **Every control hit-tests below the visible pointer** — you must hold the
cursor above a button to activate it.

Measured on a real application (the Paradox launcher shipped with Cities: Skylines II):

```
Win32 window rect : 228,346 px = 114,173 pt
Cocoa window drawn at         : 232,402 px = 116,201 pt     -> 56 px = 28 pt apart

Cocoa window       1279 x 674 pt
Cocoa content view 1279 x 642 pt   -> a 32 pt title bar that should not exist
Win32 client rect  1279 x 669.5 pt -> widths identical, heights 27.5 pt apart
```

Not a pointer-mapping bug — `GetCursorPos` agrees with macOS `CGEvent` to within truncation
(`dx -0.4, dy -0.4 px`, pointer verified stationary by bracketing the reads).

## Analysis

Two functions answer "does this window have a title bar" from different inputs, and nothing
reconciles them:

| caller | function | input |
|---|---|---|
| `macdrv_GetWindowStyleMasks` — win32u asks how much non-client space the window rect reserves | `get_window_features_for_style()` | **style bits only** |
| window creation / style change — the actual Cocoa decoration | `get_cocoa_window_features()` | style bits **+ `data->rects`** |

`get_cocoa_window_features()` already carries an evidence-based override —
`EqualRect(&data->rects.window, &data->rects.visible)` — so the incompleteness of the style test was
clearly known. But it never consults `rects.client`, which is precisely the record of what
`WM_NCCALCSIZE` did, and `struct window_rects` carries it already.

**That guard is also why this is not more widely noticed.** An application that reclaims the
*entire* window rect gets `dx=0 dy=0`, `window == visible` fires, and the window is left
undecorated — Steam's own client does exactly this and is unaffected. The bug needs a **border with
no caption**, which is the more common Electron shape.

## What does not fix it

Suppressing `title_bar` in `get_cocoa_window_features()` when `client.top == window.top` removes the
doubled chrome but **not the offset**: `GetWindowStyleMasks` still reports caption masks, win32u
keeps reserving the space, and the NSWindow simply moves down by it. Measured content-view vs
client: 27.5pt apart before and after. A fix has to make both answers share one source of truth, and
the ordering is the hard part — `GetWindowStyleMasks` is called *while* win32u is computing the very
rects it would need to consult.

## Disclosure

This was investigated with heavy AI assistance. I am filing a bug report rather than a patch, and
the reproducer is deliberately small enough to confirm or dismiss in two minutes without taking my
analysis on trust.
