# The wine reference implementation in upstream form — readable, split, and generated from git

**Status: BUILT 2026-09-03 (exit criterion 5 held for James) · check-it'd 2026-09-03 — build-ready-with-fixes (pass 3, fitted re-check after the instruments build at `cc62ff8`; T6 restated in boot-verify's contract, §2 greps corrected, no structural change). Pass 2: check-it'd 2026-09-02 — build-ready-with-fixes (the history design was the pass-1 blocker, corrected and re-checked).** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`; the review lens's separability table and draft commit message are preserved in the issue.

> **🔧 As-built (2026-09-03): BUILT.** Commits `e32fc34` (the split, the generator and the three
> patches), `938fb50` (the T1 gate correction and `scripts/strip-comments.py`), `d5318a1` + `564a76e`
> (a probe defect found by the battery). Source history: the nested repo at
> `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv`, bundled to
> `~/cs2-patch/evidence/winemac-drv-history-20260903.bundle` and verified complete before the eleven
> `*.pre-*` backups were deleted. Ledger **C31**; cells `exp_519eef` `exp_1da98c` `exp_37f651`
> `exp_4679e5`; boot-verify run `20260902-214032`.
>
> **Measured.** T1: each form pass verified by two gates, a comment-stripped source comparison and
> an object comparison — `cocoa_window.o` and `macdrv_main.o` byte-identical across passes (a) and
> (b), `window.o` byte-identical under `-DNDEBUG`, and the (c) rename byte-identical even before
> `strip -x`. T2: core applies with zero fuzz to pristine 11.16 **and** to 11.16+aquadran, builds on
> pristine at exit 0 with the driver's warning set identical to the 56-warning stock baseline, and
> takes the FIXME string 1 → 0; both mutants observed red and restored. T3: stock+aquadran+combined
> reproduces all five files byte-for-byte, and core-then-glue reaches the same place. T4: the
> `--check` drift gate is green and its mutant red. T5: the C29 battery on module `53c9443db3145f58`
> — six navigations RENDERED, blackout 83/84/85 with 0 bright edges, 0 GPU crashes over three cells,
> 2 prunes, 1 slot drained, churn ×2 + control at 0 gaps. T6: `VERDICT: PASS`, `GRACEFUL: yes`.
>
> **Deviations.** (1) **Three** hunks carried vendor context, not two — the import block was the
> third, and the helper moved to sit before `@implementation WineContentView`. (2) The
> `DestroyWindow` release must go on the plan's exact anchor; one statement later its trailing
> context reaches the line aquadran edits. (3) T1's byte-identity premise is false for a unit
> containing `assert()`, which bakes `__LINE__` into the object. (4) T2's first mutant fails as a
> compile error, not the predicted string return, because that hunk also carries a call-signature
> change. (5) Comment share landed at **15–16 %** (first recorded as 14 %; re-measured 2026-09-04), not ≈10% — stopped deliberately, the remainder being
> reasons rather than evidence. (6) The first battery run was VOID on its capture rows: the cell
> harness's `caffeinate` covers only its own 215 s, and captures were taken without raising the
> window first. Both fixed in the harness, then re-run.
>
> **Done 2026-09-03.** Exit criterion 5 — the core patch is attachment **82030** on wine bug 60263
> (35,531 B, `is_patch`, comment #2), and attachment 82021 is marked obsolete. Posted after James
> approved the draft, via the Bugzilla REST API. ⚠ Found while preparing it: the committed core
> patch had drifted (D1/D2 on `main` only) — fixed in 643dd6c, see GOTCHAS 2026-09-03 and ledger
> C31 addendum. The vulkan.c path is stated in the comment as compiled but never exercised.
>
> **Comment pass 2026-09-04 (issue #6 review).** Nine comment-only corrections on nested `core`
> (`63a0cec`; `main` rebuilt as aquadran → core → glue, tip `52789ff`), patches regenerated,
> `--check` three `ok` + three invariants. Gates: `strip-comments.py` CODE IDENTICAL on both files,
> and `cocoa_window.o`, `window.o` and `winemac.so` **byte-identical** to the pre-pass build — the
> assert kept its line, so no `-DNDEBUG` compare was needed; the installed module
> `00ac32aa3115b455` is unchanged. Fixed: a comment stating a design that no longer exists
> (children "owned by another process", "no WindowPosChanged of their own"), orphaned onto
> `remote_layer_context_for`; the z-order note orphaned onto `getCALayerHostPlacement:`; the stock
> `WindowPosChanged` banner separated from its function by the inserted helpers; a
> swapchain-creation comment claiming the rect positions the host (only its size reaches the
> layer); a CALayer.h attribution the header does not make; and four misattributed measurements or
> rationales. Bug 60263's attachment 82030 predates this and stages 1–2 — deliberately not
> re-attached. ⚠ **§2's comment share is now 181/691 = 26 %** after stages 1–2 (15–16 % at build);
> exit criterion 3 has not been re-decided for that material. Bundle
> `winemac-drv-history-20260904-comments.bundle`; old tips tagged `pre-fable6-*`.

**Standing decision this plan does not change:** the project files *reports, not patches* (dxmt
forbids AI-authored PRs; wine got bug 60263 with the implementation offered as a reference). The
deliverable here is a reference a maintainer can read in ten minutes — not a submission.

**Scope.** (1) Put the winemac source under git so patches are generated, never hand-maintained.
(2) Bring the code to upstream form: no provenance tags, wine-length comments, no fprintf
instrument, neutral names in the core. (3) Split the published patch into a stock-applicable
**core** and a DXMT **glue** layer, and prove the split compiles on stock wine 11.16.

---

## 1. Git-track the source (mechanism against drift)

`git init` in `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/` (safe: wine's makedep
never globs a source dir and only writes a `.gitignore` into the *object* dir of an in-tree build,
and this build is out-of-tree; the build Makefile's `git describe` looks at the tree top, which has
no `.git`). **Branched, not linear** — the check lens measured that a core patch cut from the
current insertion points does not apply to stock: core hunks carry aquadran's lines as context,
and `git apply --check` against pristine fails on them. **Measured at build time: there are THREE
such hunks, not two.** `macdrv.h`'s field sits after `dxmt_client_surfaces`; the `DestroyWindow`
release sits after aquadran's `CFRelease`; and — the one the check pass missed — the retina
edge-snap helper was inserted straight after `#import "cocoa_opengl.h"`, which is exactly where
aquadran inserts `#import "dxmt_objc.h"`. So:
- `stock` — the pristine 11.16 files (which already ship a `.gitattributes` giving ObjC `@@`
  headers for `.m`/`.h`).
- `core` — branched off `stock`, authored with all three insertion points **moved away from
  aquadran's**: `remote_layer_children` goes after `drag_event` (pristine `macdrv.h:187`, before
  the bitfields); the `CFRelease` goes right after `if (!(data = get_win_data(hwnd))) return;`
  in `DestroyWindow` (pristine `window.c:1270`) — **not one statement later, past `drag_event`:
  three lines of trailing context then reach `destroy_cocoa_window()`, which is where aquadran
  inserts, and the hunk stops applying to the vendor base**; and the edge-snap helper moves off
  the import block entirely, to just before `@implementation WineContentView`, whose surrounding
  context is identical in both bases and which is where its callers live. `git diff stock core`
  then applies fuzz-free to both stock and stock+aquadran — verified with `patch -F0` against a
  clean copy of each base, 0 failed hunks.
- `main` — `stock` → `aquadran` → cherry-pick(`core`) → `glue`. Combined patch =
  `git diff aquadran main`; glue = `git diff <cherry-pick> main`.
Set `diff.srcPrefix=a/dlls/winemac.drv/` and `diff.dstPrefix=b/dlls/winemac.drv/` in the nested
repo's config so regeneration cannot forget them. Both existing patches use `a/dlls/winemac.drv/<file>`
paths, so applying them *inside* the nested repo needs `git apply -p3` (or `--directory`). **Verify the base commits, not just the patches:**
the `stock` commit `cmp`s byte-for-byte against `~/cs2-patch/build-1116/wine-11.16/dlls/winemac.drv/`,
and `aquadran` equals `stock` + `scripts/wineandaqua-dxmt.patch` applied (`cmp` after `patch -p1`; the
`winemac.drv/` part of that patch is **nine** files — `event.c`, `dxmt_objc.m`/`.h`, `Makefile.in` among
them — and the `aquadran` commit must carry all nine, or the `cmp` compares the wrong set).
Without that, T3/T4 compare git to git. Cost of the relocation: struct field order
changes, so the rebuilt module is not byte-identical to C29's — T5/T6 cover that. **Before deleting
the eleven `*.pre-*` backups, `git bundle` the nested repo into `~/cs2-patch/evidence/`**: it is
the only copy of the history and has no remote; the deletion is gated on `git bundle verify`
passing, not on a week elapsing. The drift guard is T4, promoted to a `button up`
gate (regenerate to a temp file, `cmp` against `scripts/*.patch`).

## 2. Upstream form (counts re-measured 2026-09-02 by the check lens on the combined diff, added lines only)

| item | now | target | grep (on `scripts/winemac-crossprocess-remote-layer.patch`) |
|---|---|---|---|
| `macgameport` handle tags | **9** (all parenthetical); dated lines 22 (the grep returns 27 — minus the five `+++ … 2026-09-02 16:23:25` file-header lines); union 23 (28 − 5) | 0 in core; allowed in glue | `grep -c '^+.*macgameport'` · `grep -c '^+.*2026-0[0-9]-[0-9][0-9]'` (subtract the `+++` lines) |
| `EXPERIMENT (…)` headers | **1** | 0 | `grep -c '^+.*EXPERIMENT'` |
| comment share of added lines | **28.7%** comment-only of 839 added (31.3% of non-blank) | ≈10% in core; measurements live in `docs/winemac-crossprocess-remote-layer-history.md`. **Landed at 15–16 %, not 10 %** (re-measured 2026-09-04 with this row's grep: core 56/374, combined 80/497 at `e32fc34`; the "88 of 602" first recorded here does not reproduce on any committed version) — both passes stopped there deliberately, on the ground that what remains is the reason a maintainer needs (why a child's rect is converted to the root's space, why a zero-area layer is hidden, why visibility and geometry are tested separately, why layers stack by paint order, why a superseded layer is retired late) rather than the evidence, which moved to the history doc | `grep -c '^+[[:space:]]*\(/\*\|\*\|//\)'` ÷ `grep -c '^+'` (minus `+++`) |
| `DXMT_RSZ` instrument | 2 definition pairs + 2 `dxmt_rsz_ms` helpers + **3 inline `#ifdef DXMT_RSZ_DEBUG` blocks**, 7 call sites, 5 include lines (three headers — `<sys/time.h>`, `<unistd.h>` in the `.m`; `<stdio.h>`, `<sys/time.h>`, `<unistd.h>` in `window.c` — unconditional, none inside the `#ifdef` blocks) — ≈101 lines | **removed** from the tree; the history doc keeps the definition verbatim. **One observation survives as a core `TRACE`, in C:** the per-layer z assignment in `window.c`'s `update_remote_layer_frames` (`context_id`, `zpos`, `have_z` — replacing the former `WINPOS` instrument line at its call site), because the design-gaps plan's T5 reads it. Not in the `.m` method: no `.m` file includes `wine/debug.h`, and the Cocoa-side `ERR` is not `WINEDEBUG`-controlled | `grep -c '^+.*DXMT_RSZ'` |
| vendor-named symbols in core | `dxmt_fill_view_edges` (4 lines: definition, 2 call sites, 1 comment mention) | `snap_host_frame_to_view_edges` (file-local static) | `grep -c '^+.*dxmt_fill_view_edges'` |
| `ERR`/`TRACE`/`FIXME` use | done in the review pass | unchanged | — |
| non-ASCII | 0 in added lines; 1 in the `#` header (the line-1 em dash) | 0 — drop the em dash from the published core/glue headers | `grep -cP '^\+.*[^\x00-\x7F]'` for added lines; the bare form counts the header too |
| the AI-authorship disclosure (header lines 5–13) | present | **kept** in every published header — it is not provenance noise | — |

Behaviour-neutral by construction — but **byte-identity is not the universal gate the 2026-08-31
precedent implied, and pass (a) measured why (2026-09-03).** macOS `assert(x)` expands to
`__assert_rtn(__func__, __FILE__, __LINE__, …)`, so a translation unit containing an `assert` bakes
its line number into the object: removing 32 comment lines from `window.c` moved its one assert from
line 1328 to 1296 and changed `window.o` in exactly five bytes, every one `0x30 -> 0x10` — `impl_from_client_surface()` has
four call sites, so the fifth is presumably its out-of-line body; the count is measured, that attribution is not. The gate is therefore **byte-identical, or
byte-identical under `-DNDEBUG` for a file containing `assert()`** (measured: with the assert
compiled out the two revisions produce an identical `window.o`), and it is paired with a
**comment-stripped source comparison** — `scripts/strip-comments.py`, which strips C/ObjC
comments and normalises whitespace — since that is the check that actually proves no code moved.
`cocoa_window.m` and `macdrv_main.c` contain no `assert` and stay plainly byte-identical. Find the
exposure before a pass with `grep -nE '(^|[^_[:alnum:]])assert[[:space:]]*\(' <files>`. The instrument removal is byte-identical
too (`DXMT_RSZ` expands to `do {} while (0)`, the `#ifdef` blocks are not compiled, the five libc
include lines — three headers — change no codegen), and the static rename is byte-identical after `strip -x`. Only the
`set_bounds` deletion, the insertion-point relocation and the one added z `TRACE` change the
binary, so T5/T6 re-verify.

## 3. The split

**Core** (stock-applicable, implements the FIXME for every caller including `vulkan.c`, whose
calls — `macdrv_client_surface_acquire_metal_swapchain`, `macdrv_swapchain_get_layer` — keep
their signatures): the child-window swapchain against the root with the child in `wParam`;
root-space geometry with px→pt conversion at the two Cocoa entry points; the three-case frame
handling (null / empty / real); `updateCALayerHostFrame:frame:` and
`setCALayerHostZPosition:zPosition:`; `zPosition` from the paint-order walk (already shipped
2026-08-31); `retire_superseded_layers`; the tracked-id guard in the RELEASE handler; the per-root
tracking table, `update_remote_layer_frames` and its `WindowPosChanged` call, and the table's
release in `DestroyWindow`; **and `snap_host_frame_to_view_edges`** — it is owner-side retina
geometry (an odd Win32 pixel size is a half Cocoa point on any retina display), reads only the
stock `retina_on` global, and is not CEF-specific. Measured ≈335 code lines before comments
(cocoa_window.m ≈98, window.c ≈228, headers 9); ≈370–400 with wine-length comments.

**Deleted before the split** (the design-gaps plan's D3 decision, executed here because it is a
pure removal of measured-dead code): `macdrv_swapchain_set_bounds`, its prototype, and the
`macdrv_client_surface_update` remote branch that called it.

**Glue** (DXMT-specific, applies on top of core + aquadran): the two `DECLSPEC_EXPORT`s, the
view-keyed surface table, `pending_by_child` + `collect_dead_pending` (`macdrv_main.c`, ≈153
lines), and the **deferred black background** (`dispatch_after` block, ≈30 lines) — the one
CEF-measured workaround. Glue inserts *inside* two core methods
(`addCALayerHostViewWithContextId:frame:` and `updateCALayerHostFrame:`), so the core commit is
authored without those lines and the glue commit adds them back; the glue patch's context is core
text. Roughly 185–225 lines.

Published as `scripts/winemac-crossprocess-child-core.patch` and
`scripts/winemac-crossprocess-dxmt-glue.patch`; the existing combined file stays (bug 60263 links
it) and its header names the two.

**Licensing/attribution (acted on in the headers, nothing submitted):** all five files are
LGPL-2.1-or-later with CodeWeavers copyright lines, and a unified diff of them reproduces LGPL
context and removed lines — so "MIT-licensed like the rest of this repo" (the current combined
header, and the attachment on bug 60263) cannot be asserted over a patch of LGPL files. Both
published headers say instead: *modifications © 2026 the author, offered LGPL-2.1-or-later, the
license of the files they modify; context lines are Wine's and are not relicensed; the repo's own
scripts and docs remain MIT.* Wine convention for a contribution this size is a
`Copyright 2026 <Real Name>` line in each touched file header — the one form of in-code provenance
a future submission would *add*, not strip. The AI-assisted disclosure stays in every header.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | the form passes are behaviour-neutral | rebuild after each pass: (a) comments/tags, (b) instrument removal, (c) the static rename. **Two gates, both required**: the comment-stripped source comparison (`scripts/strip-comments.py`, proves no code moved) and the object comparison | Per translation unit: byte-identical, **except a unit containing `assert()`, which is byte-identical only under `-DNDEBUG`** — `assert` bakes `__LINE__` into the object, so any comment line added or removed above it shifts an immediate (measured 2026-09-03: `window.c`, 5 bytes, `0x30 -> 0x10`). The referent is the **unsigned build-dir artifact** `wine-1116-vis-build/dlls/winemac.drv/winemac.so`, sha256 `acbf3156…`, 503,800 B, not the 526,016 B signed installed module. `(c)` byte-identical after `strip -x`. The z `TRACE` is added in its own step and is *not* expected byte-identical | introduce one **codegen-visible** change alongside (a) — a string literal, not a dead store the optimiser removes → the object differs by more than the line-number immediates → the detector works; run once |
| T2 | core applies to **stock** 11.16 and compiles with stock flags (T7 folded in: `vulkan.c`'s callers keep their signatures, so this build is the vulkan check) | fresh stock tree + `git diff stock core`; `git apply --check` then apply; configure a stock build dir with the engine's configure line **minus `-fvisibility=default`** (core adds no exports; a maintainer builds hidden) and with the stock `configure` path — the engine's line, from `wine-1116-vis-build/config.log`: `…/wine-11.16-dxmt/configure --prefix=…/vis-throwaway --host=x86_64-apple-darwin --enable-archs=i386,x86_64 --without-x … 'CC=clang -arch x86_64' 'CFLAGS=-fvisibility=default -O2 -Wno-error' … LDFLAGS=-L…/CS2dxmt11.app/Contents/SharedSupport/wine/lib`; run the pristine `wine-11.16/configure` with the same flags minus the visibility one and decide the LDFLAGS deliberately; check `build-1116/vanilla-1116/` first, it may already be that dir; **record the stock warning count from the same build dir before applying**; `gmake dlls/winemac.drv/{window,cocoa_window,macdrv_main}.o` as the fast compile check, then `gmake dlls/winemac.drv/winemac.so` — which first builds `ntdll.so`/`win32u.so` in a fresh dir (budget it) | apply-check clean, exit 0, warning count unchanged, the string `Cross-process child window Metal swapchains are not implemented` absent from the binary, the link succeeds (macOS `-undefined error` catches a core function left in glue) | drop **the hunk that replaces the FIXME** (the one carrying `-            FIXME("Cross-process child window Metal swapchains are not implemented\n")` — `@@ -1178` in the combined patch, pristine `window.c:1183` in the core patch) **Both observed red 2026-09-03, and the first does not fail as predicted:** the string does **not** return, because that hunk also carries the `macdrv_create_offscreen_swapchain` call-signature change, so the build fails first with `window.c: too few arguments to function call, expected 3, have 2` — louder than the predicted red, but a different mechanism, since the hunk is not independent. Reversing the `macdrv.h` field hunk gives `error: no member named 'remote_layer_children' in 'struct macdrv_win_data'`. ⚠ Extract each mutant hunk **with its file header**: splitting the patch on `^@@` and dropping a part orphans the header, and the following file's hunks are then applied to the wrong file, which reads as a spurious failure |
| T3 | the branched history reproduces the tree | `git diff aquadran main` applied to a fresh stock+aquadran copy; `cmp` all five files against `main` | byte-identical | n/a |
| T4 | the published patches match git — **standing `button up` gate** | regenerate combined/core/glue to temp files; `cmp` against `scripts/*.patch` | identical; the gate fails loudly on any hand edit | edit one byte in a `.patch` → gate red |
| T5 | Steam battery on the rebuilt module | the C29 battery as defined in `hosting-layer-design-gaps.md` § "The C29 battery" | inside its bounds | n/a |
| T6 | game boots | `bash scripts/boot-verify.sh`, detached (`--judge-only <run> --t0 <epoch>` re-judges a run) | `VERDICT: PASS` + `GRACEFUL: yes`, exit 0 — PASS already requires `MainMenu reached`, `GameManager destroyed` and 0 `InvalidProgramException`; a killed run reads `FAIL` + `GRACEFUL: no` (SceneFlow.log is written live); exit 2 = refused, prefix busy — rerun | n/a |
| T7 | vulkan path at runtime | not testable here (no Vulkan cross-process client); the core header says so | — | n/a |

## Exit criteria
1. Source under git with the branched history (`stock` → `core`; `main` = stock → aquadran → cherry-pick → glue), diff prefixes configured, a bundle in `~/cs2-patch/evidence/`; `*.pre-*` backups gone. `set_bounds` deleted.
2. Core patch compiles on stock 11.16 (T2) and the combined patch reproduces the tree (T3, T4).
3. The §2 counts are at target, measured with the greps recorded in the table.
4. Steam battery and game boot match C29; ledger row C31 names the cells.
5. Bug 60263 gets the core patch as a second attachment marking the first obsolete — **only with
   James's go-ahead**, which this plan records as a step, not a given.

## Sequencing
**Umbrella order: instruments (plan 5) → this plan → design gaps (plan 1) → DXMT side (plan 3);
repo hygiene (plan 4) independent.** Plan 5 is **built** (`cc62ff8`, 2026-09-03; only its I3 human
live-drag step is pending and this plan does not use it), so `scripts/boot-verify.sh` exists and this
plan is now first in the build queue; plan 1 builds on this plan's history, its `set_bounds`
deletion and its z `TRACE`.

## Rollback
The git history *is* the rollback: `git checkout main` restores the pre-form tree; the installed
module's backup sits beside it.

## Review corrections (triple-check 2026-09-03, pass 3 — fitted re-check after the instruments build)

Trigger: `cc62ff8` built plan 5 (this plan's T6 depends on `boot-verify.sh`). One agent re-ran the
key-path staleness check (only docs commits since `276f43d5`; the two patches and the history doc
unchanged since the baseline), reproduced the tree (pristine + aquadran + combined patch `cmp`s
identical to all five live files), re-measured the `git apply --check` finding (both aquadran-context
hunks still fail on pristine, so the branched history stands), re-measured every §2 count with the
recorded greps, and confirmed the build dir, the eleven backups and the installed module's backups.
Folded: T6 in the judge's vocabulary (`VERDICT: PASS` + `GRACEFUL: yes`, exit 0); the sequencing
gate is satisfied; §2's dated-line and non-ASCII greps corrected for the five `+++` timestamp lines
and the header em dash, `dxmt_fill_view_edges` is 4 lines not 3 sites, the include count is 5 lines
of 3 headers; the T2 mutant names its pristine line (`window.c:1183`). Gaps folded: T1's baseline is
the unsigned build-dir artifact (`acbf3156…`), T2 quotes the engine's configure line and points at
`vanilla-1116/`, §1 records `git apply -p3` for the nested repo and the nine-file `aquadran` commit.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | wine-maintainer form + builder simulation (hunk-by-hunk core/glue classification, `git apply --check` vs pristine, makedep/Makefile `.git` behaviour, link flags, counts) | 1 agent, 13 tool calls | claude-fable-5-1 | `c94d9e9` | build-ready-with-fixes — mechanism sound; the linear history was the blocker (core context carried aquadran lines, measured non-applicable to stock); snap belongs in core; `set_bounds` decision resolved by measurement (delete); counts corrected; licensing wording fixed. Folded. |
| 2026-09-02 | 1b | cross-plan test-plan audit | 1 agent, 10 tool calls | claude-fable-5-1 | `310e631c` | adequate-with-fixes — base commits verified against pristine and stock+aquadran, T2 names its string and hunk, T4 a standing gate. Folded. |
| 2026-09-02 | 2 (fitted re-check of the fold) | one agent over the rewritten sections, cites re-verified against the code and the trace | 1 agent, 11 tool calls | claude-fable-5-1 | `276f43d5` | build-ready-with-fixes — relocation targets confirmed in pristine (`macdrv.h:187`, `window.c:1270`), `diff.srcPrefix`/`dstPrefix` honoured (tested live), no stale text; the z `TRACE` moved from the `.m` method to its C caller. **Cleared for build in umbrella order (after plan 5).** |
| 2026-09-03 | 3 (fitted re-check after the instruments build) | boot-verify contract (T6) · cite re-verification (pristine relocation targets, patch hunks, build dir, installed backups) · §2 counts re-measured with the recorded greps · tree reproduction (pristine + aquadran + combined `cmp` = live tree ×5) · `git apply --check` of the two aquadran-context hunks vs pristine (both fail, as claimed) | 1 agent, 12 tool calls | claude-fable-5-1 | `cc62ff8` (key paths unchanged at `a364e02`) | build-ready-with-fixes — T6 restated in boot-verify's real contract, sequencing gate satisfied; §2 greps corrected for the `+++` timestamps, the header em dash and the 4th `dxmt_fill_view_edges` line; T2 mutant given its pristine line (1183). No structural change. Folded above. |

**Key paths:** `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/` ·
`~/cs2-patch/build-1116/wine-11.16/dlls/winemac.drv/` (pristine) · `scripts/wineandaqua-dxmt.patch` ·
`scripts/winemac-crossprocess-remote-layer.patch` · `docs/winemac-crossprocess-remote-layer-history.md` ·
`scripts/boot-verify.sh` (T6)
