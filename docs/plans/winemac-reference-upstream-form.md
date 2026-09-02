# The wine reference implementation in upstream form — readable, split, and generated from git

**Status: Not yet triple-checked — run `check it` before build.** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`; the review lens's separability table and draft commit message are preserved in the issue.

**Standing decision this plan does not change:** the project files *reports, not patches* (dxmt
forbids AI-authored PRs; wine got bug 60263 with the implementation offered as a reference). The
deliverable here is a reference a maintainer can read in ten minutes — not a submission.

**Scope.** (1) Put the winemac source under git so patches are generated, never hand-maintained.
(2) Bring the code to upstream form: no provenance tags, wine-length comments, no fprintf
instrument, neutral names in the core. (3) Split the published patch into a stock-applicable
**core** and a DXMT **glue** layer, and prove the split compiles on stock wine 11.16.

---

## 1. Git-track the source (mechanism against drift)

`git init` in `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/` with a linear history:
`stock` (the pristine 11.16 files) → `aquadran` (the DXMT support patch) → `core` → `glue`.
Patches become `git diff` between commits with `--src-prefix=a/dlls/winemac.drv/`
`--dst-prefix=b/dlls/winemac.drv/`, so `patch -p1` from a wine tree root keeps working. The
`*.pre-*` backups are retired once the history exists (kept as an untracked `backups/` dir for a
week, then deleted). `check-experiments.py` gains nothing here; the drift guard is the byte-compare
in the test plan.

## 2. Upstream form (counts measured 2026-09-02 by the maintainer lens)

| item | now | target |
|---|---|---|
| `macgameport` date tags in code comments | 15 | 0 in core; allowed in glue |
| `EXPERIMENT (2026-08-29…)` headers | 3 (one already removed) | 0 |
| comment share of added lines | ≈33% | ≈10% in core; the measurements move to `docs/winemac-crossprocess-remote-layer-history.md` where they already largely are |
| `DXMT_RSZ` fprintf instrument (2 definitions, 7 call sites, 5 includes) | present, `#ifdef`'d | **removed** from the tree; the history doc keeps the definition verbatim for anyone re-instrumenting |
| vendor-named symbols in core | `dxmt_fill_view_edges` | `snap_host_frame_to_view_edges` (file-local static) |
| `ERR`/`TRACE`/`FIXME` use | done in the review pass | unchanged |
| non-ASCII | 0 | 0 |

Behaviour-neutral by construction: the comment/tag pass must produce a **byte-identical**
`winemac.so` (the project's own 2026-08-31 precedent); the rename and instrument removal change
symbols and must be re-verified on the Steam battery.

## 3. The split

**Core** (stock-applicable, implements the FIXME for every caller including `vulkan.c`):
child-window swapchain against the root with the child in `wParam`; root-space geometry with
px→pt conversion; three-case frame handling (null / empty / real); `zPosition` from paint order
(after the design-gaps plan lands, the counted walk); `retire_superseded_layers`; the per-root
tracking table and its release in `DestroyWindow`; `WM_MACDRV_UPDATE_REMOTE_LAYER` if the
design-gaps plan has landed. Roughly 250–300 lines.

**Glue** (DXMT-specific, applies on top of core + aquadran): the two `DECLSPEC_EXPORT`s, the
view-keyed surface table, `pending_by_child` + `collect_dead_pending`, the deferred black
background, `snap_host_frame_to_view_edges` — the last two are kept out of core because they are
measured workarounds for the CEF-under-DXMT case, not part of the mechanism. Roughly 200 lines.

Published as `scripts/winemac-crossprocess-child-core.patch` and
`scripts/winemac-crossprocess-dxmt-glue.patch`; the existing combined file stays (bug 60263 links
it) and its header names the two.

**Licensing/attribution (recorded, not acted on):** the repo is MIT; any future wine submission
would be offered LGPL-2.1+ by the author under a real name with no in-code provenance. The core
patch header states this so nobody mistakes MIT text for the offer.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | comment/tag pass is behaviour-neutral | rebuild after the pass only | `winemac.so` byte-identical to the pre-pass build (compare before codesign) | introduce one code change alongside → hash differs → the pass is contaminated (this is the detector, run once to prove it works) |
| T2 | core applies to **stock** 11.16 and compiles | fresh stock tree + core patch; configure a stock build dir (no DXMT patch) with the engine's configure line; `gmake dlls/winemac.drv/winemac.so` | exit 0, no new warnings, the FIXME string is gone from the binary | drop one core hunk → build fails or FIXME string returns |
| T3 | core + glue reproduce the tree | apply both to stock+aquadran; `cmp` all five files against the git `glue` commit | byte-identical | n/a |
| T4 | the git-generated patches match the tree | regenerate from git; dry-run apply; `cmp` | identical | n/a |
| T5 | Steam battery on the rebuilt module | 3 cells, navigation ×6, blackout sequence, churn ×2 + control, popup open/close | matches C29 | n/a |
| T6 | game boots | boot-verify | `MainMenu reached`, graceful exit | n/a |
| T7 | vulkan path still builds | core on stock includes `vulkan.c`'s caller unchanged | compiles (T2 covers it); runtime not testable here — say so in the header | n/a |

## Exit criteria
1. Source under git with the four-commit history; `*.pre-*` backups gone.
2. Core patch compiles on stock 11.16 (T2) and the combined patch reproduces the tree (T3, T4).
3. The maintainer-lens counts in §2 are at target, measured with the same greps.
4. Steam battery and game boot match C29; ledger row C31 names the cells.
5. Bug 60263 gets the core patch as a second attachment marking the first obsolete — **only with
   James's go-ahead**, which this plan records as a step, not a given.

## Rollback
The git history *is* the rollback: `git checkout glue` restores the pre-form tree; the installed
module's backup sits beside it.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | not yet checked | — | — | — | — | — |

**Key paths:** `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/` ·
`~/cs2-patch/build-1116/wine-11.16/dlls/winemac.drv/` (pristine) · `scripts/wineandaqua-dxmt.patch` ·
`scripts/winemac-crossprocess-remote-layer.patch` · `docs/winemac-crossprocess-remote-layer-history.md`
