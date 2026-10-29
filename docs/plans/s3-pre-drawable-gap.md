# The S3 pre-drawable gap — the child's own layer before its first drawable

**Status: check-it'd 2026-10-29 — build-ready-with-fixes for S2a, S2b, S2c, S3 (Studio), S3-T,
S6a, S6b, the § 6 preamble, § 4.1 (9)–(10) and § 7 (pass 4, a fitted re-check of pass 3's fold;
corrections folded, § Review corrections pass 4).** ⚠ **§ 4.1 (9) needs James's decision before
S2c, S3 or S6.** Pass 3: check-it'd 2026-10-27 — build-ready-with-fixes for S2a, S2b, S2c, S3
(Studio), S6b and the § 6 preamble; needs-rework for S3-T and S6a, reworked in place. Pass 2: check-it'd 2026-10-10
— needs-rework for S3 + S6, build-ready-with-fixes for S7 + T3 (the move to the Mac Studio — 60 Hz
2× display, macOS 27; § Review corrections pass 2); S3 + S6 were reworked 2026-10-27 (§ Rework
2026-10-27) and pass 3 checked that rework. Pass 1:
Triple-checked 2026-09-07 — build-ready-with-fixes (pass 1 needs-rework on the test plan,
reworked in place; the fitted re-check the same day built D and found no blocker; all corrections
folded — see § Review corrections and § Review log). Build order: § 6 instruments → S1a → S0 → the
§ 7 decision rule → D.** Tracker:
[issue #13](https://github.com/macgameport/cities-skylines-2-macos/issues/13); the observation it
splits from is [#12](https://github.com/macgameport/cities-skylines-2-macos/issues/12); umbrella
[#1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: cs2 `3515efc`;
nested winemac `main` = `52789ff`, `core` = `63a0cec`, `aquadran` = `fe281fe`; pristine winehq tree
`~/cs2-patch/build-1116/wine-11.16/`; DXMT fork `~/cs2-patch/dxmt-fork/`; installed daily driver =
stage 1 `2a251a4b2510fb84`. Line numbers are against nested `main` and name their file; unqualified
`:N` is `cocoa_window.m`; `pristine :N` is the winehq 11.16 tarball's copy.

> **🔧 As-built (2026-09-07): PARTIAL — § 6's instruments BUILT and **S1a RUN**; no candidate is.**
> **S1a result (ledger C62, 2,924 generations over 10 valid rows, clock gate PASS on all 10):
> (ii) detach follows present in 1,440 of 1,442 successions = 99.9 %, so § 7.2 resolves to BUILD D.
> (i) the null is REFUTED — 0 of 2,924 present within one refresh of the owner's commit; the
> displaying child's median is ~53 ms.**
> **S0's mechanism question is ANSWERED (ledger C63): A `--drop` is SOUND — an opaque CAMetalLayer
> with no background that has never presented composites as NOTHING through a `CALayerHost`,
> cross-process. So A is not inert and the `opaque = NO` fallback is not needed.** Measured with a
> new direct probe (`scripts/calayerhost-probe.m`) rather than inferred from the drag battery; the
> plan's in-situ S0 arm was called **VOID** (C64) — **and that verdict is itself RETRACTED
> 2026-09-08 (C65): the page was never the problem, the SCORER was.** The battery counts an
> episode at `fraction > 0`, and the median cyan frame among those 542 carries **one pixel**,
> present in nearly every frame of every run; 542 against 543 compared a stray pixel with itself.
> Re-scored by SIZE — `scripts/full-client-episodes.py`, a colour covering ≥ 0.80 × the window's
> initial area — **the two arms separate completely: A-drop shows cyan 2 / blue 0 / black 0, the
> mutant shows blue 4 / cyan 0 / black 0**, over the same 24 recordings. The regions coincide to
> within 4 px of 671,658. **So S0 in situ is ANSWERED, outcome 1, and `black = 0` on the A arm
> refutes "A-drop is inert" through the real pipeline as well as on the bench. S4 is answered by
> the same re-scoring: A alone RELOCATES the flash, it does not remove it.**
> **D is BUILT (2026-09-07): module `4975a8c9a720773f`, nested branch `d` at `72184cd`, compiles
> clean, NOT installed and NOT merged to `main`.** It starts from the re-check's `d-sim` `b2186a0`
> and adds the two things § 4.1 required that the simulation left out — see § 4.1's build note.
> `build-winemac.sh` gained the `WINEMAC_BRANCH` knob § 8 asked for, so a candidate never has to
> land on `main` to be built. **Owed before D can be judged: S3 · S6 · S7 · T3** (S4 is answered — C65).
> Commit: this one. Nothing was installed; the daily driver is still stage 1 `2a251a4b2510fb84`
> and the nested tree is back on `main` `52789ff`, clean. Build order position: *instruments → S1a
> → S0 → § 7 decision rule → D* is complete end to end — every step above has been taken.
> Modules built, none installed: the S1a stamp+colours build `28d40ea5d38a180c` (at
> `~/cs2-patch/winemac.so.s1a-stamp-diag`), the `--cyan` reconstruction `e700ac8fdfef0e80`, the
> `--norelease` mutant `cf200bbf146ff56f`. The first stamp build `5bfb1f07ce0d7598` is superseded
> and must not be used — see the `presentedTime` note below.
> **Four deviations from the plan, all recorded in § 6:** (a) S1a's "one clock" needed a mechanism
> the plan did not specify — the Cocoa side's `ERR()` carries no `+timestamp`, so the stamp prints
> `NtGetTickCount()` itself through a hand-declared `ms_abi` prototype, gated by a new
> `align-trace-video.py --check-clock` (PASS on all 10 rows); (b) C42's module is **not
> byte-reproducible** and instrument (4) is a reconstruction, not a reproduction; (c)
> **`presentedTime` is 0 for a drawable that was never displayed**, and the first stamp build read
> that as a timestamp — 175 of 234 FIRST drawables came back 0, so the instrument now attaches
> handlers until one really presents (GOTCHAS 2026-09-07); (d) S1a ran in **window capture**
> (`CAPMODE=window`), because its signal is in the trace and the trial video row was voided by a
> window overlapping Steam. **S1b still needs a video run with a clear screen.**
> **Verify against:** `scripts/first-drawable-stamp-patch.py` · `scripts/align-trace-video.py` ·
> `scripts/live-hosts.py` · `scripts/video-blue.swift` · `scripts/diag-colours-patch.py` ·
> `scripts/drag-session.sh` · `scripts/strip-module-ab.sh` · `scripts/video-gap-battery.sh` ·
> `scripts/full-client-episodes.py`.
>
> **🔧 As-built addendum (2026-09-08): the scoring gate, and D's diag builds.** The plan's § 6
> preconditions asked for a shape gate "declared before the run"; it is now a committed instrument
> with its bar swept and published rather than a sentence — `full-client-episodes.py`, BAR = 0.80 ×
> the window's initial area, flat over 0.65–0.92 across 24 runs. It replaces the battery's
> `fraction > 0` tally for every decision, and the battery calls it per arm. `video-gap-battery.sh`
> gained `MODS`, which runs several modules **interleaved** — the plan requires interleaved arms and
> C64's two were 100 minutes apart. `diag-colours-patch.py` gained a second exact anchor per colour
> for branch `d` (which re-indented the magenta block and deleted the line blue recolours), via
> `sub_any`: exactly one anchor must match exactly once, so a file the patcher does not understand
> still refuses loudly. Proven byte-identical on `main` across all five recipes. Modules built on
> branch `d`, **neither installed**: **D-diag `6385a7ffb1cbb408`** (`--noblue --cyan`) and
> **D-mutant-blue `cf9a904f283e55e0`** (S3's mutant (a) — the dropped background restored, in blue).
>
> **▶ S3 + S4 RUN 2026-09-08, 10 of 15 planned rounds (C66/C67), stopped by hand — the machine was
> needed, and an unwatched video battery voids its own rows.** Interleaved D-diag against A-alone.
> **D: 0 full-client episodes in 10 valid runs. A alone: 4 in 4 of 10.** That is suggestive at
> p = 0.018–0.043 and it is **NOT the closure bar**, which needs n ≥ 15 for P(0) = 0.0067
> (the M3 Max-era Poisson bar, kept as C66's record; superseded by § 6 S3 (Studio) — pass 4).
> ~~Five more rounds finish it … and pool~~ — **SUPERSEDED 2026-10-10 (pass 2):** those 10 rounds
> ran on the M3 Max at **120 Hz, 1×**; the machine is now a Mac Studio at **60 Hz, 2×**, which moves
> both the detection probability of a one-refresh flash (C58's correction) and the scorer's pixel
> scale. C66 stands as the **prior-machine stratum**; the remaining work is a **fresh interleaved
> ~~n ≥ 15~~ battery on the Studio** with its own A-alone control — see § 6 S3 (Studio), which
> stops at 8 hit rows, not at a run count (pass 3).
> **S7's bound is met in passing** (max 2 over 1,611 creates, dwell 99.7 % against A's 0.0 %) and D
> also takes `retired-but-never-released` from 140 to 0, at the cost of roughly doubling the
> resident host count. **Owed (re-stated 2026-10-10): a fresh Studio S3 battery (after the scale fix +
> an S2 gate) · S3 mutant (a) observed red · S6 (blocked on capture) · S7's terminal case +
> `--norelease` on branch `d` + boot-verify on D · T3.** The daily driver was verified back at stage 1 `2a251a4b2510fb84`
> after the last row. ⚠ **Re-stated again 2026-10-27 (the rework):** the scale fix, the 2× measurement
> and the rect clamp are DONE (`c280a39`, `bf6b611`) and S6's capture works (`ebfcce7`). Owed now:
> § 4.1 (9) decided (and built, if adopted) · § 6's S2a → S2b → S2c → S3 (or S3-T) · S6a + S6b · S7's
> tail · T3. **Pass 3 (same day) puts one item first: pass 4, a fitted re-check of pass 3's fold** — **run
2026-10-29: build-ready-with-fixes, folded; § 4.1 (9)'s decision is now the first item.**

> ⚠ **This document REDIRECTS issue #13's stated direction.** #13 proposed deferring
> `retire_superseded_layers`. § 2.3 shows that cannot work on its own — the new generation sits
> *above* its predecessor — but § 2.5 measures a window in which a companion form of it can. Read
> § 2 before § 4.

## 1. What is already established (do not re-derive)

| | |
|---|---|
| **C55** | The one-frame black full-client host occurs on the pre-stage-1 baseline `cd79fc463795939f`. **Architectural — neither stage introduced it.** |
| **C56** | Its surface is **S3, the child's own offscreen layer before its first drawable** (`Tblue=100 %` on the diag build). Blue is a positively rendered colour, so it is a **real display gap, not a capture artifact**. C56 also establishes that the remote layer's *background* composites through the host before any drawable exists. |
| **C58** | **A single captured frame** in every episode — 4 episodes in 12 valid runs, covering 13–53 % of the recorded area. ⚠ Read with its sampler: `screencapture -v` at a 16.7–25 ms cadence on the **120 Hz** main display (`system_profiler`: 1920×1080 @ 120 Hz; the ledger's "1–2 frames at 60 Hz" is corrected 2026-09-07). One sample bounds the flash **below two intervals (< 50 ms, 1–5 refreshes)**, not ≤ 25 ms, and a periodic sampler catches a one-refresh (8.3 ms) flash with p ≈ ⅓ — so **0.3 per drag is a lower bound** on the rate. |
| **C13** | Hosted layers stack in creation order — the OBSERVED half of § 2.3's z-order argument. |

⚠ **What is NOT established, and was mis-stated in this document's first draft:** the figure
"2331 intervals, median 127 ms, 35.9 s of a 35.4 s drag" is **the swapchain re-create cadence**,
not an exposure — `scripts/layer-gap.py`'s own header says so ("127 ms is simply the 120 ms step
period … Do not quote it as a gap duration"). **The per-generation pre-drawable duration — create
to first drawable — has never been measured**, and no wine-side trace stamps a first drawable (0
hits for `nextDrawable`/`first drawable` in `window.c`, `cocoa_window.m`, `macdrv.h`). S1a
measures it first, on an instrument-only build.

## 2. The mechanism, read from source (2026-09-07)

### 2.1 Which layer S3 is, and whose code it is

`scripts/diag-colours-patch.py:64-71` paints blue onto `offscreen_layer.backgroundColor` and says
in situ that it "Runs in the GPU process." That layer is `CAContextSwapChain`'s, `:4303`,
constructed at `:4327-4342`:

```objc
offscreen_layer = [[CAMetalLayer alloc] init];          /* :4327 */
offscreen_layer.framebufferOnly = YES;                  /* :4337 */
offscreen_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);   /* :4339 */
```

**The black is set unconditionally at construction, before any drawable exists.** On a production
build that black is exactly what a user sees in the gap; the diag build only recolours it.

⚠ **Wine's construction block is not what runs.** DXMT rewrites the layer's properties after wine
hands it over (`dxmt_presenter.cpp:16-21` → `winemetal_unix.c:1517-1529`, `_MetalLayer_setProps`):
`opaque = YES`, **`framebufferOnly = NO`** ("setting it true results in worse performance"),
`contentsScale`, `displaySyncEnabled`, and an explicit `drawableSize` (applied at
`winemetal_unix.c:1527` from the presenter's props) — wine never sets `drawableSize` (0 hits, nested
and pristine). `CAMetalLayer.opaque` defaults to YES anyway (SDK
`CAMetalLayer.h`, "The default value of the `opaque' property for CAMetalLayer instances is
true"). After the first present the background is invisible because the layer is opaque and
`contentsGravity` (default `resize`) stretches the drawable to the bounds, which are fixed at
construction (`:4341`) — not because of `framebufferOnly`. **The same black line exists on the
in-process path at `:1257`** (`WineMetalView`, pristine `:1039`); any upstream text must say why
only `:4339` changes ⚠ That path has no covering either: its view is created hidden
(`window.c:1280`) and unhidden by a one-shot `.present` **at creation** (`:1285`), before any
drawable — so whether it flashes too is a real question for the upstream text, not an answered one
(the first fold of this paragraph claimed a hide-until-present; it was wrong).

**It is upstream wine's code.** The line is at `pristine :4119` in the untouched winehq 11.16
tarball, inside a `CAContextSwapChain` that is also pristine (`pristine :4080`), created from
`pristine window.c:1188`. So is the **host** side: `CALayerHost` (12 references),
`addCALayerHostViewWithContextId` (`pristine :725`), `macdrv_create_remote_layer` and
`WM_MACDRV_CREATE_REMOTE_LAYER` are all upstream, and pristine already keeps N hosts per window in
a dictionary (`pristine :396`, `:725-740`). What this project added is the cross-process plumbing
on top: the `child:` parameter, `remote_layer_children`, `retire_superseded_layers`, per-child
frames and zPosition, and the 120 ms deferred host background. **Consequently the S3 flash exists
in stock wine for any recreated CAContext-hosted swapchain**, and a change at `:4339` is a change
to wine core — § 5.

### 2.2 The publish happens strictly before the first present — and the commit later still

Still inside the same initialiser, immediately after the layer is built (`:4344-4359`):

```objc
OnMainThread(^{
    remote_context = [[CAContext contextWithCGSConnection:CGSMainConnectionID() ...] retain];
    [remote_context setLayer:offscreen_layer];
    context_id = [remote_context contextId];
});
...
macdrv_create_remote_layer(hwnd, child_hwnd, context_id);   /* :4359 */
```

`macdrv_create_remote_layer` is `NtUserPostMessage(WM_MACDRV_CREATE_REMOTE_LAYER, ...)`
(`window.c:1793-1798`). **The child advertises the context to the owner at construction — before
DXMT has rendered anything into it.** Every hosted generation therefore begins life as a black
rectangle of the correct size.

`OnMainThread` is synchronous for the *block* (`cocoa_event.m:486-540`, `kevent` loop or semaphore wait),
not for the *commit*: `setLayer:` is an implicit-transaction change, committed at the child's next
main-run-loop iteration (`CATransaction.h`) — after `:4359` has posted. And the first drawable
presents **asynchronously to any commit**: `presentsWithTransaction` is never set (0 hits), so
CAMetalLayer's default applies ("changes to the layer's render buffer appear on-screen
asynchronously to normal layer updates"). **The black is visible from the later of the child's
commit and the owner's `addSublayer` commit (`:890`), until the first drawable lands.** That is
the race's mechanism, and it is why S1a's anchor is the owner's handler (`window.c:1717`), not the
child's post.

### 2.3 Why the predecessor cannot be the covering — and why #13's deferral cannot work alone

The owner handles the posted message at `window.c:1710-1766`: it adds the new host
(`macdrv_window_create_ca_layer_host_view` → `addCALayerHostViewWithContextId`, `:832`, which
`addSublayer`s it at `:890`), sets its zPosition **when `have_z`** (`window.c:1747-1750`,
`:4428-4429`, same main-thread block as the add, `:4416-4430`), and **only then** calls
`retire_superseded_layers` (`window.c:1761`), which releases every other host mirroring the same
child. Retire-at-create is deliberate; its rationale is on the function at `window.c:943-945`.

**But the new generation is on top of the old one.** `paint_order_zpos` (`window.c:130-137`) keys
zPosition on the child **hwnd**, so two generations of one child share one zPosition, and Core
Animation draws equal-zPosition siblings in sublayer order — `addSublayer` appends. **DOCUMENTED:**
Core Animation Programming Guide § *Building a Layer Hierarchy* — `addSublayer:` "causes the
sublayer to appear on top of any siblings with the same value in their zPosition property";
`CALayer.h` (`sublayers` "listed in back to front order"). **OBSERVED:** C13. The comment at
`:940-942` describes exactly this. And C56 measured that the remote layer's background composites
through the host before the first drawable. So **from the owner's first commit of the new host,
its black covers the child rect whether or not the predecessor is still in the tree** — the
predecessor is underneath.

⚠ **The one ordering that inverts this:** when `have_z` is FALSE for the new generation (paint
order truncated — `PAINT_ORDER_DEPTH` = 32, `window.c:46`, checked at `:97-100` — or OOM), it keeps CALayer's default
zPosition 0.0 and "sorts below every ordered one" (`window.c:128-129`). Today that cannot matter,
because the predecessor is retired in the same handler; under any hold it would put stale content
*over* live content for a whole step. **D falls back to keep-one whenever `have_z` is FALSE.**

Two consequences:

1. **The first draft named the predecessor as what covers the gap; that was wrong**, and
   **#13's proposal — defer the retire until the replacement presents — cannot cover anything by
   itself.** A held predecessor sits beneath an opaque black layer. B (§ 4) is dead as a
   standalone candidate.
2. **What keeps the gap rare has a simpler null hypothesis than any covering agent: the gap is
   rare because it is short.** If the child's first present typically lands within one display
   refresh (8.3 ms) of the owner's commit, nothing needs to cover it, and the ~0.3+/drag episodes
   are the tail where the first drawable is late. C58's own numbers already point there: ~300
   creates per drag × 12 drags → 4 captures, p ≈ 10⁻³ per generation at a sampler that would
   catch a one-refresh flash a third of the time. Consistent with every episode being one captured
   frame (1–5 refreshes) and with § 1's correction (the duration is unmeasured). **S1a measures it
   before any candidate is chosen.**

### 2.4 The in-tree precedent — project-authored, absent upstream

The **owner** side of *this project's* tree already hit this and fixed it: from
`addCALayerHostViewWithContextId`, `:847-861`:

```objc
/* The background covers what the snap below cannot -- an odd Win32 rect in a whole-point
 * slot leaves a sliver uncovered, showing white. Deferred because backgroundColor paints
 * the whole layer, which is visible from the moment it is added, so doing it at creation
 * flashes black on every new layer; transparent until only the seam is left to reveal. */
```

— then a 120 ms `dispatch_after` that paints the background only if that same layer is still the
one registered for the id. **The child side (`:4339`) does at construction precisely what the
owner side deliberately stopped doing, for the reason its own comment gives.** ⚠ The precedent is
**ours, not upstream's**: `pristine :725-740` sets no host background at all and has no
`dispatch_after`. To a wine maintainer this precedent does not exist in their tree; the argument
to them is § 2.1's (on an opaque layer whose contents are only ever presented drawables, the
background is visible only before the first one).

⚠ **And the same 120 ms paint is a ceiling on any hold (§ 4 D).** It paints the **new** host's
background black at +120 ms while that host is registered — and the new host sits *above* a held
predecessor (§ 2.3). Unless the deferred paint is gated on "no other host registered for this
child", a hold covers only `min(window, 120 ms)`, and the late-drawable tail is exactly where that
cap bites. Found independently by two lenses.

### 2.5 The signal-free window: the child creates the new swapchain BEFORE destroying the old

Measured 2026-09-07 from the trace already on disk (`~/cs2-patch/strip-ab/20260906-140732/`
`…-r1-baseline/stdout.txt`, one full-coverage drag, baseline module), pairing every
`retiring superseded layer ctx O … (replaced by N)` (`window.c:964`) with
`WM_MACDRV_CREATE_REMOTE_LAYER … N` (`:1717`) and `WM_MACDRV_RELEASE_REMOTE_LAYER context_id O`
(`:1770`); **re-run independently by the correctness lens with identical results**, and on the
stage-1 row of the same battery:

| | baseline r1 | stage-1 r1 |
|---|---|---|
| creates / retires / releases | 300 / 285 / 271 | 277 / 262 / 248 |
| `RELEASE(old)` **after** `CREATE(new)` | **271 of 271** (0 before) | **248 of 248** |
| `RELEASE(old) − CREATE(new)` | min **33 ms** · p10 106 · median **126** · p90 491 · max 58 561 (a C60 stall) | min 92 · p10 108 · median 130 · p90 774 · max 60 998 |
| `RELEASE(old)` arriving after its own retire (handler skips as untracked) | 271 of 271 | 248 of 248 |
| predecessors that never received a RELEASE | 14 | 14 |

So: **the child keeps the old context alive after creating its replacement — never the other way
round in 519 generations — and today the owner discards that live, fully-drawn predecessor at the
replacement's create.** That is a window in which a *transparent* new generation over a *held*
predecessor would show the last real frame with no signal from anyone.

⚠ **Two bounds on what that window is worth.** (a) The numbers are owner-handler times: the child
posts RELEASE (`:4370`) and then tears the context down **asynchronously** on its main thread
(`:4375-4380`, `setLayer:nil`/release), so the last frame is guaranteed only until the child's own
detach — RELEASE at the owner is an *upper* bound on the hold, and what a `CALayerHost` shows for a
detached context is unmeasured. (b) The owner's 120 ms host paint (§ 2.4) caps it unless gated.
The 14 never-released predecessors are the leak class the 2026-08-31 fix and C29 bounded
(`EXPERIMENTS.md` § LEAK FIXED; `GOTCHAS.md` § *A "hold until the next event for the same key"
cache leaks when the key never fires again*), so any hold must keep that bound (§ 4, D's exits).

**Inferred, not measured:** whether the child detaches the old context *after* the new one's
first drawable (the sane resize ordering — D closes the gap) or before it (D narrows it by the
window above and no more). S1a (ii) measures it in one clock.

## 3. Why #7's candidates do not reach this

Unchanged from #13, restated so this doc stands alone: #7's three candidates all target the **host**
background — the area a stale or reframed host fails to cover. S3 is a different surface. The host
is fine; the child's own layer is the thing with no content. #7 candidate 1 changes the gap's
colour, not its existence; candidate 3 moves black between host and content view; stage 2 is ruled
out on other grounds (C54).

## 4. Candidates

| | candidate | cost | what it does not do / what is unknown |
|---|---|---|---|
| **A** | **Remove the child's black background** (`:4339`) — *drop* (principled: on an opaque layer whose contents are only presented drawables, the background is visible only pre-drawable) or *defer* on the § 2.4 timer pattern (conservative). The form is fixed by S0 before S3 | one line (drop) or ~10 (defer); wine core; any diag build of a source that drops the line needs `diag-colours-patch.py --noblue` or the patcher fails | **Whether an `opaque=YES` `CAMetalLayer` with no background and no drawable composites as nothing through a `CALayerHost` is undocumented and unmeasured** (every cell so far ran black or blue). If it composites as an opaque fill, A-drop is inert and S3's mutant can never be red — **S0 decides before anything is built on A.** If inert, the only fallback is `opaque = NO` *deferred* on the § 2.4 pattern (steady-state `opaque = NO` would blend every presented frame's alpha < 1 pixels and is out of scope). If transparent, A *alone* shows whatever is beneath: the content view's own layer, **black in production** (`:1257`; cyan only on C42's build) — so A alone most likely turns a black flash into a black flash from a different surface, which is what S4 measures |
| **B** | Defer the retire (#13's direction) | — | **Cannot work alone** — § 2.3. Retained only as the second half of D |
| **C** | Publish after the first present — move `macdrv_create_remote_layer` (`:4359`) to the child's first drawable | removes the race at its source | **Wine has no first-present signal on this path.** `macdrv_client_surface_present` (`window.c:1243-1258`) is wine's generic `client_surface` `.present` callback — it toggles which `cocoa_view` is unhidden and carries no drawable. **A hook precedent exists in the DXMT glue, not pristine:** `WineMetalLayer.nextDrawable` (`dxmt_objc.m:38-72`) posts `CLIENT_SURFACE_PRESENTED` (→ `event.c:399` → `macdrv_main.c:910-915`) — but only when the layer's delegate is a `WineMetalView` (`dxmt_objc.m:50-54`), which `offscreen_layer` (a plain `CAMetalLayer`, `:4327`) never has, and it is instantiated only for the in-process view (`:1253`). C needs its own subclass; DXMT acquires through the layer object wine hands it (`winemetal_unix.c:1496-1498`, `[layer nextDrawable]`), so a subclass is reached. It fires at *acquire*, a lower bound on present; `addPresentedHandler:` on the returned drawable gives `presentedTime` (public, `MTLDrawable.h`) |
| **D** | **A + a one-generation hold.** Remove the black, and hold each child's *previous* generation until the earliest of its four exits | see § 4.1 — **not** "one function": four files, +140/−37 as built by the re-check (nested branch `d-sim` `b2186a0`, compiles clean, digest `8ff5e4f30492304b`, **not installed, not merged**) | Closes the gap only while the child keeps the old context attached after the new one's create (§ 2.5 (a)) and only until the 120 ms host paint unless gated (§ 2.4). Whether that spans the first present is S1a (ii). In the *grown* region of a resize there is no predecessor content; that is #7's strip, not this. On a *shrink* the held predecessor is larger than its successor — a new artifact class S5/S6 must look for. While the 120 ms paint is withheld the § 2.4 sliver is uncovered unless re-armed (§ 4.1 (4)) |

### 4.1 D, specified (the touch set the first draft called "one function")

> **🔧 Built 2026-09-07 — module `4975a8c9a720773f`, nested branch `d` (`72184cd`), not installed.**
> Built on the re-check's `d-sim` (`b2186a0`, digest `8ff5e4f30492304b`) plus the two items below
> that simulation omitted; the digests differ for that reason.
> **(3) second half — FIXED, and it was the real one.** `update_remote_layer_frames` (`:1986`)
> walks *every* tracked entry, and under D a child has two, so unchanged it reframed the held
> predecessor on every drag step — stretching stale content across the ground the window just
> gained, on exactly the path #7 is about and worse than the gap the hold exists to cover. The
> skip is placed **after** the child-gone check, so a gone child's pair is still released together
> and no hold outlives its window.
> **(4) — the drain and root-destroy exits are deliberately left unarmed, and that is a decision,
> not the omission it looks like.** Both exits fire only when the child (or the root) is going
> away, and `update_remote_layer_frames` drops *all* of a gone child's entries in the same pass —
> so there is no survivor to re-arm. Verified by reading `remote_layer_target_rect`'s per-child
> failure, not assumed. The RELEASE handler's arm remains the one that matters.
> **(7) — `remote_layer_context_for`'s comment corrected**: it claimed "the" hosted layer for a
> child, and under D there can be two; its one remaining caller is a fallback.

1. **A** at `:4339` (form per S0).
2. **Ordering the owner does not have today.** `remote_layer_children` is CAContextID → child HWND,
   unordered (`window.c:1758`, `macdrv.h:188`, core patch line 412), and context ids are
   window-server-allocated and reusable, so "the two newest" is not recoverable from it. Add a
   per-child *current-context* record set in the CREATE handler beside `:1758`;
   `retire_superseded_layers` (`:946-970`) keeps `{current, previous}` and **keeps its
   `vals[i] == child` filter** (`:963`) — a stale entry for a reused id must not retire another
   child's host. Every read of the record is validated against `remote_layer_children` — a recycled
   id must not reframe another child's host either — and the record is cleared at all three
   `remote_layer_children` removal sites (`:966`, `:1780`, `:2038`), routed through one helper, or
   the two drift.
3. **`remote_layer_context_for` (`window.c:1852-1872`) returns the first match.** Its D1-scoped
   caller `:2105` (`update_remote_layer_frame_for(data, hwnd, remote_layer_context_for(data, hwnd))`)
   reframes **one** host per child move; with two tracked it would move an arbitrary one, leaving
   the live generation at its old frame about half the time — a new misplacement on the path C32
   found fragile. D reframes the *current* generation (from the new record). **And the bulk path:**
   `update_remote_layer_frames` (`window.c:1986`; callers `:2144`, `:2429`, `:2449`) iterates every
   tracked entry, so unchanged it reframes the held predecessor too — stretching stale content to
   the new rect on every drag step, on exactly the path #7 is about. It must skip a held
   predecessor. (Found by building it — the re-check's most consequential omission.)
4. **Gate the 120 ms deferred host paint (`:847-861`)** — but not where the first fold put it: the
   Cocoa side never receives the child (`macdrv_window_create_ca_layer_host_view`, `:4409-4410`,
   takes `context_id, frame, zpos, zpos_valid`; `_caLayerHosts` is keyed by context id; the gate at
   `:858` is id-only). The *decision* lives on the unix side, which knows the hold: pass a `paint_bg`
   flag down and split the deferred paint into an `-armCALayerHostBackground:` the owner can fire
   later. **Withholding the paint forfeits the § 2.4 sliver cover for the life of the hold**, so each
   of the four exits in (6) needs a re-arm site — the re-check wired one from the RELEASE handler and
   left the drain and root-destroy exits unarmed — or the sliver is stated as D's cost. The
   alternative is to accept `min(window, 120 ms)` as D's reach.
5. **`have_z` FALSE → keep-one** (§ 2.3). A generation created with `have_z` FALSE is never recorded
   as *current*, so the generation after it holds nothing — otherwise the inversion recurs one
   generation later.
6. **Four exits, named** (the pattern `GOTCHAS.md` § hold-until-next-event requires): the next
   CREATE for the child · the predecessor's own `WM_MACDRV_RELEASE_REMOTE_LAYER`
   (`window.c:1767-1785` already frees a tracked id) · the dead-child drain (`:2033-2041`, which
   runs only from root frame updates — callers `:2144`, `:2429`, `:2449`) · root destroy
   (`:1419-1420`). A child that stops recreating, never releases, and dies keeps its held pair
   until the root's next frame update — today's bound, one larger. Any new structure (the
   current-context record) needs its own release at the root-destroy exit, which today releases
   `remote_layer_children` only.
7. **Comments that become false and must change with the code** (upstream-bound): `window.c:943-945`,
   `:1760`, `:1850-1851` ("the context id of this root's hosted layer for this child" — under D
   there are two), `cocoa_window.m:882-884` ("the old one retired at CREATE"), core patch line 412.
8. **Pattern-fit in D's favour, unused by the first draft:** the root-with-NULL-child path already
   holds until RELEASE (retire is gated `if (child)` at `:1761`; `addCALayerHostViewWithContextId`
   removes only the same id, `:841`), and pristine keeps N hosts per window. D generalises an
   in-tree behaviour rather than inventing one.
9. **A fifth exit D does not have: the current generation framed EMPTY** (found 2026-10-27 by a
   feasibility read of C66's ten D traces — § Rework 2026-10-27; ~~measured once~~ **corrected by
   pass 3: it happens in every one of the 10 runs** — the rework's probe skipped a `(0,0)-(0,0)`
   successor as "not framed yet", which hid nine of them). The four exits in (6) all wait on the
   child — its next CREATE, its RELEASE, or its death. None fires when a live child is **sized to
   zero** (~~hidden or~~ — pass 3: hiding alone frames nothing empty, since
   `remote_layer_target_rect`, `d:window.c:1976-1983`, has no visibility test). The per-child path
   frames the current generation `(0,0)-(0,0)` (`update_remote_layer_frame_for`, called at
   `d:window.c:2200`) and the bulk path repeats it, while the bulk path's skip keeps the held
   predecessor at its old frame (`… is held behind … -- keeping its own frame`, `d:window.c:2129`).
   The predecessor, covered by nothing, shows the child's last content. **Measured (pass 3's
   builder prototype over all 10 D rows; r1 and r6 re-read from the raw trace; pass 4's
   independent probe agrees on all 10): once per session in every run, on the full-width × 657
   page child (1610–1685 px wide; ~~1660×657~~ — pass 4), the predecessor full-size, uncovered for 21, 6, 18,
   18, 6, 16, 19, 14, 16 and 19 ms (r1–r10).** E.g. r1, child `0x500e2`: its current generation
   `1687972282` framed empty at `355206.895`, the held `3954933104` released at `.916`. Every
   measured case ended because the child recreated (at `(0,0)-(0,0)`) and released the predecessor
   in the same millisecond; a child sized to zero that does not recreate has no exit short of its
   death. The scorer cannot see it — a stale frame is CEF content, not a diagnostic colour — which
   is how C66's D arm scored 0 with it present in every row. **Recommended fix** (corrected by pass
   3): when the current generation's target rect is empty, retire everything but the current
   generation in the same pass — `retire_superseded_layers(data, child, current, 0)` (`keep`,
   `hold`; `d:window.c:982-983`) — **from both the per-child and the bulk path, and only when `current` is non-zero and
   another generation of the child is tracked** (pass 4): in the bulk path inside the
   `d:window.c:2114-2133` block, where `current` is local, on an empty target rect; in the
   per-child path, call `remote_layer_current_for(data, child)` itself and skip on 0 —
   `update_remote_layer_frame_for` (`:2024-2025`) receives only a `context_id`, and `:2200`'s
   fallback is an arbitrary first match. Never pass keep = 0: the loop skips only `keep` and
   `hold` (`:1000`), so it would retire the live generation too, and `current` is 0 after an
   unordered CREATE (`:1817-1818`) or once its record is forgotten (`:968-972`). Retire before
   the frame TRACE (`:2046`/`:2144`), so S6a term (3) logs no event rather than a 0 ms one. Then
   **re-arm the current generation's background** (`macdrv_window_arm_ca_layer_host_bg(…, current)`). Without the
   re-arm the survivor never gets the background its creation withheld: the predecessor's later
   RELEASE finds an untracked id and skips the arm (`d:window.c:1833-1847`). In the bulk loop, skip
   snapshot entries that are no longer tracked, or a released id prints a false "held" line.
   Re-shown without recreating is safe: the current generation covers itself, or, if it never
   presented, the gap is keep-one's, no worse than A. Gate: S6a term (3) = 0. ⚠ **Ordering:**
   adopting it makes a new D and D-diag, so S2c, S3, S5, S6 and S7's tail run on the rebuild; a
   closure on the staged `6385a7ffb1cbb408` would close a module that is then changed. **Pass 3
   recommends adopting it before S2c** (both lenses: none of those rows has run, so a rebuild costs
   no evidence, and declining leaves S6a (3) ungateable; pass 4 concurs, with the guard above).
   The decision is James's.
10. **What D holds can be empty: a predecessor that never presented** (pass 3, judgment lens; not
    an instrument). D holds the latest `have_z` generation whether or not it ever presented, and a
    generation that never presented composites as nothing (C63) — unless its host background
    was armed ≥ 120 ms earlier (its own predecessor's RELEASE re-arms it, `d:window.c:1845-1847`;
    `d:cocoa_window.m:937-950`), in which case it composites black: production-equivalent to
    keep-one's black, and S3 counts black (`full-client-episodes.py:50`) (pass 4, from source,
    not run). C62 measured the displaying child
    presenting in 92–98 % of its generations, so in roughly 2–8 % of its successions D's cover is
    empty and the gap is keep-one's. That is the first suspect for a D "narrows" outcome, and a
    ceiling S3-T reports rather than gates. Holding the latest *presented* generation instead would
    close it; that is a design change, recorded here, not proposed.

**Recommended for the re-check to adjudicate: D, with A alone as a control arm, gated on S0 and
S1a.** C is the only candidate that eliminates the race rather than covering it, and the only one
whose code lives in the glue.

## 5. Where a change belongs (upstream form)

§ 2.1 measured that `:4339` and the whole CAContext/CALayerHost mechanism are pristine winehq. So:

- **A and D are wine-core changes.** Wine is a separate project with its own process; the dxmt
  no-PR rule does **not** apply to them. The natural vehicle is
  [bug 60263](https://bugs.winehq.org/show_bug.cgi?id=60263), whose published core patch already
  modifies `CAContextSwapChain` (the `child:` plumbing; 4 hits in
  `scripts/winemac-crossprocess-child-core.patch`). The claim a maintainer will act on — *"stock
  wine flashes black for a frame on every recreated hosted swapchain"* — is § 2.1 + C56 and
  should be stated with the § 2.5 numbers, **and must say what happens to the identical line at
  `:1257`** (§ 2.1).
- **C's hook is glue** (`dxmt_objc.m` is the DXMT glue half of this tree, not pristine); its
  upstream form is #6's boundary question. A DXMT-side notification instead would touch
  `~/cs2-patch/dxmt-fork`, where `CLAUDE.md` § ⛔ applies: no PR, a comment with exact locations,
  AI assistance disclosed.
- Core vs glue for D: `retire_superseded_layers` is in **core** today (the 60263 patch). D changes
  it in place plus the § 4.1 sites, all core.
- #6's two decisions were parked on *"wait for stage 2 to settle"*; stage 2 settled (C54, ruled
  out). That hold has expired independently of this plan.

## 6. Test plan

**Preconditions on every row** (the test-plan lens found them unstated and partly unmet): every
drag row is fingerprinted (`drag-session.sh:120` → `steam-render-cell.sh:77` →
`cell-fingerprint.sh` → `config.json`) — but **without `--strict`** today (0 hits in either
script): add it, or justify non-strict in the row. `video-gap-battery.sh` carries the lock-screen
refusal, the network hold and the **loadavg < 12 gate** (`:93-98` since the MODS interleave; kept at
12 on the 18-core Studio — it guards absolute contention, and a gate must not change mid-battery); `strip-module-ab.sh` has **no
loadavg gate** — add one before S6. Record the capture display and its refresh (`cell-fingerprint.sh`
records neither; a run on the 60 Hz portrait panel halves every sampled rate with nothing in
`config.json` to show it). Arms interleaved; void a comparison whose arms' achieved cadences differ
by > 10 %. Every candidate cell lists its module digest per arm so D-diag, A-diag and stamp builds
can be told apart later. ⚠ Score the top band as black **or** any diagnostic colour (C56; the
C49/C53/C56 scorer-bug family) — and note **the video tally counts only
`blue/green/magenta/cyan`** (`video-gap-battery.sh:104-119`) while video mode writes **no
`bands.txt`** (`livedrag-probe.sh:27`): a prod build paints no colour and reads "no episodes" by
construction. **Every comparison arm below therefore runs a diag build; prod modules are for S5
and S6 only.** ⚠ **That constraint survives instrument (9), but its reason has changed and the new
reason is narrower.** The battery now scores a black episode too (`BLACK_MIN`, default 5 %), so a
prod arm is no longer unscoreable by construction — what a prod arm still cannot do is
**attribute**. A diagnostic colour says *which surface* is exposed; black says only that something
dark is, and on a prod build nothing separates the defect from a dark banner. So: comparison arms
stay diag because attribution is what they are for, and a prod arm is now usable to *confirm a rate
the diag arm already attributed*. ⚠ Cyan is unsafe on the store page (Steam artwork; C61): S0/S3/S4
need a page knob — ✅ instrument (5) built it, `STEAM_PAGE`, recorded per run in `steam-page.txt` —
or a **shape gate**. ✅ **SETTLED 2026-09-08 (C65), and as an instrument rather than a sentence:
`scripts/full-client-episodes.py`.** A frame is full-client for a colour when that colour covers
**≥ 0.80 × the window's INITIAL area** (`video-rect.txt`; a size the client never falls below).
Three things the plan's draft version got wrong and this does not: it counts **pixels, not the
bounding box** — the C61 column is 26 distinct columns inside a 1005 px bbox, so a bbox test passes
it and a pixel test does not; the bar is **swept and published** (flat 0.65–0.92 over 24 runs, so
0.80 is not a tuned number, and `--sweep` prints the table for any new battery); and **isolation is
reported, never required** — every episode measured to date is one frame, so an isolated-spike
filter would reproduce today's counts *and* would silently miss a multi-frame episode, which is the
one result a closure test must not miss. ⚠ **This supersedes the page requirement, and the reason
matters more than the fix: presence is the wrong test for a defect that has a SIZE.** C64 voided a
sound run because a single stray cyan pixel at (30,479), present in nearly every frame, scored 542
episodes on one arm and 543 on the other. No page is safe under a `> 0` count and every page is
safe under this one.

**Instrument work this plan requires, named as such** (all small, all prerequisites — nothing
here is candidate code). ✅ **All nine BUILT 2026-09-07** — see the as-built header; per-item
build notes are inline below, and two of them change how a result may be read. (1) `scripts/first-drawable-stamp-patch.py` — a diag-only `CAMetalLayer`
subclass for `CAContextSwapChain` overriding `nextDrawable` to TRACE the first acquire per context
id and to `addPresentedHandler:` on that drawable, tracing `presentedTime`. ✅ **BUILT**, module `5bfb1f07ce0d7598`, compiles clean, all five stamp
strings and the `_NtGetTickCount` import verified present in the `.so`. ⚠ **The plan did not
specify how the child reaches "one clock", and it needed a decision.** The Cocoa side's `ERR()`
goes through `LogErrorv`'s raw `fprintf` (`cocoa_app.m:2402-2412`) and never enters wine's debug
header — measured on a real trace: **300 untimestamped `^err:` lines against 35 timestamped ones**
— so a stamp emitted the obvious way lands on no clock at all. The stamp therefore prints
`NtGetTickCount()` itself, declared `__attribute__((ms_abi))` by hand because `WINAPI` → `__stdcall`
→ `ms_abi` on x86_64 with no unix-lib carve-out (`minwindef.h:157`, `corecrt.h:112-117`) even though
winemac.drv is a `UNIXLIB`. **A wrong ABI there would not fail the build, it would print a
plausible wrong number** — so S1a is gated on `align-trace-video.py --check-clock`, which refuses a
run whose stamp ticks fall outside the trace's own tick range. **Run that gate before reading any
S1a number.** (2)
`scripts/align-trace-video.py` — anchor video PTS to the trace (the first visible edge motion,
C59's magenta seam, to the first `SysCommand f002` stamp), since nothing aligns them today
(`drag-session.sh:87` names only wall-clock; `win-resize-driver.c` prints no timestamps).
✅ **BUILT**, and it carries the `--check-clock` gate above. Anchor arithmetic verified against a
controlled fixture (planted offset recovered to 8 ms, inside the ±25 ms one-frame uncertainty) and
the gate observed **red then green** on a spliced `tick=0`. ⚠ Two limits are printed with every
run rather than assumed: it is a **one-point anchor worth about one video frame**, and drift is
estimated by re-anchoring on the last right-edge press — **not** on the last coloured frame, which
would compare the first f002 against the *top*-edge segment and report that segment's duration as
drift. ⚠ **Not yet exercised end to end: no run on disk pairs a trace with scored video**, because
`drag-session.sh`'s trace-copy fix postdates every video row. S1b is its first real use. (3)
`--rect x,y,w,h` on `video-blue.swift` (`--where` gives one whole-frame bbox, `:80-108`).
✅ **BUILT**, both the counting and the locating paths, tested on a real recording; fractions are
rect-relative and every line carries `rect=`, so a rect run cannot be misread as a whole-frame one,
and an off-frame rect reads as `rect=…,0,0` rather than as a clean sheet. (4) fold
C42's cyan content-view patch into `diag-colours-patch.py --cyan` — **C42's build
`38b52d6b3971d78b` had no committed build input**. ✅ **BUILT** as `--cyan` (background at
`initWithFrame:`, GDI blit suppressed — C42's void first attempt is the reason for the first half),
module `e700ac8fdfef0e80`, compiles clean. ⚠ **It is a RECONSTRUCTION, not a reproduction, and it
cannot be made into one** — so **C42's 3-of-15 split and C61's 25 px column are not a baseline a new
`--cyan` arm continues; S0/S3/S4 must carry their own controls.** Two independent reasons a
byte-compare is unavailable: five behavioural commits landed on `main` after C42's module was built
at 21:22 on 2026-09-03 (`eecbe79`..`5dd318c`), and `main` is the glue commit rebased over the core
series, so the tip C42 built from is not a commit that still exists. The check that IS available is
the `--noblue` mutant (blue returns), which catches the failure C42 actually hit. (5) a
`STEAM_PAGE` knob in `drag-session.sh`. ✅ **BUILT**, and the chosen page is written to
`steam-page.txt` in the run dir, since it is part of the fixture;
(6) a `*)` default in `strip-module-ab.sh`'s module map (`set -u` at `:24`; the map covered only
`s1diag|baseline|stage1|s2b` with no `*)`: an unknown role **aborted loudly if it came first and
silently reuses the previous iteration's module if it comes later** — S6's `"baseline stage1 D"` is
the silent case) + its loadavg gate. ✅ **BOTH BUILT**; the dispatch was exercised over all six
names including `D` and `Ddiag`, and any arm whose name ends in `diag` now sets the digest's
colour-reading flag. (7) `scripts/live-hosts.py`
(+1 at `:1717`, −1 at `:964`/`:1770`, max per child). ✅ **BUILT, and it reproduces every one of
§ 2.5's six published figures exactly** (baseline r1 300/285/271, stage-1 r1 277/262/248, 14
retired-but-never-released in both) — an independent replay of the same traces. ⚠ **It replays the
dictionary rather than counting events**, because RELEASE is not a decrement: the handler skips an
untracked id and § 2.5 measured that as 271 of 271, so a per-line −1 would run the count to −271
and report health. ⚠ **And S7's bound must be read off the DWELL column, not the max**: today's
baseline already reaches 2 momentarily (CREATE adds before retire removes), measured at 0.07 s of
149 s = 0.0 %, so max is 2 on a clean baseline *and* on a correct D. `--max N` is a gate with an
exit code, observed red then green. (8) a `--norelease` child mutant at `:4370`. ✅ **BUILT** into
`diag-colours-patch.py` beside `--e1` (same file, same one-file `build-winemac.sh` contract),
module `cf200bbf146ff56f`, compiles clean. (9) a black group in `video-gap-battery.sh:105,113`,
so prod arms become scoreable and the all-diag constraint can be revisited. ✅ **BUILT** — and it
needed a threshold the plan did not name. `> 0` is sound for a diagnostic colour and **wrong for
black**, which measured 0.14 % of the frame on a *static* store page in this battery's own
recordings and would mark every frame an episode; C58's real episodes covered 13–53 %, so
`BLACK_MIN` (default 5 %) separates them and is printed with the tally. Regression-checked against
C61's stored run: 281 cyan episodes over 10 runs, unchanged.

⚠ **Still owed in this section, and deliberately not done with the instruments** (both are
preconditions, not instruments, and both change harness behaviour rather than adding a tool):
**`--strict` on the drag rows' fingerprint** — still 0 hits in `drag-session.sh` and
`steam-render-cell.sh`, so the plan's "add it, or justify non-strict in the row" is unanswered and
every S-row below must do one or the other; and **recording the capture display and its refresh**
in `cell-fingerprint.sh`, without which a row taken on the 60 Hz portrait panel halves every
sampled rate with nothing in `config.json` to show it. Neither blocks S1a; both must be settled
before a rate from one run is compared with a rate from another.
✅ **Both SETTLED by the rework (2026-10-27), as instrument changes that land before S2a:**
**`--strict`: add it.** In `cell-fingerprint.sh` it changes exactly one thing: the foreign-Steam
warning at `:163` becomes a refusal (`:24`, `:35`, `:163` are its only three hits). Every S-row wants
that refusal, since a foreign Steam in the window lands in the recording. ~~Pass it from
`drag-session.sh`'s fingerprint call~~ **(pass 3: `drag-session.sh` has no fingerprint call — it runs
`steam-render-cell.sh` (`drag-session.sh:121`), whose parser rejects unknown args
(`steam-render-cell.sh:54`). Add `--strict` to that parser and forward it to the
`cell-fingerprint.sh` call at `:77`.)** A refused row then propagates as: `steam-render-cell.sh` exits
1, `drag-session.sh` prints `VOID: …FATAL…`, the battery retries the row once after 60 s
(`video-gap-battery.sh:104-106`), and a second refusal leaves the row VOID in the tally and absent
from the scorer. **Display + refresh: record them** (`cell-fingerprint.sh` has 0 hits for either).
~~Write one `display` entry to `config.json`: … (`system_profiler SPDisplaysDataType`, `UI Looks like:
… @ 60.00Hz`)~~ **(pass 3: neither source works on this machine — `system_profiler` prints no `UI Looks
like` line for the Studio Display, only for the DELL; `winlist --displays` prints id, main, size,
origin and asleep but no scale or refresh (`winlist.swift:25-32`); and `config.json` is written to
`/tmp/steam-cell-<label>/` before Steam has a window, so no run dir carries it.)** Instead:
`winlist --displays` gains `scale=` (pixel width ÷ point width) and `hz=` from
`CGDisplayCopyDisplayMode` — measured 2560×1440 pt, 5120×2880 px, scale 2.0, 60.0 Hz on the Studio
Display — and `livedrag-probe.sh`, which already finds the display holding the window (`:183-192`),
writes that line into the run dir as `frames/display.txt`. A battery whose rows disagree on any of
the four is void. Every comparison in this plan is within one battery, so this is a guard, not a
stratifier.

| id | test | pass / what it decides | mutant |
|---|---|---|---|
| **S0** ✅ **MECHANISM ANSWERED 2026-09-07 — see C63; in-situ arm running** | **A's transparency, before anything is built on it.** A-drop (with `--noblue`) on the diag base, cyan content view (`--cyan`), Library page or shape-gated, video, n ≥ 12 | three outcomes: **cyan** full-client episodes at ≥ the blue rate ⇒ the pre-drawable layer is transparent, A/D proceed; **black** full-client episodes at the blue rate ⇒ A-drop is inert ⇒ A becomes deferred `opaque = NO` + no background on the `:847-861` pattern, S0 re-run; **neither** ⇒ re-read the scorer before believing it (C56). ⇒ **RESULT: outcome 1 — the pre-drawable layer IS transparent, so A/D proceed and the `opaque = NO` fallback is not needed.** Reached by a **direct probe** (`scripts/calayerhost-probe.m`, C63) rather than by this row's battery: the question is a compositing MECHANISM, and § 2b says build the artifact and run it. Three arms hosted side by side over one green backdrop, read from ONE capture, in wine's cross-process topology; control `0,0,0` and A-drop `0,249,0` in the same frame, 4 of 4 same-process and 4 of 5 cross-process valid runs. ⚠ The battery arm below is a **confirmation through the real DXMT pipeline**, not the decider — module `d79c80d951b3a5e9` (A-drop + `--cyan`, `--noblue`), `STEAM_PAGE=steam://open/games`, video, N = 12. ⇒ **IN-SITU RESULT 2026-09-08 (C65): AGREES, outcome 1.** Re-scored at the full-client bar, the arms separate completely: **A-drop cyan 2 / blue 0 / black 0 · mutant blue 4 / cyan 0 / black 0**, 12 valid rows each, every episode one frame. The regions coincide to within 4 px of 671,658 (`x 0..1034, y 180..828` on both). **`black = 0` on the A arm is the in-situ refutation of "A-drop is inert"** — were the layer still opaque, its flash would read black, and it reads the content view. ⚠ The two arms ran sequentially, 100 minutes apart, so the between-arm RATE (0.17 vs 0.33/drag) is weak; the within-arm attribution is not | ⇒ **OBSERVED RED then GREEN**: the mutant arm (`e700ac8fdfef0e80`, `:4339` restored, blue on) shows 4 full-client blue episodes in 12 where the A arm shows 0, and 0 cyan where the A arm shows 2 |
| **S1a** ✅ **RUN 2026-09-07 — see C62** | **Per-generation timing, trace only, one clock** — the stamp build (instrument-only; no candidate code), diag colours on, 10 full-coverage drags (~300 generations each). (i) `first-acquire(N)` and `presentedTime(N)` − owner host-commit(N) (`window.c:1717`). (ii) `RELEASE(N−1)` **and the child's detach block** vs `presentedTime(N)` | (i) **null upheld** if ≥ 90 % of generations present within one refresh (8.3 ms) of the host commit; report the fraction beyond 120 ms (D's cap). (ii) **D closes** if the child's detach follows `presentedTime(N)` in ≥ 95 % of generations, else **D narrows**, with the covered fraction. **The 95 % is fixed here, before the run**. ⇒ **RESULT: (i) null REFUTED — 0 of 2,924 within 8.3 ms; acquire is immediate (median +2 ms) but the PRESENT lags, median ~53 ms on the displaying child. (ii) detach follows present in 1,440 of 1,442 = 99.9 %, median +83.5 ms ⇒ D CLOSES.** ⚠ The present rate is **bimodal by child** — two long-lived children per run, one presenting 92–98 %, the other 19–31 %; never quote the pooled 50 % | n/a — diagnostic |
| **S1b** | Video per *visible* episode only (expect ~3 in 10 drags), via the aligner + `--rect`; 25 ms floor stated | confirms S1a's tail is what the eye can see; does not decide anything S1a decides | n/a |
| ~~**S2**~~ | ~~Baseline rate on the scorer's known-positive build: `MOD=s1-diag`, N = 12, video; rate pooled with C58~~ — **SUPERSEDED by the rework (2026-10-27): split into S2a / S2b / S2c below.** Pooling with C58 died with the machine change (pass 2), and on the Studio a zero from this row could not tell "scorer blind" from "defect not visible at 60 Hz" — S2a exists to separate those | — | — |
| **S2a** (rework 2026-10-27) | **Known-positive, end to end, on the Studio, with no game in it.** No video row has ever been recorded on the Studio (0 `video-frames.txt` newer than 2026-10-01 under `~/cs2-patch`); the 2× path is proven only on a synthetic copy of C66 (`c280a39`). A helper, **`scripts/flash-probe.swift` (new)**, opens a borderless window on the Studio Display, fills it neutral grey, and on a display-link-timed schedule paints **exactly one refresh** of a test colour over it: 20 full-window **blue**, 20 full-window **cyan**, and 20 **blue covering 40 %** of the window (the scale discriminator), one every 2 s, printing each flash's timestamp. The colours must satisfy the classifier (`video-blue.swift:113-121`: blue `b ≥ 200, r,g ≤ 60`; cyan `g,b ≥ 200, r ≤ 60`). **Capture and scoring are the battery's own calls, not new ones**: `screencapture -v -V… -R…` (`livedrag-probe.sh:213`) over the helper's rect, written as `video-rect.txt` in the `:212` format; `/tmp/video-blue` (`:265-266`); then `full-client-episodes.py --sweep`. Needs the session unlocked (`livedrag-probe.sh:165-172`). The region holds only the helper window, so the recording is publishable-safe; delete it after scoring anyway. **Pass 3 completes the spec (the builder lens typed the pipeline):** the scorer reads `<dir>/frames/video-frames.txt` and `<dir>/frames/video-rect.txt` (with `window=WxH` and `rect=x,y,w,h`), so S2a writes that layout; it voids only on a missing rect or window, a scale that is neither 1× nor 2×, overlaps ≠ 0/0, or < 2 frames, and with no `capture-state.txt` it has **no overlap guard**, so S2a writes one from `winlist` as the battery does, after its own lock check. The helper prints its rect in CG top-left global points. `-V` ≥ 130 s (60 flashes × 2 s + a start delay). **Rebuild `/tmp/video-blue` fresh** (`swiftc -O scripts/video-blue.swift -o /tmp/video-blue -framework AVFoundation`): `livedrag-probe.sh:265` builds it only if absent, and a stale binary would score silent zeros. **Colour path:** paint with the diag patch's own constructor — `CGColorCreateGenericRGB`, set as a `CALayer` `backgroundColor`, with the same component values (`diag-colours-patch.py:100` blue, `:161` cyan — pass 4) — and report each colour's captured mean RGB (`video-blue --where`): the Studio Display is P3, and a helper that paints another way could pass while D-diag's cyan reads blind (generic-RGB cyan's red after conversion can exceed the classifier's r ≤ 60). The helper logs each flash's presented time from its display link; a flash that did not last exactly one refresh is excluded from k | **PASS = every counted episode is a full-window flash, as a 1-frame full-client episode, and no 40 % flash is counted.** The fraction caught (k of 20 per colour) **is the Studio's detection probability for a one-refresh event at 60 Hz** — the quantity pass 2 said the machine change moves, measured rather than argued. It is measured on an idle machine, so it is an upper bound under battery load; and C65 shows `screencapture -v` already sampled at 16.7 ms on the 120 Hz machine, so it may rise here rather than fall. k < 20 is not a failure. Both S3 arms share it, so the conditional test there is unaffected, but S2b's rate is then a lower bound by k/20. k = 0 for a colour ⇒ the instrument is blind to it; stop | **unscaled area** — score the same recording with the pre-fix scorer (`git show c280a39^:scripts/full-client-episodes.py`). At 2× it counts recording pixels against a point-space area, so a 40 % flash reads as 0.40 × 4 = 1.6 × the window's point area, twice the 0.80 bar. **Red = ≥ 1 of the 40 % flashes counted** |
| **S2b** (rework 2026-10-27) | **Baseline defect rate on the Studio**: `s1-diag` (`50fdfe79898dac36`, C58's known-positive build), N = 12, video, one arm, after S2a passes. Command: `STEAM_PAGE=steam://open/games bash scripts/video-gap-battery.sh` (`MODS` defaults to `s1-diag`, `N` to 12, `video-gap-battery.sh:31,74`); same page as S3, so the rates are comparable. Time the rows from their `cell.txt` mtimes: C66's 3 min a row was measured at 1×, and a 2× recording gives `video-blue` 4× the pixels per frame, so S3's time budget uses this measurement (pass 3) | **≥ 1 blue full-client episode ⇒ the defect is visible on the Studio.** ~~r̂ = episodes ÷ valid runs, with an exact Poisson CI~~ **(pass 3: episodes cluster by row — C65's mutant arm put 4 episodes in 2 of 12 rows — so the rate that matters is per row.)** Report **hit rows** (valid rows with ≥ 1 full-client episode) beside episodes: p̂ = hit rows ÷ valid rows, with an exact binomial CI. p̂ sets S3's feasibility (**≥ 4 of 12** to start it; with a void row, ≥ 4 hit rows **and** p̂ ≥ 1/3 — pass 4) and S2c's N (below). **0 of 12 with S2a green ⇒ the flash is not observable at this machine's refresh, or its hit-row rate is below 0.22 (one-sided 95 %)** ~~or rarer than ~1 in 12 drags~~. Then S3 cannot be decided by video here and goes to **S3-T**, and T3 (S5) is recorded as moot on this machine (there is nothing to see), not run. 0 of 12 with S2a red ⇒ instrument; stop | n/a — this row *is* the known-positive for the defect; S2a is the known-positive for the scorer |
| **S2c** (rework 2026-10-27) | **S3's mutant (a), finally observed** — owed since 2026-09-08 (staged, never run). `D-mutant-blue`: `cf9a904f283e55e0` as staged, **or its rebuild if § 4.1 (9) is adopted** (the mutant must sit on the D that S3 judges). N = 12 (pass 3: or the larger N in the next column), video, after S2b, and **only if S3 (Studio) will run** (S2b ≥ 4 of 12 hit rows); on the S3-T route, S3-T's own keep-one mutant stands instead | **Red = ≥ 1 blue full-client episode.** Only meaningful once S2b has fired. ~~P(false green) = e^(−12·r̂): 0.02 at C66's 0.33/drag. If r̂ < 0.25, raise N to ⌈4.6 ÷ r̂⌉ before reading a green, so that P(false green) ≤ 0.01~~ **(pass 3: that Poisson formula ignores clustering — at C65's mutant arm, 2 of 12 hit rows, P(no hit row in 12) is 0.112, not 0.018 — and its own threshold was inconsistent: at r̂ = 0.25 it kept N = 12 for e^−3 = 0.0498.)** **N = max(12, ⌈ln 100 ÷ −ln(1 − p̂)⌉)**, p̂ = S2b's hit-row fraction, so that P(no hit row \| the mutant is as visible as S2b's build) ≤ 0.01: N = 12 at p̂ = 4/12 (pass 4: on the video route p̂ ≥ 1/3, so N is always 12; the formula binds only if S2c is ever run below 1/3) | this row is the mutant |
| **S3 (M3 Max — prior stratum)** ◐ **RUN 2026-09-08, 10 of 15 rounds — see C66; the Studio run is S3 (Studio) below** | **D-diag** (`6385a7ffb1cbb408`, `--noblue --cyan`), **interleaved with the A-alone arm** via the battery's new `MODS`, **n = 15 each**, `STEAM_PAGE=steam://open/games`, video; host bound from `live-hosts.py`. Command (C66): `MODS="D-diag s0-adrop-cyan" N=15 STEAM_PAGE=steam://open/games bash scripts/video-gap-battery.sh`; new rows start at `r1` in a new `VID_OUT` (no resume knob). **Scored by `full-client-episodes.py` at BAR = 0.80, declared and committed before the run** (C65). ⇒ **RESULT (C66): D-diag 0 full-client episodes of any colour in 10 valid runs; the interleaved A-alone control 4 in 4 of 10 (0.40/drag).** Both arms 10 valid rows, 150 children, ~1,600 generations — the interleave held. ⚠ **NOT closure.** The bar is 0 episodes at **n ≥ 15** (exact Poisson P(0) = 0.0067, the only n that clears 0.007); at n = 10 it is **0.0357** against the pooled baseline, **0.0183** against this battery's own control, Fisher **0.0433**. ~~Five more rounds settle it~~ **(pass 2, 2026-10-10): re-run FRESH on the Studio, never pooled with C66.** ~~Before the first Studio row: (1)–(5) …; n ≥ ln(1/0.007) ÷ rate_A ≈ 4.96 ÷ rate_A; use the staged modules~~ — **superseded by the rework (2026-10-27):** (1) the scorer's scale is fixed (`c280a39`); (2) `screencapture -v` measured at 2× (in `c280a39`'s message); (3) the clamp is fixed (`bf6b611`); (4) is settled in the § 6 preamble; (5) is now S2a + S2b. The run-count formula and the module choice are replaced by the **S3 (Studio)** row below | **closure**: 0 full-client cyan episodes, exact Poisson p ≤ 0.007 against the pooled rate; **narrows** (if S1a (ii) said so): decide on S1a's per-generation metric with n ≈ 60/arm interleaved with A-alone, video as confirmation only; max live hosts per child ≤ 2 | (a) restore `:4339` on the D-diag source, build **without** `--noblue` → blue returns, red = ≥ 1 episode in 12 — staged as `winemac.so.D-mutant-blue` `cf9a904f283e55e0` but **never observed red** (not in C66's `MODS`): owed; (b) restore keep-one → this is S4's A-alone arm, **red observable under closure only** |
| **S3 (Studio)** (rework 2026-10-27) | **D-diag interleaved with A-alone, stopped by an EVENT count, not a run count.** Pass 2's n ≥ 4.96 ÷ rate_A took rate_A from the battery's own control, which is circular: the battery's length would depend on the rate it is estimating, and that rate's own uncertainty never enters. ~~The rework uses the exact conditional test for two Poisson counts, which needs no rate at all. Interleaving gives the arms equal exposure, so under H0 (D no better than A) each full-client episode lands in D with probability n_D ÷ (n_A + n_D), independently of the others.~~ (pass 4: that was the episode-level test pass 3 replaced; the test is the within-pair sign test below, which needs no rate either.) ~~Stopping rule: stop when the two arms TOGETHER reach k = 8 full-client episodes~~ **(pass 3: episodes cluster by row — C65's mutant arm put 4 episodes in 2 of 12 rows — so 8 episodes can be 4 rows, and P(all in A) is then 2⁻⁴ = 0.0625, not 2⁻⁸.)** **Stopping rule, fixed here before any row: count HIT ROWS — valid rows with ≥ 1 full-client episode, any colour, BAR 0.80 — **in complete pairs only** (pass 4), and stop after the round in which the two arms' hit rows in complete pairs together reach 8, or at the cap.** The unit of the test is the **pair** (the round's D row and A row, adjacent in time): a pair with a VOID row (after the battery's one retry) is dropped from the test **and from the stop count** (pass 4), its other row reported apart, so n_D = n_A by construction and drift across the battery cannot bias the result. Stopping on the total, never on one arm's count, keeps the test exact: the stop does not depend on the labels. The cadence rule stays as `video-gap-battery.sh:68-72` defines it (achieved cadences within 10 %; pass 4: those lines are a comment and the battery never compares the arms, so compare by hand from each arm's `achieved cadence` line, `:180-183`); ~~arms whose valid n differ by > 10 % void the battery~~ (pass 3: a valid-n rule is a hair trigger at small n, and pair-dropping makes it moot). **Cap: 40 pairs** — 80 rows, ~4 h at C66's measured 3 min a row (`cell.txt` mtimes 09:10:47 → 09:37:45 over its first 10 rows), **re-timed on S2b's rows**, since that cadence was measured at 1×. **Feasibility, decided from S2b before the first row:** ~~if S2b's r̂ < 0.2/drag, do not start … the cap catches that~~ **(pass 3: at a hit-row rate of 0.2 the chance of reaching 8 within 40 pairs, if D works, is 0.56 — a coin flip, not a feasibility rule; and "A-alone ran at half the mutant's rate in C65" was the clustering artifact: by rows the two arms were equal, 2 of 12 each.)** **Start iff S2b shows ≥ 4 of 12 hit rows.** If D works, P(8 A hit rows within 40 pairs) = 0.98 at a true rate of 1/3 and 0.82 at 1/4 (binomial), ≈ 0.86 averaged over a 4-of-12 estimate's uncertainty (Jeffreys) — assuming no void pairs; "40 pairs" is `N=40` rounds, and at 36 complete pairs the 0.98 / 0.82 fall to 0.95 / 0.71 (pass 4). Fewer ⇒ S3-T. Each row needs the session unlocked and untouched (`video-gap-battery.sh:52-59` refuses a locked one), so the battery runs in a window James sets aside, not opportunistically. **Modules:** D-diag **rebuilt with § 4.1 (9)** if pass 3 adopts it, otherwise the staged `6385a7ffb1cbb408`; A-alone `s0-adrop-cyan` `d79c80d951b3a5e9` as staged. **Command:** `MODS="D-diag s0-adrop-cyan" N=40 STEAM_PAGE=steam://open/games bash scripts/video-gap-battery.sh`. The battery has **no stop-on-count knob**; add ~~`STOP_EPISODES=8`~~ **`STOP_HITS=8`** rather than stopping by hand — a hand-stop off a live tally is how C66 ended early. **Where it goes (pass 3):** after each round, between `video-gap-battery.sh:114` and `:115`, so the stop falls on a pair boundary; score each arm's run dirs as `:199-200` does (~~`:197-199`~~ — pass 4) and count hit rows from the per-run lines (`full-client-episodes.py:192`), or give the scorer a `--json`. ~~Voided rows have no `video-frames.txt` and the scorer omits them silently, so its "N valid runs" is the right n per arm.~~ **(pass 4: an A hit whose D partner voided would reach the total of 8 but not the test, leaving closure on 7 discordant pairs, P = 2⁻⁷ = 0.0078.)** Voided rows have no `video-frames.txt` and the scorer omits them silently (`full-client-episodes.py:161-165`), so `STOP_HITS` pairs rows by round itself: round k counts only if both `r<k>-D-diag` and `r<k>-s0-adrop-cyan` have `frames/video-frames.txt` and pass the overlap guard, and a hit row is a distinct label across colours (`:192` prints one line per colour per run). n is the number of complete pairs, not the scorer's per-arm "N valid runs". The final tally passes `$N` (`:131-133`), so a battery stopped early would list every unrun row as VOID: pass the achieved round count. Scored at BAR 0.80 with `--sweep` printed; its plateau must be re-confirmed on Studio recordings before any number is read. C66 stays the prior-machine stratum, never pooled | **closure** = D has 0 hit rows at the stop, so all 8 are A rows in 8 discordant pairs: ~~P = (n_A ÷ (n_A + n_D))^8 ≤ 0.007, 0.0039 at equal n~~ **exact within-pair sign test, P = 2⁻⁸ = 0.0039** ≤ 0.007, whatever the dependence between episodes within a row (pass 3). It cannot overshoot: a total past 8 needs both rows of the last pair to hit, so D ≥ 1 and there is no closure to overstate. k = 7 would give 0.0078, over the 0.007 fixed in pass 1, and that is the whole reason k is 8. **What closure buys, stated:** ~~D's hit-row rate ≤ ≈ 0.45 × A's at 95 %~~ (pass 4: 0.45 is an odds, not a rate ratio) the odds of a discordant pair favouring D ≤ 0.45 at 95 % (one-sided, 0 of 8: θ ≤ 0.31); as a ratio of hit-row rates, ≤ ≈ 0.53 at A's 1/4 and ≤ ≈ 0.56 at 1/3, the rows of a pair taken as independent; never report it as "eliminated". **narrows** = D ≥ 1: run to the stop anyway, report the sign-test P over discordant pairs and D's rate relative to A's with its CI, then decide on S3-T's per-generation metric; § 4.1 (10) is the first suspect. **cap reached before 8** = video cannot decide on the Studio: S3-T, counts reported. Max live hosts per child ≤ 2 throughout (S7's bound) | (a) = **S2c**; (b) restore keep-one ⇒ that is the A-alone arm itself, red observable under closure only (unchanged) |
| **S3-T** (rework 2026-10-27; only if S2b or the cap sends S3 here) | **Trace route: is the held predecessor still hosted when its successor first presents?** D covers the pre-drawable gap by construction exactly when the cover outlives the gap. S1a (ii) measured the precondition on `main` (the child's detach follows present in 99.9 % of generations, C62); this row measures the cover **on D itself**, where the owner's release ends it. Build: D-diag + the S1a stamp patches (`first-drawable-stamp-patch.py`) on branch `d`. ~~⚠ Unverified that the stamp patcher applies on `d`~~ **(pass 3: verified on a copy of `d:cocoa_window.m` — all six anchors match exactly once, and with `--colours --noblue --cyan` the diag colours apply through their second anchor; the diffs are the same size as on `main`. The patcher's header saying "`main` only", `first-drawable-stamp-patch.py:15`, is stale.)** Recipe, with the nested repo on `d` as in S7's: `WINEMAC_BRANCH=d bash scripts/build-winemac.sh <out> scripts/first-drawable-stamp-patch.py --colours --noblue --cyan`, digest recorded. Trace-only (`CAPMODE=window`, as S1a ran), so no unlocked session is needed; ≥ 10 valid rows (~3,000 generations); stamp ticks gated by `align-trace-video.py --check-clock` before any number is read, as S1a's were; stamps joined to `live-hosts.py`'s replay by tick. The analysis extends `scripts/s1a-timing.py` (pass 4): the stamp lines (`stamp create\|acquire\|presented\|relpost\|detach ctx=… tick=…`, `first-drawable-stamp-patch.py:63-69`) are keyed by ctx, so the COVERED join is typeable | ~~pass = in ≥ 99 % of generations the predecessor's host is still tracked at the successor's first `presentedTime`~~ **(pass 3: tracked is not cover. A held generation that never presented composites as nothing (C63), the displaying child never presents in 2–8 % of its generations (C62), and the criterion pooled both children against C62's own warning — so it would pass vacuously or fail by construction.)** **Per displaying child (the one presenting ≥ 90 % of its generations), a succession N−1 → N is COVERED iff N−1 presented before `presentedTime(N)`, N−1's host is still tracked at `presentedTime(N)`, and the child's detach of N−1 follows `presentedTime(N)`.** Successions whose predecessor never presented are D's structural ceiling (§ 4.1 (10)), reported as a fraction, not gated; successions whose successor never presents have no gap and are counted apart. **Pass = ≥ 99 % of the remaining successions covered**, fixed here before the run, with the uncovered fraction's distribution reported. It decides the mechanism, not visibility: report a pass as "covers the gap in the trace; not decidable by video on this machine", never as a video closure | **keep-one** (A-alone + the same stamps): the predecessor is retired at CREATE, so red = it is gone at first present in ≥ 50 % of generations. Red by construction — it checks the stamp-to-replay join, not D |
| **S4** ✅ **ANSWERED 2026-09-08 — see C65** | **A alone, the control arm**, same build recipe minus the hold — module `d79c80d951b3a5e9` | full-client cyan at the blue rate ⇒ A relocates the flash (black in production, `:1257`); under D that must not occur. ⇒ **RESULT: A ALONE IS NOT A FIX.** 2 full-client cyan episodes in 12 runs against the mutant's 4 full-client blue in 12 — the same surface, in the same place, in the same shape, one frame each. On a production A build that region is the content view's ordinary black, so **A alone moves the flash from the child's layer to the surface below it**. D's hold is what has to remove it, and the row above is that test. ⚠ n = 12, 2 events; and this arm re-runs interleaved beside D-diag in the S3 battery, which is the rate comparison the sequential pair could not give | restore `:4339` → **full-client** cyan episodes vanish. ⇒ **OBSERVED: 2 → 0** (and blue 0 → 4 in the same frames). The C61 growing-edge column persists regardless and does not reach the bar — that is not this mutant's signal, and the gate counting pixels rather than a bbox is what keeps it out |
| **S5** | **T3 (human)**, James on the D **prod** build (`4975a8c9a720773f`, or its rebuild if § 4.1 (9) is adopted — pass 3; installed and restored by the same trap as S7's boot-verify wrapper; digest asserted back to `2a251a4b2510fb84` after). Protocol written before he starts: Steam on the Studio Display (main), `steam://open/games`, 10 grows then 10 shrinks by the bottom-right corner, the question asked verbatim and his answer copied verbatim into the ledger; no screen recording kept | verdict verbatim: any full-client flash still visible? any *new* artifact — a stale predecessor showing after the new generation should have covered it, especially on **shrinks**? | none — a human drag is not repeated per mutant |
| **S6a** (rework 2026-10-27; **spec reworked in place by pass 3**) | **Trace: placement and stale exposure — the half of S6 pixels cannot see.** New `scripts/held-layers.py`, timestamp-sorted as `live-hosts.py` is. ~~Promoted from the 2026-10-27 feasibility probes~~ — **pass 3: those probes had a bug** (they skipped a `(0,0)-(0,0)` successor and seeded no CREATE frames), so start from pass 3's prototype, `~/cs2-patch/checkit-2026-10-27/builder/held_layers_proto.py` — which differs from this spec in five ways the instrument must fix (pass 4): term (2) sampled only at held lines; no 1-px floor (it opens term (3) on the 1×1 predecessor: 20 events, the extra ten 0.6–1.2 s); term (3) ended only by a release; term (1) on the per-child path only; no unit check. Pass 4's integrating probe, `~/cs2-patch/checkit-2026-10-29-pass4/indep.py`, follows the spec and is the cross-check. **Inputs, all TRACE lines branch `d` already writes** (pass 3 corrected and completed this list): **child → root and each generation's first frame** — `child %p layer frame in root %p = %s` at CREATE (`d:window.c:1769`), not DXMT's `cross-process child … -> root`, which is another process's line; without it a predecessor that was never reframed is invisible. **Reframes** — `update_remote_layer_frame_for child … context … frame …` (`:2046`, per-child; called at `:2200`, which passes the current context and falls back to the first match) and `update_remote_layer_frames child … context … frame …` (`:2144`, bulk): identical formats, so key on the `trace:macdrv:<function>` prefix; **`(0,0)-(0,0)` is a real framing from either path and is never skipped**. **The bulk-path skip** `… is held behind … -- keeping its own frame` (`:2129`). **"Current"** = the child's latest hosted CREATE (`:1758`), undone if followed by `gone before context %u could be hosted` (`:1776`; 0 in C66); a `have_z` FALSE CREATE needs no special case, since keep-one retires the others (`:1796`). **Releases** — `WM_MACDRV_RELEASE_REMOTE_LAYER` (`:1830`), the gone-child `… gone -- releasing hosted layer` (`:2109`) and `retiring superseded layer ctx` (`:1001`). **Root size** — `sync_window_position … frame` (`:871`), W×H only: child frames are root-relative (offset at CREATE), valid for the borderless Steam root. **Unit check per run:** at least one current-generation frame at x ≤ 1 equals the root's W×H from `:871` (pass 4; 1,424–1,581 such frames a run in C66) ~~the full-size current frame must equal the root's size~~, else term (2) is void (the child rect is in raw-DPI units and `:871` prints Cocoa points; they coincide at 1×, C66). **Terms, per run:** **(1) wrong-target reframes** — a reframe from **either** path naming any generation but the child's current context (pass 4: ~~naming a held predecessor rather than the child's current context~~ — the feasibility read and the prototype both count "anything but current", the safer reading): § 4.1 (3)'s failure, and the "child placement" the old row asked for. **(2) stale exposure** — the predecessor's frame clipped to the root, minus the successor's clipped frame, integrated in px·s from each geometry event (CREATE, either reframe, root frame, any release) to the next — not only at held lines, which appear only on bulk passes. **Floor: an exposure ≤ 1 px wide is reported, not gated** — every D run has a 1×1 predecessor at `(0,0)-(1,1)` beside a successor at `(1,92)-…`. **(3) stale after collapse** — from the successor being framed empty while a predecessor above the floor is held, to that predecessor's release or the successor's next non-empty frame, whichever comes first (§ 4.1 (9)). Runs on any D trace: first on C66's 10 D rows (on disk), then on S6b's D rows. **Feasibility, re-measured by pass 3** (prototype; the instrument must reproduce these before it is trusted): (1) **0 of 1,458** per-child reframes off target — per-run counts equal `grep -c 'trace:macdrv:update_remote_layer_frame_for child'`; the A arm gives 1,449 and 0, as it must, since it tracks one host per child. (2) ~~185 overhangs, all on the right edge, 0 px exposed apart from the r6 collapse~~ — **194 overhangs with a non-empty successor once CREATE frames are seeded, mostly the right edge, median one 25 px step, plus one 1-px corner case per run; and ~~the collapse in (3) exposes 1.06–1.09 Mpx at a held line in 8 of 10 runs~~ (pass 4: that was the prototype's held-line-only view) the collapse in (3) exposes 1.06–1.11 Mpx in 10 of 10 runs, integrated over every geometry event as specified (a held-line-only view sees 8 of 10 at 1.06–1.09 Mpx: r2 and r5 have no bulk pass inside their 6 ms); above the floor, term (2) on today's D is the collapse and nothing else, 6.5–22.9 kpx·s per run.** (3) ~~1 event, 16 ms (r6)~~ — **10 of 10 runs, 6–21 ms, median ≈ 17 ms**, each ended by the child's re-CREATE and RELEASE in the same millisecond (§ 4.1 (9)). ⚠ Limit, stated: trace time is not composite time, and (2) is a geometric bound on what CAN be on screen, not a pixel reading — which is why S6b stays | **(1) = 0 · (2) = 0 above the floor · (3) = 0** on the D that ships (with (9) built; on today's D, (2) and (3) are red in every run — the collapse, measured above; ~~(3) is red in every run~~ — pass 4). Reported per run alongside `live-hosts.py`'s host bound | (1): a fixture trace with one reframe's context swapped to the held predecessor ⇒ red (**pass 3: built and observed**, 1 bad); on source, **(1a)** D with `d:window.c:2200` reduced to `remote_layer_context_for(data, hwnd)` alone (the first match; the anchor is unique) and **(1b)** D with the bulk path's held skip deleted (`d:window.c:2127-2132`; the predecessor is then reframed through `update_remote_layer_frames`) ⇒ red on a real run. Both are `window.c` mutants, so they need a window.c patcher run with `PATCH_FILE=window.c` (`build-winemac.sh:34-37`; `signal-mutants.py` is the precedent but is main-only), and since one build patches one file they build on D prod, not D-diag — no build input yet. (2): a fixture whose predecessor extends 25 px past its successor inside the root ⇒ red (**pass 3: observed**, 10,000 px, 400 px·s; the control without the overhang gives 0). (3): today's D is its own mutant — red in all 10 C66 runs |
| **S6b** (rework 2026-10-27; was S6) | **Pixels: no regression on #7's strip**, prod arms: `strip-module-ab.sh MODULES="baseline stage1 D" N=7 FRAMES=300`, interleaved and loadavg-gated (instrument (6)). Window capture (`screencapture -l`) **works on Steam's window at 2×** (`ebfcce7`; 3320×1600, rendered), so the harness's forced `CAPTURE=window` (`strip-module-ab.sh:38`) stands and `CAPTURE=screen`, which is blind to the strip (C52), is not needed. D is the prod module of the same build as S3's D-diag. **Coverage, before the battery:** one row per arm; ~~the last capture must postdate the start of the drag's last right-edge segment (`sizedrag-right.txt`)~~ **(pass 3: there is no common clock to compare — `sizedrag-right.txt` stamps are a driver tick in ms, captures carry only wall-clock mtimes, the trace runs on `NtGetTickCount`)** the row's `frames/sizes.txt` must show the width grow, shrink, grow, shrink, grow and then the top segment's height change (all 14 rows of strip-ab `20260906-140732` pass at FRAMES = 300, at 1×), else FRAMES is raised **for every arm** before the battery starts — 2× captures are 4× the pixels, and C53's "300 frames cover the drag" was measured at 1×. **Shrink clause, now with an instrument to build:** `band-counts.py` gains the shrinking-frame split (width < the previous capture's) beside its growing-frame one (pass 3: a one-line mirror of `band-counts.py:46`, prototyped — 28–35 shrinking frames per row on strip-ab `20260906-140732`); the synthetic drag has two shrink segments (`drag-session.sh:184-187`). ⚠ **The black metric cannot tell correct cover from STALE cover:** a held predecessor covering the strip would read as an improvement. That is S6a's term (2), not this row's | stage 1 < baseline **reproduces in this run** (not against C54's stored numbers) **and** D's growing-frame right-band mean ≤ stage 1's + ½ (baseline − stage 1) **and** D's shrinking-frame right-band mean ≤ stage 1's + the same margin | none — structural (the band can only regress); the stale-cover blind spot is S6a's |
| **S7** | **The hold's bound**: `--norelease` mutant (8) + `shimmer-probe.sh churn` (`hosting-layer-tests.sh:254`) + `live-hosts.py`, ≥ 300 creates; then the terminal case — a child that recreates twice, stops, never releases, is destroyed; then `scripts/boot-verify.sh` (the game never constructs a `CAContextSwapChain` — `window.c:1298-1336` — but shares the module). **Recipes (pass 2):** `--norelease` on `d` = `git -C $NR checkout d && WINEMAC_BRANCH=d bash scripts/build-winemac.sh ~/cs2-patch/winemac.so.D-norelease scripts/diag-colours-patch.py --noblue --cyan --norelease; git -C $NR checkout main` (the script refuses unless the repo is already on `d` and restores only the patched file, never the branch; the patcher applies the colour patches too, so the flags match D-diag), digest recorded. **Terminal case = trace-only**: `live-hosts.py --dump` over a D session in which a CEF child is destroyed; pass when that child's count reaches 0 after its gone-child TRACE (near `d:window.c:2105`); check C66's 10 D traces for that TRACE before running anything new. **boot-verify on D**: `boot-verify.sh` has no module knob, so a wrapper copies `winemac.so.D` (`4975a8c9a720773f`, or its rebuild if § 4.1 (9) is adopted — pass 3) into the wrapper under a `trap restore EXIT` modelled on `drag-session.sh:106-110` (`DAILY=~/cs2-patch/winemac.so.stage1`), runs boot-verify detached, then asserts `shasum` = `2a251a4b2510fb84` | max live hosts per child ≤ 2 throughout; the terminal child's held pair drops to 0 after the root's next frame update; boot-verify PASS. ⇒ **FIRST HALF MET 2026-09-08 (C67): max live 2, never 3, over 1,611 creates across 10 D runs**, replayed with `live-hosts.py --max 2` off the S3 battery rather than the churn probe (a different path; the create count far exceeds the row's ≥ 300). The DWELL column is what separates the arms, as the instrument note warned: **D 99.7 % of its life at ≥ 2 hosts, A alone 0.0 %**. Unlooked-for: **`retired-but-never-released` falls from 140 to 0** — under today's code the owner retires at CREATE and the child's later RELEASE finds an untracked id. ⚠ **Cost, as a number: D roughly doubles the resident host count** (290 tracked at end vs 150; 140 of 150 children end holding 2, against A's 0), which is precisely why the terminal case matters. **STILL UNRUN: the `--norelease` mutant on D, the terminal case, and `boot-verify.sh`** | (a) drop the next-CREATE exit → max grows monotonically (≥ 10); (b) disable the **`window.c`** drain (`main :2033-2041`; on `d` the gone-child block near `:2105`) → dead pairs persist. ⚠ Neither (a) nor (b) has a build input yet — the patcher only has `--norelease` |

Every listed mutant is **applied to real source and observed red, then restored green**. "Argued
red" is not red. Where a mutant is red-observable only under one S1a outcome, the row says so.

## 7. Exit criteria

1. **S1a run first** — an instrument-only build is permitted; no candidate build. Both halves
   reported with their distributions. If (i) upholds the null, that is recorded as the mechanism
   of rarity in a ledger row.
   ✅ **MET 2026-09-07** (C62): instrument-only build `28d40ea5d38a180c`, 10 valid rows, both halves
   reported with distributions. **The null is REFUTED, so the brevity of the window is NOT the
   mechanism of rarity** — it is ~6 refreshes at 120 Hz on the displaying child, not one. What
   the ledger records instead is that something covers a window that long nearly always, and (ii)
   establishes the child's live predecessor is available to be that cover in 99.9 % of successions.
   ⚠ The covering surface is **still unattributed** — C42/C61 name other candidates — so this is a
   narrowing, not an answer.
2. **Decision rule, fixed before S1a runs:** if the child's detach precedes `presentedTime(N)` in
   more than 5 % of generations, D cannot reach the tail — return to § 2 / C. Otherwise build D.
   ✅ **RESOLVED 2026-09-07: 0.1 % (2 of 1,442), far inside the 5 % bar ⇒ BUILD D.**
3. **S0 decided** (transparent / inert-with-fallback / scorer re-read) before S3.
   ✅ **MET 2026-09-07 (C63): TRANSPARENT.** A's form is fixed as `--drop`; `--defer` is not needed
   and is deliberately left unimplemented in `scripts/candidate-a-patch.py` so nothing is built on
   a branch S0 closed. ✅ **The in-situ arm now AGREES (C65, 2026-09-08)**, so the condition "S3
   should not start until it agrees" is satisfied and S3 is running. ⚠ Worth recording, because it
   is the third member of the C49/C53/C56 family and the first one to bite an S-row of this plan:
   the in-situ arm was reported VOID for a day on a scoring artifact, not a fixture fault. The run
   was always sound. **What the third instance changes is the remedy** — a scorer bug caught by
   re-reading is a scorer bug that will recur, so the gate is now a committed instrument with a
   published sweep, not a threshold chosen per analysis.
4. S3 at the closure bar (~~0 episodes, n ≥ 15,~~ on the Studio: 0 D hit rows when the arms together reach 8 — pass 3; exact p ≤ 0.007) or on the per-generation metric if
   S1a said narrows; S4 shows A-alone's relocation, if any, as a number; every mutant observed red
   then green, with the S1a-conditional ones marked.
   ◐ **S4 MET 2026-09-08 (C65): A alone relocates the flash — 2 full-client cyan episodes in 12
   runs where the mutant shows 4 full-client blue, same surface, same shape, one frame each.**
   The arithmetic behind S3's bar, checked rather than assumed: the pooled baseline is C58's 4/12
   plus the mutant arm's 4/12 = **8 episodes in 24 drags = 0.333 per drag**, so 15 drags with zero
   episodes gives an exact Poisson P(0) = e^−5 = **0.0068**, just inside the 0.007 the plan fixed
   in advance. n = 15 is therefore the minimum, not a round number, and a voided row costs the
   bar — `full-client-episodes.py` refuses an all-void battery rather than reporting zero episodes
   off zero evidence. ~~S3 ▶ running~~ ⚠ **Pass 2 (2026-10-10): that 0.333/drag is a 120 Hz, M3 Max
   rate.** ~~The Studio battery takes its bar from its own A-alone control and S2 gate: n ≥ 4.96 ÷
   rate_A~~ — **replaced by the rework (2026-10-27):** on the Studio, S3 is met by § 6's **S3
   (Studio)** event-count rule. It stops when both arms together reach 8 ~~full-client episodes~~ **hit rows (pass 3) in complete pairs (pass 4)**, and
   closure means all 8 are A rows: ~~P = (n_A ÷ (n_A + n_D))^8 ≤ 0.007 (0.0039 at equal n)~~ **a sign test over
   complete pairs, P = 2⁻⁸ = 0.0039**. It is
   preceded by **S2a** (the scorer fires end to end at 2×/60 Hz; detection fraction recorded) and
   **S2b** (the defect is visible here; ≥ 4 of 12 hit rows to start S3 — pass 3; with a void row, ≥ 4 and p̂ ≥ 1/3 — pass 4). If S2b or the 40-pair cap says video
   cannot decide on this machine, S3 is met by **S3-T**'s trace criterion instead, reported as a
   trace result, never as a video closure. Mutant (a) is observed red in **S2c**, on the same D
   that S3 judges.
5. S6 green including the shrink clause; S7 green including the terminal case and boot-verify.
   ⚠ Pass 2: S6 cannot start until its capture instrument works on macOS 27 and the shrink clause
   has a scorer (§ 6 S6). **Rework (2026-10-27):** the capture works (`ebfcce7`). S6 is met by
   **S6a** (trace: wrong-target reframes 0, stale exposure 0 above the floor, stale-after-collapse 0,
   on the D that ships) **and S6b** (strip regression, growing and shrinking clauses, coverage checked at 2×).
   The shrink scorer is `band-counts.py`'s new split; the placement scorer is S6a term (1).
   ◐ **S7's bound MET 2026-09-08 (C67)**; its terminal case, its `--norelease` mutant and boot-verify
   are unrun, and S6 has not started. ⚠ **The `--norelease` mutant must be rebuilt on branch `d`, not
   reused from `main`** (`cf200bbf146ff56f` is main's): under D the child's RELEASE is the *only*
   exit that frees a held predecessor, since the retire path is skipped — 0 retires against 1,321
   releases-that-freed — so the mutant is only meaningful on D, where it should grow past 2.
5a. **§ 4.1 (9) decided before ~~S3~~ S2c** (rework 2026-10-27; pass 3 moved this item below item 5's
   S7 note, which it had split from its item, and widened it): adopted and built, so S2c, S3, S5,
   S6 and S7 (boot-verify included) run on the rebuilt D/D-diag; or declined, with
   stale-after-collapse recorded as D's stated cost and S6a term (3) reported rather than gated.
   Pass 3 recommends adopting, with the corrected fix in § 4.1 (9).
6. T3 (S5) recorded verbatim in the ledger.
7. Upstream form settled per § 5: the wine-core change described for 60263 with the § 2.1 + § 2.5
   claims and the `:1257` answer, AI assistance disclosed; no dxmt PR under any outcome.

## 8. Rollback

The installed daily driver is stage 1 `2a251a4b2510fb84`, kept. Any candidate ships as a separate
module built through `scripts/build-winemac.sh` and is only installed after S3/S6/S7; reverting is
reinstalling `2a251a4b2510fb84`. No prefix or settings change is involved.
**Pass 2 (2026-10-10):** every battery restores stage 1 through `drag-session.sh`'s `trap restore EXIT`
(`:106-112`), but the restore is `cp … 2>/dev/null &&` and asserts nothing — end every battery, and
the S7/T3 D installs, with `shasum -a 256 <installed winemac.so> | cut -c1-16` = `2a251a4b2510fb84`.
Building D on the shared tree overwrites its `winemac.so` (today `cf9a904f283e55e0`); copy the
output out before the next build.

⚠ ~~`scripts/build-winemac.sh:36-37` refuses any nested branch but `main`~~ **(stale since 30ea6b7: the
script has `WINEMAC_BRANCH` at `:39-50` — it still requires the repo to be checked out on that branch
first.)** The original note, kept for the record: it refused any nested branch but `main` and any dirty tree, so a
candidate on a branch cannot go through it as written: either land D on `main` behind the § 7 gate,
or give the script a branch knob. The re-check's fallback was the target the script names —
`gmake dlls/winemac.drv/winemac.so` in `~/cs2-patch/build-1116/wine-1116-vis-build` — with the
digest taken by hand. (The file's exported Cocoa wrappers close with two braces, `@autoreleasepool`
inside the body; the first compile of D tripped on it.)

## Review corrections (triple-check 2026-09-07)

Pass 1: four lenses (architecture · correctness · platform-facts · test-plan audit), Fable 5.1,
against cs2 `3515efc` / nested `52789ff` / pristine `wine-11.16/`; the classic security surface is
empty here (no authz/tenant/RLS) and was folded into architecture as upstream-form + privacy.
Every `[BLOCKER]` was spot-checked in this session before folding. Landed above:

- **[BLOCKER, ×2 independent] the 120 ms host paint caps any hold** → § 2.4 ¶3, § 2.5 (b), § 4.1 (4),
  S1a (i)'s 120 ms fraction.
- **[BLOCKER] `CAMetalLayer.opaque` defaults YES and DXMT sets it; A's transparency is unmeasured**
  → § 2.1 ¶2, § 4 A, **S0** (new), exit criterion 3.
- **[BLOCKER ×4, test plan]** video tally cannot fire on a prod build → every arm is diag, S2 on
  the known-positive build; `strip-module-ab.sh` silently reruns the previous module for an unknown
  role → instrument (6) before S6; Mann-Whitney unreachable on a count metric → exact-count bar,
  n ≥ 15, pooled baseline with CI; S1 needed an instrument build the ordering forbade → S1a/S1b
  split, instrument-only build permitted, exit criterion 1.
- **[SHOULD-FIX] D's cost** → § 4.1 (ordering record, `:2105`, `have_z`, four exits, comments).
- **[SHOULD-FIX] the leak class is C29 / the 2026-08-31 entry, not C30** → § 2.5.
- **[SHOULD-FIX] `framebufferOnly` was the wrong property; DXMT rewrites the block** → § 2.1 ¶2.
- **[SHOULD-FIX] `nextDrawable` hook precedent exists** (`dxmt_objc.m`) → § 4 C.
- **[SHOULD-FIX] commit ≠ block; `presentsWithTransaction` unset** → § 2.2 ¶3.
- **[SHOULD-FIX] RELEASE at the owner is an upper bound on the hold** → § 2.5 (a).
- **[SHOULD-FIX] exit criterion 2 had no decision rule** → 95 % fixed in S1a and criterion 2.
- **[SHOULD-FIX] S4's mutant was unobservable as written; S7 had no instrument and no terminal
  case** → S4, S7, instruments (7)(8).
- **[SHOULD-FIX] 120 Hz, not 60 Hz; one sample < 50 ms; 0.3/drag is a lower bound** → § 1 C58 row;
  **ledger C58 corrected the same day.**
- **[MINOR]** 5 → 4 patch hits; "~half" → 13–53 %; `:1767-1790` → `:1767-1785`; `:1243-1256` →
  `:1243-1258`; `:64-72` → `:64-71`; `cocoa_event.m:486-488` → `:486-535`; the content view is
  black in production, so A alone is "black from a different surface", not "stale content".

**Rejected:** nothing — every finding survived the spot-check. One lens cited `window.c:1716` as
the handler's TRACE; it is `:1717` (`:1716` is blank).

### Fitted re-check (same day) — builder-simulation on the folded plan

One agent (Opus 5), against `407348d`: verified every fold edit against the code (all true), then
**built D as § 4.1 specified** on a throwaway nested branch (`d-sim` `b2186a0`, compiles clean, digest
`8ff5e4f30492304b`, not installed, not merged; nested `main` and this repo untouched). No blocker.
Every finding is an omission in § 4.1's touch set, landed above:

- `[SHOULD-FIX]` the bulk reframe path moves the held predecessor → § 4.1 (3).
- `[SHOULD-FIX]` the 120 ms gate cannot live on the Cocoa side, and withholding the paint forfeits
  the sliver cover with no re-arm → § 4.1 (4), § 4 D.
- `[SHOULD-FIX]` `build-winemac.sh` refuses any branch but `main` → § 8.
- `[SHOULD-FIX]` the all-diag constraint is two lines from expiring → § 6 preamble, instrument (9).
  ✅ **Resolved 2026-09-07 by building (9)** — and the constraint did not lift, it narrowed: prod
  arms are now scoreable but still cannot attribute. See the § 6 preamble.
- `[SHOULD-FIX]` the generation after an unordered one; a second structure at the root-destroy exit;
  id reuse on the record → § 4.1 (5), (6), (2).
- `[MINOR]` `window.c:1850-1851` becomes false → § 4.1 (7); the unknown-role failure is loud on
  iteration 1 → § 6 preamble; cites: drain `:2033-2041`, map `:89-94`, `cocoa_event.m:486-540`,
  `drawableSize` applied at `winemetal_unix.c:1527` → § 2.1.

**Rejected:** nothing.


## Review corrections (re-check 2026-10-10, pass 2 — the Mac Studio)

Re-check of the **remaining** work (S3 tail, S6, S7 tail, T3) after the move from the M3 Max
MacBook + 120 Hz external to the Mac Studio (Studio Display 60 Hz at 2×, macOS 27.0.1). Two lenses
(premises; builder-simulation + test-plan), read-only apart from one disclosed side effect below;
every BLOCKER spot-checked inline. All corrections are folded into the status, § 6 and § 8.

- **[BLOCKER] "Five more rounds and pool" does not survive the machine change** — refresh (120 → 60 Hz)
  moves the detection probability of a one-refresh flash (C58), and the display scale moves the
  scorer. → fresh Studio battery; C66 is the prior-machine stratum.
- **[BLOCKER] The scorer is scale-unsafe on a 2× display** — `full-client-episodes.py:73` takes a
  point-space area, `:84-91` counts recording pixels (spot-checked). → normalise before any Studio row.
- **[BLOCKER] S6's capture mode cannot run on macOS 27** — `strip-module-ab.sh:38` `CAPTURE=window` →
  `livedrag-probe.sh:219` `screencapture -l` (spot-checked); `screen` is blind to the strip. → blocked,
  re-specify on video.
- **[SHOULD-FIX]** the rect clamp compares points with device pixels; S3's command was cited but not
  in the row; S3 mutant (a) built but never observed red; S6's shrink clause and placement scorer do
  not exist; `--norelease`-on-`d` recipe, the terminal-case instrument and the boot-verify-on-D
  install/restore were unwritten; S7 mutant (b) cited the wrong file; restores assert no digest;
  T3 protocol under-specified; no capture rule for recordings (they show the Steam account).
- **[MINOR]** stale cites (`:63-68` → `:93-98`; `build-winemac.sh:36-37`); loadavg gate kept at 12.
- **Publishability rule (added):** only numeric summaries and digests enter the repo; Steam-UI
  recordings and frames stay in `~/cs2-patch` and are never attached to issues.
- Verified unchanged: nested `main` `52789ff` / `d` `72184cd`, tree clean; every sampled `main`
  cite (`:1257`, `:4339`, `:4370`, `window.c:964/1717/1770/2033-2041/2105`); the `--norelease`
  anchor present on `d` (`:4378`); staged arm digests (`D` `4975a8c9…`, `D-diag` `6385a7ff…`,
  `s0-adrop-cyan` `d79c80d9…`, `D-mutant-blue` `cf9a904f…`, `stage1` `2a251a4b…`); the band metric
  is relative (scale-safe); per-row restore via `drag-session.sh` traps.
- **Side effect of the review itself:** the builder lens ran `gmake -n -B` in
  `wine-1116-vis-build`, which re-ran `configure` (failed at the bison 2.3 check) and overwrote only
  `config.log`; `config.status` / `include/config.h` kept their Aug 29 timestamps (spot-checked).
  Trap for builders: `/usr/bin/bison` 2.3 is first on PATH, so any reconfigure fails — Homebrew's is
  `/opt/homebrew/opt/bison/bin`.

## Rework 2026-10-27 — S3 + S6 (after pass 2; not a check-it pass)

Pass 2 left S3 and S6 `needs-rework`. This is that rework: one model, inline, against cs2 `9e1fbf4`
and nested `d` `72184cd`, plus three throwaway trace probes over C66's ten D runs (kept, not
committed, in `~/cs2-patch/s6-feasibility-20261027/`). Its numbers are feasibility reads, and the
instruments S6a names must reproduce them before anything is decided on them. **Pass 3 has to
check this section and the rows it changed.** ~~Nothing here is checked yet.~~ **Pass
3 checked it the same day: its corrections are in the rows and in § Review corrections pass 3, and
the bullets below are marked where it overturned them.**

**What pass 2 asked for that had already been done** (`git log 9a953c1..HEAD`):
- the scorer's scale (`c280a39`, with a synthetic 2× copy and an unscaled mutant observed red);
- `screencapture -v` measured at 2× (400×300 pt → 800×600, in the same message);
- the rect clamp (`bf6b611`, `winlist --displays`);
- `-l` on Steam's window at 2× (`ebfcce7`).

So the S3 row's prerequisites (1)–(3) were stale, and so was S6's "blocked on capture".

**Measured during the rework:**
- **No video row has ever been recorded on the Studio**: 0 `video-frames.txt` newer than
  2026-10-01. The 2× path is proven only on a synthetic copy, hence **S2a**.
- **C66's row cadence is 3 min, steady** (`cell.txt` stamps). That turns a closure bar into a
  time budget: 40 pairs ≈ 4 h, and the battery needs an unlocked, untouched session throughout.
- **Placement under D holds**: 0 of 1,458 per-child reframes target anything but the child's
  current generation. Not a control on the A arm, which tracks one host per child and so cannot
  fail it; S6a names real mutants instead.
- **The shrink artifact § 4 predicted exists in the trace, and the window clips all of it**: 185
  predecessor overhangs, a median of one drag step, every one outside the root's width.
  ⚠ **Pass 3: the probe seeded no CREATE frames and skipped `(0,0)-(0,0)` successors.** Re-measured:
  194 overhangs plus a 1-px corner case per run, and the collapse below exposes ~~≈ 1.07 Mpx in 8 of
  10 runs~~ 1.06–1.11 Mpx in every run (8 of 10 at a held line — pass 4).
- **A new class D introduces** (→ § 4.1 (9)): a live child framed empty while its held
  predecessor keeps its frame. ~~Once in 10 runs, 16 ms~~ **In every run, 6–21 ms (pass 3; the
  probe's skip hid nine of ten)**, bounded only by that child's own RELEASE.

**Design changes, and why:**
- **S2 → S2a / S2b / S2c.** On the Studio, a zero from S2 could not separate "scorer blind" from
  "the flash is not visible at 60 Hz". S2a is a game-free known-positive through the battery's
  own capture and scoring calls. Its catch fraction is the measured detection probability that
  pass 2 only argued about. S2c finally observes mutant (a) red.
- **S3's bar: run count → event count.** n ≥ 4.96 ÷ rate_A took the rate from the battery being
  sized, and ignored the rate's own uncertainty. The exact conditional test for two Poisson
  counts with equal exposure needs no rate: stop at 8 episodes across both arms; closure iff all
  8 are A's, P = 2⁻⁸ = 0.0039. It comes with a cap (40 pairs) and a feasibility rule taken from
  S2b's rate (< 0.2/drag ⇒ don't start). ⚠ **Pass 3: count hit rows, not episodes (episodes cluster
  by row), test by pairs, and start only at ≥ 4 of 12 S2b hit rows** (§ 6).
- **S3-T, pre-registered**, for when video cannot decide on this machine. It is a trace criterion
  on D itself (≥ 99 % of generations still covered at the successor's first present), reported as
  a mechanism result, never as a video closure. ⚠ **Pass 3 reworked the criterion** (§ 6 S3-T): a
  predecessor that never presented covers nothing, so covered means presented, still tracked and
  not yet detached, per displaying child.
- **S6 → S6a (trace) + S6b (pixels).** The black-band metric is blind to stale cover: a held
  predecessor over the strip reads as an improvement. Placement and stale exposure are geometric
  questions the trace answers directly. S6b keeps the strip regression, gains its shrink clause
  (`band-counts.py`'s new split) and a 2× coverage check, and drops the capture question (`-l`
  works).
- **Preconditions settled:** `--strict` added (it changes only the foreign-Steam refusal), and
  display + refresh recorded per row. ⚠ Pass 3 corrected where each lands (§ 6 preamble).

**Decisions this leaves for pass 3** (owner in brackets):
1. **Adopt § 4.1 (9) before S3, or state it as D's cost?** [pass 3 → James]. Recommended: adopt. **Pass 3: both lenses recommend adopt, with the corrected fix (re-arm, both
   paths).**
   The unbounded case (~~a hidden child that never presents again~~ a child sized to zero that never
   recreates — pass 4) has no exit, and adopting it
   later would void an S3 closure taken on today's D.
2. **S3-T's 99 % bar** and **S3's 40-pair cap**. Both are fixed here before any row, and both are
   judgment calls a reviewer should push on. **Pass 3: the 99 % bar kept, on the corrected criterion;
   the cap kept, with feasibility raised to ≥ 4 of 12 S2b hit rows.**
3. **New build inputs the rows assume:**
   - `flash-probe.swift`, `held-layers.py`, ~~`STOP_EPISODES`~~ `STOP_HITS` (pass 3) in `video-gap-battery.sh`,
     `band-counts.py`'s shrink split, `--strict` and the display entry;
   - the S6a source mutant's patcher flag;
   - the stamp patcher on branch `d` (~~unverified that it applies~~ pass 3: it applies).

   All are instruments, not candidate code. Pass 3's builder lens should confirm each is
   specified well enough to type in.

## Review corrections (re-check 2026-10-27, pass 3 — the S3 + S6 rework)

A fitted re-check of § Rework 2026-10-27 and the rows it changed, split by surface: a **judgment**
lens (statistics, the § 4.1 (9) diagnosis, internal consistency) and a **builder-simulation** lens
(prototype every new input from the rows' text and run it on C66's traces). Both read-only, no
side effects in either repo; scratch in `~/cs2-patch/checkit-2026-10-27/`. Every BLOCKER was
spot-checked inline: r1's collapse re-read from the raw trace (`355206.895` → `.916`, 21 ms), the
prototype re-run on r1/r2/r5/r10, C65's "blue 4 in 2 of 12" read in the ledger, and every binomial
figure below recomputed. All corrections are folded into the status, § 4.1 (9)–(10), the § 6
preamble, rows S2a–S7 and § 7.

- **[BLOCKER] § 4.1 (9) happens in every run, not once.** The rework's probe skipped a
  `(0,0)-(0,0)` successor as "not framed yet" (a wrong comment: its table held only framed
  contexts), which hid 9 of 10 events. Measured: once per session, 6–21 ms, the predecessor
  full-size (≈ 1.07 Mpx exposed). → § 4.1 (9), S6a, § Rework corrected; the case for adopting
  (9) is stronger, not weaker.
- **[BLOCKER] S3 (Studio)'s episode count is not exact: episodes cluster by row** (C65's mutant
  arm: 4 in 2 of 12). With two episodes a row, 8 episodes are 4 rows and P(all in A) = 0.0625.
  → count hit rows, test by pairs (a VOID row drops its pair), sign test P = 2⁻⁸ = 0.0039; it
  cannot overshoot. The valid-n "cadence rule" was a mislabel and is dropped.
- **[BLOCKER — S3-T] tracked is not cover.** A held generation that never presented composites
  as nothing (C63); the displaying child never presents in 2–8 % of its generations (C62); the
  criterion pooled both children. → covered = presented, tracked and not yet detached, per
  displaying child; never-presented predecessors reported as D's ceiling (new § 4.1 (10)).
- **[BLOCKER — S6a] the spec could not be typed in as written, and its feasibility numbers were
  the probe's bug.** → inputs completed (CREATE-time frames `d:window.c:1769`; both reframe paths
  by function prefix; `(0,0)-(0,0)` never skipped; "current" = latest hosted CREATE; releases
  `:1830`/`:2109`/`:1001`; a per-run unit check), term (2) integrated over every geometry event
  with a 1-px floor, term (3)'s end condition stated, mutant (1b) for the bulk path.
- **[SHOULD-FIX] S3 feasibility was a coin flip** (P(reach 8 within 40 pairs) = 0.56 at a 0.2
  hit-row rate) → start iff S2b ≥ 4 of 12 hit rows (≈ 0.86). "A-alone ran at half the mutant's
  rate" was the clustering artifact (by rows 2 of 12 each) — struck. Row cadence re-timed at 2×.
- **[SHOULD-FIX] S2c's formula** ignored clustering and contradicted its own threshold (e^−3 =
  0.0498 kept at N = 12) → N = max(12, ⌈ln 100 ÷ −ln(1 − p̂)⌉); S2c runs only on the video route.
- **[SHOULD-FIX] § 4.1 (9)'s fix needed a re-arm and both paths** — the predecessor's later
  RELEASE finds an untracked id and skips the arm (`d:window.c:1833-1847`); "hidden" frames
  nothing empty (`:1976-1983`), so the trigger is "sized to zero".
- **[SHOULD-FIX] S2a's pipeline and colour path were unspecified** (the scorer's `frames/` layout,
  the overlap guard, a stale `/tmp/video-blue`, generic-RGB painting on a P3 panel, flash-duration
  logging) → added to the row.
- **[SHOULD-FIX] the preamble's two settlements named sources that do not work:** `drag-session.sh`
  has no fingerprint call (`--strict` goes through `steam-render-cell.sh:54` → `:77`), and neither
  `system_profiler` nor `winlist --displays` gives the Studio Display's scale and refresh (→
  `CGDisplayCopyDisplayMode` into `winlist --displays`, written per run by `livedrag-probe.sh`).
