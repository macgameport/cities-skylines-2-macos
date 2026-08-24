# Open threads

Current stack: **self-built stock Wine 11.16 + DXMT**, promoted 2026-08-23 — 10 patches. Built by
`scripts/build-engine-1116.sh` from the official winehq source (the DXMT binaries and x86_64
dylibs are reused from a Porting Kit Wine11+DXMT wrapper, which remains the prerequisite install).
**Porting Kit Wine 11.0 + DXMT** is the parked fallback (`CS2dxmt11-pk110.app`); **Wine 10
Sikarugir + D3DMetal** (`S734M.app`) is the older proven one. See `README.md` for how it works,
`INSTALL.md` §6 for the engine build, and `docs/patch-inventory.md` for the patch-by-patch
breakdown.

## ✅ SOLVED: the alt-tab freeze (was this project's headline defect since July)

**Fixed in the daily stack as of 2026-08-23.** In exclusive Fullscreen, losing focus used to
freeze the render permanently — input and audio continued, the screen updated exactly once per
window-order change, and recovery meant a force-kill. It is gone: click-away → the game
self-minimizes (its own behaviour, unchanged) → **restore comes back live**, repeatedly,
confirmed in-game by James on the promoted engine.

**Root cause, pinned by measurement then reproduced standalone:** presents to an HWND's
*non-newest* swapchain are silently never composited. CS2 creates a second swapchain on focus
loss and keeps rendering into the original, so its output goes to a layer nothing shows.
`scripts/minrepro3.c` demonstrates it in ~150 lines with no fullscreen, minimize or focus change
required. Three earlier hypotheses were eliminated with evidence first (swap-effect warning,
`dxgi.handleAltTab`, the `DXGI_STATUS_OCCLUDED` gating) — full table in
`docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`, mechanism detail in `GOTCHAS.md` § alt-tab.

