# DXMT side — record the mixed vintage, close the review nits, generate the patch from git

**Status: BUILT 2026-09-03 · check-it'd 2026-09-03 — build-ready-with-fixes (pass 3, fitted re-check after the instruments build at `cc62ff8`; four facts corrected — the unixlib table is 132 entries, T5 in boot-verify's contract, §4's codesign step removed, boot-verify exists — no design change). Pass 2: check-it'd 2026-09-02 — build-ready-with-fixes (corrections folded, re-checked).** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`; scratch tree `~/cs2-patch/dxmt-v080` (git, tag `v0.80` checked out, uncommitted diff).

> **🔧 As-built (2026-09-03): BUILT.** Ledger **C33**. Rebuilt `winemetal.so` `81b94bbf1e6fe598`
> installed byte-identical to the build artifact, unsigned like the file it replaced, dated backup
> beside it. Patch regenerated from branch `cs2/remote-layer` in the scratch tree (two commits — the
> mingw `<iomanip>` fix is its own). Suite run `20260903-062937`, boot `20260903-063316`.
>
> **Measured.** §1 vintage rows re-run and recorded in `INSTALL.md` §6 and the README stack row.
> Pre-build gate: only the `.o` + link, **0** `metal` invocations. **Unixlib table 132 entries,
> `nm` delta `0x420`** — the plan's original 131/`0x418` would have failed its own T2 gate, corrected
> in the pass-3 re-check and confirmed here. Export set identical to the previously installed `.so`.
> T1: the patch reproduces the working tree byte for byte from a pristine `v0.80`. §2's swapchain
> outcome test passed both sides — the live diff matched the preserved patch hunk-for-hunk before the
> checkout, and `git apply --check` succeeds after. T3 battery: T0 disjoint, T1 green, T2 restacks
> 86/channel and restores, blackout 85/84/85 with 0 bright edges, churn and static 0 gaps, 0 acquire
> failures, 0 GPU crashes. T5 boot `VERDICT: PASS`, `GRACEFUL: yes`.
>
> **Mutants, all observed red and restored.** Ignoring the release hook's TRUE → blank client
> (40,903 B against a 2,594,598 B baseline, instrument healthy at 1.1 MB) — red, though via a blank
> client rather than the crash the plan predicted. Disabling the acquire hook → **6 GPU crashes**,
> black window, exactly as predicted. The wine side handing back a NULL view → **6 crashes and the
> new defensive line fires 6 times**, which is the only way to reach a branch that is dead by
> construction.
>
> **Deviations.** (1) The `<stdio.h>` include is kept, per the pass-2 correction — the file already
> has a real `fprintf` that compiles only through a transitive Cocoa include, and the new defensive
> line adds another. (2) The DXMT comment still carries a `(macgameport, 2026-08-31)` provenance tag,
> which the wine side had stripped in the upstream-form pass. Left alone deliberately: this plan's §2
> table is explicit about what changes, and widening it mid-build is how scope creeps. Worth a
> one-line follow-up since that patch is published too. (3) The first attempt at the wine-side mutant
> used an anchor missing a guard clause, did not apply, and the cell then ran on the unmutated build
> and looked healthy — a failed mutation that reads as "the mutant did nothing". Re-run with the
> correct anchor.
>
> **Verify against:** `scripts/dxmt-remote-layer-fallback.patch` · `INSTALL.md` §6 · `README.md`
> stack row · branch `cs2/remote-layer` in `~/cs2-patch/dxmt-v080` · `EXPERIMENTS.md` C33.

**Scope.** Everything the review found on the DXMT half that needs a `winemetal.so` rebuild, plus
two bookkeeping facts nobody had written down. Not in scope: any change to the PE side
(`d3d11.dll`, `dxgi.dll`, `winemetal.dll`), which stays Porting Kit's build.

---

## 1. Facts to record (INSTALL.md §6, README stack table)

| fact | measured |
|---|---|
| installed PE binaries | Porting Kit's, version string `v0.80-17-g79f6279` inside `d3d11.dll` |
| that commit | not in 3Shain/dxmt (GitHub API 422; `git fetch origin` brings no such object) — a fork or rewritten branch |
| installed `winemetal.so` | built here from tag `v0.80` + `scripts/dxmt-remote-layer-fallback.patch` |
| the cross-process guard string | 0 copies in PK's `d3d11.dll`, 1 in a build from tag `v0.80` (commit `952713e` is in the tag's history) |
| unixlib call table indices used | 72 `_CreateMetalViewFromHWND`, 73 `_ReleaseMetalView` in both `__wine_unix_call_funcs` (the x86_64 PE's dispatch table) and `__wine_unix_call_wow64_funcs` (a 32-bit PE's) — **132 entries each, index 83 a `NULL` slot** (counted in the source and by `nm -n` delta `0x420`, 2026-09-03); PK's `winemetal.dll` exports 131 names — 129 unix-call thunks, each loading an `edx` index whose table entry carries the same name (only naming difference: PE `WMTCopyAllDevices` ↔ table `_MTLCopyAllDevices`, index 4), plus `WMTBootstrapLookUp`/`WMTBootstrapRegister` which load no index; table slots 83 (`NULL`), 121, 122 have no PE thunk; the PE's highest index is 131. So the PE never calls a slot the `.so` lacks (measured with pefile + capstone). A mismatch would be **silent**: the table is a bare pointer array with no count or identity — any DXMT-side edit that inserts an entry before 131 or fills slot 83 re-pairs PK's PE without a diagnostic |

Wording to add: *"the .so and the PE side are different DXMT vintages; they agree on the two unix
calls this patch touches, and the pairing has been exercised on every cell since 2026-08-31."*
The check lens looked at the binaries: PK's `winemetal.dll` was built with clang 22 against a
`wine-private` include tree, its original `winemetal.so` embeds AIR metadata naming a **Gcenx
checkout of dxmt** (build paths under the packager's home directory — do not reproduce them), no
fork URL is embedded, and `79f6279` is not a ref tip of Gcenx/DXMT or 3Shain/dxmt. Neither the
installed `.so` nor PK's embeds a version string, so the `.so` vintage is provable only by
provenance: `cmp` against the build artifact (identical, 27,924,120 B) + `git describe` = `v0.80`
+ the byte-identical patch. Write "Gcenx checkout, per embedded build paths" and stop there. `INSTALL.md` has no `winemetal`
mention today, so this paragraph is new text, not an amendment — anchor it in §6 (`:85-127`) after the
`:100` paragraph about the preserved `CS2dxmt11-pk110.app`.

## 2. Code nits (all in `src/winemetal/unix/winemetal_unix.c`, working-tree lines)

| line | now | change |
|---|---|---|
| 3 | `#include <stdio.h>` | **keep** — the file already has one real `fprintf` (line 1305, a signal-handler message) that compiles only through a transitive Cocoa include, row 1616 adds another, and a transitive include is exactly how `com_guid.cpp` broke under mingw |
| 1660 | `BOOL (*pfn_release_remote)(macdrv_view)` — ObjC `BOOL` is `signed char`, wine returns `int` | declare `int (*)(macdrv_view)` |
| 1616–1623 | `remote_view == NULL` with a non-NULL layer is returned as success; the PE side then `abort()`s with "your Wine has no exported symbols" | **dead by construction on this wine** — `macdrv_CreateClientSurface` (`window.c:1332-1347`) assigns `cocoa_view` unconditionally and a nil view makes the acquire itself fail, so layer-without-view cannot occur. Write the minimal defensive form anyway: `if (remote_layer && remote_view) { … } else if (remote_layer) fprintf(stderr, "…unreachable on this winemac; defensive…");` and fall through (the `if (win_data)` block is skipped → `STATUS_SUCCESS`, `ret_view` 0 → PE abort) |
| 1610 | comment "we fall through unchanged" | say what actually happens: on an unpatched **winemac** `dlsym` returns NULL, the block is skipped, `ret_view` stays 0 and the PE aborts with a misleading message. That is an **improvement**, not preserved behaviour — unpatched v0.80 dereferenced `win_data->client_cocoa_view` unconditionally, a NULL-deref crash inside `winemetal.so` with PK's guard-less PE (and `E_FAIL` before the call with upstream's PE) |
| `src/d3d11/d3d11_swapchain.cpp` | env-gate hunk still uncommitted in the scratch tree | `git checkout --` it (preserved as `scripts/dxmt-force-crossprocess.patch`, whose `index` line comes from another tree). **Outcome test around the checkout:** before — `git diff -- src/d3d11/d3d11_swapchain.cpp` equals the patch body hunk-for-hunk; after — the file is clean and `git apply --check scripts/dxmt-force-crossprocess.patch` succeeds. `build/src/d3d11/d3d11.dll` (22.9 MB, 08-31) already exists from it: the install step copies the `.so` **only** |
| `src/util/com/com_guid.cpp` | third dirty file: `+#include <iomanip>`, the known mingw fix (`scripts/build-dxmt-fork.sh:51-54`, applied from `scripts/dxmt-fork-iomanip.patch`, the identical hunk — cite it in the commit) | keep, as its **own** commit on the branch — without it no PE rebuild from this tree compiles |

