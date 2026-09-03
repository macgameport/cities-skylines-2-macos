# Live resize — the black strip at the growing edge

**Status: DRAFT 2026-09-03 — not yet triple-checked; run `check it` before build.** Tracker:
[issue #7](https://github.com/macgameport/cities-skylines-2-macos/issues/7); umbrella
[#1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: cs2 `9a1ee73`;
nested winemac history `main` = `5d28d7b` (glue tip), `core` = `eddf167`; installed module
`cd79fc463795939f`; pre-D1/D2 backup `winemac.so.bak-preD12-20260902-221649` = `53c9443db3145f58`.
Line numbers below are against the nested `main` unless a branch is named.

**Scope.** One user-visible artifact: while a Steam window is being dragged larger, the newly
exposed strip along the growing edge is solid black until the hosted browser catches up. Not in
scope: the ~1-frame content gap at a swapchain recreate (C26 closed it to the probe's resolution),
the top-level's own GDI surface colour, matching Windows pixel-for-pixel, or offering any of this
upstream — this is a beyond-Windows quality fix for daily use (§2.4 says why).

---

## 1. The defect, measured (ledger C35)

| measurement | value | evidence |
|---|---|---|
| live drag by hand, 60 frames, right band ≥ 20 % true black (lum < 6) | **19 / 60**, worst **92.6 %** (frames 32, 09, 41, 50) | cell `livedrag-setup3`, `drag-*.png` |
| top chrome row, the two frames where the top edge was dragged | **100 %** (49), 97.6 % (46) | same |
| bottom band | not counted — the store page's own black artwork crosses the threshold | same |
| churn (programmatic resize), current module | 17 / 40 frames, right max 86.2 %, bottom max 100 % | cell `edge-post` |
| churn, pre-D1/D2 module `53c9443d` | 8 / 40, **identical maxima** | cell `edge-pre` |
| native macOS Steam client (James) | none, or very short-lived | observation |

The A/B settles the regression question: the artifact predates D1/D2. The counts across the two
churn runs are not comparable (different start sizes); the maxima are. Frame 09 is the picture to
keep in mind: the chrome row and the bottom bar already span the new width, the store page is still
at its old width, and the ~280 px between the page's right edge and the window's is solid black.

⚠ The first publication said 56 of 60 — a field-mapping bug in the scorer's summary (GOTCHAS
2026-09-03). The numbers above are the recomputed ones; `scripts/darkboxes.swift` is the scorer.

## 2. Mechanism, read from the code

### 2.1 The child side has no resize path

`CAContextSwapChain` (`cocoa_window.m:4191-4278`) is an offscreen `CAMetalLayer` whose bounds are
fixed at creation (`:4234`), background black (`:4232`), exported through a `CAContext`. There is
no method that changes its size. The only way a hosted child changes size is a **new swapchain**,
and CEF does exactly that on every size step — 417 `CREATE`s in one session (C30).

### 2.2 The owner side, per size step of a drag

1. CEF resizes its child HWND → `macdrv_WindowPosChanged(child)` takes the cross-process branch
   (`window.c:1984-2007`, D1) → `update_remote_layer_frame_for` (`:1884`) →
   `macdrv_window_update_ca_layer_host_frame` (`:4328`) → `updateCALayerHostFrame`
   (`:813-838`), which sets `host.frame` to the **new** rect at once (`:835`, actions disabled).
   The root's own `WindowPosChanged` runs the full pass `update_remote_layer_frames` (`:1909`)
   with the same effect — which is why the pre-D1/D2 module shows the same strip.
2. The host's remote content is still the **old** swapchain at its creation bounds. A `CALayerHost`
   shows the remote tree 1:1; `masksToBounds` clips, nothing stretches. The uncovered remainder of
   the host's frame shows **`host.backgroundColor`** — black, set 120 ms after creation by the
   deferred block at `:769-782`, which the hardening pass added to close the odd-pixel white sliver
   (GOTCHAS 2026-08-31 "Retina turns an ODD Win32 pixel size into a HALF POINT"). A host that has
   lived longer than 120 ms is black underneath.
3. The GPU process creates a swapchain at the new size → `WM_MACDRV_CREATE_REMOTE_LAYER`
   (`:1709`) → `addCALayerHostViewWithContextId` (`:758-811`) adds a **new** host at the new rect
   (transparent for its first 120 ms, then black) and `retire_superseded_layers` (`:946`) removes the
   old host at once (`:1760`).
4. The new host shows content when the GPU process presents its first frame. Under a continuous
   drag the cycle repeats every size step, so the visible state is mostly steps 1–3.

**Anchoring, measured (M0 frame 15):** when a host is reframed larger, its stale content stays at
the **top-left** of the new frame and the uncovered L-shape is at the right and bottom — so the
remote layer is effectively top-left anchored in the content view's coordinate space. A **shrink**
is not a clean clip: M0 frame 14 (2400x1500 → 2200x1360) shows the chrome row cut off at the top
and a black band at the bottom, i.e. content displaced, not cropped. Both directions are therefore
in scope for T7, and the two top-edge live-drag frames (chrome row black) are the same displacement
seen from the other side.

**The black sources, measured** (M0/M0b, §2.3), and what lies beneath them:

| source | what paints it | churn frames ≥ 20 % of the right band (M0 / M0b, of 40) | fix family |
|---|---|---|---|
| **S1** | the *reframed old* host's black background, uncovered where the stale content ends (step 2) | **9 / 10** (green) | keep content and frame in lock-step: scale the stale content (§4 stage 1) |
| **S2** | a *new* host older than 120 ms whose first frame has not arrived (step 3) | not cleanly measurable yet — the diagnostic red is also the store banner's colour; T0 re-runs with magenta | the deferred-black timing (§4 stage 3, conditional) |
| **S3** | the child's own offscreen `CAMetalLayer` background (`:4232`, black) before its first drawable | **0 / 0** — painted blue in M0b, and no blue appeared in any frame | none needed |
| **S4** | **beneath every host**: the window has grown but no host covers the strip yet, so the content view's layer shows — its `contents` is the GDI window-surface image (`:597`), black for Steam's root, which never GDI-paints | **6 / 8** (black with no diagnostic colour) | stretch the full-client hosts with the root during live resize (§4 stage 2) |

S4's *why* is an inference: the root's `WindowPosChanged` has run (the content view is already the new
size) but the app has not yet resized its child HWNDs, so the hosts still mirror the old child
rects and nothing covers the new strip. T0 verifies it from the `+macdrv` trace (root rect vs child
rects per frame). On Windows that strip is the top-level's own client area with a NULL class brush —
no erase, stale pixels — so black there is, again, Windows-faithful.

### 2.3 M0/M0b — the colour diagnostics (executable spec)

Rather than argue which source dominates, colour them: a diagnostic module with the create-path
background **red** (`:781`) and the reframe-grow path **green** (a line before `:835` that paints
the background when the new frame is larger), churned with frames kept, scored by
`darkboxes.swift`, which now counts pure red and pure green per band.

**Result (cells `m0-colour`, `m0b-colour`, 40 churn frames each, ledger C36):** green (S1) in 9 and
10 frames at 78–86 % of the right band; black with **no** diagnostic colour (S4) in 6 and 8 frames
at 77–86 %; **blue never** (S3 ruled out); red unusable because the store banner is red — the top
band, which the banner does not reach, shows red only where the content was displaced. Two lessons
folded into `darkboxes.swift`'s header: choose diagnostic colours the page cannot contain (magenta,
green, blue), and parse its output by label, never by position.

### 2.4 Why the native client does not show it, and what Windows shows

Chromium's macOS resize path — `ui/accelerated_widget_mac/window_resize_helper_mac.h`, verified
2026-09-03 from chromium.googlesource.com — waits *"inside AppKit drawing routines on the UI thread
for the compositor to produce a frame of same size as the NSView"*, *"until a timeout occurs"*, so
that *"the window size and the size of the contents being drawn in that window are resized in
lock-step"*. Wine has no hook into CEF's compositor, and Steam's Windows build has no such helper.

What Windows would paint into the exposed area is the class background brush. Measured
2026-09-03 with `win-resize-driver.exe classbg` (new verb):

| window | class | `hbrBackground` |
|---|---|---|
| root `0x1011E` | `SDL_app` | **NULL** (no erase) |
| both hosted children | `CefBrowserWindow` | **NULL** |
| their `Chrome_WidgetWin_1` | Chromium's widget | solid brush, **colour 000000 (black)** |
| `Chrome_RenderWidgetHostHWND` | | `COLOR_WINDOW+1` → white, beneath the widget |

So on Windows the exposed area of the resized CEF widget is erased **black** by Chromium's own
brush until the compositor presents. Black at the growing edge is therefore consistent with the
Windows behaviour (unverified on a real Windows machine — nobody here has one), and *any* fix is a
beyond-Windows nicety that only makes sense because the native Mac client sets the bar. That is
also why none of this goes to wine bug 60263: wine's bar is Windows.

## 3. Options

| | option | verdict |
|---|---|---|
| A | paint the class-brush colour (issue #7's first candidate) | **dead** — measured black; it is the status quo. Recorded so it is not re-proposed. |
| B | **scale the stale host to its new frame** until the replacement presents — what a native `CAMetalLayer` does during live resize | **build** — S1 is measured (stage 1) |
| B′ | during a live resize, stretch the hosts of **full-client** children with the root, before the app resizes those children | **build, guarded** — S4 is measured (stage 2) |
| C | re-arm the 120 ms deferred black on every reframe, so a host that is still being resized never turns black before its content arrives | conditional on T0's magenta count (stage 3) |
| D | do nothing (Windows-faithful) | the upstream answer; not the daily-use answer |

**Decision, from M0/M0b:** S1 and S4 are each roughly a quarter of churn frames and neither is the
child layer, so B and B′ are both needed and are independent (different code paths: the child's own
reframe vs the root's full pass). C waits for a clean S2 number. Nothing here changes what Windows
would show; §2.4 stands.

## 4. Design — three stages, each measured before the next

All owner-side; stage 1 in `cocoa_window.m`'s `WineContentView`, stage 2 in `window.c`'s root pass;
no change to the child side, the message protocol, the paint order, D1/D2, or DXMT. Ship and
measure stage 1 before writing stage 2: T2's per-source counts say what each stage bought.

### 4.0 Stage 1 = B (S1) · Stage 2 = B′ (S4) · Stage 3 = C (S2, conditional)

### 4.1 Content size is known: it is the creation rect

The remote content's size only changes through a recreate (§2.1), and a recreate arrives as a new
context id with a new host. So the size the content was created at **is** the content size for the
host's whole life. Store it beside the host: a second dictionary `_caLayerHostContentSizes`
(`NSNumber` context id → `NSValue` `CGSize`) set in `addCALayerHostViewWithContextId` from the
snapped frame (`:784`), removed in `removeCALayerHostView` (`:856`). ⚠ The create handler reads the
child's **window** rect (`window.c:1723`), the child's swapchain is created from its **client** rect
(`:1187`); for CEF children these coincide (no border), and T6 checks the stored size against the
frame the content actually fills.

### 4.2 Reframe = position + scale, never a bare frame

In `updateCALayerHostFrame` (`:827-838`), replace `host.frame = frame` with:

```objc
CGSize content = [self contentSizeForHost:contextId];      /* creation size, §4.1 */
CGFloat sx = content.width  > 0 ? frame.size.width  / content.width  : 1.0;
CGFloat sy = content.height > 0 ? frame.size.height / content.height : 1.0;
host.anchorPoint = CGPointMake(0, 0);                       /* Cocoa: bottom-left */
host.bounds = (CGRect){ CGPointZero, content };
host.position = frame.origin;
host.transform = CATransform3DMakeScale(sx, sy, 1.0);
host.magnificationFilter = (sx == 1.0 && sy == 1.0) ? kCAFilterNearest : kCAFilterLinear;
```

inside the existing `CATransaction` with actions disabled. A host whose frame matches its content
gets the identity transform, i.e. today's behaviour exactly. `snap_host_frame_to_view_edges`
(`:508`) still runs on the target frame first; the 1-px seam logic is unchanged because the scaled
host covers the same snapped rect. The create path (`:803`) sets an unscaled host, as now.

**Anchor.** M0 frame 15 shows the stale content pinned to the **top-left** of a grown host, so the
content view's layer space is effectively flipped and the corner to keep is the top-left: set
`anchorPoint` to the top-left in that space (`(0,1)` if the layer is unflipped, `(0,0)` if
`geometryFlipped` — read `WineContentView`'s flip state at build time rather than assume it) and
`position` to the frame's top-left. The shrink displacement in frame 14 says the *current* setter
does not keep that corner on a shrink; stage 1 must, in both directions. T7 measures both.

**Retire timing** is untouched: the replacement still retires the old host at CREATE (`:1760`),
so C26's "never unhosted" property holds.

### 4.2b Stage 2 — B′: stretch full-client hosts with the root during live resize (S4)

In `update_remote_layer_frames` (`window.c:1909`, the root's full pass), a hosted child whose rect
**equalled the root's client rect before this move** is a full-client child; for it, use the root's
**new** client rect as the target frame instead of the child's (still old) rect, so its host is
stretched with the root in the same pass — the strip is covered before the app has resized the
child. When the child follows (its own `WindowPosChanged`, D1), the frame matches and nothing
changes. **Guard:** only while the window is in live resize (`-[NSWindow inLiveResize]`, observed
on the owner's main thread and mirrored into `macdrv_win_data`), and re-derive every host from the
child's *actual* rect at `windowDidEndLiveResize` — so an app whose child does **not** follow the
root is misrepresented for the duration of the drag at most, never afterwards. Programmatic
resizes (`SetWindowPos`, the churn probe) are not live resizes; T2's churn measures stage 1 only
and T3's drag measures both. This is a heuristic and is listed with D3's three.

### 4.3 C — re-arm the deferred black on reframe (if M0 says S2)

The deferred block (`:773-783`) fires 120 ms after creation. Under a recreate storm a new host can
pass 120 ms before its first frame. Change: keep the dispatch, but have `updateCALayerHostFrame`
record `host.lastReframe = now` and have the block re-schedule itself while `now - lastReframe <
120 ms`. A host that is still being resized never turns black; a host that has settled turns black
120 ms after its last reframe, which is what the seam fix needs. Measured, not argued: T2 with C
alone must move the red count in M0's terms.

### 4.4 Which patch each hunk lands in

`updateCALayerHostFrame`, `addCALayerHostViewWithContextId` and `removeCALayerHostView` are core
(`stock..core`); the deferred background block is glue (the glue patch's own description names it).
So B is a `core` commit and C is a `glue` change. **Both go through the generator's invariants**:
commits land on `core`, `main` is rebuilt as aquadran → core → glue, `--check` must print three
`ok` lines plus the three invariants (GOTCHAS 2026-09-03 "a generator with a relative range").
The builder does not commit on `main` after glue; the generator refuses if they do.

## 5. Test plan

The battery instruments already exist: `hosting-layer-tests.sh` (C29 T0–T8, churn, blackout),
`shimmer-probe.sh` and `livedrag-probe.sh` with the EXPOSED-EDGE line, `darkboxes.swift` with
per-band and per-colour counts. Every mutant below is applied to real source, built, observed red,
then restored — "argued red" is not red.

| # | test | pass | mutant (observed red) |
|---|---|---|---|
| T0 | **attribution, completed for churn (§2.3), still owed for the live drag and for S2** — the diagnostic module rebuilt with **magenta** (create path), green (reframe-grow), blue (child layer); one churn cell with the `+macdrv` trace to confirm S4's root-vs-child rect timing; one live drag by James | per-frame magenta/green/blue/black split for the drag; the trace shows root rect ≠ child rects in the S4 frames | none — it is the measurement stages 2–3 key on |
| T1 | **spike: a transformed `CALayerHost` scales its remote content** — a mutant that applies a fixed 1.5× scale to every host on `main`, one churn cell | the page renders enlarged in the frames (a feature's width measured by `pixel-probe strip` grows ×1.5) | **gate, not a test** — if the host ignores the transform, B is dead and §3 falls back to C/D |
| T2 | **churn EXPOSED-EDGE** on the built module, same churn as `edge-post`, scored per source with the diagnostic colours of T0 | after stage 1: green (S1) frames 9–10/40 → **0**; black-no-colour (S4) unchanged (churn is not a live resize); after stage 2 under a live drag (T3): both → **≤ 1**; right-band black maximum 86 % → **< 20 %** | M1: `host.transform = CATransform3DIdentity` → green returns to 9–10/40 |
| T3 | **live drag by James**, `livedrag-probe.sh` with `WAIT=1800` | right band ≥ 20 %: 19/60 → **≤ 2/60**; and his verdict on the stretch (a rubbery page for ~100 ms is the native look; a persistent distortion is a fail) | same as M1, one run |
| T4 | **the seam fix still holds** — the blackout sequence 2400x1500 → 2399x1499 → 2400x1500 | interior 85/84/85-class, **0 bright edges** on the odd size, exactly the C29 row | M2: skip the snap → the 1-px white seam returns (already an observed-red mutant in C29's history) |
| T5 | **C29 battery + boot** — `hosting-layer-tests.sh` T0–T8, `boot-verify.sh` | all as in C32/C33: T0 disjoint, T1 green, T2 restack + restore, churn/static 0 gaps, 0 acquire failures, 0 GPU crashes, `VERDICT: PASS` | — |
| T6 | **no host stays scaled after the drag settles** — a `TRACE("host %u scale %.3f,%.3f")` on every reframe; after 3 s of rest the last trace per surviving host is 1.000,1.000 | every surviving host at identity; stored content size equals the host's bounds | M3: never store the content size (falls back to `frame`) → hosts report scale ≠ 1 at rest, or never scale at all |
| T7 | **anchor, both directions** — four churns with the diagnostic colours: width-only grow, width-only shrink, height-only grow, height-only shrink (`churn <hwnd> 2200x1500 2400x1500`, …), plus a top-edge live drag (James) | on a grow the content stays top-left and the new area is stretched content, never background; on a shrink the top-left content is what remains (M0 frame 14's cut-off chrome row and bottom black band are gone); the chrome row is never black in the top band | M4: the other corner as anchor → the content jumps on one of the four churns; M5: skip the shrink handling → frame 14's displacement returns |
| T8 | **C alone** (only if built) | the M0 red count under churn → 0 with B disabled | M5: do not re-arm on reframe → red returns |
| T9 | **the reference regenerates** — `regen-winemac-patches.sh --check` | three `ok` + three invariants; core applies to pristine 11.16 and compiles with the warning set unchanged (the T-gate from the upstream-form plan) | — |

**Fixtures:** the Steam store page (two hosted `CefBrowserWindow` siblings, black artwork in the
lower tiles — which is why only the right and top bands are scored); the `edge-post`/`edge-pre`
cells as the before-baseline; module backups for A/B.

## 6. Exit criteria

1. T0 completed for the live drag and for S2 with magenta, numbers folded into §2.3 (the churn half
   is done); T1 passed (or B abandoned with the spike's frames as the reason, and the plan re-checked).
2. T2 and T3 at their thresholds, T3 with James's verdict recorded verbatim in the ledger row.
3. T4–T7 green; every mutant observed red and restored; `--check` green.
4. Ledger row (C36 or later) with Config · Measured · Inferred separated; C35 amended to point at
   it; issue #7 updated; as-built header on this doc; module hash recorded; GOTCHAS entry if a
   test-discovered assumption fell.
5. The wine bug is **not** updated — see §2.4.

## 7. Rollback

Owner-side only; the installed module is replaced with a dated backup beside it, as every build has
done (`winemac.so.bak-*`). Revert = copy the backup back with Steam down; no prefix, registry or
DXMT change to undo. Source: the commits sit on `core`; `git branch -f core <previous>` and rebuild
`main` per the generator's rule; tags `pre-*` are taken first, as on 2026-09-03.

## 8. Sequencing

After the M0/M0b attribution (done) and before anything else on the hosting layer: it is the most user-visible
open item. Independent of the #6 audit. T1 (the spike) is the first build step and takes one
module build plus one churn cell; if it fails, stop and re-plan before writing §4's code.

## 9. Non-goals and open questions

- **Not** a Windows-parity change and **not** for upstream (§2.4).
- The content view's own surface colour beneath the hosts — if M0 shows black with neither colour,
  that is a separate, cheaper question (a background on the content view's layer) filed on its own.
- Whether Chromium's Windows build shows the same black strip on a real Windows machine: assumed
  from the measured brush, unverified. Anyone with Windows can settle it in a minute.
- The ~1-frame gap at each recreate (retire at CREATE, replacement empty until its first present):
  C26 measured it at the probe's resolution; a 60 Hz screen recording would say more. Out of scope.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | not yet triple-checked |

Key paths: `dlls/winemac.drv/cocoa_window.m` (`WineContentView` host methods `:758-861`,
`CAContextSwapChain :4191-4278`, entry points `:4302-4360`), `dlls/winemac.drv/window.c`
(`:1709-1780`, `:1884-1963`, `:1984-2007`), `scripts/darkboxes.swift`, `scripts/shimmer-probe.sh`,
`scripts/livedrag-probe.sh`, `scripts/regen-winemac-patches.sh`, `scripts/win-resize-driver.c`
(`classbg`).
