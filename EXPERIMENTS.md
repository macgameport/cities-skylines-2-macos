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

## ⚠ The git log is NOT a source of truth for this thread

`git log` is immutable, and the commit subjects written between 2026-08-24 and 2026-08-30 assert
conclusions this ledger has since withdrawn — *"eliminate text RASTERISATION"*, *"the glyph story
resolves"*, *"no wine-version bisect is warranted"*, *"macOS is not the variable"*. They were
honest when written and they are wrong now, and nothing in a commit message can be edited to say so.

**Rule: for anything in the Steam-UI thread, the register below outranks any commit subject, README
line, or a heading in `GOTCHAS.md` / `docs/steam-ui-investigation.md`.** Several headings still read "ELIMINATED" or "SOLVED" with a
`Ledger:` banner directly beneath them retracting exactly that word — the banner wins. Headings were
deliberately left alone so the history stays greppable and the retraction stays visible next to the
claim it retracts.

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
| C2 | The cross-process **child-window** patch makes Steam's client composite on stock winemac + DXMT | `PARTIAL` | `exp_6bd192` `exp_06760c` `exp_3d7586` `exp_015b85` — **void-ok:** whether a layer composites is font-independent, so the byte-size jump stands | **Rendering supported** — window went 108,343 B → 2,588,759 B, and whether a layer composites does not depend on FreeType. **The "still no text" half is VOID** — every one of those cells ran with no font backend. |
| C3 | `macdrv_get_cocoa_window` returns NULL for a foreign HWND — the cross-process root cause | `SUPPORTED` | source read + direct measurement | Derived from reading wine's source and a targeted probe, not from a render cell. |
| C4 | The glyph loss is in-process GPU itself, not the `--in-process-gpu` flag | `VOID` | cells with 14–73 FreeType failures | The premise ("this engine renders art but not text") is explained by the missing font backend. Re-test with a fingerprinted cell before believing any part of it. |
| C5 | Text **rasterisation** eliminated — `dwritetest` byte-identical across engines | `RETRACTED` | `scripts/dwritetest.c` | The measurement stands (ALIASED 545/1633 sum 138975; CLEARTYPE 315/4899 sum 80325, identical on both). The **elimination** does not: `dwritetest` runs as a standalone PE, and standalone PEs were measured 2026-08-30 to resolve FreeType fine on *both* engines. It never exercised the failing condition. |
| C6 | Glyph-atlas texture path eliminated — `scripts/r8test.c` | `RETRACTED` | same class as C5 | Same defect: a standalone PE probe cannot eliminate a fault that only appears under Steam. Measurement kept, elimination withdrawn. |
| C7 | CPU raster renders Steam **with text** on an 11.0-lineage engine | `PARTIAL` | `exp_8d065a`, `exp_fb79d9` | `winestable-cpuraster` is genuine — shim installed, libs resolve, text visible. **`pk-cpuraster` is mislabeled**: that prefix has no shim, so `--shim-args` never applied and it was an ordinary launch, not CPU raster. |
| C8 | macOS is not the variable; wine-stable 11.0 renders where our 11.16 does not | `RETRACTED` | `exp_fb79d9` vs `exp_53a8e6` | Not a controlled comparison: one side had the shim and a working font backend, the other had neither. Retracted 2026-08-30, same day it was committed. |
| C9 | DXMT beats vanilla wined3d at every cell (wined3d gets FL 9_3 only) | `UNREVIEWED` | `scripts/dxgiprobe.c`, the `vanilla-*` cells | The feature-level measurement comes from a standalone probe and is font-independent, so it plausibly survives — but it has **not** been re-audited against the config rules. Do not cite as settled. |
| C10 | Our self-built 11.16 loses FreeType/gnutls/MoltenVK **under Steam** while PK 11.0 does not | `SUPPORTED` | `exp_7b9920` (61 FT) vs `exp_8d065a` (0), same script; `exp_54cc10`/`exp_a96ecc` (61/59 FT) — **void-ok:** the library failure *is* the measurement here, not a defect in it | Both plain no-shim launches, so the shim asymmetry does not explain it. Standalone PEs resolve fine on both engines (32- and 64-bit, fresh prefix and real prefix, identical metrics). **This is the open lead.** |
| C11 | The FreeType failure removes **GDI** fonts but **not DirectWrite** — so it does not, on its own, explain Chromium's missing glyphs | `PARTIAL` | `exp_95fb82` — first probe ever run *inside* Steam's process tree (the shim, `SHIM_FONTPROBE`) — **void-ok:** the library failure is the condition being measured, not a defect in the measurement | Measured in-tree: **GDI 0 families, DirectWrite 204, `hr=S_OK`**, in a cell logging 63 FreeType failures and showing a black window. Shell control on the same engine: GDI **924** with `DYLD_FALLBACK` set, **0** without; DirectWrite **204** either way. ⚠ A family *count* is not proof of rasterisation — nothing yet draws a glyph and checks pixels. That probe is the next step, and it is what would settle C4. |