## 3. Generate from git

Commit the winemetal change on a local branch `cs2/remote-layer` in the scratch tree (one commit);
`scripts/dxmt-remote-layer-fallback.patch` = header + `git diff v0.80..cs2/remote-layer --
src/winemetal/unix/winemetal_unix.c`. The current patch file has **no** header (line 1 is `diff --git`;
`dxmt-force-crossprocess.patch` carries a six-line one), so the header is authored here, not preserved;
and after §2 lands the patch is regenerated from the new branch tip, so T1's target is that tip, not
today's file. Same drift guard as the wine side: dry-run apply + byte compare in the test plan.

## 4. Build and install

Target: `src/winemetal/unix/winemetal.so` (path-qualified; no short alias — `ninja -t targets all`
lists it). **A clean build of it DOES need the Metal toolchain**: its `.o` has order-only deps on
airconv's `air_{msad,samplepos,tessellation}.h`, which are `xxd` dumps of `.air` files produced by
`xcrun -sdk macosx metal`, and the link consumes `libairconv.a` + LLVM 15. In this build dir those
artifacts exist (2026-08-30), so `ninja -n -d explain src/winemetal/unix/winemetal.so` reports only
the `.o` + link and never invokes `metal`. **That `-n -d explain` output is the pre-build gate**; an
Xcode/CLT update that bumps `xcrun`'s mtime re-arms the `.air` rules and the gate will say so.
Install with a dated backup beside the installed file — **no codesign step**: the installed `.so` is
unsigned today (`codesign -v`: "code object is not signed at all"), x86_64 code under Rosetta needs
none, it is the file every cell since 08-31 and the boot-verify PASS ran on, and signing it would break
§1's and T6's `cmp`. **Outcome test:** `shasum -a 256` of the built `.so` recorded, the installed file
`cmp`-identical to it. No `winemetal.so.bak-*` exists beside the installed file today — the dated
sibling backup starts with this build; the pre-existing rollback is PK's original inside the
whole-engine copy `wine.pk11.0-BAK/lib/wine/x86_64-unix/winemetal.so` (51,786,184 B).

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | patch reproduces the tree | dry-run apply to `git show v0.80:…winemetal_unix.c`; `cmp` | identical | n/a |
| T2 | the target rebuilds incrementally without invoking `metal` | `ninja -n -d explain src/winemetal/unix/winemetal.so` shows only the `.o` + link; then `ninja` it | exit 0; table length: 132 entries counted between the braces of `__wine_unix_call_funcs[]` (index 83 is a `NULL` slot); `nm -n` address delta `___wine_unix_call_wow64_funcs − ___wine_unix_call_funcs` = `0x420` (132 × 8 — a 131-entry table would pad to the same delta, so the count comes from the source, not from `nm`); `nm -gU` export set identical to the installed `.so` | n/a |
| T3 | Steam battery on the rebuilt `.so` | the C29 battery as defined in `hosting-layer-design-gaps.md` § "The C29 battery" | inside its bounds; 0 GPU crashes | **call `pfn_release_remote` but ignore its TRUE and fall through** to `macdrv_view_release_metal_view` — wine still holds the surface, so on that child's next drain (its second resize, or popup close) `macdrv_dispose_view` messages a freed view → GPU-process crash, Steam UI blank, last trace `dxmt-life: release view … draining`. (The obvious mutant, "hook returns 0", is **silent**: the view is freed, the surface leaks, nothing touches the dead pointer again.) Observe red on churn ×2, restore |
| T3b | first-cell-loud mutant | force `pfn_remote = NULL` in `_CreateMetalViewFromHWND` | `ret_view` 0 → PE `abort()` (`d3d11_swapchain.cpp:138`) on the first cross-process swapchain: 6 GPU crashes, black window | that is the mutant |
| T4 | the `remote_view == NULL` branch | unreachable by construction (see §2), so it is exercised with a **wine-side mutant**: `macdrv_main.c` `my_dxmt_acquire_remote_layer` returns the layer with `*ret_view = NULL` (one line), rebuild winemac, one cell | the new DXMT log line appears, then the known PE abort ("your Wine has no exported symbols…") — a deliberate red cell is still a run; restore, rebuild, one green cell | that mutant is the test |
| T5 | game boots on the rebuilt `.so` | `bash scripts/boot-verify.sh`, detached with a log, run **after** the T3 battery's Steam is down (`steam.exe -shutdown`, then `wineserver -k`) — it REFUSES with exit 2 while any process holds the prefix | `VERDICT: PASS` + `GRACEFUL: yes`, exit 0 (the judge requires `MainMenu reached`, `GameManager destroyed`, a SceneFlow first line after t0 and 0 `InvalidProgramException`; a killed run reads `FAIL` + `GRACEFUL: no` — SceneFlow.log is written live); keep the `~/cs2-patch/boot-verify/<stamp>/` run dir | n/a |
| T6 | vintage note is accurate | re-run the §1 rows: `strings` for `v0.80-17-g79f6279`, the guard-string counts (0 / 1), `cmp` of the installed `.so` against the build artifact, `git describe` = `v0.80`, and the full PE-thunk ↔ `.so`-table pairing with pefile + capstone (every index-loading thunk lands on the same-named table entry; 132 entries, index 83 `NULL`, PE highest index 131 — ~12 lines, stronger than the two-index spot check). `strings` on macOS has no `-e`, so the guard-string count is narrow-only, which is the encoding DXMT's `ERR` uses | same numbers | n/a |

