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

### 2b. D6 + the shimmer — ✅ HYPOTHESIS CONFIRMED, fix BUILT, verification PENDING

**T1 ran and answered it (2026-08-31).** Churn does produce visible gaps:

| | distinct frames / 40 | interior lum min | near-black frames |
|---|---|---|---|
| static control | **1** | 105 | **0** |
| 240-step churn | **35** | **0** | **2** |

And the frames are diagnostic, not just dark: Steam's **chrome renders perfectly** — menu bar, nav,
URL bar, bottom bar — with the **entire content area black**. That is the content browser's layer
un-hosted with no replacement up. Not a stretch (ruled out), not the z-order blackout (that blacks
the whole window). At churn rate during a drag, that is the shimmer.

**Fix built:** retirement is now driven from the **create** side. `retire_superseded_layers()` runs
*after* the replacement is in the layer tree and drops any older layer mirroring the same child;
`WM_MACDRV_RELEASE_REMOTE_LAYER` skips a context already retired that way. The child is therefore
never unhosted. This is a reordering, not a delay, and it subsumes the `pending_release` hack —
though that is left in place until the reordering is verified.

**VERIFIED 2026-08-31, and the honest answer is "reduced ~4x, not eliminated".** Instrument
validated live first (known-good non-wine window captured at 1.1 MB) per trap 2.

| build | samples | near-black frames | rate | interior lum min |
|---|---|---|---|---|
| pre-fix | 40 | 2 | **5.0%** | **0** |
| gap fix | 160 (4 x 40) | 2 | **1.25%** | 0 (2 of 4 trials), 43-72 (other 2) |

⚠ **The first post-fix trial showed 0/40 and I would have called it fixed.** Trials 2 and 3 each
showed 1. Repeating is what turned "fixed" into "4x better"; a single clean run of 40 at a 5% base
rate has a ~13% chance of showing zero by luck.

**The residual has the same signature** — chrome perfect, content black — so it is the same class of
gap, not a new one. Leading hypothesis, untested: `retire_superseded_layers()` matches on the **same
child HWND**. If CEF destroys a content child and creates a *different* HWND for the replacement,
nothing matches, and the old layer still goes out on `WM_MACDRV_RELEASE_REMOTE_LAYER` with no
successor — exactly the original gap, in the sub-case the fix does not cover.

⚠ One confound was **checked and falsified**: the residual frame had a dropdown menu open, which
suggested a resize-under-a-stationary-pointer might be triggering hovers and creating popup layers.
Measured — the pointer was outside the window entirely. The menu was left open from earlier
interaction. Not a confound.

**Superseded note (verification was pending at the time of writing):** The screen
locked mid-session (`CGSSessionScreenIsLocked: True`); `screencapture -l` then fails for *every*
window including a known-good non-wine one, while full-screen capture returns a 43 KB lock frame.
That is trap #2 in `steam-render-cell.sh`, and it is why the harness validates against a known-good
window before believing any black reading. **Re-run T1 with the screen awake before claiming the
shimmer is fixed.**

### 2b-original. D6 + the shimmer — one lifetime design, not two fixes

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
| T1 | **Does churn actually cause the shimmer?** ⚠ **first attempt 2026-08-31 was VOID** — the churn was driven at HWND `6012A`, not the top-level Steam window, so nothing resized; 30 captures came back byte-identical in both the churn and control runs and I nearly blamed `screencapture` caching for my own targeting error. Re-run selecting the top-level by class `SDL_app`, and **assert the window size actually changed** before scoring a single frame. | Drive N resize steps; count `HOST create`/`remove` from the trace; capture *during* the drag, not after — a post-settle capture cannot see it (that is why this is still open). Compare a slow drag (few recreations) against a fast one (many). | shimmer severity tracks recreation count | n/a — this is an experiment, not a regression test |
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

## 6. Design guidance taken from wine's own source

Read out of `winemac.drv` while working in it. These are not style preferences — each is a pattern
the codebase already uses, and in four cases the bug we hit was a *departure* from it.

| pattern in wine | what it buys | how we broke it |
|---|---|---|
| **`struct window_rects` keeps `window` / `client` / `visible` as three separate rects** rather than deriving one from another | the three coordinate truths stay independently checkable, so a disagreement between them is *visible* instead of averaged away | the decoration bug (R4) exists precisely because `get_cocoa_window_features` consults two of the three and never `client` — the evidence was sitting there unused |
| **`cgrect_mac_from_win` / `cgrect_win_from_mac` as a named pair**, converting at the boundary | the Win32-pixels ↔ Cocoa-points boundary is explicit and greppable | the 1px seam was one entry point that never called it. Name your coordinate spaces and convert at **every** edge, not most |
| **`C_ASSERT` on `macdrv_functions_t`'s size** | an ABI invariant the compiler enforces, not a comment someone must read | this one we *followed* — it is why we exported a standalone symbol instead of adding a struct member |
| **`FIXME` naming the exact case**: *"Cross-process child window Metal swapchains are not implemented"* | a greppable statement of a known gap. This is the only reason the route was findable at all | — a TODO saying "fix this" would have cost us days |
| **`TRACE` / `ERR` / `FIXME` channels rather than `fprintf`** | output that can be filtered per-subsystem at runtime | we used `fprintf` for diagnostics. Justified (a `WINEDEBUG=-all` swallowed our `ERR`s and produced a wrong conclusion) but it is a departure, and the diagnostics are now compiled out by default |
| **`OnMainThread` / `OnMainThreadAsync` wrappers** | thread affinity expressed structurally, so you cannot forget it | followed throughout |
| **`get_cocoa_window_features` already carries an evidence-based override** (`EqualRect(window, visible)`) on top of the style heuristic | wine's authors knew style bits were insufficient and added a rect check rather than documenting the limitation | the lesson is that they only did it **halfway** — one rect comparison, not the one that mattered. A heuristic with a partial escape hatch is more dangerous than one with none, because it looks handled |

**The transferable rule from the last row**, and it is the one worth keeping: *when you know a
heuristic is incomplete, the escape hatch must be driven by the evidence that actually decides the
case* — not by whichever adjacent value was convenient. Half an override reads as a solved problem.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | not yet checked | — | — | — | — | — |

**Key paths:** `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/{window.c,cocoa_window.m,macdrv_main.c}` ·
`scripts/winemac-crossprocess-remote-layer.patch` · `scripts/win-resize-driver.c` · `scripts/pixel-probe.swift`
