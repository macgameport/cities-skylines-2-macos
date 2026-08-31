# R4 — winemac decorates a frameless window, offsetting every mouse coordinate by the caption height

**Component:** winemac.drv (window) · **Severity:** normal · **Platform:** macOS
**Status: NOT FILED — see "Before filing" at the foot. This is the TODO.**

## Summary

The frameless-but-resizable pattern — Electron and CEF apps, including the Paradox launcher that
ships with Cities: Skylines II — keeps `WS_CAPTION|WS_THICKFRAME` so Windows still supplies resize
borders, snap and normal window management, then handles `WM_NCCALCSIZE` to reclaim the caption area
for the client and draws its own title bar inside it.

winemac gives such a window a **real macOS title bar on top of the one it draws itself** (two sets of
window controls), and — the part that actually hurts — the Cocoa content view then ends up shorter
than the client rect Win32 reports, so **`ScreenToClient` returns a y that is ~28 points too large
and every control hit-tests below the visible pointer.** You have to aim above a button to press it.

## Root cause: two functions answer the same question from different inputs

| caller | function | input |
|---|---|---|
| `macdrv_GetWindowStyleMasks` — win32u asks how much **non-client** space the window rect reserves | `get_window_features_for_style()` | **style bits only** |
| window creation / style change — the **actual Cocoa decoration** | `get_cocoa_window_features()` | style bits **+ `data->rects`** |

Nothing reconciles them. `get_cocoa_window_features()` has one escape hatch —
`EqualRect(&data->rects.window, &data->rects.visible)` — which never consults `rects.client`, and
`rects.client` is precisely the record of what `WM_NCCALCSIZE` did.

`struct window_rects` already carries all three (`window`, `client`, `visible` —
`include/wine/gdi_driver.h`), so the evidence needed is present and unused.

## Measured

Two windows that the style test cannot tell apart. Neither is shaped or layered; both have
`WS_CAPTION`:

| | Steam (`SDL_app`) | Paradox launcher (`Chrome_WidgetWin_1`) |
|---|---|---|
| style | `0x94cf0000` | `0x14c70000` |
| client vs window | `2346x1500` == window (**dx=0 dy=0**) | `2560x1341` vs `2570x1346` (**dx=5 dy=0**) |
| macOS title bar | none (escapes via `EqualRect`) | **added** |

The launcher reserves 5px of frame left/right/bottom and **zero on top** — a resize border with no
caption. Consequences:

```
Cocoa window        1279 x 674 pt
Cocoa content view  1279 x 642 pt      -> a 32 pt title bar that should not exist
Win32 client rect   1279 x 669.5 pt    -> widths identical, heights 27.5 pt apart
```

**It is not a pointer-mapping bug.** wine's `GetCursorPos` agrees with macOS `CGEvent` to within
truncation, with the pointer verified stationary by bracketing the reads:

```
macOS 891.7,641.2 pt = 1783.4,1282.4 px | wine 1783,1282 px | dx -0.4  dy -0.4 px
```

It is window-relative: `ScreenToClient` subtracts a window origin 56 px (28 pt) above where the
NSWindow actually is (Win32 `228,346` px vs Cocoa `232,402` px).

## A half fix that does NOT work — recorded so nobody repeats it

Suppressing `title_bar` in `get_cocoa_window_features()` when `rects.client.top == rects.window.top`
removes the doubled chrome, and it was verified visually. **It does not fix the offset**, because
`macdrv_GetWindowStyleMasks` still reports caption masks and win32u keeps reserving the space — the
NSWindow merely moves *down* by it:

| | content view vs Win32 client |
|---|---|
| before | 642.0 vs 669.5 → **27.5 pt** |
| after | 643.0 vs 670.5 → **27.5 pt** |

Same error, different mechanism. It was reverted here: a half fix that leaves the two functions
contradicting each other is worse than the original, because the next reader sees no title bar and
no reason to suspect the window rect still contains one.

**A real fix has to make both answers come from one source.** The ordering is the hard part —
`GetWindowStyleMasks` is called *while* win32u is computing the very rects it would need to consult.

## Before filing — the actual TODO

1. **Build a minimal reproducer against STOCK wine.** Everything above was observed on a
   DXMT-patched wine 11.16. The relevant code is byte-identical in stock (`get_cocoa_window_features`
   diffed; `macdrv_GetWindowStyleMasks` confirmed style-only) — but *identical code* is an inference,
   not a reproduction, and this project has been bitten by exactly that gap. ~40 lines: a window with
   `WS_CAPTION|WS_THICKFRAME` that returns the full rect from `WM_NCCALCSIZE`, printing its window
   rect, client rect and `ScreenToClient` for a known screen point. Run it in a throwaway prefix.
   ⚠ `~/cs2-patch/build-1116/engine-1116` has the stock `winemac.so` but **no `bin/wine64`** — there
   is no runnable stock build on this machine yet.
2. **Check WineHQ's position on AI-assisted reports.** No published policy was found (Developer FAQ,
   Project Organization; the only wine-devel AI thread is about using AI *for review* and reads as
   tongue-in-cheek). Absence is not permission for AI-authored *patches* — but this is a bug report,
   not a patch. Disclose the AI assistance either way, as was done on dxmt#141.
3. **File on bugs.winehq.org, component `winemac.drv`.** Searched via the Bugzilla REST API
   2026-08-31: **69 bugs in the component** (confirmed with `limit=0`, not a default cap), 26 open,
   and **nothing covers this** — no open bug on title bar / caption / decoration / frameless, none on
   cursor offset, none on cross-process Metal. Broad quicksearches across all components: 0 open hits.
   So this is a new report, not a comment on an existing one.
4. **Report the diagnosis, not a patch.** The fix needs an ordering decision that belongs to someone
   who knows win32u's rect pipeline.

## Deliberately NOT filed: the cross-process Metal swapchain

Wine already knows — `Cross-process child window Metal swapchains are not implemented` is an
explicit FIXME in `winemac.drv`. Our implementation of it is a **feature**, not a bug fix, it is
AI-authored, and wine's patch process wants a human author. It is public in `scripts/` and described
in full on [dxmt#141](https://github.com/3Shain/dxmt/issues/141#issuecomment-5477055980) for anyone
who wants it. Revisit only if a wine developer asks.