## Exit criteria
1. §1 recorded in INSTALL.md and the README table (Gcenx provenance, no paths); §2 all applied including the `com_guid.cpp` commit; §3 patch generated from git; the install copies the `.so` only.
2. T1–T6 green; T3's (fall-through) mutant, T3b and T4's wine-side mutant observed red and restored; the `-n -d explain` gate output and the install hashes kept with the run.
3. Ledger row for the cells; `docs/steam-ui-findings.md` § Hardened gains one line.

## Sequencing
Last in the umbrella order (instruments → upstream form → design gaps → **this**).
`scripts/boot-verify.sh` exists since `cc62ff8` (2026-09-03). It rebuilds `winemac.so` once for T4's
mutant, and `~/cs2-patch/build-1116/wine-11.16-dxmt` is not a git repository today, so the git history
from plan 2 should exist first — T4's mutant/restore has no VCS safety net until then.

## Rollback
`winemetal.so.bak-<date>` beside the installed file (created by this build — none exists today); before
that, PK's original `.so` inside `wine.pk11.0-BAK/lib/wine/x86_64-unix/`; the scratch tree's branch keeps
the old commit.

## Review corrections (triple-check 2026-09-03, pass 3 — fitted re-check after the instruments build)

Trigger: `cc62ff8` built plan 5 (this plan's T5 depends on `boot-verify.sh`). One agent re-ran the
key-path staleness check (empty since the baseline), reproduced all three dirty scratch-tree files
byte-for-byte from the committed patches, re-verified every cite in `winemetal_unix.c`, the wine tree
and `d3d11_swapchain.cpp`, re-measured the §1 vintage rows and the ninja graph (order-only deps
present, `-n -d explain` = no work), and ran the full PE-thunk ↔ table pairing. Four facts corrected
and folded: the unixlib table is **132** entries (index 83 `NULL`), so T2's `nm` delta is `0x420` and
the count comes from the source; T5 is stated in boot-verify's contract with Steam down first; §4's
`codesign` step contradicted §1/T6's `cmp` (the installed `.so` is unsigned and is the file every
result ran on) and is removed; the sequencing names `boot-verify.sh` as shipped and the missing git
safety net for T4. Also folded: `1616–1623`, the `com_guid.cpp` cite and its patch, the patch-header
and regenerated-tip notes in §3, the `INSTALL.md` anchor, the real pre-existing rollback path, the
full pairing check as part of T6, and the narrow-only `strings` note.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | correctness + builder simulation (ninja graph, pefile/capstone on the PE thunks, `git show v0.80`) | 1 agent, 17 tool calls | claude-fable-5-1 | `c94d9e9` | build-ready-with-fixes — code sound; the test gate was the defect (T3's mutant silent), §4's toolchain claim false for a clean build, a third dirty file unaccounted for. Folded. |
| 2026-09-02 | 1b | cross-plan test-plan audit | 1 agent, 10 tool calls | claude-fable-5-1 | `310e631c` | adequate-with-fixes — T4 became a wine-side mutant run, the checkout and the install got outcome tests. Folded. |
| 2026-09-02 | 2 (fitted re-check of the fold) | one agent over the rewritten sections, cites re-verified against the code and the trace | 1 agent, 11 tool calls | claude-fable-5-1 | `276f43d5` | build-ready-with-fixes — rows 3/1616 consistent, three dirty files accounted for, C29 referenced not restated; one minor wording fix. **Cleared for build, last in umbrella order.** |
| 2026-09-03 | 3 (fitted re-check after the instruments build) | correctness + builder simulation (T1 and the swapchain-checkout dry-runs in /tmp, ninja graph incl. order-only deps, full PE-thunk ↔ .so-table pairing with pefile/capstone, installed-binary vintage rows, T5 against boot-verify's real output) | 1 agent, 12 tool calls | claude-fable-5-1 | `cc62ff8` | build-ready-with-fixes — every code cite holds and the patches reproduce all three dirty files byte-for-byte; four facts corrected: the unixlib table is 132 entries (index 83 NULL) so T2's delta is `0x420` not `0x418`; T5's pass is `VERDICT: PASS`/`GRACEFUL: yes`/exit 0 with Steam down first; §4's codesign step contradicted T6/§1's `cmp` (installed `.so` is unsigned and proven); `boot-verify.sh` now exists. Folded above. |

**Key paths:** `~/cs2-patch/dxmt-v080/src/winemetal/unix/winemetal_unix.c` ·
`~/cs2-patch/dxmt-v080/src/d3d11/d3d11_swapchain.cpp` · `scripts/dxmt-remote-layer-fallback.patch` ·
`scripts/build-dxmt-fork.sh` · `INSTALL.md` · `README.md` · `scripts/boot-verify.sh` (T5) ·
`scripts/dxmt-force-crossprocess.patch` · `scripts/dxmt-fork-iomanip.patch`
