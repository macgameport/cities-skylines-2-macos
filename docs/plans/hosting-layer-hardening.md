# Hosting-layer hardening — fix what the diagnosis build got away with

> **Status: DRAFT — not yet checked. Run `check it` before the first commit of any Phase 2 work.**
> Phase 1 is mechanical and does not need the gate; Phase 2 does and must not start without it.

**Scope:** the cross-process `CALayerHost` code in `winemac.drv` that this project added on
2026-08-31 (`scripts/winemac-crossprocess-remote-layer.patch`). It works — Steam's client renders
out-of-process with 0 GPU crashes — but it was optimised for **finding the bug**, not for shipping,
and a re-read on 2026-08-31 found six defects. This plan fixes them.

**Not in scope:** the DXMT-side `dlsym` fallback (6 lines, no defects found), and anything upstream.

---

## 0. The defects, as re-read from the source

Each was found by reading the code back, not by a failure. Numbered so the test plan can cite them.

| # | defect | where | severity |
|---|---|---|---|
| D1 | **Quadratic z-order lookup on the hot path.** `dxmt_paint_zpos()` walks the *entire* window tree from the root, and is called **inside** the per-layer loop in `update_remote_layer_frames()` — so every `WindowPosChanged` costs `layers × full_tree_walk`, each node an `NtUserGetWindowRelative` syscall. Fires continuously during a drag. | `window.c` | **highest** — it is on the path where James reports a shimmer |
| D2 | **Silent truncation.** `HWND kids[64]` and `depth > 8`, neither logged. Exceed either and layers silently get z-order 0. | `window.c` `paint_index_walk()` | high |
| D3 | **Ambiguous sentinel.** `dxmt_paint_zpos()` returns `0.0` for "not found" *and* as a legitimate bottom position — failure is indistinguishable from success. | `window.c` | high |
| D4 | **Magic thresholds.** `dxmt_fill_view_edges()` hardcodes `1.0` point. The real quantity is **one device pixel** = `0.5` pt on retina, `1.0` pt otherwise. Correct only for the case it was tested on. | `cocoa_window.m` | medium |
| D5 | **Timing guess + aliasing hole.** The background is deferred `120 ms` (a guess), and the block re-looks-up `cid`, so a remove+create of the same context inside the window paints the wrong layer. | `cocoa_window.m` | medium |
| D6 | **`pending_release` is one global slot**, not per-window lifetime. A delay, not a design. | `macdrv_main.c` | medium |

Deliberately excluded: the vendor-named `dxmt_acquire_remote_layer` export. It is wrong for
upstream (winemac should not know DXMT exists) but it is *correct here*, and the ABI reasoning that
produced it still holds. Changing it buys this port nothing.

---

## 1. Phase 1 — mechanical (no design question, no gate)

Each is a local change with an obvious right answer. **These do not need `check it`.**

- **D2/D3 together.** Give `paint_index_walk()` a `truncated` out-param; `ERR()` once when either
  bound trips. Change `dxmt_paint_zpos()` to return `BOOL` with the index by out-param, so callers
  can leave `zPosition` untouched on failure rather than slamming it to the bottom.
- **D4.** Derive the threshold: `const CGFloat px = retina_on ? 0.5 : 1.0;` and use `px` in all four
  comparisons. Behaviour on retina is unchanged (the current `1.0` is merely loose); non-retina stops
  snapping rects that are a whole point away from the edge.
- **D5 (aliasing half only).** Capture the `CALayerHost*` and compare identity on fire, instead of
  re-looking-up `cid`. The 120 ms itself stays until Phase 2 decides whether it can go.

## 2. Phase 2 — design (needs `check it` before the first commit)

These interact, which is exactly why they need a plan rather than three separate patches.

### 2a. D1 — compute the paint order once per update

Build the whole `HWND → index` map in one tree walk at the top of `update_remote_layer_frames()`,
then look each child up. Also called from `WM_MACDRV_CREATE_REMOTE_LAYER`, which handles **one**
child — there the single walk is already optimal, so the map must be constructible for both callers
without forcing the create path to build a map it does not need.

**Open question for the check:** where does the map live? A stack array is bounded (see D2); a
`CFDictionary` allocates on a path that fires per-frame during a drag. Leaning stack-with-a-logged-
bound, but a reviewer should push on it.

### 2b. D6 + the shimmer — one lifetime design, not two fixes

