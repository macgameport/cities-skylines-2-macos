# Test matrix — what works, what doesn't, and what we're allowed to say

> Generated from the evidence store (`~/cs2-patch/evidence`, 80 cells) and `EXPERIMENTS.md`,
> **2026-08-31**, last updated after the resize fixes landed. Numbers are read out of `config.json` + `stdout.txt` per cell, not from memory.
> Regenerate the cell table with the snippet at the foot of this file.

## 1. The port, as it stands

| thing | state | evidence |
|---|---|---|
| **The game** | ✅ **works** — daily driver, 44.9 FPS, Direct presentation | wine 11.16 + DXMT, self-built, promoted 2026-08-23 |
| **Game fonts / UI text** | ✅ works, always did | the launcher execs wine directly |
| **Alt-tab / fullscreen freeze** | ✅ fixed by 11.16 | C1 `SUPPORTED`, upstream closed as dup of dxmt#183 |
| **Mods** | ✅ load (EasyZoning, FindIt, InfoLoomTwo, Anarchy, MoveIt) | boot log, 2026-08-30 |
| **Steam client UI — patched stack, plain launch** | ✅ **renders, with text** — no shim, no injected switches | `resize-ship`, 3.0 MB capture, 0 GPU crashes |
| **Steam client UI — stock stack** | ❌ **black** | every pre-patch out-of-process cell; GPU process crashes 6×/launch |
| **Steam client UI — with shim (`--in-process-gpu`)** | ✅ renders — the earlier workaround, now unnecessary | `ipgpu-fonts-fixed`, 727 KB, [screenshot](images/steam-renders-with-text.png) |
| **Steam client — resize** | ✅ white edge fixed · ✅ resize blackout fixed · ⚠ live-drag flicker untested | `resize-diag` → `resize-ship`; 3 bright-edge findings before, 0 across 20 captures after |
| **Steam client — navigation** | ✅ Library blackout fixed (a 0×0 browser was stretched over the view) | found in real use, not by the suite; six-navigation sweep all render, 0 GPU crashes |
| **Steam store tab** | ⚠ renders but **flickers** on autoplaying video; library is clean | observed live 2026-08-30 |
| **Game display selection** | ⚠ picks the wrong monitor on a 2-external setup | 3840×2160 window on a 1920×1080 main display |

**Bottom line:** on the patched wine + DXMT everything works, including Steam's client out-of-process
with no shim. What is left is one *unmeasured* question (flicker during a live drag) and the fact
that none of the patches can be upstreamed as a PR.

## 2. Render-cell matrix — the fingerprinted cells

**37 of 80 cells carry a `config.json`** and only those are interpretable; the other **43** predate
`cell-fingerprint.sh` and are permanently `VOID-LIBS`. The table below lists the decisive ones — the
full index is auto-derived in [`../EXPERIMENTS.md`](../EXPERIMENTS.md) § Experiment index.
**FT** = "Wine cannot find the FreeType font library" count. FT>0 ⇒ no font backend ⇒ art without
glyphs, whatever else was under test.

| cell | FT | window | what it tested | verdict |
|---|---|---|---|---|
| `ipgpu-fonts-fixed` | 0 | ✅ **RENDER** | shim injecting `--in-process-gpu`, fonts fixed | **the one that works** |
| `nohup-removed` | **0** | black | removing `nohup` from the harness | fonts fixed, 63→0 |
| `raster-intree` | 63 | black | DirectWrite rasterisation inside Steam's tree | 204 families, **0 coverage** |
| `fontprobe-intree` | 63 | black | font *enumeration* inside Steam's tree | GDI 0 / DWrite 204 |
| `default-oop-control` | 0 | black | out-of-process, default backend | 6 crashes |
| `swiftshader-oop` | 0 | black | out-of-process, **pure software** | 6 crashes, **byte-identical** |
| `xproc-angle-d3d11` | 0 | black | ANGLE forced onto D3D11 | 6 crashes |
| `ucrtbase-builtin` | 0 | black | forcing wine's builtin CRT | no change |
| `vpn-up-baseline` | 0 | black | Proton tunnel up | 6 crashes |
| `proton-off` | 0 | black | home tunnel instead | 6 crashes, **byte-identical** |
| `seh-fastfail` / `seh-module` | 0 | black | `WINEDEBUG=+seh` tracing | located the fault |
| `dyldpath-first` | 61 | black | `DYLD_LIBRARY_PATH` instead of fallback | **falsified** |
| `dyld-env-probe` | 59 | black | live-process env capture | probe was blind |
| `childpatch-noshim` / `-forced` | 0 | black | CHILD-patched winemac alone | patch never fired |
| `xproc-v080` | 0 | black | DXMT v0.80 + force-crossprocess | forced path logged 0× |
| `notpop-fork-fonts-fixed` / `fork-seh` | 0 | black | notpop's fork, fonts working | superseded by `fork-abi-matched` |
| `fork-abi-matched` | 0 | black | fork **rebuilt against the shipped engine** | ❌ **fork does not fix it** |
| `gpu-fastfail-verbose` | 0 | black | Chromium verbose logging | produced nothing |
| `resize-diag` | 0 | ✅ RENDER | patched winemac + DXMT, instrumented | white edge + blackout both reproduced |
| `resize-fix` | 0 | ✅ RENDER | edge + z-order fixes | both defects gone |
| `resize-final` | 0 | ✅ RENDER | z-order trace enabled | `0x2011E→z2`, `0x10140→z5` observed |
| `resize-ship` | 0 | ✅ RENDER | diagnostics compiled out | full suite clean, 0 crashes |

