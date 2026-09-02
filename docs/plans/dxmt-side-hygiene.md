# DXMT side — record the mixed vintage, close the review nits, generate the patch from git

**Status: check-it'd 2026-09-02 — build-ready-with-fixes (pass 1; corrections folded below).** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`; scratch tree `~/cs2-patch/dxmt-v080` (git, tag `v0.80` checked out, uncommitted diff).

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
| unixlib call table indices used | 72 `_CreateMetalViewFromHWND`, 73 `_ReleaseMetalView` in both `__wine_unix_call_funcs` (the x86_64 PE's dispatch table, 131 entries) and `__wine_unix_call_wow64_funcs` (a 32-bit PE's); PK's `winemetal.dll` thunks load the immediates `0x48`/`0x49` for them and export 131 entries = the table length (measured with pefile + capstone). A mismatch would be **silent**: the table is a bare pointer array with no count or identity |

Wording to add: *"the .so and the PE side are different DXMT vintages; they agree on the two unix
calls this patch touches, and the pairing has been exercised on every cell since 2026-08-31."*
The check lens looked at the binaries: PK's `winemetal.dll` was built with clang 22 against a
`wine-private` include tree, its original `winemetal.so` embeds AIR metadata naming a **Gcenx
checkout of dxmt** (build paths under the packager's home directory — do not reproduce them), no
fork URL is embedded, and `79f6279` is not a ref tip of Gcenx/DXMT or 3Shain/dxmt. Neither the
installed `.so` nor PK's embeds a version string, so the `.so` vintage is provable only by
provenance: `cmp` against the build artifact (identical, 27,924,120 B) + `git describe` = `v0.80`
+ the byte-identical patch. Write "Gcenx checkout, per embedded build paths" and stop there.

## 2. Code nits (all in `src/winemetal/unix/winemetal_unix.c`, working-tree lines)

| line | now | change |
|---|---|---|
| 3 | `#include <stdio.h>` | **keep** — it is unused today, but row 1616 adds an `fprintf`, and a transitive Cocoa include is exactly how `com_guid.cpp` broke under mingw |
| 1660 | `BOOL (*pfn_release_remote)(macdrv_view)` — ObjC `BOOL` is `signed char`, wine returns `int` | declare `int (*)(macdrv_view)` |
| 1616–1622 | `remote_view == NULL` with a non-NULL layer is returned as success; the PE side then `abort()`s with "your Wine has no exported symbols" | **dead by construction on this wine** — `macdrv_CreateClientSurface` (`window.c:1332-1347`) assigns `cocoa_view` unconditionally and a nil view makes the acquire itself fail, so layer-without-view cannot occur. Write the minimal defensive form anyway: `if (remote_layer && remote_view) { … } else if (remote_layer) fprintf(stderr, "…unreachable on this winemac; defensive…");` and fall through (the `if (win_data)` block is skipped → `STATUS_SUCCESS`, `ret_view` 0 → PE abort) |
| 1610 | comment "we fall through unchanged" | say what actually happens: on an unpatched **winemac** `dlsym` returns NULL, the block is skipped, `ret_view` stays 0 and the PE aborts with a misleading message. That is an **improvement**, not preserved behaviour — unpatched v0.80 dereferenced `win_data->client_cocoa_view` unconditionally, a NULL-deref crash inside `winemetal.so` with PK's guard-less PE (and `E_FAIL` before the call with upstream's PE) |
| `src/d3d11/d3d11_swapchain.cpp` | env-gate hunk still uncommitted in the scratch tree | `git checkout --` it (preserved as `scripts/dxmt-force-crossprocess.patch`, whose `index` line comes from another tree — verify with `git apply --check`, not `cmp`). `build/src/d3d11/d3d11.dll` (22.9 MB, 08-31) already exists from it: the install step copies the `.so` **only** |
| `src/util/com/com_guid.cpp` | third dirty file: `+#include <iomanip>`, the known mingw fix (`scripts/build-dxmt-fork.sh:51`) | keep, as its **own** commit on the branch — without it no PE rebuild from this tree compiles |

## 3. Generate from git

Commit the winemetal change on a local branch `cs2/remote-layer` in the scratch tree (one commit);
`scripts/dxmt-remote-layer-fallback.patch` = header + `git diff v0.80..cs2/remote-layer --
src/winemetal/unix/winemetal_unix.c`. Same drift guard as the wine side: dry-run apply + byte
compare in the test plan.

