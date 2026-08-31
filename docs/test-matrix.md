# Test matrix — what works, what doesn't, and what we're allowed to say

> Generated from the evidence store (`~/cs2-patch/evidence`, 63 cells) and `EXPERIMENTS.md`,
> **2026-08-31**. Numbers are read out of `config.json` + `stdout.txt` per cell, not from memory.
> Regenerate the cell table with the snippet at the foot of this file.

## 1. The port, as it stands

| thing | state | evidence |
|---|---|---|
| **The game** | ✅ **works** — daily driver, 44.9 FPS, Direct presentation | wine 11.16 + DXMT, self-built, promoted 2026-08-23 |
| **Game fonts / UI text** | ✅ works, always did | the launcher execs wine directly |
| **Alt-tab / fullscreen freeze** | ✅ fixed by 11.16 | C1 `SUPPORTED`, upstream closed as dup of dxmt#183 |
| **Mods** | ✅ load (EasyZoning, FindIt, InfoLoomTwo, Anarchy, MoveIt) | boot log, 2026-08-30 |
| **Steam client UI — with shim** | ✅ **renders, with text** | `ipgpu-fonts-fixed`, 727 KB capture, [screenshot](images/steam-renders-with-text.png) |
| **Steam client UI — plain launch** | ❌ **black** | every out-of-process cell; GPU process crashes 6×/launch |
| **Steam store tab** | ⚠ renders but **flickers** on autoplaying video; library is clean | observed live 2026-08-30 |
| **Game display selection** | ⚠ picks the wrong monitor on a 2-external setup | 3840×2160 window on a 1920×1080 main display |

**Bottom line:** everything works *except* Steam's client rendering out-of-process, and there is a
usable workaround for that (arm the shim), whose only known cost is store-tab flicker.

## 2. Render-cell matrix — the 20 cells with a recorded config

Only these are interpretable; the other 43 predate `cell-fingerprint.sh` and are `VOID-LIBS`.
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
| `xproc-v080` | 0 | black | DXMT v0.80 + force-crossprocess | ⚠ **suspect, see §4** |
| `notpop-fork-fonts-fixed` / `fork-seh` | 0 | black | notpop's fork, fonts working | ⚠ **VOID, see §4** |
| `gpu-fastfail-verbose` | 0 | black | Chromium verbose logging | produced nothing |

**The shape of it:** one cell renders. Every out-of-process cell is black with exactly **6** GPU
crashes, regardless of backend, CRT, tunnel, or graphics stack.

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

**Three retracted plus one disproven — four of eleven claims withdrawn**, and two more (C2, C7) are only half-standing. That ratio is the point of keeping the register.

## 4. What we are NOT entitled to claim

- **`xproc-v080` and both fork cells are suspect or void.** Both stacks were built against
  `~/cs2-patch/build-1116/engine-1116` (2026-08-28) and hand-installed into the **shipped** engine
  (2026-08-23). Their `ntdll.so` differ, so the PE↔unix ABI does not match. The fork run proved it:
  the fault moved into `__wine_unix_call_dispatcher +0xc9` dereferencing address 0 — a `.so` that
  failed to register. **"The cross-process path is unreachable" may therefore have been a
  registration failure, not an unreachable branch.** Re-run against a matching engine before citing.
- **"Backend-independent" needs one more check.** Software rendering gave a byte-identical result,
  which requires `winemetal.so` to be reached under swiftshader too. Not yet confirmed by `vmmap`.
- **The 43 pre-fingerprint cells can never be rehabilitated.** No config was recorded; they are
  `VOID-LIBS` permanently.
- **Nothing here says the fork does or does not fix Steam.** That test has not yet been run validly.

## 5. The open bug, stated precisely

```
winemetal.so  _CreateMetalViewFromHWND +0xbf

  a3d9   callq *%r15              ; call
  a3dc   movq  %rax, %r15         ; keep the return value
  a3df   movq  0x18(%rax), %rdi   ; <== FAULT — rax is NULL
```

An unchecked NULL return, dereferenced at `+0x18`. Stock null-tests a *different* call's result 21
bytes later, which is what makes it an oversight rather than a deliberate invariant. notpop's fork
rewrites this exact function and does not contain the faulting instruction.

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
