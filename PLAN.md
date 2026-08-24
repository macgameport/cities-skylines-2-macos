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
state: **watch #206 for maintainer response**; offer to run experiments / test builds on
request (`minrepro3.c` source since shared — repo is public). No PR, ever — any fix is theirs to write.

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

**✅ RESOLVED UPSTREAM IN WINE 11.16 (tested 2026-08-23).** Ran `scripts/minrepro3.exe` under
WineForge 0.6.0.3 (wine-11.16 + DXMT v0.80) and presents to the older swapchain composite normally:
the red pulse animates live — `(241,37,27)` → `(131,15,9)` → `(16,0,0)` — where wine-11.0 gave
byte-identical stale teal `(32,126,127)`. Three runs, consistent. The DXMT in WineForge is *older*
than ours (`v0.80` vs `v0.80-17-g79f6279`), so the fix is on the Wine side — almost certainly
[`2293b0e`](https://github.com/wine-mirror/wine/commit/2293b0e) *"win32u: Keep unused client
surfaces around and reuse them if possible"*, which landed in **11.16, not 11.15**. Reported to
[dxmt#206](https://github.com/3Shain/dxmt/issues/206).

**Validated the same day — the upgrade is de-risked.** Stock wine 11.16, compiled from source
here, passes the file-IO probe clean (44 OK / 7, zero garbage errno — identical to 11.0 and 11.15),
so the 10-patch stack stays 10 on a clean 11.16 base; only WineForge's build regresses it
(`docs/wine-bugs/FINDING-wine11.16-tradeoff.md`). So a DXMT engine on a clean 11.16+ base is
strictly better than wine 11.0: alt-tab freeze gone, exclusive Fullscreen usable again, macOS Game
Mode eligible (the HUD shows it Off in borderless), same patch count.

**Standing action:** when Porting Kit (or anyone) ships a DXMT engine on 11.16+, run the probe once
against it before switching — `scripts/monohost.exe` + `scripts/filetest_net.exe`, see
`docs/wine-bugs/README.md`. 44 OK / 7 means switch; anything else means `CS2_ERRNO_PATCHES=1`.
Until such an engine exists, wine 11.0 + Fullscreen Window remains the recommendation.

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

## Bring the stack up on wine 11.16 — the plan (feasibility verified 2026-08-23)

The freeze fix is upstream in 11.16 and stock 11.16 probes clean, but nobody ships a clean-base
11.16 DXMT engine yet. Two paths; A costs nothing, B is fully specified below and its unknowns
were verified on this machine.

**Path A (the standing action above):** wait for Porting Kit (or anyone) to ship a DXMT engine on
a clean 11.16+ base, probe it, switch. Zero effort, unknown timeline.

**Path B: build the engine ourselves** from the stock 11.16 already compiled here — no LLVM/DXMT
toolchain burden, because the DXMT binaries are copied, not rebuilt. **CHOSEN 2026-08-23 (James):
build now, validate on a cloned wrapper.** The full implementation plan is
`docs/plans/build-wine1116-dxmt-engine.md` — gate: run `check it` on it before building.

Verified 2026-08-23 (all measured on this machine, none assumed):

- **aquadran's "DXMT support" winemac patch applies clean to 11.16** — dry-run, 9/9 files, zero
  fuzz. Preserved at `scripts/wineandaqua-dxmt.patch` (was only in volatile /tmp). Its `C_ASSERT`s
  turn struct-layout drift into a compile error rather than a runtime mystery.
- **The toolchain is already installed:** the probe build's configure found and used a real PE
  cross-compiler (`x86_64-w64-mingw32-gcc`); brew has bison, freetype, gnutls.
- **No ffmpeg/gstreamer needed:** the PK engine's `winedmo.so`/`winegstreamer.so` link dylibs the
  bundle does not contain — they cannot load today, so the working baseline runs without them.
- **steam.exe is 64-bit** (PE32+); the only PE32 binaries are off-path helpers (uninstaller,
  crash reporters, fossilize). Build `--enable-archs=i386,x86_64` anyway to match PK.
- **The 10 patches are engine-independent** (they live in the game's `mscorlib`), and stock 11.16
  already probed 44 OK / 7 — the stack stays 10 patches.
- **Open question — PK's DXMT binding.** Upstream DXMT finds winemac via
  `dlsym("macdrv_functions")` with a bare-symbol fallback, but the PK engine exports NONE of those
  symbols (dlopen/dlsym probed: all NULL) and its DXMT is a fork build (`v0.80-17-g79f6279`,
  commit not upstream). Whatever glue PK uses is undocumented — so PK's DXMT binaries on a stock
  build are a test, not a given. The hedge is half-proven by WineForge (an 11.16 winemac serving
  DXMT v0.80 presents): our winemac carries the aquadran patch, try PK's fork binaries first, and
  fall back to WineForge's plain-v0.80 DXMT binaries (their *wine* was the broken half, not their
  DXMT; DMG sha256 is in the ledger).

Ladder (one session to bootable, one to validated; rollback at every step = `mv` the .BAK back):

1. **Recon on the current engine (5 min):** `DXMT_LOG_LEVEL=debug WINEDEBUG=+macdrv` run of
   `scripts/run-minrepro3.sh` — log which path creates the metal view; says whether the winemac
   patch is load-bearing at all.
2. **Build:** re-configure the 11.16 source with the full set — drop `--disable-winemac-drv
   --without-freetype --without-gnutls`, keep `--host=x86_64-apple-darwin` and
   `CC="clang -arch x86_64"`, switch to `--enable-archs=i386,x86_64`, brew bison + gmake — apply
   the patch, build ~45–60 min. (⚠ the /tmp build tree and source do not survive a reboot; the
   tarball is re-downloadable.)
3. **Assemble in PK layout:** `bin/wine64` + `bin/wineserver`, `lib/wine/{x86_64-unix,
   x86_64-windows,i386-windows}`, copy the PK engine's bundled dylibs (freetype, gnutls, brotli,
   MoltenVK, SDL2), drop in the DXMT binaries (`d3d11.dll`, `dxgi.dll`, `winemetal.dll`,
   `winemetal.so`, + i386 PE variants).
4. **Smoke ladder, in order:** minrepro3 (binding works + freeze fix present) → errtest (9/9) →
   monohost + filetest_net (**gate: 44 OK / 7, zero garbage errno**).
5. **Game, on a safety copy:** APFS-clone the wrapper (`cp -c`, near-free) or `.BAK` the `wine/`
   dir (the `wine.sikarugir10-BAK` pattern). The prefix updates in place on first boot. Then:
   Steam login → city load → **exclusive fullscreen + alt-tab** (the point) → in-game Paradox
   Mods download (the §11 `ClearFolderAndKeepPatchFile` path) → Game Mode on the HUD + FPS
   exclusive-vs-borderless → second-display/refresh-rate check → save/load.
6. **Promote + docs:** flip the wrapper default, update the launcher's display-mode comment
   (exclusive fullscreen becomes recommendable again — edit only with the game closed), update
   README/INSTALL/GOTCHAS/this file, report the working combination on dxmt#206, and decide:
   publish a build-engine script so strangers can follow, or keep the public recommendation at
   PK 11.0 + borderless until a public engine exists.

Payoff beyond the freeze: exclusive fullscreen returns → macOS **Game Mode** becomes eligible
(the HUD shows it Off in borderless) — measure it at step 5.

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
