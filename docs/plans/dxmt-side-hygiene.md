# DXMT side — record the mixed vintage, close the review nits, generate the patch from git

**Status: Not yet triple-checked — run `check it` before build.** Umbrella:
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
| unixlib call table indices used | 72 `_CreateMetalViewFromHWND`, 73 `_ReleaseMetalView`, identical in the tag; the PE side reaches the same two through the wow64 table |

Wording to add: *"the .so and the PE side are different DXMT vintages; they agree on the two unix
calls this patch touches, and the pairing has been exercised on every cell since 2026-08-31."* If
PK's source is ever identified (the strings in PK's `winemetal.so` may carry a repo URL — a check
lens should look), rebuild `winemetal.so` from it and retire the note.

## 2. Code nits (all in `src/winemetal/unix/winemetal_unix.c`, working-tree lines)

| line | now | change |
|---|---|---|
| 3 | `#include <stdio.h>` | remove (no printf in the final diff; verify with `grep -c printf` = unchanged from HEAD) |
| 1660 | `BOOL (*pfn_release_remote)(macdrv_view)` — ObjC `BOOL` is `signed char`, wine returns `int` | declare `int (*)(macdrv_view)` |
| 1616–1622 | `remote_view == NULL` with a non-NULL layer is returned as success; the PE side then `abort()`s with "your Wine has no exported symbols" | treat as failure: if `remote_layer && !remote_view`, log one clear `fprintf` and fall through to the old path (which returns `STATUS_SUCCESS` with `ret_view` 0 — the existing contract), so the abort message is at least preceded by the real reason |
| 1610 | comment "we fall through unchanged" | say what actually happens on an unpatched winemac: `dlsym` returns NULL, the old code returns `ret_view` 0, the PE side aborts with a misleading message — and that this is the pre-existing behaviour, not a regression |
| `src/d3d11/d3d11_swapchain.cpp` | env-gate hunk still uncommitted in the scratch tree | `git checkout --` it (preserved as `scripts/dxmt-force-crossprocess.patch`); a full install from the tree can then never ship an untested `d3d11.dll` |

## 3. Generate from git

Commit the winemetal change on a local branch `cs2/remote-layer` in the scratch tree (one commit);
`scripts/dxmt-remote-layer-fallback.patch` = header + `git diff v0.80..cs2/remote-layer --
src/winemetal/unix/winemetal_unix.c`. Same drift guard as the wine side: dry-run apply + byte
compare in the test plan.

## 4. Build and install

Target: the unix module only. A check lens must confirm the ninja target name from
`ninja -C ~/cs2-patch/dxmt-v080/build -t targets | grep winemetal` (read-only) and whether it needs
the Metal shader toolchain (`build-dxmt-fork.sh` says the *shaders* do; the unix `.so` should not).
Install with a dated backup beside the installed file, `codesign -f -s -` under the real basename.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | patch reproduces the tree | dry-run apply to `git show v0.80:…winemetal_unix.c`; `cmp` | identical | n/a |
| T2 | build target exists and builds without the Metal toolchain | `ninja <target>` | exit 0; `nm` shows the same unix-call table symbols as the installed `.so` | n/a |
| T3 | Steam battery on the rebuilt `.so` | 3 cells, navigation ×6, blackout sequence, churn ×2 + control, popup open/close | matches C29; 0 GPU crashes | make `pfn_release_remote` always return 0 → the remote view falls through to `macdrv_view_release_metal_view` → observe the over-release (GPU crash or black child on resize), restore |
| T4 | the `remote_view == NULL` branch | cannot be reached with the current wine side (it always creates the view); instead **unit-check by inspection** and record that it is unexercised | the code path is present and logged; the header says it is untested | n/a |
| T5 | game boots | boot-verify | `MainMenu reached` | n/a |
| T6 | vintage note is accurate | re-run the three measurements in §1 | same numbers | n/a |

## Exit criteria
1. §1 recorded in INSTALL.md and the README table; §2 all applied; §3 patch generated from git.
2. T1–T3, T5, T6 green; T3's mutant observed red and restored.
3. Ledger row for the cells; `docs/steam-ui-findings.md` § Hardened gains one line.

## Rollback
`winemetal.so.bak-<date>` beside the installed file; the scratch tree's branch keeps the old commit.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | not yet checked | — | — | — | — | — |

**Key paths:** `~/cs2-patch/dxmt-v080/src/winemetal/unix/winemetal_unix.c` ·
`~/cs2-patch/dxmt-v080/src/d3d11/d3d11_swapchain.cpp` · `scripts/dxmt-remote-layer-fallback.patch` ·
`scripts/build-dxmt-fork.sh` · `INSTALL.md` · `README.md`
