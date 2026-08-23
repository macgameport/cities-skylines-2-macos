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

**Source dive 2026-08-22 (late) — the suspect list is now concrete** (details + `file:line` in
`GOTCHAS.md` § alt-tab and in the draft report's "Source-level findings"; v0.80 ≡ master here):

- Established: the swapchain **is exclusive fullscreen** (`Windowed == FALSE`) — the boot
  `Setting display mode` line is only reachable from exclusive-fullscreen paths. The draft's open
  question is answered.
- Established: `dxgi.handleAltTab` is **structurally inert for a game that minimizes itself on
  focus loss** (both reaction sites require `!window_minimized`) — explains the null result.
- Two live mechanism candidates with **opposite fingerprints**:
  (1) *wedged drawable pool* — `presentDrawableAfterMinimumDuration` on a never-composited layer
  wedges the 3-drawable pool; `nextDrawable` then returns nil forever and DXMT never nil-checks →
  silent no-op frames; near-idle CPU. (2) *orphaned layer* — the once-per-swapchain metal view gets
  disposed/replaced by winemac across miniaturize/restore; presents "succeed" into a detached
  layer; full-speed CPU.

**Next step (needs James at the keyboard, ~10 min):** one diagnostic repro discriminates the two.

1. `bash scripts/diag-launch-dxmt11.sh` (canonical launcher + `WINEDEBUG` macdrv/display/event
   trace to `/tmp/cs2-diag-<ts>.log`)
2. reach the menu, alt-tab away, come back → freeze
3. `bash scripts/capture-freeze.sh` **while frozen** (read-only: 5s `sample`, per-thread CPU,
   screen-static check, trace tail → `/tmp/cs2-freeze-<ts>/`)
4. recover as usual; next session reads the artifacts and pins the mechanism

**A minimal reproducer could not be built** (`scripts/focustest.c`, and see its notes in
`scripts/README.md`): a small DX11 app never receives `WM_ACTIVATEAPP DEACTIVATED` from a synthetic
focus change, so the trigger cannot be applied without a human at the keyboard. The game remains the
only reproducer.

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
