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

**REPRODUCED STANDALONE 2026-08-23 (same day), and simpler than the game's trigger:**
`scripts/minrepro3.c` + `run-minrepro3.sh` — two swapchains on one HWND, present to the OLDER one:
completes at 120fps/S_OK, never reaches the screen (byte-identical screenshots across 6s), while
presents to the newest chain show instantly. **No fullscreen, no minimize, no focus change
required.** The defect: only the newest swapchain's layer on an HWND is composited; CS2 freezes
because Unity creates a recovery swapchain on alt-tab and keeps rendering into the original.
(`minrepro.c` v1 and `minrepro2.c` v2 are the experiment ladder — kept because their negative and
intermediate results are cited in the report.)

**FILED 2026-08-23: [3Shain/dxmt#206](https://github.com/3Shain/dxmt/issues/206)** — the full
report (trace timeline, frozen-state sample, standalone reproducer recipe with numeric verdicts),
with AI assistance disclosed per their policy. Authored by the personal account — the "needs
macgameport auth" premise was a misunderstanding (macgameport is an org, not an account). Standing
state: **watch #206 for maintainer response**; offer to run experiments / test builds / share
`minrepro3.c` source on request (repo currently private). No PR, ever — any fix is theirs to write.

**Historical note:** the 2026-08-22 reproducer attempt (`scripts/focustest.c`) failed only because
it assumed the trigger was a *real* macOS focus loss, which automation cannot deliver to a Wine
window. The actual trigger (second swapchain on the same HWND) needs no focus event at all.

Interim workaround: don't switch away from fullscreen; use the windowed launcher when you must —
and if it bites mid-session, the one-refresh-per-alt-tab behavior lets you blind-save and quit.
**CONFIRMED 2026-08-23 (Option-2 test):** toggling to **Fullscreen Window** while frozen revives
presentation LIVE (trace: no new swapchain — the game switches to presenting its windowed chain,
the visible one). Better: **Fullscreen Window mode is immune to the freeze entirely** (alt-tab
clean, input correct, verified in-city). The freeze is neutralized for daily play; exclusive
Fullscreen stays broken until upstream fixes #206. ⚠ After the game closes: update the launcher
comment that recommends exclusive fullscreen (never edit launch scripts while the game runs).

**Upgrade experiment (promising, raised 2026-08-23):** wine dev post-11.0 is actively
reworking the exact machinery the freeze lives in: `2293b0e` (2026-07-08, ~11.14+) "win32u: Keep
unused client surfaces around and reuse them if possible" — surface REUSE could make the
second-swapchain-hides-first defect not exist at all — and `1a1d1f3` (2026-08-04, ~11.15/16)
changes the client_view hide logic again. Test = a DXMT-enabled engine on wine-11.15+: either find
a newer engine on the Porting Kit/Wineskin channel, or build wine + the DXMT-enablement winemac
patch ourselves (plain clang; the patch may need porting to the reworked client-surface code).
Either freeze outcome is worth a comment on dxmt#206. Needs a regression pass over the 10-patch
stack (dev wine may move other behaviors).

**Local-fix options — likely unnecessary now that Fullscreen Window is immune; kept for reference** (neither violates DXMT's AI policy — that governs
contributions to *their* repo, not what runs on this machine): (a) binary-patch the engine's
`winemac.so` so the previous client view is not hidden when a new one attaches (the new view is
added BELOW existing siblings, so the old — presented-to — view would stay on top and composite;
one call site to neutralize; same class of local patch as the occlusion diagnostic was); (b)
rebuild the Wine side from source with that one-line change — plain clang build, none of DXMT's
LLVM-15 toolchain burden. Both are next-session work if wanted.

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
