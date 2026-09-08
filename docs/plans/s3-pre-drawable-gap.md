# The S3 pre-drawable gap — the child's own layer before its first drawable

**Status: Triple-checked 2026-09-07 — build-ready-with-fixes (pass 1 needs-rework on the test plan,
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
> plan's in-situ S0 is running as confirmation.
> **D is BUILT (2026-09-07): module `4975a8c9a720773f`, nested branch `d` at `72184cd`, compiles
> clean, NOT installed and NOT merged to `main`.** It starts from the re-check's `d-sim` `b2186a0`
> and adds the two things § 4.1 required that the simulation left out — see § 4.1's build note.
> `build-winemac.sh` gained the `WINEMAC_BRANCH` knob § 8 asked for, so a candidate never has to
> land on `main` to be built. **Owed before D can be judged: S3 · S4 · S6 · S7 · T3.**
> Commit: this one. Nothing was installed; the daily driver is still stage 1 `2a251a4b2510fb84`
> and the nested tree is back on `main` `52789ff`, clean. Build order position: step 1 of
> *instruments → S1a → S0 → § 7 decision rule → D* is complete; **S1a has not been run.**
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
> `scripts/drag-session.sh` · `scripts/strip-module-ab.sh` · `scripts/video-gap-battery.sh`.

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
refusal, the network hold and the **loadavg < 12 gate** (`:63-68`); `strip-module-ab.sh` has **no
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
or a **shape gate** (full-client = cyan bbox w ≥ 100 px **and** h ≥ 50 % of the window; the C61
growing-edge column is ≤ 4 drag steps wide).

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

| id | test | pass / what it decides | mutant |
|---|---|---|---|
| **S0** ✅ **MECHANISM ANSWERED 2026-09-07 — see C63; in-situ arm running** | **A's transparency, before anything is built on it.** A-drop (with `--noblue`) on the diag base, cyan content view (`--cyan`), Library page or shape-gated, video, n ≥ 12 | three outcomes: **cyan** full-client episodes at ≥ the blue rate ⇒ the pre-drawable layer is transparent, A/D proceed; **black** full-client episodes at the blue rate ⇒ A-drop is inert ⇒ A becomes deferred `opaque = NO` + no background on the `:847-861` pattern, S0 re-run; **neither** ⇒ re-read the scorer before believing it (C56). ⇒ **RESULT: outcome 1 — the pre-drawable layer IS transparent, so A/D proceed and the `opaque = NO` fallback is not needed.** Reached by a **direct probe** (`scripts/calayerhost-probe.m`, C63) rather than by this row's battery: the question is a compositing MECHANISM, and § 2b says build the artifact and run it. Three arms hosted side by side over one green backdrop, read from ONE capture, in wine's cross-process topology; control `0,0,0` and A-drop `0,249,0` in the same frame, 4 of 4 same-process and 4 of 5 cross-process valid runs. ⚠ The battery arm below is now a **confirmation through the real DXMT pipeline**, not the decider — module `d79c80d951b3a5e9` (A-drop + `--cyan`, `--noblue`), `STEAM_PAGE=steam://open/games`, video, N = 12 | restore `:4339` and build **without** `--noblue` → blue returns (≥ 1 episode in 12) |
| **S1a** ✅ **RUN 2026-09-07 — see C62** | **Per-generation timing, trace only, one clock** — the stamp build (instrument-only; no candidate code), diag colours on, 10 full-coverage drags (~300 generations each). (i) `first-acquire(N)` and `presentedTime(N)` − owner host-commit(N) (`window.c:1717`). (ii) `RELEASE(N−1)` **and the child's detach block** vs `presentedTime(N)` | (i) **null upheld** if ≥ 90 % of generations present within one refresh (8.3 ms) of the host commit; report the fraction beyond 120 ms (D's cap). (ii) **D closes** if the child's detach follows `presentedTime(N)` in ≥ 95 % of generations, else **D narrows**, with the covered fraction. **The 95 % is fixed here, before the run**. ⇒ **RESULT: (i) null REFUTED — 0 of 2,924 within 8.3 ms; acquire is immediate (median +2 ms) but the PRESENT lags, median ~53 ms on the displaying child. (ii) detach follows present in 1,440 of 1,442 = 99.9 %, median +83.5 ms ⇒ D CLOSES.** ⚠ The present rate is **bimodal by child** — two long-lived children per run, one presenting 92–98 %, the other 19–31 %; never quote the pooled 50 % | n/a — diagnostic |
| **S1b** | Video per *visible* episode only (expect ~3 in 10 drags), via the aligner + `--rect`; 25 ms floor stated | confirms S1a's tail is what the eye can see; does not decide anything S1a decides | n/a |
| **S2** | **Baseline rate on the scorer's known-positive build**: `MOD=s1-diag` (C58's `50fdfe79898dac36`), N = 12, video | PASS = ≥ 1 blue episode (the scorer can fire — the C56 rule); the baseline rate is C58 + S2 pooled (24 drags) with an **exact CI** (4/12 alone is ~0.09–0.85/drag and decides nothing) | n/a |
| **S3** | **D-diag** (`--noblue --cyan`, page knob or shape gate), interleaved with S2's build, **n ≥ 15**; host bound from `live-hosts.py` | **closure**: 0 full-client cyan episodes, exact Poisson p ≤ 0.007 against the pooled rate; **narrows** (if S1a (ii) said so): decide on S1a's per-generation metric with n ≈ 60/arm interleaved with A-alone, video as confirmation only; max live hosts per child ≤ 2 | (a) restore `:4339` on the D-diag source, build **without** `--noblue` → blue returns, red = ≥ 1 episode in 12; (b) restore keep-one → this is S4's A-alone arm, **red observable under closure only** |
| **S4** | **A alone, the control arm**, same build recipe minus the hold | full-client cyan at the blue rate ⇒ A relocates the flash (black in production, `:1257`); under D that must not occur | restore `:4339` → **full-client** cyan episodes vanish (the C61 growing-edge column persists regardless — that is not this mutant's signal) |
| **S5** | **T3 (human)**, James on the D **prod** build | verdict verbatim: any full-client flash still visible? any *new* artifact — a stale predecessor showing after the new generation should have covered it, especially on **shrinks**? | none — a human drag is not repeated per mutant |
| **S6** | **No regression on #7's strip**, after (6): `strip-module-ab.sh MODULES="baseline stage1 D" N=7 FRAMES=300`, interleaved, loadavg-gated | stage 1 < baseline **reproduces in this run** (not against C54's stored numbers) **and** D's growing-frame right-band mean ≤ stage 1's + ½ (baseline − stage 1); plus a **shrink-frame clause** via `band-counts.py`'s grow/shrink split; child placement scored, since `:2105` changed | none — structural |
| **S7** | **The hold's bound**: `--norelease` mutant (8) + `shimmer-probe.sh churn` (`hosting-layer-tests.sh:254`) + `live-hosts.py`, ≥ 300 creates; then the terminal case — a child that recreates twice, stops, never releases, is destroyed; then `scripts/boot-verify.sh` (the game never constructs a `CAContextSwapChain` — `window.c:1298-1336` — but shares the module) | max live hosts per child ≤ 2 throughout; the terminal child's held pair drops to 0 after the root's next frame update; boot-verify PASS | (a) drop the next-CREATE exit → max grows monotonically (≥ 10); (b) disable the `:2033-2041` drain → dead pairs persist |

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
   a branch S0 closed. The in-situ battery arm is confirmation, and S3 should not start until it
   agrees.
4. S3 at the closure bar (0 episodes, n ≥ 15, exact p ≤ 0.007) or on the per-generation metric if
   S1a said narrows; S4 shows A-alone's relocation, if any, as a number; every mutant observed red
   then green, with the S1a-conditional ones marked.
5. S6 green including the shrink clause; S7 green including the terminal case and boot-verify.
6. T3 (S5) recorded verbatim in the ledger.
7. Upstream form settled per § 5: the wine-core change described for 60263 with the § 2.1 + § 2.5
   claims and the `:1257` answer, AI assistance disclosed; no dxmt PR under any outcome.

## 8. Rollback

The installed daily driver is stage 1 `2a251a4b2510fb84`, kept. Any candidate ships as a separate
module built through `scripts/build-winemac.sh` and is only installed after S3/S6/S7; reverting is
reinstalling `2a251a4b2510fb84`. No prefix or settings change is involved.

⚠ **`scripts/build-winemac.sh:36-37` refuses any nested branch but `main` and any dirty tree**, so a
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

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-07 | pre-review of the first draft (not a check-it pass) | inline: z-order · provenance · present-hook · trace ordering | one model, direct reads + one trace measurement | Fable 5.1 | cs2 `43227c7`, nested `main` `52789ff`, pristine `wine-11.16/` | first draft needs-rework → reworked in place (§ 2.3 covering claim wrong on z-order; § 5 ownership wrong; § 1 quoted a cadence as an exposure) |
| 2026-09-07 | **pass 1** | architecture (+ upstream-form/privacy) · correctness · platform-facts · test-plan audit | 4 independent agents, ≤ 15 tool calls each; every blocker spot-checked inline | Fable 5.1 ×4 | cs2 `3515efc`, nested `main` `52789ff`, pristine `wine-11.16/`, `dxmt-fork` | **needs-rework** (test plan) · build-ready-with-fixes ×3 → all folded the same day |
| 2026-09-07 | **fitted re-check** of the fold + builder-simulation | fold verification · build D on a scratch branch · compile · gates | 1 agent, ~15 tool calls; D built and compiled (`d-sim` `b2186a0`, digest `8ff5e4f30492304b`) | Opus 5 | cs2 `407348d`, nested `main` `52789ff`, pristine, `dxmt-fork` | **build-ready-with-fixes** — no blocker; nine omissions in § 4.1 / § 6 / § 8 folded the same day |

**Key paths** (re-check if these move): `dlls/winemac.drv/cocoa_window.m` (`:832-894`, `:940-953`,
`:1253-1257`, `:2033-2041`, `:4298-4385`), `dlls/winemac.drv/window.c` (`:46`, `:97-137`, `:943-970`,
`:1243-1258`, `:1280-1285`, `:1850-1851`, `:1986`, `:1710-1798`, `:1852-1872`, `:2105`), `dlls/winemac.drv/dxmt_objc.m` (`:38-72`),
`dlls/winemac.drv/cocoa_event.m` (`:486-540`), `~/cs2-patch/dxmt-fork/src/dxmt/dxmt_presenter.cpp`
(`:16-21`), `…/winemetal/unix/winemetal_unix.c` (`:1496-1529`), `scripts/diag-colours-patch.py`,
`scripts/layer-gap.py`, `scripts/strip-module-ab.sh`, `scripts/video-gap-battery.sh`,
`scripts/drag-session.sh`, `scripts/livedrag-probe.sh`, `scripts/video-blue.swift`,
`scripts/build-winemac.sh` (`:36-37`).