`pending_release` and the shimmer are the same problem seen twice: **a hosted layer is un-hosted
before its replacement is live.** The candidate design is "hold the retired host until its
replacement is confirmed hosted", which subsumes the deferred-by-one hack and, if the churn
hypothesis is right, removes the shimmer.

> ⚠ **This rests on an UNTESTED hypothesis and must not be built on until it is measured.**
> Measured so far: the shimmer is **not** the compositor stretching our layers (instrumented scale
> check, **0** stretch events; and the only path that could stretch one is dead code — C16). What the
> trace *does* show is churn: **24 scripted resize steps → 101 `HOST create` / 83 `HOST remove`**.
> That is consistent with the gap theory and does not establish it.
>
> **Phase 2b therefore starts with an experiment, not an implementation** — see §3 T1. If T1 fails to
> reproduce the shimmer from churn, this whole sub-phase is void and the fix would be aimed at the
> wrong mechanism. `check it` verifies a plan against the *codebase*; it cannot tell me a hypothesis
> about the *compositor* is false. Only T1 can.

---

## 3. Test plan

Instruments exist and are committed: `scripts/win-resize-driver.c` (exact sizes, per-monitor DPI
aware, `tree`, `rects`, `cursor`, `close`) and `scripts/pixel-probe.swift` (edge-vs-interior RGB).
Rebuild `winemac.drv` with `-DDXMT_RSZ_DEBUG` for the trace.

| # | test | method | pass | mutant (must be observed RED, then restored green) |
|---|---|---|---|---|
| T1 | **Does churn actually cause the shimmer?** | Drive N resize steps; count `HOST create`/`remove` from the trace; capture *during* the drag, not after — a post-settle capture cannot see it (that is why this is still open). Compare a slow drag (few recreations) against a fast one (many). | shimmer severity tracks recreation count | n/a — this is an experiment, not a regression test |
| T2 | z-order still correct after the D1 restructure | `tree` dump + trace `stack:` line | `0x2011E → z2`, `0x10140 → z5`, independent of creation order | force the map lookup to return a constant → blackout returns |
| T3 | blackout does not regress | `2400x1500 → 2399x1499 → 2400x1500` | interior luminance stays >40 throughout (was 82 → 1 → 0 broken, 63 → 63 → 113 fixed) | revert the z-order assignment → luminance collapses |
| T4 | seam does not regress, both retina states | all four parities × retina on/off | 0 bright edges | set `px = 0.0` → seam returns on the odd axis |
| T5 | popups still render | `steam://open/friends`, `steam://open/settings`, menu bar sweep | Friends List >200 KB, interior lum >20 | re-gate the un-hide on frame-changed → Friends List goes black (the exact C15 regression) |
| T6 | navigation blackout does not regress | store → library → friends → downloads → library → store | all six render, 0 GPU crashes | restore the two-way `CGRectIsEmpty` test → Library goes black |
| T7 | **game still boots** — winemac is on the boot path | run the shortcut | `MainMenu reached`, mods load, 0 `InvalidProgramException` | n/a |
| T8 | no new per-frame allocation on the drag path | trace/instrument the resize path | no allocation inside `update_remote_layer_frames` | n/a |

## 4. Rollback

Every winemac change is one file swap: `winemac.so.bak-*` sit beside the installed module, and
`1a7225cec348f44c` is the current boot-verified build. Source backups `*.pre-*` in the wine tree.
Rebuild is `gmake dlls/winemac.drv/winemac.so` in `~/cs2-patch/build-1116/wine-1116-vis-build`,
then `cp` + `codesign -f -s -` **under the real basename** (the ad-hoc signature identifier is
derived from the filename — signing a copy elsewhere yields a different sha and a false mismatch).

## 5. Exit criteria

1. D1–D6 each closed or explicitly deferred with a reason recorded here.
2. T2–T7 green, every listed mutant **applied to real source and observed red**, then restored.
3. T1 answered either way — and if it falsifies the churn hypothesis, §2b is struck and the shimmer
   returns to the open list rather than being quietly declared fixed.
4. Game boot-verified on the final binary, judged by a `SceneFlow.log` timestamp that postdates the
   install.
5. `python3 scripts/check-experiments.py` exit 0; any claim that moves gets a register row.
6. No silent caps anywhere in the new code — every bound logs when it trips.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | not yet checked | — | — | — | — | — |

**Key paths:** `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/{window.c,cocoa_window.m,macdrv_main.c}` ·
`scripts/winemac-crossprocess-remote-layer.patch` · `scripts/win-resize-driver.c` · `scripts/pixel-probe.swift`
