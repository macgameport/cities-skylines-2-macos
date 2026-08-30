# Experiment ledger

> **Read the "Conclusions register" below before designing any new test.** It exists so a later
> session can tell what we already know, how much to trust it, and what would overturn it — without
> re-deriving it from 2,500 lines of `GOTCHAS.md` prose. Checked by `scripts/check-experiments.py`,
> which `button up` runs.

## Why this exists

On **2026-08-30** an audit of the Steam-UI thread found that **41 of 43 render cells had been
measured with no font library** — wine could not resolve `libfreetype.dylib`, so `win32u` printed
one message and continued with no font backend. Those runs render art and no glyphs, which is
indistinguishable from a GPU/compositing failure. A week of work had been spent eliminating fonts,
rasterisation, texture formats, occlusion, DirectComposition and presentation architecture — while
the actual cause of "no text" sat unrecorded in every log.

Two further confounds surfaced in the same audit: the webhelper shim was installed in a `cef` dir
Steam does not use (so `--shim-args` silently never applied), and the harness's `ps` and window
capture were not prefix-filtered (so another wrapper's Steam supplied a **false PASS**).

None of the three were detectable after the fact, because **no artifact recorded the configuration
a result was measured under.** That is what this ledger fixes.

## The rule: three columns, never fused

| column | what it is | when it changes |
|---|---|---|
| **Config** | the state the run happened in | captured automatically, never typed |
| **Measured** | the raw observation, no interpretation | never — a measurement is permanent |
| **Inferred** | what we concluded from it | freely, as premises fall |

Fusing *Measured* and *Inferred* into prose is what cost the week. When a premise collapses you must
be able to retract the **inference** and keep the **measurement** — otherwise the only safe move is
to re-run everything, which is exactly the circle this file exists to break.

## Status vocabulary

| status | meaning |
|---|---|
| `SUPPORTED` | measured under a recorded, sound config; still believed |
| `PARTIAL` | some claims survive, others don't — the entry says which |
| `UNREVIEWED` | never audited against the config rules; treat as unknown, not as true |
| `VOID` | the run could not have measured what it claimed (failed precondition) |
| `RETRACTED` | the inference was drawn and later disproved |

`VOID` is about the **run**; `RETRACTED` is about the **claim**. A VOID run can still hold a valid
measurement of something *else* — say so rather than deleting it.

---

## Conclusions register

Each row: what we believe, what it rests on, and what would overturn it. **Audited 2026-08-30.**

| # | Claim | Status | Rests on | Notes / what would overturn it |
|---|---|---|---|---|
| C1 | Wine 11.16 retires the alt-tab / exclusive-fullscreen freeze (dxmt#206) | `SUPPORTED` | in-game confirmation; upstream closed as dup of #183 | Font/graphics-lib independent. Unaffected by the 08-30 audit. |
| C2 | The cross-process **child-window** patch makes Steam's client composite on stock winemac + DXMT | `PARTIAL` | `child-real`, `clean-patch-verify`, `geom-*` — **void-ok:** whether a layer composites is font-independent, so the byte-size jump stands | **Rendering supported** — window went 108,343 B → 2,588,759 B, and whether a layer composites does not depend on FreeType. **The "still no text" half is VOID** — every one of those cells ran with no font backend. |
| C3 | `macdrv_get_cocoa_window` returns NULL for a foreign HWND — the cross-process root cause | `SUPPORTED` | source read + direct measurement | Derived from reading wine's source and a targeted probe, not from a render cell. |
| C4 | The glyph loss is in-process GPU itself, not the `--in-process-gpu` flag | `VOID` | cells with 14–73 FreeType failures | The premise ("this engine renders art but not text") is explained by the missing font backend. Re-test with a fingerprinted cell before believing any part of it. |
| C5 | Text **rasterisation** eliminated — `dwritetest` byte-identical across engines | `RETRACTED` | `scripts/dwritetest.c` | The measurement stands (ALIASED 545/1633 sum 138975; CLEARTYPE 315/4899 sum 80325, identical on both). The **elimination** does not: `dwritetest` runs as a standalone PE, and standalone PEs were measured 2026-08-30 to resolve FreeType fine on *both* engines. It never exercised the failing condition. |
| C6 | Glyph-atlas texture path eliminated — `scripts/r8test.c` | `RETRACTED` | same class as C5 | Same defect: a standalone PE probe cannot eliminate a fault that only appears under Steam. Measurement kept, elimination withdrawn. |
| C7 | CPU raster renders Steam **with text** on an 11.0-lineage engine | `PARTIAL` | `pk-cpuraster`, `winestable-cpuraster` | `winestable-cpuraster` is genuine — shim installed, libs resolve, text visible. **`pk-cpuraster` is mislabeled**: that prefix has no shim, so `--shim-args` never applied and it was an ordinary launch, not CPU raster. |
| C8 | macOS is not the variable; wine-stable 11.0 renders where our 11.16 does not | `RETRACTED` | `winestable-cpuraster` vs `cpuraster` | Not a controlled comparison: one side had the shim and a working font backend, the other had neither. Retracted 2026-08-30, same day it was committed. |
| C9 | DXMT beats vanilla wined3d at every cell (wined3d gets FL 9_3 only) | `UNREVIEWED` | `scripts/dxgiprobe.c`, `vanilla-*` cells | The feature-level measurement comes from a standalone probe and is font-independent, so it plausibly survives — but it has **not** been re-audited against the config rules. Do not cite as settled. |
| C10 | Our self-built 11.16 loses FreeType/gnutls/MoltenVK **under Steam** while PK 11.0 does not | `SUPPORTED` | `cpuraster-canonical` (61 FT) vs `pk-cpuraster` (0), same script — **void-ok:** the library failure *is* the measurement here, not a defect in it | Both plain no-shim launches, so the shim asymmetry does not explain it. Standalone PEs resolve fine on both engines (32- and 64-bit, fresh prefix and real prefix, identical metrics). **This is the open lead.** |

**Open question descending from C10:** why does the failure appear only under Steam? Not the wrapper
(canonical resolves all three under `wineboot`), not the prefix, not bitness, not architecture, and
not `$HOME/lib` (not a dyld fallback on this macOS — only `/usr/lib`). Our engine asks for the
unversioned `libfreetype.dylib`; PK's asks for `libfreetype.6.dylib`.

---

## Experiment index

Auto-derived from the evidence store by `scripts/check-experiments.py --regen`.
Artifacts: `~/cs2-patch/evidence/<cell>/` (outside the repo — see § Privacy).

`VOID-LIBS` = ran with at least one unresolved graphics/font library. `capture` is **unreliable for
pre-2026-08-30 cells**: the harness did not prefix-filter its window list, so a "rendered" reading
may belong to a different wrapper's Steam.

| ran | cell | FT | gnutls | MVK | capture | status |
|---|---|---:|---:|---:|---|---|
| 2026-08-29 16:56 | `split-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 16:59 | `split-pair-v2` | 14 | 7 | 4 | — | VOID-LIBS |
| 2026-08-29 17:01 | `split-ipgpu-swiftshader` | 24 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 17:04 | `split-single` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 17:15 | `dxmt-single-control` | 17 | 0 | 0 | rendered | VOID-LIBS |
| 2026-08-29 18:17 | `vanilla-real-control` | 59 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 18:19 | `vanilla-real-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 18:21 | `vanilla-real-single` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 18:24 | `vanilla-real-ipgpu` | 24 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 18:26 | `vanilla-vk-control` | 24 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 18:27 | `vanilla-vk-control2` | 56 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 19:27 | `cef-force-gpu` | 59 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 19:29 | `angle-d3d9` | 59 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 19:46 | `vis-control` | 60 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 19:54 | `vis-control2` | 54 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 21:05 | `fork-control` | 22 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 21:09 | `fork-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 21:12 | `fork-pair2` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 21:30 | `forced-xproc` | 59 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 21:33 | `forced-xproc-dbg` | 59 | 0 | 0 | black | VOID-LIBS |
| 2026-08-29 21:53 | `foreign-hwnd` | 14 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 21:57 | `foreign-hwnd2` | 32 | 22 | 5 | black | VOID-LIBS |
| 2026-08-29 22:14 | `vk-remote-layer` | 59 | 49 | 13 | black | VOID-LIBS |
| 2026-08-29 22:20 | `remote-layer` | 58 | 48 | 13 | — | VOID-LIBS |
| 2026-08-29 22:27 | `remote-layer2` | 54 | 48 | 12 | black | VOID-LIBS |
| 2026-08-29 22:31 | `remote-layer3` | 59 | 49 | 13 | black | VOID-LIBS |
| 2026-08-29 22:39 | `child-warm` | 31 | 0 | 0 | — | VOID-LIBS |
| 2026-08-29 22:42 | `child-real` | 28 | 24 | 8 | — | VOID-LIBS |
| 2026-08-29 23:12 | `glyph-nodcomp` | 28 | 22 | 5 | rendered | VOID-LIBS |
| 2026-08-29 23:17 | `glyph-nodcomp2` | 33 | 23 | 6 | rendered | VOID-LIBS |
| 2026-08-29 23:23 | `glyph-onelayer` | 73 | 57 | 13 | black | VOID-LIBS |
| 2026-08-29 23:29 | `z-bottom` | 33 | 23 | 6 | black | VOID-LIBS |
| 2026-08-30 00:23 | `geom-mapped` | 33 | 23 | 6 | rendered | VOID-LIBS |
| 2026-08-30 01:39 | `mvk-in-winelib` | 33 | 23 | 6 | rendered | VOID-LIBS |
| 2026-08-30 01:44 | `angle-d3d11-live` | 33 | 23 | 6 | rendered | VOID-LIBS |
| 2026-08-30 01:56 | `mikey92-exact` | 14 | 7 | 4 | — | VOID-LIBS |
| 2026-08-30 02:02 | `cpuraster` | 14 | 7 | 4 | — | VOID-LIBS |
| 2026-08-30 02:29 | `pk-cpuraster` | 0 | 0 | 0 | rendered | candidate |
| 2026-08-30 02:49 | `sw-vulkan` | 14 | 7 | 4 | — | VOID-LIBS |
| 2026-08-30 03:41 | `clean-patch-verify` | 33 | 23 | 6 | rendered | VOID-LIBS |
| 2026-08-30 04:28 | `geom-reposition` | 33 | 23 | 6 | rendered | VOID-LIBS |
| 2026-08-30 05:27 | `winestable-cpuraster` | 0 | 0 | 0 | rendered | candidate |
| 2026-08-30 11:55 | `cpuraster-canonical` | 61 | 52 | 14 | rendered | VOID-LIBS |

43 cells · 41 VOID-LIBS · 2 candidate

---

## Running a cell (the procedure this ledger assumes)

```bash
bash scripts/cell-fingerprint.sh --out /tmp/steam-cell-<label> \
     --shim-args " --disable-gpu --single-process" --strict   # refuses on a fatal precondition
bash scripts/steam-render-cell.sh --label <label> --shim-args " --disable-gpu --single-process"
```

`cell-fingerprint.sh` writes `config.json` beside the result and **exits non-zero** when a
precondition that would void the cell is unmet. It checks:

1. **every graphics/font soname the engine references actually resolves** under the cell's env,
   probed x86_64 (an arm64 probe would resolve dylibs the engine can never load)
2. **the shim is in every `cef` dir present** when `--shim-args` is passed — not just one
3. **no foreign wrapper's Steam is running** (`--strict` refuses; otherwise warns)

⚠ **Read the real exit code.** `bash scripts/cell-fingerprint.sh … | tail` reports *tail's* status,
so a VOID cell announces itself as exit 0. This bit the script's own first test on 2026-08-30.

A cell whose fingerprint says `VOID` is **not evidence** and must not get a ledger row beyond the
fact that it was voided.

## Privacy — what may leave this machine

The repo is intended to be publishable. Audited **2026-08-30**:

| artifact | contains | disposition |
|---|---|---|
| `stdout.txt`, `windows.txt` | only `C:\` / `Z:\` wine-internal paths — **no** `/Users/<name>`, no Steam ID, no persona name (verified by grep) | safe to quote in the repo |
| `config.json` | wrapper + prefix paths under `/Users/<name>` | evidence store only; redact `$HOME` if quoting |
| `win-*.png` | Steam client window — **persona name twice** (top-right, and as a nav item) plus the avatar | evidence store only, **never committed unmasked**; mask the two regions before publishing |
| `known-good.png` | an arbitrary browser/terminal window — whatever was frontmost | **not retained.** Only its byte size is kept (`known-good.size.txt`). This is the largest accidental-disclosure surface in the harness and it has no evidentiary value beyond "the capture worked". |

`scripts/salvage-cells.sh` applies all of this when moving cells out of `/tmp`.

**Cheapest durable fix for the screenshots:** the Steam persona name is a *label*, freely editable —
set it to something generic while doing capture work and new captures are clean at source, with no
post-processing to get wrong. A mask you got wrong is worse than no mask, because it looks safe.

## Maintenance

- **`wake up`** — read the **Conclusions register** (not the whole file, not `GOTCHAS.md` whole).
  It is the index of what we already know and how much to trust it.
- **`button up`** — run `python3 scripts/check-experiments.py`. It fails on drift: a claim citing a
  VOID run, a ledger row whose evidence is missing, a cell in the store with no row, or a
  `GOTCHAS.md` conclusion with no `Evidence:` line.
- **On every new conclusion** — add a `C<n>` row here *and* an `Evidence:` line in the GOTCHAS
  section, so invalidating a run is a grep rather than an audit.
- **When a premise falls** — flip the *inference* to `RETRACTED`/`VOID` and say what survives.
  Never delete a measurement.