- **[SHOULD-FIX] S6b's coverage check had no common clock** → `sizes.txt` segment pattern.
  **`STOP_HITS`** placed (`video-gap-battery.sh:114`/`:115`) and the early-stop tally fixed (`$N`
  at `:133`). The S6a source mutants need a `window.c` patcher (`PATCH_FILE=window.c`).
- **[SHOULD-FIX] consistency:** item 5a had split item 5's S7 note from its item (moved); 5a, S5
  and S7's boot-verify now say "or its rebuild"; the unstruck "n ≥ 15" in the as-built header
  and § 7 item 4 struck.
- **[MINOR]** S2b's zero branch bounds the hit-row rate at 0.22 (one-sided 95 %), not "~1 in 12";
  closure's meaning stated (D ≤ ≈ 0.45 × A at 95 %, never "eliminated").
- **Verified unchanged:** every `d:window.c` TRACE cite (`:871`, `:1758`, `:1830`, `:2046`,
  `:2129`, `:2144`, `:2200`) and its format string against C66's traces; `main:window.c:2105`;
  the classifier thresholds (`video-blue.swift:113`, `:117`, `:121`); the S2a mutant arithmetic
  against `c280a39^`'s scorer; `--strict`'s three hits; the stamp patcher applies on `d` (all six
  anchors); term (1) = 0 of 1,458; staged module digests; nested `main` `52789ff` / `d` `72184cd`.