**The shape of it, in two eras.** Before the cross-process patch: one cell rendered (the shim), and
every out-of-process cell was black with exactly **6** GPU crashes regardless of backend, CRT,
tunnel or graphics stack. After it: every cell renders out-of-process with **0** crashes, and the
remaining work was geometry, not graphics.

## 3. Conclusions register

| # | claim | status |
|---|---|---|
| C1 | 11.16 retires the alt-tab freeze | ✅ `SUPPORTED` |
| C2 | cross-process child-window patch composites Steam | ⚠ `PARTIAL` |
| C3 | `macdrv_get_cocoa_window` NULL for a foreign HWND | ✅ `SUPPORTED` |
| C4 | glyph loss is in-process GPU itself | ❌ **`DISPROVEN`** |
| C5 | text rasterisation eliminated | ❌ `RETRACTED` |
| C6 | glyph-atlas texture path eliminated | ❌ `RETRACTED` |
| C7 | CPU raster renders Steam with text on 11.0 | ⚠ `PARTIAL` |
| C8 | macOS is the variable | ❌ `RETRACTED` |
| C9 | DXMT beats vanilla wined3d at every cell | ❓ `UNREVIEWED` |
| C10 | **`nohup` strips `DYLD_*` → no fonts** | ✅ **`SUPPORTED` — solved** |
| C11 | DirectWrite enumerates but rasterises nothing without FreeType | ✅ `SUPPORTED` |
| C12 | The white edge hairline is retina **half-point rounding**, not a race | ✅ `SUPPORTED` |
| C13 | The resize **blackout** is hosted-layer **z-order**, not a lifetime bug | ✅ `SUPPORTED` |
| C14 | The **navigation** blackout is a 0×0 child rect read as "no rect" and stretched | ✅ `SUPPORTED` |

**Three retracted plus one disproven — four of fourteen claims withdrawn**, and two more (C2, C7) are only half-standing. That ratio is the point of keeping the register.

## 4. What we are NOT entitled to claim

- ~~`xproc-v080` and both fork cells are suspect~~ — **withdrawn 2026-08-31.** The ABI-mismatch
  reasoning was wrong. Rebuilding the fork against the shipped engine produced a **byte-identical**
  `winemetal.so` (`wine_install_path` selects `winecrt0`, which is linked into the *DLLs*, not the
  unix `.so`) and the outcome did not move: still 6 crashes, still black. So `xproc-v080` stands on
  its own terms again. The `__wine_unix_call_dispatcher` null remains **unexplained** — it is not a
  build mismatch, and `winemetal.so` loads fine standalone.
- **"Backend-independent" needs one more check.** Software rendering gave a byte-identical result,
  which requires `winemetal.so` to be reached under swiftshader too. Not yet confirmed by `vmmap`.
- **The 43 pre-fingerprint cells can never be rehabilitated.** No config was recorded; they are
  `VOID-LIBS` permanently. That is 43 of 80 — more than half the store.
- **Nothing here says the fork does or does not fix Steam.** That test has not yet been run validly.

## 5. The bug that started it, stated precisely (FIXED — kept for the record)

```
winemetal.so  _CreateMetalViewFromHWND +0xbf

  a3d9   callq *%r15              ; call
  a3dc   movq  %rax, %r15         ; keep the return value
  a3df   movq  0x18(%rax), %rdi   ; <== FAULT — rax is NULL
```

An unchecked NULL return, dereferenced at `+0x18`. Stock null-tests a *different* call's result 21
bytes later, which is what makes it an oversight rather than a deliberate invariant. notpop's fork
rewrites this exact function and does not contain the faulting instruction.

Fixed by routing the NULL case to wine's remote-layer path (`dxmt-remote-layer-fallback.patch` +
`winemac-crossprocess-remote-layer.patch`) rather than by null-checking it — the caller aborts on a
null view by design, so a check alone only moves the crash.

## 6. Resize — how it was measured

Two instruments, both in `scripts/`, both reusable:

| instrument | why hand-testing could not answer it |
|---|---|
| `win-resize-driver.c` | exact sizes via `SetWindowPos`, **per-monitor DPI aware** so odd raw pixel sizes are reachable at all; also `tree` (the ancestry that made the z-order fix correct) and `close` (`WM_CLOSE`, not a signal) |
| `pixel-probe.swift` | a one-device-pixel seam is invisible in a screenshot; this makes it a number |

| sequence | before | after |
|---|---|---|
| `2401x1500` (odd width) | white column at x=2401, `255,255,255` | no bright edge |
| `2400x1501` (odd height) | white row at the bottom | no bright edge |
| `2400x1500` (even) | clean | clean |
| `2400x1500 → 2399x1499 → 2400x1500` | interior luminance **82 → 1 → 0** (black, and stays black) | **63 → 63 → 113** |
| 60 alternations at 60 ms | not run before the fix | renders; hosted population stable at 3; 0 GPU crashes |

## Regenerating the cell table

```bash
python3 - <<'EOF'
import json, os, glob
store = os.path.expanduser("~/cs2-patch/evidence")
for d in sorted(glob.glob(store + "/*/")):
    cfg = os.path.join(d, "config.json")
    if not os.path.exists(cfg): continue          # unfingerprinted -> VOID-LIBS
    so = os.path.join(d, "stdout.txt")
    ft = open(so, errors="ignore").read().count("cannot find the FreeType") if os.path.exists(so) else "?"
    big = max([os.path.getsize(p) for p in glob.glob(d + "win-*.png")], default=0)
    print("%-28s FT=%-4s %s" % (os.path.basename(d.rstrip('/')), ft,
          "RENDER" if big > 500000 else ("black" if big else "-")))
EOF
```