### Open lead (C10) — why does our engine lose FreeType *only* under Steam?

Our engine's `config.h` has `SONAME_LIBFREETYPE "libfreetype.dylib"` (unversioned, from Homebrew);
PK's `win32u.so` asks for `libfreetype.6.dylib`. Both names exist in every wrapper's `Frameworks/`
(the unversioned one as a symlink, present on the canonical wrapper since 2026-08-23).

**Sharpened 2026-08-30 (second pass).** A bare `dlopen("libfreetype.dylib")` with **no** DYLD
variable set FAILS — dyld's built-in fallback is `/usr/lib` only, and macOS ships no
`/usr/lib/libfreetype.dylib`. It SUCCEEDS the moment the engine's own `wine/lib` is on
`DYLD_FALLBACK_LIBRARY_PATH`, on **both** engines. Our launcher and the cell harness both export
exactly that (`launch-cs2-dxmt11.sh:63`, `steam-render-cell.sh:65`), and `cell-fingerprint.sh`
confirms it resolves — yet the same cell logs 61 FreeType failures once Steam is running.

So the variable is neither the engine nor the library.

**Tested and FALSIFIED 2026-08-30: it is not variable priority.** The obvious next move was
`DYLD_LIBRARY_PATH` — searched *first*, and not the variable a runtime would overwrite. Two cells
ran with it set alongside the fallback (`exp_54cc10` 61 FreeType failures, `exp_a96ecc` 59). No
improvement, so "Steam overwrites the fallback path and the fix is a higher-priority variable" is
dead. Do not re-run it.

Both cells are the first ever recorded with a full `config.json`, and both confirm the shim now
works: `steamwebhelper.exe` spawns `steamwebhelper_real.exe` children in `cef.win64`. So a
CPU-raster cell is finally possible — that is the next real experiment, not another env tweak.

### ⚠ The audit's own mechanism is now in question (2026-08-30, second pass)

This file opens by saying 41 of 43 cells "render art and no glyphs" because they had no font
backend. **The correlation is real; the mechanism is not established, and one half of it is now
measured false.** Chromium renders text through **DirectWrite**, and DirectWrite reports **204
families with `S_OK` inside the failing process tree** (`exp_95fb82`). Only **GDI** collapses to 0.

So "those cells could not have shown text anyway" — the sentence the blanket `VOID` rests on — does
not follow from the FreeType failure. What still stands, unchanged, is the *other* reason those
cells are untrustworthy: **their configuration was never recorded**, and two of them were confounded
by shim placement and unfiltered capture. That was always the stronger argument. Keep the retractions
on those grounds; stop citing "no fonts" as the reason.

**What would settle it:** rasterise in-tree, do not enumerate. Draw a known string through
DirectWrite inside the shim and count non-background pixels. 204 families with a dead rasteriser and
204 families that actually draw are indistinguishable from a count, and this thread has already paid
once for treating a load as an implementation (§ "a load is not an implementation").

**Still open.** What remains is to catch the failure in the act. The remaining hypothesis
worth testing is that macOS strips `DYLD_*` across the exec into wine's preloader for Steam's
children specifically — which would have to be measured *inside* the process, e.g. by extending
the webhelper shim (our own code, already running there) to log the environment it actually sees.