- **Open:** § 4.1 (9) adopt or decline [James; pass 3 recommends adopt]. **A fitted re-check of
  this fold (pass 4)** before any instrument is built — a fold is new, unreviewed material.

## Review corrections (re-check 2026-10-29, pass 4 — fitted re-check of pass 3's fold)

One agent, briefed on `1c0b8b7` only: every new cite opened, every new number recomputed, § 4.1 (9)
re-measured on all 10 C66 D traces with pass 3's prototype **and** an independent probe typed from
the S6a row (`~/cs2-patch/checkit-2026-10-29-pass4/indep.py`), and a two-sided stale audit over 38
phrasings. Read-only; scratch in `~/cs2-patch/checkit-2026-10-29-pass4/`. Both blockers and S1 were
spot-checked inline: `full-client-episodes.py:161-165` omits void dirs; r2's raw trace has only the
per-child reframe (`.714`) and no bulk pass inside its 6 ms collapse (`.714` → `.720`), so no held
line; the probe re-run on r1/r2/r5/r10 gives 1,089,306 / 1,089,306 / 1,105,731 / 1,089,306 px;
`d:window.c:1000` skips only `keep` and `hold`; `current` is block-local at `:2114-2133`; the odds
bound recomputed. Corrections folded into the status, § 4.1 (9)–(10), S2a, S2b, S2c, S3 (Studio),
S3-T, S6a, § 7 item 4 and § Rework.

