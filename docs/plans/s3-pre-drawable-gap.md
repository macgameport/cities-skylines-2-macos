# The S3 pre-drawable gap — the child's own layer before its first drawable

**Status: NOT YET CHECKED — run `check it` before any build.** Fable pre-review 2026-09-07
(inline, one model, not a check-it pass — see § Review log): the first draft's central claim was
wrong on z-order and its ownership claim was wrong on provenance; both are corrected below.
Tracker: [issue #13](https://github.com/macgameport/cities-skylines-2-macos/issues/13); the
observation it splits from is [#12](https://github.com/macgameport/cities-skylines-2-macos/issues/12);
umbrella [#1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: cs2
`43227c7`; nested winemac `main` = `52789ff`, `core` = `63a0cec`, `aquadran` = `fe281fe`; pristine
winehq tree `~/cs2-patch/build-1116/wine-11.16/`; installed daily driver = stage 1
`2a251a4b2510fb84`. Line numbers are against nested `main` and name their file; unqualified `:N` is
`cocoa_window.m`; `pristine :N` is the winehq 11.16 tarball's copy.

> ⚠ **This document REDIRECTS issue #13's stated direction.** #13 proposed deferring
> `retire_superseded_layers`. § 2.3 shows that cannot work on its own — the new generation sits
> *above* its predecessor — but § 2.5 measures a window in which a companion form of it can. Read
> § 2 before § 4.

## 1. What is already established (do not re-derive)

| | |
|---|---|
| **C55** | The one-frame black full-client host occurs on the pre-stage-1 baseline `cd79fc463795939f`. **Architectural — neither stage introduced it.** |
| **C56** | Its surface is **S3, the child's own offscreen layer before its first drawable** (`Tblue=100 %` on the diag build). Blue is a positively rendered colour, so it is a **real display gap, not a capture artifact**. C56 also establishes that the remote layer's *background* composites through the host before any drawable exists. |
| **C58** | It is a **single frame, ≤ 25 ms**, covering ~half the recorded client area. 4 episodes in 12 valid runs — **~0.3 per drag**. |

⚠ **What is NOT established, and was mis-stated in this document's first draft:** the figure
"2331 intervals, median 127 ms, 35.9 s of a 35.4 s drag" is **the swapchain re-create cadence**,
not an exposure — `scripts/layer-gap.py`'s own header says so ("127 ms is simply the 120 ms step
period … Do not quote it as a gap duration"). **The per-generation pre-drawable duration — create
to first drawable — has never been measured.** Every argument below that depends on it is marked
as depending on it, and test S1 measures it first.

## 2. The mechanism, read from source (2026-09-07)

### 2.1 Which layer S3 is, and whose code it is

`scripts/diag-colours-patch.py:64-72` paints blue onto `offscreen_layer.backgroundColor` and says
in situ that it "Runs in the GPU process." That layer is `CAContextSwapChain`'s, `:4303`,
constructed at `:4327-4342`:

```objc
offscreen_layer = [[CAMetalLayer alloc] init];          /* :4327 */
offscreen_layer.framebufferOnly = YES;                  /* :4337 */
offscreen_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);   /* :4339 */
```

**The black is set unconditionally at construction, before any drawable exists.** On a production
build that black is exactly what a user sees in the gap; the diag build only recolours it.

**It is upstream wine's code.** The line is at `pristine :4119` in the untouched winehq 11.16
tarball, inside a `CAContextSwapChain` that is also pristine (`pristine :4080`), created from
`pristine window.c:1188`. So is the **host** side: `CALayerHost` (12 references), 
`addCALayerHostViewWithContextId` (`pristine :725`), `macdrv_create_remote_layer` and
`WM_MACDRV_CREATE_REMOTE_LAYER` are all upstream. What this project added is the cross-process
plumbing on top: the `child:` parameter, `remote_layer_children`, `retire_superseded_layers`,
per-child frames and zPosition, and the 120 ms deferred host background. **Consequently the S3
flash exists in stock wine for any recreated CAContext-hosted swapchain**, and a change at
`:4339` is a change to wine core — § 5.

### 2.2 The publish happens strictly before the first present

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
rectangle of the correct size. `OnMainThread` is synchronous (`cocoa_event.m:486-488`).

### 2.3 Why the predecessor cannot be the covering — and why #13's deferral cannot work alone

The owner handles the posted message at `window.c:1710-1766`: it adds the new host
(`macdrv_window_create_ca_layer_host_view` → `addCALayerHostViewWithContextId`, `:832`, which
`addSublayer`s it at `:890`), sets its zPosition, and **only then** calls
`retire_superseded_layers` (`window.c:1761`), which releases every other host mirroring the same
child. Retire-at-create is deliberate; its rationale is on the function at `window.c:943-945`.

**But the new generation is on top of the old one.** `paint_order_zpos` (`window.c:130-137`) keys
zPosition on the child **hwnd**, so two generations of one child share one zPosition, and Core
Animation draws equal-zPosition siblings in sublayer order — `addSublayer` appends. The comment at
`:940-942` describes exactly this ("a client that recreates a swapchain on every resize puts the
last-recreated layer on top of live content"; zPosition cannot separate generations of the *same*
window). And C56 measured that the remote layer's background composites through the host before
the first drawable. So **from the owner's first commit of the new host, its black covers the child
rect whether or not the predecessor is still in the tree** — the predecessor is underneath.

Two consequences:

1. **The first draft named the predecessor as what covers the gap; that was wrong**, and
   **#13's proposal — defer the retire until the replacement presents — cannot cover anything by
   itself.** A held predecessor sits beneath an opaque black layer. B (§ 4) is dead as a
   standalone candidate.
2. **What actually keeps the gap rare has a simpler null hypothesis than any covering agent: the
   gap is rare because it is short.** If the child's first present typically lands within one
   display refresh of the owner's commit, nothing needs to cover it, and the ~0.3/drag episodes
   are the tail where the first drawable is late by ≥ 1 refresh. This is consistent with C58
   (every episode exactly one frame) and with § 1's correction (the duration is unmeasured). **S1
   measures it before any candidate is chosen.**

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
to them is § 2.1's (the black's only visible effect on a `framebufferOnly` layer whose drawable
fills its bounds is the pre-drawable flash).

### 2.5 The signal-free window: the child creates the new swapchain BEFORE destroying the old

Measured 2026-09-07 from the trace already on disk (`~/cs2-patch/strip-ab/20260906-140732/`
`…-r1-baseline/stdout.txt`, one full-coverage drag, baseline module), pairing every
`retiring superseded layer ctx O … (replaced by N)` with `WM_MACDRV_CREATE_REMOTE_LAYER … N` and
`WM_MACDRV_RELEASE_REMOTE_LAYER context_id O`:

| | |
|---|---|
| creates / retires / releases | 300 / 285 / 271 |
| `RELEASE(old)` **after** `CREATE(new)` | **271 of 271** (0 before) |
| `RELEASE(old) − CREATE(new)` | min **33 ms** · p10 106 · median **126** · p90 491 · max 58 561 (a C60 stall) |
| `RELEASE(old)` arriving after its own retire (handler skips as untracked) | 271 of 271 |
| predecessors that never received a RELEASE at all | 14 |

So: **the child keeps the old context alive for at least 33 ms — typically one drag step — after
creating its replacement**, and today the owner discards that live, fully-drawn predecessor at the
replacement's create, ~100 ms before the child would have. That is a window in which a
*transparent* new generation over a *held* predecessor would show the last real frame with no
signal from anyone. The 14 never-released predecessors are the C30 leak class that
retire-at-create exists to bound, so any hold must keep that bound (§ 4, candidate D).

**Inferred, not measured:** whether the child destroys the old swapchain *after* the new one's
first present (the sane resize ordering — in which case D closes the gap fully) or before it (in
which case D narrows it by the window above and no more). S1 (ii) measures it.

## 3. Why #7's candidates do not reach this

Unchanged from #13, restated so this doc stands alone: #7's three candidates all target the **host**
background — the area a stale or reframed host fails to cover. S3 is a different surface. The host
is fine; the child's own layer is the thing with no content. #7 candidate 1 changes the gap's
colour, not its existence; candidate 3 moves black between host and content view; stage 2 is ruled
out on other grounds (C54).

## 4. Candidates

| | candidate | cost | what it does not do |
|---|---|---|---|
| **A** | **Drop the child's black background** (`:4339`) — or defer it on the § 2.4 pattern. On a `framebufferOnly` layer whose drawable fills its bounds, the background's only visible effect is the pre-drawable flash, so *drop* is the principled form and *defer* the conservative one | one line (drop) or ~10 (defer); wine core | Makes the pre-drawable layer **transparent**, so what shows is whatever is beneath: today the content view's own layer (C61's strip surface), because the predecessor is retired in the same handler. A alone likely converts a black flash into a stale-content flash |
| **B** | Defer the retire (#13's direction) | — | **Cannot work alone** — § 2.3. Retained only as the second half of D |
| **C** | Publish after the first present — move `macdrv_create_remote_layer` (`:4359`) to the child's first drawable | removes the race at its source | **Wine has no first-present signal.** `macdrv_client_surface_present` (`window.c:1243-1256`) is wine's generic `client_surface` `.present` callback — it toggles which `cocoa_view` is unhidden and carries no drawable; `layer-gap.py` used it as "present" and measured the step cadence. DXMT owns the present (`macdrv_swapchain_get_layer` hands it the layer). A hook is either a `CAMetalLayer` subclass overriding `nextDrawable` (fires at first *acquire*, before render — narrows, does not close) or a DXMT-side notification (crosses into `~/cs2-patch/dxmt-fork`, where the no-PR rule applies) |
| **D** | **A + a one-generation hold.** Drop the black, and change `retire_superseded_layers` to keep the **two** newest generations instead of one: the predecessor is retired at the *next* create (N+1) or at its own `WM_MACDRV_RELEASE_REMOTE_LAYER`, whichever comes first — the release handler (`window.c:1767-1790`) already frees a still-tracked id | A's line + a small change to one owner-side function; **no signal needed**; bounded at 2 hosts per child, so the C30 leak class stays bounded | Closes the gap only for as long as the child keeps the old context alive after the new one's create — ≥ 33 ms, median 126 ms (§ 2.5). Whether that spans the first present is S1 (ii). In the *grown* region of a resize there is no predecessor content; that is #7's strip, not this |

**Recommended for the check to adjudicate: D, with A alone as a control arm.** C is the only
candidate that eliminates the race rather than covering it, and it is also the only one that needs
code outside wine.

## 5. Where a change belongs (upstream form)

§ 2.1 measured that `:4339` and the whole CAContext/CALayerHost mechanism are pristine winehq. So:

- **A and D are wine-core changes.** Wine is a separate project with its own process; the dxmt
  no-PR rule does **not** apply to them. The natural vehicle is
  [bug 60263](https://bugs.winehq.org/show_bug.cgi?id=60263), whose published core patch already
  modifies `CAContextSwapChain` (the `child:` plumbing; 5 hits in
  `scripts/winemac-crossprocess-child-core.patch`). The claim a maintainer will act on — *"stock
  wine flashes black for one frame on every recreated hosted swapchain"* — is § 2.1 + C56 and
  should be stated as such, with the § 2.5 numbers.
- **Only C's DXMT-side hook** touches `~/cs2-patch/dxmt-fork`, where `CLAUDE.md` § ⛔ applies:
  no PR, a comment with exact locations, AI assistance disclosed.
- Core vs glue: `retire_superseded_layers` is in **core** today (the 60263 patch). D changes it in
  place; there is no boundary decision to make unless the check finds one.
- #6's two decisions were parked on *"wait for stage 2 to settle"*; stage 2 settled (C54, ruled
  out). That hold has expired independently of this plan.

## 6. Test plan

Instruments exist; the diag build (`scripts/diag-colours-patch.py`) and `CAPTURE=video`
(`scripts/video-gap-battery.sh`, C58) resolve the artifact at a 25 ms cadence, and
`scripts/strip-module-ab.sh FRAMES=300` scores #7's strip. ⚠ Score the top band as black **or**
any diagnostic colour — a true-black threshold cannot fire on a diag build (C56; the C49/C53/C56
scorer-bug family). ⚠ Cyan is unsafe on the store page (Steam artwork; C61) — use the Library page
for any cyan cell.

| id | test | pass / what it decides | mutant |
|---|---|---|---|
| **S1** | **Measure what § 1 says is unmeasured.** Diag build, video capture, one full-coverage drag, n ≥ 10. (i) Per generation: `CREATE(N)` in the trace → first video frame in which N's rect is no longer blue = the **pre-drawable duration**; report the distribution. (ii) Per generation: `RELEASE(N−1)` vs that same first-content frame — **does the child destroy the old swapchain before or after the new one shows content?** | Decides the null hypothesis of § 2.3 (short gap: median ≪ 25 ms) and D's reach (ii). A refutation of both sends this document back to § 2, not forward. ⚠ 25 ms resolution; timestamps are the trace's and the video's presentation clock — align them on a known event (the first CREATE after drag start) | n/a — diagnostic |
| **S2** | **Baseline rate**, installed stage-1 driver, `FRAMES=300`, video, n ≥ 12 | reproduces C58's ~0.3 episodes/drag within its spread — the denominator every candidate is measured against | n/a |
| **S3** | **D built**, prod module: episodes/drag vs S2 | separable **below** S2 at the C54 standard (Mann-Whitney); host count per child never exceeds 2 in the trace | (a) restore `:4339`'s black → the S2 rate returns; (b) restore keep-one in `retire_superseded_layers` → A-alone behaviour (S4's rate) returns |
| **S4** | **A alone, as a control arm**, on C42's cyan content-view build, Library page | if A merely relocates the artifact, cyan appears in the child rect at the rate blue did — **that is A-alone failing**, scored not argued. Under D cyan must not appear there (the predecessor covers) | restore `:4339`'s black → blue/black returns at the S2 rate and cyan vanishes |
| **S5** | **T3 (human), narrowed.** James drags on the D build | verdict verbatim: any full-client flash still visible by eye? any *new* artifact (a stale predecessor showing after the new generation should have covered it)? | none — a human drag is not repeated per mutant |
| **S6** | **No regression on #7's strip**: `strip-module-ab.sh MODULES="stage1 D" N=7 FRAMES=300`, right band, growing frames | stage 1's separation from baseline (p = 0.0079, C54) preserved; D not separable *above* stage 1 | none — structural |
| **S7** | **The leak bound** (C30 class): synthetic churn with the 14-never-released pattern (a child whose old context never sends RELEASE) | every predecessor is retired by the create after next; `remote_layer_children` never holds > 2 ids per child; boot-verify PASS on the game (the `MetalViewSwapChain` path is disjoint but shares the module) | drop the "or at the next create" half of D's retire → the count grows without bound in the churn |

Every listed mutant is **applied to real source and observed red, then restored green**. "Argued
red" is not red.

## 7. Exit criteria

1. **S1 run first**, both halves reported with their distributions, before any candidate is built.
   If (i) shows the gap is typically shorter than one refresh, that is recorded as the mechanism of
   rarity and § 2.3's null hypothesis becomes a ledger row.
2. A candidate is chosen with its **cost and reach stated** from S1 (ii) — D closes or D narrows.
3. S3 separable below S2 at the C54 standard; S4 shows A-alone's relocation, if any, as a number;
   every mutant observed red then green.
4. S6 green; S7 green including boot-verify.
5. T3 (S5) recorded verbatim in the ledger.
6. Upstream form settled per § 5: the wine-core change described for 60263 with the § 2.1 + § 2.5
   claims, AI assistance disclosed; no dxmt PR under any outcome.

## 8. Rollback

The installed daily driver is stage 1 `2a251a4b2510fb84`, kept. Any candidate ships as a separate
module built through `scripts/build-winemac.sh` and is only installed after S3/S6/S7; reverting is
reinstalling `2a251a4b2510fb84`. No prefix or settings change is involved.

## Review log

Not yet checked. **Run `check it` before the first build commit.**

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-07 | pre-review of the first draft (not a check-it pass) | inline: z-order · provenance · present-hook · trace ordering | one model, direct reads + one trace measurement | Fable 5.1 | cs2 `43227c7`, nested `main` `52789ff`, pristine `wine-11.16/` | **first draft needs-rework → reworked in place** (§ 2.3 covering claim wrong on z-order; § 5 ownership wrong — upstream wine, not DXMT; § 1 quoted a cadence as an exposure; S1 had no wine-side source; S4's mutant was inverted) |

**Key paths** (re-check if these move): `dlls/winemac.drv/cocoa_window.m` (`:832-894`, `:940-953`,
`:4298-4385`), `dlls/winemac.drv/window.c` (`:128-137`, `:943-970`, `:1243-1256`, `:1710-1798`),
`dlls/winemac.drv/cocoa_event.m` (`:486-488`), `scripts/diag-colours-patch.py`,
`scripts/layer-gap.py`, `scripts/strip-module-ab.sh`, `scripts/video-gap-battery.sh`.