> ⚠ **RETRACTED 2026-08-30 (same day): "`wine notepad` is a blind font probe" was WRONG, and the
> way it was wrong is the more useful finding.** That A/B was run as
> `timeout 25 wine notepad 2>&1 | grep -c ...`. **macOS ships no `timeout`.** Every run exited 127
> without launching anything, and `grep -c` on the resulting error text returns **0** — identical to
> "ran, found nothing". Re-run properly, `wine notepad` is a **good** probe: **0** FreeType failures
> with `DYLD_FALLBACK_LIBRARY_PATH` set, **7** without, on the canonical engine. It discriminates.
>
> **Two traps worth more than the probe:**
> - **`timeout` does not exist on this machine** (no coreutils). `timeout <cmd> 2>&1 | grep -c` is a
>   silent zero-generator. Assert the command produced *expected* output — not just that grep
>   returned a number. A `ran=yes/NO` line on every probe is the cheap fix.
> - **`bash -c` strips `DYLD_*`.** macOS purges `DYLD_*` when exec'ing a SIP-protected binary, and
>   `/bin/bash` is one. Wrapping a probe in `bash -c "wine ..."` silently removes the very variable
>   under test — measured here: 7 failures *both* with and without DYLD via `bash -c`, but 0 vs 7 on
>   direct invocation. **Invoke wine directly.** This is also the leading candidate mechanism for the
>   whole of C10.

> ⚠ **`ps eww` cannot read another process's environment on this macOS — it returns nothing even
> for a process you own with the variable definitely set** (validated 2026-08-30 against a
> `DYLD_LIBRARY_PATH=... sleep` sentinel; both `ps eww -p` and `ps eww -o command=` came back
> empty). A harness that reads env this way will report "the variable did not survive" for every
> process on the machine. `wine cmd /c set` is no substitute: it shows the *Windows* environment
> block, which does not carry `DYLD_*` either.

> ⚠ **`cell-fingerprint.sh`'s library check has a blind spot, by construction.** It probes with the
> env *the harness exports*, so it answers "can this library be resolved from here?" — not "will the
> process that matters resolve it?". It would have passed every one of the 41 contaminated cells.
> It is a precondition, not a verdict; the FreeType count in the cell's own `stdout.txt` is the verdict.

**Already eliminated — do not re-test these.** Each was measured on 2026-08-30; re-running them is
the circle this ledger exists to break.

| hypothesis | how it was eliminated |
|---|---|
| the wrapper is missing the libs | canonical has all three in `Frameworks/` **and** `wine/lib/`; `wineboot -u` there resolves all three (292-line log, prefix built, MoltenVK initialised) |
| the unversioned symlink is broken | `dlopen("libfreetype.dylib")` succeeds from a plain x86_64 process under the cell's exact env |
| architecture mismatch | `lipo -archs`: engine `wine64`, and every `Frameworks/` dylib, are all `x86_64` on both wrappers |
| the real Steam prefix is different | the GDI font probe resolves fine **in the real Steam prefix**, script-style env, both bitnesses |
| 32-bit processes can't reach the libs | 32- and 64-bit GDI probes return **identical** metrics on both engines (Arial, height 16, extent 29×16) |
| old-style vs new-WoW64 | all three engines are new-WoW64 — `lib/wine/` has no `i386-unix` in any of them |
| the engine itself can't resolve the soname | **both** engines resolve a bare `dlopen("libfreetype.dylib")` when their own `wine/lib` is on `DYLD_FALLBACK_LIBRARY_PATH` (2026-08-30, `~/cs2-patch/dlprobe`, x86_64). The engine is not the variable |
| Homebrew's copy is the one being found | `/opt/homebrew/lib/libfreetype.dylib` is **arm64** — an x86_64 wine could never load it, whatever the path says. Every engine ships its own `x86_64` copy in `wine/lib` |
| a stale `wineserver` pins a bad environment | started `wineserver` with and without the DYLD var, then launched a wine GUI process each way — no difference (but see the ⚠ below: that probe turned out to be blind) |
| `$HOME/lib` shadowing / fallback | `$HOME/lib` is **not** a dyld fallback on this macOS; the only default is `/usr/lib`, and none of the three libs is in any default fallback dir |
| the shim sanitises the environment | the failure reproduces on plain no-shim launches (`exp_7b9920`) |