- **[BLOCKER] S3 (Studio): a void's partner could count toward the stop but not the test.** The
  scorer drops void rows silently, so a `STOP_HITS` built as written counts an A hit whose D
  partner voided; closure would then rest on 7 discordant pairs (P = 2⁻⁷ = 0.0078 > 0.007) while
  reporting 0.0039. → the stop counts hit rows **in complete pairs only**; `STOP_HITS` pairs rows
  by round itself; n = complete pairs. "Cannot overshoot" holds only under that rule.
- **[BLOCKER] S6a: the feasibility figure the instrument must reproduce came from a different
  method than the row specifies** (held-line sampling, 8 of 10). Integrated as specified, the
  collapse exposes 1.06–1.11 Mpx in **10 of 10** runs (r2 and r5 have no bulk pass in their 6 ms),
  6.5–22.9 kpx·s; nothing else above the floor. → figures corrected; the prototype's five
  departures from the spec listed in the row; the pass column now says (2) and (3) are red today.
- **[SHOULD-FIX] § 4.1 (9)'s fix with keep = `current` = 0 retires the live generation too**
  (`:1000`), and `current` is 0 after an unordered CREATE (`:1817-1818`) or a forgotten record
  (`:968-972`); the per-child path has no `current` (`:2024-2025`). → guarded: non-zero `current`
  and another tracked generation; the per-child path looks `current` up itself.