**The fix is upstream in Wine 11.16, not in DXMT.** Two commits in the 11.15→11.16 window are
candidates — `1a1d1f3f3` *"winemac.drv: Hide client_view when flushing window surfaces"* and
[`2293b0e`](https://github.com/wine-mirror/wine/commit/2293b0e) *"win32u: Keep unused client
surfaces around and reuse them"* — and both ship in the stock tarball, so the built engine
carries the fix whichever it is. Verified end to end: the reproducer says `STALE` on wine 11.0
and `LIVE` on our 11.16 build (`scripts/run-minrepro3.sh` computes the verdict), and the game
confirms it.

**Filed as [3Shain/dxmt#206](https://github.com/3Shain/dxmt/issues/206)** (open, 7 comments, no
maintainer response yet) with the trace, the standalone reproducer, and the wine-version
finding. AI assistance disclosed per their policy; no PR, ever — any DXMT-side fix is theirs.
⚠ **Still to post:** the game-level confirmation from a *stock-source* 11.16 build, which is the
thing nobody else has reported.

**Delivered instead of waiting:** `scripts/build-engine-1116.sh` builds the engine from official
Wine source in ~1 hour, redistributing nothing. Full plan, gates and as-built record:
`docs/plans/build-wine1116-dxmt-engine.md`. Measured payoff (M3 Max, same city/settings):
freeze gone · **44.86 FPS vs 42.7** · GPU 23.1 ms vs 25.9–26.6 · presentation **Direct** where
11.0 composited · exclusive Fullscreen usable again · same 10 patches, mods still download.

**Measured negative:** macOS **Game Mode stays Off** even in exclusive fullscreen — the
hypothesis that regaining exclusive fullscreen would make the app eligible is closed. Likely a
Rosetta/Wine categorisation thing; nothing else depends on it.

**Second thing worth posting upstream:** [#141](https://github.com/3Shain/dxmt/issues/141) (Steam
CEF black window, ANGLE `EGL_BAD_ALLOC`, open) is **intermittent** here, not absent — library
rendered fine 2026-08-23 (purchases + DLC worked); fully black on 2026-08-24 in both GPU and
software compositing (GOTCHAS § visible Steam UI). The daily flow is immune (Steam runs
`-silent`). Any upstream comment should say "intermittent under stock wine 11.16", which is
still useful signal on the open issue.

## Performance: the deep optimization pass (RUNNING — P0–P2 measured 2026-08-24)

James, 2026-08-23: *"take a deep hard look at optimizing efficiency"* — serious token budget
approved. Plan + ethos: `docs/plans/perf-pass.md` (check-it'd, as-built header current).
Measured table: `docs/perf-pass-results.md`. Method + traps: GOTCHAS (benchmark instrument,
Settings.coc edit rule, resolution/upscaling closures).

**Done:** instrument discovered (the game's own `-benchmark` writes structured per-frame results;
`scripts/perf-bench.sh` runs autonomous cycles) · noise floor 1.03 FPS · resolution/upscaling
family closed by live adjudication (borderless locks backbuffer res; MetalFX supersample-only
there; TAAU pathological; street names are world text) · settings matrix measured autonomously
via Settings.coc edits (LOD = GPU+CPU double lever; High SMAA costs ~5 gpuMs, kept for looks;
texture-up free) · **composed daily driver measured +11.6% avg / +55% 1%-low** (native + High
SMAA + LOD 0.25 + mipbias 0) — **applied to settings, awaiting James's pop-in verdict**.

**Remaining:** P3 pacing cells (`preferredMaxFrameRate` on the daily scene, vsync decision) ·
P4 late-game CPU cells (M0-L baseline + job-worker-count/allocator boot.config levers) ·
P5 ship (README numbers + wiki draft after the profile verdict). Out of scope unchanged
(DXMT rebuild, alternative layers, Rosetta experiments) — and the MoltenVK
dylib update is **cancelled** (2026-08-24 PM: the A/B against pk110 disproved it outright; see
Known-unresolved: Steam UI). What replaces it is the **vendor-patch port
mini-project** (see Known-unresolved: Steam UI) — the bisect ran 2026-08-24 PM and found no
version regression to bisect; stock Wine never rendered embedded Chromium here.

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

- **Steam's visible UI black — DIAGNOSIS FINAL (2026-08-24 PM-2): embedded Chromium has NEVER
  rendered on stock Wine on this Mac; the Porting Kit engine renders it because of its VENDOR
  PATCHSET.** The same-day "wine 11.0 → 11.16 regression" reading was disproven by a three-version
  stock sweep (11.0/11.15/11.16, identical configure, all blank, byte-identical) — the operative
  variable in the original A/B was PK-vendor-vs-stock, not the version. Build-config omissions
  ruled out (config.h parity, md5-identical shared binaries). Measured dead as fixes: Proton
  `WINE_SIMULATE_WRITECOPY` patch (armed, in-binary, still blank) · msync/writecopy env probes on
  PK (renders with both off) · module transplants PK→stock (window stack: still blank; core/DXMT:
  crashes) · `--in-process-gpu` (Electron: breaks startup; Steam: filters the flag).
  **Mechanism CONFIRMED by elimination (evening, post-unlock):** Chromium's software
  presentation is broken on ALL winemac engines (PK's `--disable-gpu` run is byte-identically
  white; crossblit shows cross-process GDI lost on both engines) — **PK renders CEF solely
  because its GPU path works** (ANGLE→D3D11→DXMT presenting cross-process via vendor plumbing
  spanning winemac/win32u/wineserver). Stock fails the GPU path, falls back to software, hits
  the same floor. One defect family: dxmt#141 + dxmt#183 + every white window measured here.
  - ✅ **Standing workaround: two wrappers.** Play on `CS2dxmt11` (11.16), Steam UI on
    `CS2dxmt11-pk110` — **do not delete pk110.**
  - ▶ **Queued mini-project (needs own plan):** port the enabling vendor support into the 11.16
    engine, starting from public winecx source (CrossOver's shared window-surface machinery).
    Heavy; only if the two-wrapper split starts to chafe.
  - ✅ Post-unlock cells all ran 2026-08-24 evening — mechanism closed (GOTCHAS § "Mechanism
    CONFIRMED by elimination"). Driver: `~/cs2-patch/bisect/`.
  - **dxmt#206 (our alt-tab freeze issue) was closed by the maintainer as a duplicate of
    dxmt#183** (ANGLE white-window, winemac Metal-view lifetime) — same family. The game-level
    11.16 confirmation we owed #206 would now go to #183, if anywhere.
  - ✅ Upstream: the dxmt#141 evidence comment was **posted 2026-08-24** with James's approval
    (https://github.com/3Shain/dxmt/issues/141#issuecomment-5400445243) — vendor-vs-stock sweep,
    fastfail-masks-the-real-error warning, software-path failure parity, crossblit micro-repro,
    steam.exe flag-filtering facts, writecopy negative. Draft archived at
    `~/cs2-patch/bisect/draft-dxmt141-comment.md`.

- **Fullscreen-toggle cursor desync** — ⚠ *observed on wine 11.0; NOT re-tested on the promoted
  11.16 engine.* Toggling fullscreen ↔ windowed mid-session dropped the game out of exclusive
  fullscreen (a macOS title bar appeared); render resolution and window geometry stopped matching
  and cursor coordinates shifted. Since the whole defect class lived in the same client-surface
  machinery 11.16 reworked, this may already be gone — re-check before repeating the old
  "set Fullscreen and don't toggle" advice.
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