**What remains untested:** whether `DYLD_FALLBACK_LIBRARY_PATH` actually reaches Steam's child
processes (`ps eww` will not show another process's environment on macOS, so the direct read is
unavailable), and whether `DYLD_LIBRARY_PATH` — searched *first*, a different dyld code path —
survives where the fallback does not. That A/B was started 2026-08-30 and **abandoned mid-run**:
its own inter-run shutdown failed, leaving two `steam.exe` racing in one prefix, so phase A's
number (60 FreeType) is not clean and phase B never ran. Re-run it with the fingerprint attached.

---

## Experiment index

Auto-derived from the evidence store by `scripts/check-experiments.py --regen`.
Artifacts: `~/cs2-patch/evidence/<cell>/` (outside the repo — see § Privacy).

`VOID-LIBS` = ran with at least one unresolved graphics/font library. `capture` is **unreliable for
pre-2026-08-30 cells**: the harness did not prefix-filter its window list, so a "rendered" reading
may belong to a different wrapper's Steam.

| id | ran | cell | FT | gnutls | MVK | capture | status |
|---|---|---|---:|---:|---:|---|---|
| exp_a886cb | 2026-08-29 16:56 | `split-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_7ae4c7 | 2026-08-29 16:59 | `split-pair-v2` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_cc3bb9 | 2026-08-29 17:01 | `split-ipgpu-swiftshader` | 24 | 0 | 0 | — | VOID-LIBS |
| exp_0dbb6c | 2026-08-29 17:04 | `split-single` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_154886 | 2026-08-29 17:15 | `dxmt-single-control` | 17 | 0 | 0 | rendered | VOID-LIBS |
| exp_43d01c | 2026-08-29 18:17 | `vanilla-real-control` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_17e351 | 2026-08-29 18:19 | `vanilla-real-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_e8594e | 2026-08-29 18:21 | `vanilla-real-single` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_bb8f7e | 2026-08-29 18:24 | `vanilla-real-ipgpu` | 24 | 0 | 0 | — | VOID-LIBS |
| exp_20ad29 | 2026-08-29 18:26 | `vanilla-vk-control` | 24 | 0 | 0 | — | VOID-LIBS |
| exp_fc38ad | 2026-08-29 18:27 | `vanilla-vk-control2` | 56 | 0 | 0 | black | VOID-LIBS |
| exp_d2c54c | 2026-08-29 19:27 | `cef-force-gpu` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_cad7d4 | 2026-08-29 19:29 | `angle-d3d9` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_34c48b | 2026-08-29 19:46 | `vis-control` | 60 | 0 | 0 | — | VOID-LIBS |
| exp_509ae4 | 2026-08-29 19:54 | `vis-control2` | 54 | 0 | 0 | black | VOID-LIBS |
| exp_454e00 | 2026-08-29 21:05 | `fork-control` | 22 | 0 | 0 | — | VOID-LIBS |
| exp_56dbae | 2026-08-29 21:09 | `fork-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_3206bc | 2026-08-29 21:12 | `fork-pair2` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_8cf39c | 2026-08-29 21:30 | `forced-xproc` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_272e5a | 2026-08-29 21:33 | `forced-xproc-dbg` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_d7a882 | 2026-08-29 21:53 | `foreign-hwnd` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_26b733 | 2026-08-29 21:57 | `foreign-hwnd2` | 32 | 22 | 5 | black | VOID-LIBS |
| exp_457ad8 | 2026-08-29 22:14 | `vk-remote-layer` | 59 | 49 | 13 | black | VOID-LIBS |
| exp_c52a07 | 2026-08-29 22:20 | `remote-layer` | 58 | 48 | 13 | — | VOID-LIBS |
| exp_98ce17 | 2026-08-29 22:27 | `remote-layer2` | 54 | 48 | 12 | black | VOID-LIBS |
| exp_71db7a | 2026-08-29 22:31 | `remote-layer3` | 59 | 49 | 13 | black | VOID-LIBS |
| exp_7c608c | 2026-08-29 22:39 | `child-warm` | 31 | 0 | 0 | — | VOID-LIBS |
| exp_6bd192 | 2026-08-29 22:42 | `child-real` | 28 | 24 | 8 | — | VOID-LIBS |
| exp_3c7dd2 | 2026-08-29 23:12 | `glyph-nodcomp` | 28 | 22 | 5 | rendered | VOID-LIBS |
| exp_098eee | 2026-08-29 23:17 | `glyph-nodcomp2` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_200289 | 2026-08-29 23:23 | `glyph-onelayer` | 73 | 57 | 13 | black | VOID-LIBS |
| exp_fe859a | 2026-08-29 23:29 | `z-bottom` | 33 | 23 | 6 | black | VOID-LIBS |
| exp_3d7586 | 2026-08-30 00:23 | `geom-mapped` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_490c1b | 2026-08-30 01:39 | `mvk-in-winelib` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_fb1293 | 2026-08-30 01:44 | `angle-d3d11-live` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_4a9a98 | 2026-08-30 01:56 | `mikey92-exact` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_53a8e6 | 2026-08-30 02:02 | `cpuraster` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_8d065a | 2026-08-30 02:29 | `pk-cpuraster` | 0 | 0 | 0 | rendered | candidate |
| exp_311758 | 2026-08-30 02:49 | `sw-vulkan` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_06760c | 2026-08-30 03:41 | `clean-patch-verify` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_015b85 | 2026-08-30 04:28 | `geom-reposition` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_fb79d9 | 2026-08-30 05:27 | `winestable-cpuraster` | 0 | 0 | 0 | rendered | candidate |
| exp_7b9920 | 2026-08-30 11:55 | `cpuraster-canonical` | 61 | 52 | 14 | rendered | VOID-LIBS |
| exp_54cc10 | 2026-08-30 13:24 | `dyldpath-first` | 61 | 0 | 0 | black | VOID-LIBS |
| exp_a96ecc | 2026-08-30 13:27 | `dyld-env-probe` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_95fb82 | 2026-08-30 14:23 | `fontprobe-intree` | 63 | 0 | 0 | black | VOID-LIBS |

46 cells · 44 VOID-LIBS · 2 candidate
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
  dangling `exp_` reference, or a `GOTCHAS.md` status banner that disagrees with the register.
- **On every new conclusion** — add a `C<n>` row here *and* a status banner in the GOTCHAS
  section, so invalidating a run is a grep rather than an audit.

### Conventions (enforced by the checker, not by memory)

| convention | form | enforced? |
|---|---|---|
| experiment id | `exp_` + 6 hex, **minted, never derived from the cell name** | format + uniqueness |
| GOTCHAS status banner | `> **Ledger: ` + `` `STATUS` `` + ` (C<n>).** <why>` on the line directly under the `##` heading | vocabulary; must match the register's status for that claim; cited ids must exist |
| citing a VOID run | add `void-ok: <what the void run still measures>` in the claim row | a `SUPPORTED`/`PARTIAL` claim citing a VOID run fails without it |
| status words | `SUPPORTED` · `PARTIAL` · `UNREVIEWED` · `VOID` · `RETRACTED` — nothing else | rejected if not in vocabulary |

**Why ids are minted, not sequential.** `E043` silently asserts "the 43rd, and later than E042" —
so backfilling an older run makes the ordering lie, and holding the numbering stable across a regen
needs bookkeeping a minted key does not. Per the project's standing key/label rule: an identity key
that other rows point at carries no readable meaning. The cell *name* is the label; it may be
reused or renamed, which is exactly why nothing durable derives from it.

**Where each piece goes.** The register row is the claim. The GOTCHAS banner is the warning at the
point of use. The index row is the run. A conclusion missing any of the three is not recorded — it
is remembered, and this file exists because remembering failed.
- **When a premise falls** — flip the *inference* to `RETRACTED`/`VOID` and say what survives.
  Never delete a measurement.
