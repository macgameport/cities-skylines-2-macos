# Open threads

Current stack: **Wine 11.0 + DXMT** (Porting Kit wrapper), default since 2026-08-22 — 10 patches
instead of 17. **Wine 10 Sikarugir + D3DMetal** stays as the proven fallback. Both are playable with
mods downloading and loading; both have working Steam clients. See `README.md` for how it works and
`docs/patch-inventory.md` for the patch-by-patch breakdown.

## Top user-facing defect: the alt-tab freeze

Switching away from exclusive fullscreen — alt-tab **or just clicking outside the window** — freezes
the render on the default stack: input still registers, the surface never re-presents, and recovery
needs a force-kill (`wineserver -k`), which can leave a `.crash` marker that blocks the next launch.
Wine 10 + D3DMetal misbehaves too, but more mildly (cursor desync, darkening).

**Three hypotheses are eliminated, each with evidence** (full table in
`docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`):

| hypothesis | verdict |
|---|---|
| The `unsupported swap effect 3` warning means a degraded fallback swapchain | **Dead.** Cosmetic — `d3d11_swapchain.cpp:1114` logs it and builds the same swapchain regardless. |
| `dxgi.handleAltTab = True` just needed enabling | **Dead.** Config provably loaded; freeze unchanged. Matches upstream's own "still broken for certain games" comment. |
| CS2 never receives `DXGI_STATUS_OCCLUDED` because the branch is gated `SwapEffect <= SEQUENTIAL` | **Dead.** Binary-patched that comparison in the shipped `d3d11.dll` so flip-model reaches it; freeze unchanged. Reverted. |

**MECHANISM PINNED 2026-08-23** (diag run + held freeze + thread-stack sample; full account in
`GOTCHAS.md` § alt-tab and the draft report's "Live-freeze measurements"): only the *screen*
freezes — the game runs at ~250% CPU, presents complete, drawables recycle, and the screen updates
**exactly once per minimize/restore cycle**. Trigger, traced: at the first focus loss the game
minimizes itself, then **creates a second swapchain 600ms later while the window is miniaturized
with an empty client rect** — that swapchain's CAMetalLayer never enters live compositing, and it
is the one the game presents into forever after. Wedged-drawable-pool theory eliminated by
measurement (zero `nextDrawable` waits). Windowing restores are flawless in the trace — the layer
was broken at birth, not by the restore.

**Next step — build the now-possible minimal reproducer** (no human needed: the trigger is
programmatic, not a real focus loss): extend `scripts/focustest.c` → `scripts/minrepro.c`:
window + swapchain + colored presents → `ShowWindow(SW_MINIMIZE)` → create swapchain #2 on the
same HWND while minimized → `SW_RESTORE` → color-cycling presents on #2 → screencapture twice →
static screen = repro. If it reproduces, attach to the upstream report and file (still gated on
`gh auth login` as macgameport — James-only).

**Historical note:** the earlier reproducer attempt (`scripts/focustest.c`) failed only because it
needed a *real* macOS focus loss, which automation cannot deliver to a Wine window. The measured
trigger removes that requirement entirely.

**The report is written and ready** (`docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`, now carrying the
2026-08-22 source-level findings section), **not filed** —
blocked only on authenticating `gh` as `macgameport`. ⚠️ **DXMT forbids AI-authored contributions**
(`AGENTS.md`, `CONTRIBUTING.md` § AI Policy): no PR, no generated code, but AI-assisted research
shared with the developers is explicitly permitted. So this goes up as prose + measurements, with
the assistance disclosed, and a human writes any fix.

Interim workaround: don't switch away from fullscreen; use the windowed launcher when you must.

**Second thing worth posting upstream:** [#141](https://github.com/3Shain/dxmt/issues/141) (Steam CEF
black window, ANGLE `EGL_BAD_ALLOC`, open) **does not reproduce** on DXMT v0.80 + wine-11.0 here —
Steam's UI renders, purchases and DLC downloads work. A useful negative result on a still-open issue.

## ✅ Retired: "fix it upstream in Wine"

**This was the top item for months. All three root causes are now resolved, none of them by us
filing anything.** Kept as a record of how it ended:

| ID | Defect | Outcome |
|---|---|---|
| **R1** | `GetLastError` garbage after file APIs | **Fixed upstream in Wine 11.0** — measured 2026-08-22. Retires 6 patches. The bug was never in `kernel32`; bug [60220](https://bugs.winehq.org/show_bug.cgi?id=60220) blamed the wrong layer and was correctly closed INVALID. It is Mono's P/Invoke last-error capture. |
| **R2** | `CreateFile` returns handle `0` for a valid file | **Disproven.** 3200 concurrent opens, short and long paths, both Wine versions — never once (`scripts/handletest.c`, `scripts/longpathw.c`). The handle-0 symptom is real but arises elsewhere; `patch_fshandle` is still needed. |
| **R3** | `BCryptVerifySignature` fails on valid ECDSA | **Fixed upstream in Wine 11.0** — measured 2026-08-22 by reverting the Coherent Gameface licence bypass entirely and reaching the main menu with zero licence errors. This retires the one patch that could not be published. |

Consequence: **every patch the default stack needs is published in this repo.** Nothing is left to
file against Wine.

## Report upstream to Paradox

`patch_lockleak` works around a genuine PdxSdk defect, not a Wine one:
`FileIO::CreateFileStream`'s state machine has two `catch` clauses and **no `finally`**, and the
catch handler never disposes the lock acquired at IL `0x78`/`0x82` — though the FileNotFound path at
`0x120` does. Any IO exception leaks that path's lock permanently; the next waiter dies on
`GetLockToken`'s timeout. Windows just rarely throws there, so it hides. Clean fix upstream: dispose
in the handler, or wrap in `finally`.

## Known-unresolved, low severity

- **Fullscreen-toggle cursor desync.** Toggling fullscreen ↔ windowed mid-session drops the game out
  of exclusive fullscreen (a macOS title bar appears); render resolution and window geometry stop
  matching and cursor coordinates shift. Workaround: set Fullscreen and don't toggle.
- **Graphics settings must be set in-game.** Hand-editing `Settings.coc` to flip an `enabled` flag
  without its accompanying parameters produces an "on but zeroed" profile (e.g. SSGI with
  `raySteps: 0`) that the game reports as `Custom` and does not restore across a display-mode
  change. Use Options → Graphics.
- **D3DMetal unsupported-API notices** at startup (`NumClassInstances > 0`, `GetSharedHandle`,
  timestamp queries). One-time init messages, not per-frame; no observed impact.
- **Rosetta horizon.** The entire stack is x86-64 under Rosetta 2, and macOS 26 now surfaces a
  deprecation notice ([Apple 102527](https://support.apple.com/en-us/102527)) — coming, not in
  effect. Apple's stated plan: full Rosetta through macOS 27, then a reduced subset "for older
  games" in macOS 28+, with no word on whether Wine-style use qualifies. Nothing to do today;
  plan-B territory (ARM-native Wine/FEX or whatever exists by then) around late 2027.

## Not worth doing

- **Reviving the DXVK/MoltenVK stack.** Archived in `archive/`. D3DMetal is stable where it was not.
- **CrossOver.** Licence expired 2026-08-21. The free stack matched it and then exceeded it.
- **`patch_pdxsdk_io`.** Masks failures instead of fixing them; breaks boot on empty mod state.
- **The four rejected lock patches.** All chased a deadlock that does not exist. See
  `docs/patch-inventory.md` §5.