- **[SHOULD-FIX] "D ≤ ≈ 0.45 × A" is an odds, not a rate ratio.** 0 of 8 gives θ ≤ 0.312, odds
  0.454; as a rate ratio ≤ ≈ 0.53 at A's 1/4, ≤ ≈ 0.56 at 1/3. → restated in S3 (Studio).
- **[SHOULD-FIX, found inline] S3 (Studio)'s opening still described the episode-level Poisson
  test** pass 3 replaced (`n_D ÷ (n_A + n_D)`, unstruck) → struck.
- **[MINOR]** the page child is 1610–1685 px wide, not 1660 (r3 1635, r5 1685, r9 1610); line 85's
  "n ≥ 15" annotated as C66's record (pass 3's corrections said the header's was struck — that was
  line 90); § Rework's "hidden child" → "sized to zero"; `:197-199` → `:199-200`; cyan's colour
  constructor `diag-colours-patch.py:161` added; S2c's N is always 12 on the video route; the 40-pair
  feasibility assumes no voids (36 pairs: 0.95 / 0.71) and S2b's "≥ 4 of 12" defined under voids;
  the cadence comparison is by hand (`:68-72` is a comment); S6a's unit check and term (1) made
  unambiguous; § 4.1 (10)'s "empty" can be black if the predecessor was armed ≥ 120 ms earlier
  (from source, not run; S3 counts black); S3-T's analysis named (`s1a-timing.py`).