## 4. Build and install

Target: `src/winemetal/unix/winemetal.so` (path-qualified; no short alias — `ninja -t targets all`
lists it). **A clean build of it DOES need the Metal toolchain**: its `.o` has order-only deps on
airconv's `air_{msad,samplepos,tessellation}.h`, which are `xxd` dumps of `.air` files produced by
`xcrun -sdk macosx metal`, and the link consumes `libairconv.a` + LLVM 15. In this build dir those
artifacts exist (2026-08-30), so `ninja -n -d explain src/winemetal/unix/winemetal.so` reports only
the `.o` + link and never invokes `metal`. **That `-n -d explain` output is the pre-build gate**; an
Xcode/CLT update that bumps `xcrun`'s mtime re-arms the `.air` rules and the gate will say so.
Install with a dated backup beside the installed file, `codesign -f -s -` under the real basename.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | patch reproduces the tree | dry-run apply to `git show v0.80:…winemetal_unix.c`; `cmp` | identical | n/a |
| T2 | the target rebuilds incrementally without invoking `metal` | `ninja -n -d explain src/winemetal/unix/winemetal.so` shows only the `.o` + link; then `ninja` it | exit 0; table length by `nm -n` address delta `___wine_unix_call_wow64_funcs − ___wine_unix_call_funcs` = 131 × 8 = `0x418`; `nm -gU` export set identical to the installed `.so` | n/a |
| T3 | Steam battery on the rebuilt `.so` | 3 cells, navigation ×6, blackout sequence, churn ×2 + control, popup open/close | matches C29; 0 GPU crashes | **call `pfn_release_remote` but ignore its TRUE and fall through** to `macdrv_view_release_metal_view` — wine still holds the surface, so on that child's next drain (its second resize, or popup close) `macdrv_dispose_view` messages a freed view → GPU-process crash, Steam UI blank, last trace `dxmt-life: release view … draining`. (The obvious mutant, "hook returns 0", is **silent**: the view is freed, the surface leaks, nothing touches the dead pointer again.) Observe red on churn ×2, restore |
| T3b | first-cell-loud mutant | force `pfn_remote = NULL` in `_CreateMetalViewFromHWND` | `ret_view` 0 → PE `abort()` (`d3d11_swapchain.cpp:138`) on the first cross-process swapchain: 6 GPU crashes, black window | that is the mutant |
| T4 | the `remote_view == NULL` branch | unreachable by construction (see §2); **checked by inspection**, reachability argument recorded in the patch header; reaching it needs a wine-side mutant at `macdrv_main.c:825` or a dlopen harness that fights the direct `winemac.so`/`ntdll.so` link — not worth building | the branch is present, logged, and documented as unexercised | n/a |
| T5 | game boots | boot-verify | `MainMenu reached` | n/a |
| T6 | vintage note is accurate | re-run the three measurements in §1 | same numbers | n/a |

## Exit criteria
1. §1 recorded in INSTALL.md and the README table (Gcenx provenance, no paths); §2 all applied including the `com_guid.cpp` commit; §3 patch generated from git; the install copies the `.so` only.
2. T1–T3, T5, T6 green; T3's (fall-through) mutant and T3b observed red and restored; the `-n -d explain` gate output kept with the run.
3. Ledger row for the cells; `docs/steam-ui-findings.md` § Hardened gains one line.

## Rollback
`winemetal.so.bak-<date>` beside the installed file; the scratch tree's branch keeps the old commit.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | correctness + builder simulation (ninja graph, pefile/capstone on the PE thunks, `git show v0.80`) | 1 agent, 17 tool calls | claude-fable-5-1 | `c94d9e9` | build-ready-with-fixes — code sound; the test gate was the defect (T3's mutant silent), §4's toolchain claim false for a clean build, a third dirty file unaccounted for. All folded above. |

**Key paths:** `~/cs2-patch/dxmt-v080/src/winemetal/unix/winemetal_unix.c` ·
`~/cs2-patch/dxmt-v080/src/d3d11/d3d11_swapchain.cpp` · `scripts/dxmt-remote-layer-fallback.patch` ·
`scripts/build-dxmt-fork.sh` · `INSTALL.md` · `README.md`
