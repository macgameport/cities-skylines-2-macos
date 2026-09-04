# Reproducers and helpers

Compiled binaries are **not committed** (see `.gitignore`) — build them from source.
They exist to demonstrate the Wine bugs in `../docs/patch-inventory.md` **without launching
the game**, which makes them suitable to attach to a Wine bug report.

| Source | Purpose |
|---|---|
| `monohost.c` | Minimal host that runs a .NET assembly under **CS2's exact Unity Mono runtime** — so results reflect the game's runtime, not the system one |
| `filetest_net.cs` | The R1/R2 probe. Sections `[5][6][7]` cover recursive delete; `[10]`–`[13]` add Move/Delete/open-handle and nonexistent-path edges |
| `filetest.c` | Native Win32 equivalent, success paths (isolates Wine from Mono) |
| `handletest.c` | R2 probe: 8 threads × 400 opens, checks whether `CreateFile` ever returns handle `0`. Disproved R2 |
| `longpathw.c` | Long-path probe using the **wide** APIs as `System.IO.LongFile` does (`\\?\`, 449 chars). Disproved both R2 and `patch_createfile`'s premise. Note: the ANSI variants return `206 ERROR_FILENAME_EXCED_RANGE` for long paths — that is correct Windows behaviour, not a Wine bug |
| `errtest.c` | **Failure-path probe.** Checks `GetLastError` fidelity across 9 error cases. Disproved bug 60220 — passes 9/9 on both wine-10.0 and wine-11.15, so the Win32 layer is not the culprit |
| `dxtest.c` | Minimal DX11 clear-to-magenta — proves whether a graphics path can present at all. Invaluable for testing a renderer without a 78 GB game install |
| `whwrapper.c` | steamwebhelper wrapper used while chasing the CEF black screen (historical) |
| `focustest.c` | **Focus-loss probe.** DX11 present loop that logs per-frame `Present` hr + latency and every `WM_ACTIVATEAPP`/`WM_ACTIVATE`/`WM_KILLFOCUS`/`WM_SIZE`. Flags: `--flip` (FLIP_SEQUENTIAL, what CS2 asks for), `--fullscreen`, `--seconds N`. Built to reproduce the alt-tab freeze; **it does not** — see the caveat below |
| `wingrab.c` | Win32-side **window-tree dump** (hwnd / class / rect / style, recursive) for a window inside the prefix — this is what revealed Steam's top-level class is `SDL_app` with healthy CEF children. ⚠ Its pixel-grab half **does not work**: cross-process `GetWindowDC`+`BitBlt`/`PrintWindow` returns nothing under Wine, and `wine notepad` (which renders) returns the identical empty result. Use `winlist.swift` for pixels |
| `steamwebhelper-shim.c` + `install-webhelper-shim.sh` | ⚠ **PARTIAL — renders everything except TEXT** (see GOTCHAS; `--in-process-gpu` kills glyphs in Chromium 126 CEF under Wine, on PK too). Not installed by default. Takes `SHIM_ARGS` to swap injected switches without rebuild+repad. Injects `--in-process-gpu` at the webhelper (steam.exe filters it from its own cmdline), making Chromium's swapchain same-process — the path DXMT serves. Must be **zero-padded to the original's exact size**: Steam's bootstrap does "Verifying file sizes only" and silently restores an unpadded shim (exit 42). Re-run after any Steam client update; `--revert` undoes |
| `steam-render-cell.sh` | Runs ONE measured "does Steam's visible UI render?" cell and judges it by **per-window capture**, not logs. Wraps the scaffolding every revisit of the Steam-UI thread re-derives, plus the three traps that give a WRONG answer rather than no answer: a stale Chromium `SingletonLock` silently makes the launch `--silent` (no window, reads as a render failure); `screencapture` yields **no file** when the display sleeps/locks, so each cell also captures a known-good window and marks the reading VOID if that fails too; and steam.exe's Windows-style argv defeats cmdline pgrep, so processes are attributed by open files vs the prefix. `--shim-args` for switches steam.exe filters (needs the shim), `--steam-args` for ones it forwards (`--use-angle`). Calibration 2026-08-28: black 15–41 KB, rendered 0.7–2.0 MB |
| `steam-vanilla-d3d-split.sh` | Runs the Steam CLIENT on vanilla wined3d while the GAME keeps DXMT — install / verify / revert, with backups. **Measured 2026-08-28: the split lands but Steam is still black**, so this is kept for re-testing after upstream winemac work, not as a fix. Needs version-matched vanilla PEs (harvest via a `build-engine-1116.sh` run stopped after step 3). Strips wine's 17-byte `"Wine builtin DLL\0"` marker at file offset 0x40 — without that, a `native` override is redirected back to the builtin by `build_module`. ⚠ Its global `d3d11/dxgi=builtin` line is load-bearing: without it the GAME silently drops DXMT, so `--verify` checks the game path with `+loaddll` |
| `fonttest.c` | Counts the fonts **Chromium** can actually see — GDI `EnumFontFamiliesEx` vs DirectWrite `GetSystemFontCollection`, which is what CEF uses. Chromium renders no text at all if the DirectWrite collection is empty, so this separates "no fonts" from "glyphs not drawing". Measured identical (924 GDI / 204 DWrite) on both the 11.16 and PK engines |
| `crossblit.c` | Two-process probe for the **cross-process GDI presentation** question: parent paints its window green in-process, child FillRects red into it from another process; the macOS-side capture is the judge (green+red = primitive works; green-only = foreign paints land in a per-process shadow surface and never composite — the suspected reason embedded-Chromium UIs are blank on stock winemac while CrossOver-lineage builds render them). Local `GetPixel` readback returns CLR_INVALID cross-process on every engine — only the screen capture judges |
| `winlist.swift` | Lists on-screen windows (`id`, owner, size, title) via CGWindowList, so `screencapture -x -o -l <id>` can grab a **specific Wine window even when occluded** — no Accessibility permission, no hardcoded `-R` region. Built to measure Steam's black CEF windows |
| `capture-hang.sh`, `watch-mods.sh` | Diagnostics: sample a hung process; watch the mod-download tree live |
| `disasm.py` | IL walker used to derive patch offsets |
| `dump-binding-attrs.py` | Extracts mod **keybinding defaults** from `SettingsUIKeyboardBinding` attribute blobs (dnfile) — chords are enum+bool ctor args, never strings, so this is the only offline route to them. Pass `Game.dll` first (supplies the `BindingKeyboard` enum map); bool order calibrated **alt/ctrl/shift**. Built the 2026-08-25 mod-keybinding collision table (`GOTCHAS.md` § "Mod keybinding defaults are extractable offline") |
| `patch-modconflict-badge.py` | **Removes the per-boot mod keybinding ⚠ badges** in Options (deployed to `~/cs2-patch/` by `setup.sh`; the launcher re-ensures it every start, so game updates that replace `Game.dll` self-heal). Two IL edits, methods re-resolved by name each run via dnfile — run it with `~/cs2-patch/revenv/bin/python3`. No args = verify only (safe while the game runs); `apply` = backup + patch, refused unless the game is down. The badge is stale cached conflict state armed during mod registration, not a real collision — mechanism, the surviving rebind-dialog path, and the three invalid-IL forms this went through: `GOTCHAS.md` § "Mod keybind ⚠ badges" + § "IL opcode surgery" |
| `cs2-display-profile.sh` | **Display-profile applier the launcher runs before every boot** (deployed to `~/cs2-patch/` by `setup.sh`). Classifies by the *main* display — mobile (built-in retina) = native swapchain + DRS Constant 0.5 + CAS; home (external) = DRS off, native 1:1 — writing only the DRS block and Unity's "Use Native" registry flag, never the resolution tuple (measured unreliable from disk). `CS2_PROFILE=off\|home\|mobile` overrides, `DRY=1` previews without writing; fail-open with one log line per boot. Design, measurements and test battery: `docs/plans/launcher-display-profiles.md`; traps: `GOTCHAS.md` § "Retina mode" |

## Building

`dxtest.exe`, `filetest.exe`, `monohost.exe` — mingw-w64 cross-compiler:

```sh
brew install mingw-w64
x86_64-w64-mingw32-gcc dxtest.c    -o dxtest.exe    -ld3d11 -ldxgi -ldxguid -luuid
x86_64-w64-mingw32-gcc filetest.c  -o filetest.exe
x86_64-w64-mingw32-gcc monohost.c  -o monohost.exe
```

`filetest_net.exe` — build with the **prefix's own** C# compiler so it targets the same framework:

```sh
WINEPREFIX=<prefix> wine \
  "<prefix>/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe" \
  /out:filetest_net.exe filetest_net.cs
```

## Running the probe

```sh
WINEPREFIX=<prefix> wine 'Z:\path\to\monohost.exe' 'Z:\path\to\filetest_net.exe' 'C:\probe'
```

Reports per-section pass/fail. On Windows every section passes; under Wine on macOS the
garbage-errno and handle-0 sections fail deterministically — that contrast is the bug report.

## `focustest.c` — what it showed, and what it did not (2026-08-22)

Windowed and fullscreen, `DISCARD` and `FLIP_SEQUENTIAL`: all kept presenting at ~4700 fps with
`Present` returning `S_OK` while focus was stolen by `osascript`. **That is not evidence the freeze
isn't real** — in every run, `WM_ACTIVATEAPP DEACTIVATED` **never arrived**. Activation messages fire
once at startup and never again, even after explicitly making the wine process frontmost first. The
synthetic focus steal never reached the Wine window, so the trigger was never applied.

To reproduce the freeze the focus change probably has to be driven the way a human does it — a real
click on another window, or a hotkey raising another app. Until then the game remains the only known
reproducer.

### ❌ RETRACTED: the "vsync is ignored" claim from these same runs

An earlier version of this section reported `Present(sync interval 1)` running at ~4700 fps on a
120 Hz display and called it a vsync defect, "plausibly the same class as
[dxmt#26](https://github.com/3Shain/dxmt/issues/26)". **That was wrong, and it was measured wrong.**

Re-measured on an idle machine with the window raised and composited (`--sync 0|1|2`, median of
7 one-second samples, main display 1920×1080 **@ 120.00 Hz**):

| sync interval | DXMT v0.80 / wine-11.0 | expected |
|---|---|---|
| 0 (no vsync) | 306 fps | uncapped ✓ |
| **1** | **120 fps** | **= refresh ✓** |
| **2** | **61 fps** | **= half refresh ✓** |

DXMT's frame pacing is exactly correct. The original 4700 fps came from runs where the window was
**not composited** — buried under other windows, with a Steam client burning 93% CPU in the same
prefix — so nothing was throttling to the display. `Present` never returned `DXGI_STATUS_OCCLUDED`
in either condition, so the return code gave no warning that the measurement was invalid.

**The lesson, since this repo keeps re-learning it:** a frame-rate number is meaningless unless you
can show the window was on screen and the machine was idle. Screenshot the window during the run —
`focustest` renders solid magenta precisely so that "is it presenting?" is answerable from a
screenshot rather than from a number that may be measuring nothing.

⚠ Note the link line: `-ldxguid -luuid` are required (for `IID_ID3D11Texture2D`) and were missing
from this file's build commands until 2026-08-22.

---

# Instruments, harnesses and helpers

The table above is **reproducers** — small programs that demonstrate a bug without launching the
game. This section is everything else in `scripts/`: the things that *measure*, *build*, *record*
and *launch*. They were undocumented until 2026-09-04 (issue #3, which found 43 of 67 source files
unmentioned), and the split is the point — a reproducer answers "does this bug exist?", an
instrument answers "what is actually happening, and can I trust the number?".

## Measurement — the render/resize instruments

| Source | Purpose |
|---|---|
| `steam-render-cell.sh` | documented in the reproducers table above — the cell harness every render measurement runs through |
| `cell-fingerprint.sh` | Records **the config a result was measured under**, and refuses the run on a precondition that would void it. A cell with no `config.json` is `UNREVIEWED`, not a result. This exists because 41 of 43 render cells once ran with no font library and nothing recorded it |
| `shimmer-probe.sh` | Hosted-layer **gaps during resize churn**, against a static control. `churn` drives `SetWindowPos`; `static` is the do-nothing baseline any churn number must beat. ⚠ Wipes `$OUT_DIR` on entry — pass it a subdirectory, never your run root |
| `livedrag-probe.sh` | The same measurement during a **drag**. Churn is not a drag — a drag runs win32u's `SC_SIZE` loop, not `SetWindowPos` from outside (and not macOS live-resize either, C46) — so anything gated on that loop is invisible to `shimmer-probe` and only this can see it. Waits for the window to start changing size (a hand or `sizedrag`), samples hard while it does, and returns VOID rather than a clean bill if the size never actually changed |
| `drag-session.sh` | One drag measurement set up end to end — installs the right module, brings Steam up on the store page, pre-sizes so the drag can grow, waits (or drags), scores, and restores the daily driver on exit. `t0` \| `t2b` \| `t3` per issue #7's three drags, `s1` = the stage-1 daily driver. `DRAG=synth` runs the size loop through `win-resize-driver.exe sizedrag` with nobody at the mouse — the same win32u path a human drag takes here (C46/C47); a human drag stays the acceptance test |
| `pixel-probe.swift` | Measures the **edges** of a captured window against its interior, because a 1-device-pixel seam does not survive being eyeballed. `strip <x> <w>` gives the mean RGB of a column band |
| `darkboxes.swift` | Per-**edge** true-black scoring (L/R/T/B), plus the diagnostic colour classifiers (green/magenta/blue/cyan). Scores bands, never a perimeter mean — a mean over four edges diluted a 280 px black column to nothing |
| `band-counts.py` | Counts frames whose outer 10 % band is ≥ 20 % true black, **per edge**. Parses by label, never by position |
| `darkboxes-attrib.py` | The per-frame attribution table for issue #7's diagnostic colours — which *source* the black came from (S1/S2/S3/S4) |
| `churn-grow-shrink.py` | Splits a churn into GROW and SHRINK frames and scores each band **beside the static control at the same threshold**. Exists because a band criterion without its baseline can be satisfied by a window that is not being resized |
| `t6-scale-at-rest.py` | Issue #7 T6 — no *surviving* hosted layer is left scaled once the resize is over. The surviving filter is the whole test: a churn retires hundreds of contexts and a retired host's last placement is frequently non-identity, which is the fix working, not failing |
| `placement-invariants.py` | Two trace invariants no pixel test can reach: no host placed at a sub-pixel scale (the snap ran), and no host ever changes its frame origin |
| `hosting-layer-tests.sh` | The cross-process hosting-layer battery in one command — ownership, child-only move, z-restack, blackout/churn/static, traces. `--mutants` rebuilds and installs each mutant, observes it, and restores. `--list` prints the plan without touching Steam |
| `stage1-tests.sh` | The stage-1 rows of `docs/plans/exposed-edge-live-resize.md` in one command. `DIAG=1` scores by source as well as by band; `T7=1` runs the anchor churns instead |
| `stage2-tests.sh` | The stage-2 rows, unattended: a synthetic drag on prod (the mechanism — root passes read win32u's size loop, stretches fire, the end-of-loop re-derive runs), the same on the colour build, the `sig-off` mutant (must be RED), the churn guard on prod (T10), and the `sig-on` mutant on a churn (T10 must be RED). Restores the daily driver last |
| `signal-mutants.py` | Mutants of the resize signal stage 2 is armed on: `--off` never sees the size loop, `--on` always does. Applied to `window.c` on `main` through `PATCH_FILE=window.c build-winemac.sh`, observed, restored |
| `diag-colours-patch.py` | The issue-#7 diagnostic colours for `cocoa_window.m` on `main` (magenta = create-path background, green = host placed larger than its content, blue = the child's own layer; `--e1` = mutant E1). Lived in `/tmp` as a "throwaway" until the ledger cited four modules built from it and it was gone; recovered from a transcript and committed |
| `t1-spike.sh` | The T1 **gate** for the same plan — does a hosted, out-of-process layer tree honour the hosting layer's `transform` at all? A throwaway module, three phases, and a RED condition that would have killed the whole approach |
| `boot-verify.sh` | **The** way to prove the game still boots: launcher → dwell → `WM_CLOSE` → judge `SceneFlow.log`. One `VERDICT:` line, exit code follows (2 = refused, the prefix is busy). `--selftest` exercises every judge branch without launching |
| `capture-freeze.sh` | Forensics for the alt-tab presentation freeze — the state capture that ran while that bug was live |
| `perf-bench.sh` · `perf-run.sh` | One autonomous benchmark cycle, and the measurement-cell wrapper around it (`docs/plans/perf-pass.md` §2) |

## Building modules and wrappers

| Source | Purpose |
|---|---|
| `build-winemac.sh` | Build a `winemac.so` for a Steam test **with the branch and glue asserted**. Refuses a `core` build: it installs and loads fine, then Steam's GPU process dies and nothing renders, which reads as a clean measurement |
| `build-winemac-visibility.sh` | Rebuild only `winemac.so` against a visibility-instrumented tree |
| `build-dxmt-fork.sh` | Build notpop's DXMT fork (the `_CreateMetalViewFromHWND` rewrite) |
| `regen-winemac-patches.sh` | Generate the three published `winemac.drv` patches from git. `--check` verifies them against the tree **and** asserts three structural invariants about the `stock`/`aquadran`/`core`/`main` branch model |
| `strip-comments.py` | Compare two revisions of a C/ObjC file for **code** equality, ignoring comments — how a comment-only edit is proven to be comment-only |
| `make-shortcut.sh` · `make-steam-shortcut.sh` · `make-vanilla-wrapper.sh` | Build the double-clickable launchers in `~/Applications`, and a throwaway wrapper carrying vanilla wined3d |
| `install-webhelper-shim.sh` | documented in the reproducers table above |
| `pe-icon.py` | Pull the largest `RT_ICON` out of a PE binary — used to give the shortcuts real icons |
| `diag-launch-dxmt11.sh` | The canonical dxmt11 launcher plus diagnostic instrumentation |

## Evidence and the ledger

| Source | Purpose |
|---|---|
| `check-experiments.py` | Keeps `EXPERIMENTS.md` honest against the evidence store — unrecorded cells, evaporated evidence, any `SUPPORTED`/`PARTIAL` claim resting on a VOID run, unaudited committed images. Run at `button up`; exits non-zero on drift. `--regen` rewrites the run index from the store |
| `salvage-cells.sh` | Moves render-cell evidence out of volatile `/tmp` into the durable store, dropping `known-good.png` (a capture of whatever window was frontmost — the harness's largest accidental-disclosure surface, whose only datum is "the capture worked") |

## Win32-side drivers and probes

| Source | Purpose |
|---|---|
| `win-resize-driver.c` | Exact `SetWindowPos` sizes, per-monitor DPI aware so odd raw sizes are reachable. Interactive dragging cannot answer a resize question — you cannot tell a transient race from a persistent one by hand. Also `tree`, a signal-free `close`, `move <hwnd> <dx,dy>` in the parent's client space, and `sizedrag <hwnd> <edge> <dx,dy>` — a **real size loop**: it presses inside the window's own resize border, moves, releases, and polls `GUI_INMOVESIZE` on the window's thread while it runs, so the output measures the signal win32u's `SC_SIZE` loop publishes rather than assuming the loop ran (ledger C47) |
| `frameless-window-repro.c` | Minimal reproducer for the winemac frameless-window decoration bug (wine 60262) |
| `dlprobe.c` | Does a given dylib actually resolve, **under the env a cell will run with**? Wine dlopens its optional deps by bare SONAME, so a library that exists can still be invisible |
| `dwritetest.c` | Does DirectWrite actually **rasterise** glyphs on this stack? Separates "no fonts" from "fonts enumerate but nothing draws" |
| `r8test.c` | Whether the R8 texture path renders — the glyph-atlas format question |
| `dxgiprobe.c` | Calls the exact DXGI query ANGLE's D3D11 renderer fails on, and prints the HRESULT |
| `whwrapper_ipgpu.c` | Webhelper wrapper forcing in-process GPU, so CEF stops requesting a cross-process swapchain |
| `minrepro.c` · `minrepro2.c` · `minrepro3.c` | The three-stage narrowing of the alt-tab freeze: v1 showed create-while-minimized alone does **not** reproduce; v2 added fullscreen; v3 stripped it to the essential defect — a second swapchain on the same HWND. Run them with `run-minrepro.sh`, `run-minrepro2.sh` and `run-minrepro3.sh`, which capture screenshots per phase |