- **Verified unchanged:** every pass-3 `d:window.c` and script cite (bar the two off-by-ones above);
  2⁻⁸; P(Bin(40, p) ≥ 8) = 0.979 / 0.818 / 0.563; Jeffreys 0.857 / 0.694; S2b's 0.221; S2c's
  (2/3)¹² = 0.0077; the 0.112 / 0.018 / 0.0498 remarks; durations 21, 6, 18, 18, 6, 16, 19, 14,
  16, 19 ms; r1's ids and times; the trigger (`swp_flags 110e` to a 0×0 rect); term (1) 0 of 1,458
  and 1,449 / 0; 194 overhangs; C62 / C63 / C65 (these live in `EXPERIMENTS.md` `:1028` / `:1029` /
  `:1031`); `macdrv_window_arm_ca_layer_host_bg` (`d:macdrv_cocoa.h:540`, `d:cocoa_window.m:4449`);
  mutant anchors (1a)/(1b) unique; the `dispmode` probe (`scale=2.0 hz=60.0`); § 6 table 4 columns
  throughout; the status-line gate.
- **Open:** § 4.1 (9) adopt or decline [James; passes 3 and 4 recommend adopt, with S1's guard].
  Pass 4's fold applies the reviewer's replacement text, checked inline by the two-sided audit;
  the first instrument's build is its next check.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-07 | pre-review of the first draft (not a check-it pass) | inline: z-order · provenance · present-hook · trace ordering | one model, direct reads + one trace measurement | Fable 5.1 | cs2 `43227c7`, nested `main` `52789ff`, pristine `wine-11.16/` | first draft needs-rework → reworked in place (§ 2.3 covering claim wrong on z-order; § 5 ownership wrong; § 1 quoted a cadence as an exposure) |
| 2026-09-07 | **pass 1** | architecture (+ upstream-form/privacy) · correctness · platform-facts · test-plan audit | 4 independent agents, ≤ 15 tool calls each; every blocker spot-checked inline | Fable 5.1 ×4 | cs2 `3515efc`, nested `main` `52789ff`, pristine `wine-11.16/`, `dxmt-fork` | **needs-rework** (test plan) · build-ready-with-fixes ×3 → all folded the same day |
| 2026-09-07 | **fitted re-check** of the fold + builder-simulation | fold verification · build D on a scratch branch · compile · gates | 1 agent, ~15 tool calls; D built and compiled (`d-sim` `b2186a0`, digest `8ff5e4f30492304b`) | Opus 5 | cs2 `407348d`, nested `main` `52789ff`, pristine, `dxmt-fork` | **build-ready-with-fixes** — no blocker; nine omissions in § 4.1 / § 6 / § 8 folded the same day |
| 2026-10-10 | **pass 2 — re-check after the machine change** (remaining work only) | premises (architecture + correctness + platform-facts) · builder-simulation + test-plan (+ security/publishability) | 2 independent agents, read-only (one disclosed `config.log` side effect); every BLOCKER spot-checked inline | Opus 5.5 ×2 + Opus 5.5 synthesis | cs2 `9a953c1`, nested `main` `52789ff` / `d` `72184cd`, on the Mac Studio | **S3 + S6 needs-rework · S7 + T3 build-ready-with-fixes** — corrections folded |
| 2026-10-27 | **rework of S3 + S6** (not a check-it pass) | — | one model, inline; three throwaway trace probes over C66's 10 D runs (`~/cs2-patch/s6-feasibility-20261027/`) | Opus 5.5 | cs2 `9e1fbf4`, nested `d` `72184cd` | S3 + S6 re-specified (§ Rework 2026-10-27); § 4.1 (9) found; **pass-2 verdict stands until pass 3** |
| 2026-10-27 | **pass 3 — fitted re-check of the S3 + S6 rework** | judgment (statistics + § 4.1 (9) mechanism + consistency) · builder-simulation (prototype held-layers, S2a pipeline, STOP knob, band split, --strict/display, stamp patcher on `d`) | 2 independent agents, read-only, scratch in `~/cs2-patch/checkit-2026-10-27/`; every BLOCKER spot-checked inline (raw trace, prototype re-run, ledger, binomials recomputed) | Opus 5.5 ×2 + Opus 5.5 synthesis | cs2 `99e9a82`, nested `main` `52789ff` / `d` `72184cd`, on the Mac Studio | **build-ready-with-fixes** S2a · S2b · S2c · S3 (Studio) · S6b · preamble; **needs-rework** S3-T · S6a → reworked in place; **pass 4 (fitted, of the fold) owed** |
| 2026-10-29 | **pass 4 — fitted re-check of pass 3's fold** (`1c0b8b7`) | fold verification: cites · numbers recomputed · § 4.1 (9) re-measured (prototype + independent probe) · S3-T/S6a typeability · two-sided stale audit · mechanical | 1 agent, read-only, 34 tool calls, scratch in `~/cs2-patch/checkit-2026-10-29-pass4/`; both BLOCKERs and S1 spot-checked inline (scorer source, r2 raw trace, probe re-run, `d:window.c`) | Opus 5.5 + Opus 5.5 synthesis | cs2 `1c0b8b7`, nested `main` `52789ff` / `d` `72184cd`, on the Mac Studio | **build-ready-with-fixes** throughout (2 BLOCKERs, 3 SHOULD-FIX, minors) → folded |

**Key paths** (re-check if these move): `dlls/winemac.drv/cocoa_window.m` (`:832-894`, `:940-953`,
`:1253-1257`, `:2033-2041`, `:4298-4385`), `dlls/winemac.drv/window.c` (`:46`, `:97-137`, `:943-970`,
`:1243-1258`, `:1280-1285`, `:1850-1851`, `:1986`, `:1710-1798`, `:1852-1872`, `:2105`), `dlls/winemac.drv/dxmt_objc.m` (`:38-72`),
`dlls/winemac.drv/cocoa_event.m` (`:486-540`), `~/cs2-patch/dxmt-fork/src/dxmt/dxmt_presenter.cpp`
(`:16-21`), `…/winemetal/unix/winemetal_unix.c` (`:1496-1529`), `scripts/diag-colours-patch.py`,
`scripts/layer-gap.py`, `scripts/strip-module-ab.sh`, `scripts/video-gap-battery.sh`,
`scripts/drag-session.sh`, `scripts/livedrag-probe.sh`, `scripts/video-blue.swift`,
`scripts/build-winemac.sh` (`:36-37`). **Added by the rework (2026-10-27):** nested `d:window.c`
(`:871`, `:1758`, `:1830`, `:2046`, `:2129`, `:2144`, `:2200` — the TRACE formats S6a parses),
`scripts/full-client-episodes.py`, `scripts/band-counts.py`, `scripts/cell-fingerprint.sh` (`:163`),
`scripts/winlist.swift` (`--displays`), `scripts/livedrag-probe.sh` (`:165-172`, `:212-213`,
`:265-266`), `scripts/video-gap-battery.sh` (`:31`, `:52-59`, `:74`), `scripts/video-blue.swift`
(`:113-121`). **Added by pass 3 (2026-10-27):** nested `d:window.c` (`:982-983`, `:1001`,
`:1769`, `:1776`, `:1796`, `:1833-1847`, `:1976-1983`, `:2109`, `:2127-2132`), `scripts/steam-render-cell.sh`
(`:54`, `:77`), `scripts/video-gap-battery.sh` (`:68-72`, `:104-106`, `:114-115`, `:131-133`,
`:197-199`), `scripts/full-client-episodes.py` (`:192`), `scripts/build-winemac.sh` (`:34-37`),
`scripts/winlist.swift` (`:25-32`), `scripts/livedrag-probe.sh` (`:183-192`, `:265`),
`scripts/diag-colours-patch.py` (`:100`), `scripts/band-counts.py` (`:46`),
`scripts/first-drawable-stamp-patch.py` (`:15`). **Added by pass 4 (2026-10-29):** nested
`d:window.c` (`:968-972`, `:1000`, `:1817-1818`, `:1845-1847`, `:2024-2025`, `:2114-2133`),
`d:cocoa_window.m` (`:937-950`, `:4449`), `d:macdrv_cocoa.h` (`:540`), `scripts/full-client-episodes.py`
(`:50`, `:161-165`), `scripts/video-gap-battery.sh` (`:180-183`, `:199-200`),
`scripts/diag-colours-patch.py` (`:161`), `scripts/first-drawable-stamp-patch.py` (`:63-69`),
`scripts/s1a-timing.py`, `EXPERIMENTS.md` (C62 `:1028`, C63 `:1029`, C65 `:1031`).
