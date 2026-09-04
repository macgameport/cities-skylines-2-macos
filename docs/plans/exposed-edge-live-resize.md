# Live resize — the black strip at the growing edge

**Status: Triple-checked 2026-09-03 — build-ready (pass 1 + a fitted re-check of the fold;
corrections folded, test plan reworked per the audit, one blocker in the fold itself found and
fixed — see § Review log).** Tracker:
[issue #7](https://github.com/macgameport/cities-skylines-2-macos/issues/7); umbrella
[#1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: cs2 `563130a`
(the fold commit follows it); nested winemac history `main` = `5d28d7b` (glue tip), `core` =
`eddf167`; installed module `cd79fc463795939f`; pre-D1/D2 backup
`winemac.so.bak-preD12-20260902-221649` = `53c9443db3145f58`. Line numbers are against the nested
`main` and name their file; unqualified `:N` is `cocoa_window.m`.

> **🔧 As-built (2026-09-03): stage 1 BUILT and measured; stages 2 and 3 not started.**
> Nested winemac `core` +3 commits (`af4b6d8` scale-a-stale-host · `717d431` the scale TRACE ·
> `23c5404` the degenerate-size floor), `main` rebuilt as aquadran → core → glue; reference patches
> regenerated, `regen-winemac-patches.sh --check` three `ok` + three invariants (T9's first half).
> Modules: baseline `cd79fc463795939f` · stage 1 `2a251a4b2510fb84` · diag-fix `50fdfe79898dac36`
> · diag+E1 `f7b2ad5d54455689` · E2 `e84ef3b09b066b6e` · E3 `9b6993e62ca091b4` · E5
> `f309e74dfd74c77b`, all built through `scripts/build-winemac.sh`. Ledger **C37** (T1 gate),
> **C38** (the A/B), **C39** (T2a + E1), **C40** (T7, E5, E2, E3).
>
> **Stage-1 rows as measured 2026-09-03 (exit criterion 2):**
>
> | row | result |
> |---|---|
> | T2a | **PASS** — `Rgreen ≥ 20 %` 0/120 (right-band green 78–86 % → max 0.80 %), magenta 0, blue 0, S4 8·9·12 per 40, static 0/40 |
> | T4 | **PASS** — 0 BRIGHT at 2399×1499 at rest, interior lum 88 |
> | T6 | **PASS** on two independent sessions, `scripts/t6-scale-at-rest.py` |
> | T7 grow | **PASS** both axes — `Rgreen` 0/40 (width), `Bgreen` max 0.10 %, 0/40 (height) |
> | T7 shrink | **PASS via the plan's trace branch** — 0 of 906 large hosts changed origin across 1930 placements; the band form is unfalsifiable (static control `B ≥ 20 %` 40/40 at lum<40) |
> | T9 | **PASS** — three `ok` + three invariants |
> | E1 · E3 · E5 | **RED** — E1 green 8/8/9 per 40 and `3021 scale 1.000,1.000`; E3 trace `1.999,2.000`; E5 every band black with 2050 placements |
> | E6 | **not applicable** — conditional on T7 attributing the displacement to a host; the trace says none moved |
> | E2 | **RED, restated** — 230 sub-pixel placements of 1104 against **0 of 4133** on the fixed module; the BRIGHT form cannot discriminate here |
>
> **Exit criterion 2 is MET.** Two of its criteria had to be restated first — both were tests that
> could not fail, which is worse than a missing test because they read as passes
> ([#9](https://github.com/macgameport/cities-skylines-2-macos/issues/9), C40). Neither restatement
> weakened anything: each moved the signal from a pixel effect to the mechanism itself, and each is
> non-tautological in both directions on data already collected.
>
> **Deviations from this plan, in the order they were forced:**
> 1. **The two per-host tables are NOT ivars beside `_caLayerHosts` (§4.1).** They are a
>    `@interface WineContentView ()` class extension, the idiom `WineWindow` and
>    `WineApplicationController` already use. Reason, measured: aquadran adds
>    `@public void *dxmt_client_surface;` at the end of that ivar block, so **any** hunk inserting
>    within three lines of it fails to apply to the aquadran tree and breaks the generator's
>    invariant 2 (`aquadran + core == glue's parent`). Two placements were tried and rejected
>    before the class extension. ⚠ `af4b6d8`'s own message still says "beside `_caLayerHosts`" —
>    written before the third placement; this header is the accurate one.
> 2. **The §4.5 trace ships on `core`, not as a diagnostic-only build.** It is a `TRACE` on the
>    off-by-default `macdrv` channel, and without it "the layer was scaled and it did not help" and
>    "the layer was never scaled" are the same evidence. It paid for itself twice in its first run.
> 3. **A degenerate-content-size floor was added, which §4.2 explicitly declined** ("absurd factors
>    … accepted"). The trace caught two frames at `scale 1920.000,907.000` from a 1x1 Chromium
>    widget: costless in compute, but it paints one pixel's colour over the whole window, which is
>    worse than the gap. Below 8 px on a side, place at identity.
> 4. **T2a was run the same evening and passes (C39).** The colourless interleaved A/B (C38: right
>    band −33 %, bottom −48 %, worst unchanged at 86–94 %) came first and could not attribute the
>    residual; the diag-fix module then did. ⚠ **Magenta marks the create path's DEFERRED
>    background (`main-old:781`), not a second background of its own** — `main` already paints a new
>    host black 120 ms after creation, and "a new host past its deferred black" is precisely S2, so
>    recolouring it is the faithful reading rather than a deviation from §2.3. A `!backgroundColor`
>    guard keeps it from repainting a host that `placeCALayerHost:` already marked green inside that
>    120 ms window, which would score S1 as S2.
> 5. The glue hunk moved from `:766-786` to **`:837-857`** — stage 1 inserts ~71 lines above it.
> 6. New instruments, all committed: `scripts/t1-spike.sh` (the T1 gate, both phases + analysis),
>    `scripts/stage1-tests.sh`, `scripts/band-counts.py`, `scripts/t6-scale-at-rest.py` (T6 with the
>    surviving-context filter), `scripts/build-winemac.sh` (branch + glue gate),
>    `scripts/churn-grow-shrink.py` (grow/shrink split beside its static baseline). **Four** harness
>    defects found and fixed en route, each of which produced a plausible wrong answer rather than an
>    error — GOTCHAS 2026-09-03: "Two scripts sharing `OUT_DIR`"; "A module built off the wrong
>    branch renders black"; the VOID guards firing on a mutant whose effect *is* a black window; and
>    a band criterion stated without its control.
>
> **Verify against:** `scripts/winemac-crossprocess-child-core.patch` (the `placeCALayerHost:`
> method, the class extension, `getCALayerHostPlacement:`), `scripts/stage1-tests.sh`,
> `scripts/build-winemac.sh`, `scripts/t6-scale-at-rest.py`, `scripts/churn-grow-shrink.py`,
> `scripts/t1-spike.sh`, `EXPERIMENTS.md` C37–C40, `~/cs2-patch/stage1-ab2/`,
> `~/cs2-patch/stage1-tests/`, and issue
> [#9](https://github.com/macgameport/cities-skylines-2-macos/issues/9) for the two criteria that
> do not bind.

**Scope.** One user-visible artifact: while a Steam window is being dragged larger, the newly
exposed strip along the growing edge is solid black until the hosted browser catches up. Not in
scope: the ~1-frame content gap at a swapchain recreate (C26 closed it to the probe's resolution),
the colour of the top-level's own GDI surface, matching Windows pixel-for-pixel, or offering any of
this upstream — no Windows code path paints that strip (§2.4), so this is a beyond-Windows quality
fix for daily use.

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
2026-09-03). The numbers above are the recomputed ones and were reproduced to the frame by the
correctness lens; `scripts/darkboxes.swift` is the scorer, `scripts/darkboxes-attrib.py` the
per-colour table (both parse by label; the latter accepts the evidence store's `churn-NN`/`drag-NN`
names as well as a probe's live `f*.png`).

## 2. Mechanism, read from the code

### 2.1 The child side has no resize path

`CAContextSwapChain` (`:4191-4278`) is an offscreen `CAMetalLayer` whose bounds are fixed at
creation (`:4234`) with `anchorPoint (0,0)` (`:4235`) and the default position, so the remote root's
frame is `(0,0,w,h)` in the host's space — which is why stale content pins to the host's origin.
Its background is black (`:4232`) and it is exported through a `CAContext` (`:4239-4244`). The class
has only `init`, `layer` and `dealloc`; "no resize path" is a winemac statement — DXMT receives the
`CAMetalLayer` through `layer` (`:4256`), and the evidence that it recreates rather than resizes is
the count: 417 `CREATE` firings against 417 acquires in one session
(`docs/plans/hosting-layer-design-gaps.md` § T1; C30 records the same client's 20 hosted children on
one thread, not this count). Chromium's own host does the same (`display_ca_layer_tree.mm`: anchor
zero, "macOS expects all attached layers of the context at (0,0)") and never sets its host's bounds; a
host's bounds reach the remote tree only through `masksToBounds`.

### 2.2 The owner side, per size step of a drag

1. CEF resizes its child HWND → `macdrv_WindowPosChanged(child)` takes the cross-process branch
   (`window.c:1984-2007`, D1) → `update_remote_layer_frame_for` (`window.c:1884`) →
   `macdrv_window_update_ca_layer_host_frame` (`:4328`) → `updateCALayerHostFrame` (`:813-838`),
   which sets `host.frame` to the **new** rect at once (`:835`, actions disabled `:834`). The root's
   own `WindowPosChanged` runs the full pass `update_remote_layer_frames` (`window.c:1909-1963`,
   called at `window.c:2042`) with the same effect — which is why the pre-D1/D2 module shows the same strip.
2. The host's remote content is still the **old** swapchain at its creation bounds. A `CALayerHost`
   shows the remote tree 1:1; `masksToBounds` (`:804`) clips, nothing stretches. The uncovered
   remainder of the host's frame shows **`host.backgroundColor`** — black, set 120 ms after
   creation by the deferred block at `:773-783` (120 ms at `:778`, black at `:781`; the host has no
   background before it), which the hardening pass added to close the odd-pixel white sliver
   (GOTCHAS 2026-08-31 "Retina turns an ODD Win32 pixel size into a HALF POINT"). A host that has
   lived longer than 120 ms is black underneath.
3. The GPU process creates a swapchain at the new size → `WM_MACDRV_CREATE_REMOTE_LAYER`
   (`window.c:1709`) → `addCALayerHostViewWithContextId` (`:758-811`) adds a **new** host at the
   new rect (transparent for its first 120 ms, then black) and `retire_superseded_layers`
   (`window.c:946`, called at `window.c:1760` — "only now do its predecessors go") removes the old
   host at once through the synchronous release entry point (`:4351-4364`).
4. The new host shows content when the GPU process presents its first frame. Under a continuous
   drag the cycle repeats every size step, so the visible state is mostly steps 1–3.

**Anchoring, measured (M0 frame 15):** when a host is reframed larger, its stale content stays at
the **top-left** of the new frame and the uncovered L-shape is at the right and bottom. That is the
expected result of a flipped layer space: `WineContentView` returns YES from `isFlipped`
(`:560-563`), it is layer-backed (`:542`), `cgrect_mac_from_win` is a retina divide with no y-flip
(`macdrv_cocoa.h:133-144`), and the fork already treats the backing layer's `geometryFlipped` as
AppKit-managed (`:2953` copies it). In that space `anchorPoint (0,0)` is the visual top-left.

**A shrink is not a clean clip, and it is not yet attributed.** M0 frame 14 (2400x1500 →
2200x1360) shows the top ≈138 px of content (menu bar, nav, URL row, store nav) cut off and, below
the footer, a ≈16 px light strip over a ≈130 px **dark-grey** band — not true black (`B = 0.0 %` at
lum < 6 in both cells' `churn-14.png`; 67.6 % at lum < 40). The displaced content is laid out at
2200 px and the displacement equals the height delta. **Inferred, not measured:** which layer is
displaced. In the flipped space the plain `frame` setter keeps the host's top-left on a shrink just
as on a grow, so the setter that explains frame 15 does not explain frame 14. One untested
candidate, listed so T7's measurement discriminates it: the content view's own backing layer moves
(`layer.position = surfaceRect.origin`, `:596`, `surfaceRect` set at `:614`), which would displace
every host together. T7 attributes this before any shrink handling is written (§4.2).

**The black sources, measured** (M0/M0b, §2.3), and what lies beneath them:

| source | what paints it | churn frames ≥ 20 % of the right band (M0 / M0b, of 40) | fix family |
|---|---|---|---|
| **S1** | the *reframed old* host's black background, uncovered where the stale content ends (step 2) | **9 / 10** (green) | keep content and frame in lock-step: scale the stale content (§4 stage 1) |
| **S2** | a *new* host older than 120 ms whose first frame has not arrived (step 3) | not cleanly measurable yet — the diagnostic red is also the store banner's colour; T0 re-runs with magenta | the deferred-black timing (§4 stage 3, conditional) |
| **S3** | the child's own offscreen `CAMetalLayer` background (`:4232`, black) before its first drawable | **0 / 0** — painted blue in M0b, and no blue appeared in any frame | none needed |
| **S4** | **beneath every host**: no host covers the strip yet, so the content view's own backing layer shows — its `contents` is the window-surface image cropped to `layer.bounds` (`updateLayer`, `:569-597`) | **6 / 8** (black with no diagnostic colour) | stretch the full-client hosts with the root during live resize (§4 stage 2) |

Two inferences ride on S4 and T0 measures both. *Why nothing covers the strip:* the root's
`WindowPosChanged` has run (the content view is already the new size) but the app has not yet
resized its child HWNDs, so the hosts still mirror the old child rects — T0 checks the `+macdrv`
trace for root rect ≠ child rects in the S4 frames. *Why it is black:* the strip's colour is a
property of the surface image (the default `contentsGravity` stretches a smaller image over grown
bounds), assumed black because Steam's root never GDI-paints — T0 attributes it by nil-ing
`contents` and colouring `layer.backgroundColor`. On Windows that strip is the top-level's own
client area; what Windows shows there is not established (§2.4).

### 2.3 M0/M0b — the colour diagnostics (executable spec)

Rather than argue which source dominates, colour them: a diagnostic module with the create-path
background **red** (`:781`), the reframe-grow path **green** (a line before `:835` that paints the
background when the new frame is larger) and, in M0b, the child's offscreen layer **blue**
(`:4232`), churned with frames kept and scored per band and per colour.

**Result (cells `m0-colour`, `m0b-colour`, 40 churn frames each, ledger C36):** green (S1) in 9 and
10 frames at 78–86 % of the right band; black with **no** diagnostic colour (S4) in 6 and 8 frames
at 77–86 %; **blue never** (S3 ruled out); red unusable because the store banner is red — the top
band, which the banner does not reach, shows red only where the content was displaced. Two lessons
folded into `darkboxes.swift`'s header: choose diagnostic colours the page cannot contain (magenta,
green, blue), and parse its output by label, never by position. The class-brush output (§2.4) had
lived only in a terminal log and is now `classbg/classbg.txt` in its cell.

### 2.4 Why the native client does not show it, and what Windows does

Chromium's macOS resize path — `ui/accelerated_widget_mac/window_resize_helper_mac.h`, verified
verbatim 2026-09-03 from chromium.googlesource.com — waits *"inside AppKit drawing routines on the UI
thread for the compositor to produce a frame of same size as the NSView"*, *"until a timeout
occurs"*, so that *"the window size and the size of the contents being drawn in that window are
resized in lock-step"*. Wine has no hook into CEF's compositor, and Steam's Windows build has no such
helper.

The class background brushes, measured 2026-09-03 with `win-resize-driver.exe classbg` (new verb;
output in cell `classbg`):

| window | class | `hbrBackground` |
|---|---|---|
| root `0x1011E` | `SDL_app` | **NULL** (no erase) |
| both hosted children | `CefBrowserWindow` | **NULL** |
| their `Chrome_WidgetWin_1` | Chromium's widget | solid brush, colour 000000 (black) |
| `Chrome_RenderWidgetHostHWND` | | `COLOR_0+1` (index 0, `GetSysColor` → `FFFFFF`), beneath the widget |

A class brush is applied only when `WM_ERASEBKGND` reaches `DefWindowProc`, and Chromium answers
it itself: `HWNDMessageHandler::OnEraseBkgnd` (`ui/views/win/hwnd_message_handler.cc`, read
2026-09-03) returns 1 — *"Needed to prevent resize flicker"* — after at most a one-shot black fill
of the DWM title-bar inset. The widget's black brush is registered but never used to erase, and the
parents have none. **Windows erases nothing in the exposed area, and what it shows there is not
established by this measurement.** What is established is that no Windows path paints the strip,
so any fix is a beyond-Windows nicety that only makes sense because the native Mac client sets the
bar — and that is why none of this goes to wine bug 60263, whose bar is Windows.

## 3. Options

| | option | verdict |
|---|---|---|
| A | paint the class-brush colour (issue #7's first candidate) | **dead** — the brushes are NULL or black, and Windows does not use them (§2.4). Recorded so it is not re-proposed. |
| B | **scale the stale host to its new frame** until the replacement presents — what a native `CAMetalLayer` does during live resize | **build** — S1 is measured (stage 1) |
| B′ | during a live resize, stretch the hosts of **full-client** children with the root, before the app resizes those children | **build, guarded** — S4 is measured (stage 2) |
| C | re-arm the 120 ms deferred black on every reframe, so a host that is still being resized never turns black before its content arrives | conditional on T0's magenta count (stage 3) |
| D | do nothing | the upstream answer; not the daily-use answer |

**Decision, from M0/M0b:** S1 and S4 are each roughly a quarter of churn frames and neither is the
child layer, so B and B′ are both needed. They touch different paths (the child's own reframe vs
the root's pass) but **B′ depends on B**: a stretched host without content scaling is exactly S1.
C waits for a clean S2 number.

## 4. Design — three stages, each measured before the next

All owner-side; stage 1 in `cocoa_window.m`'s `WineContentView`, stage 2 in `window.c`'s root pass
plus two event handlers and one bit in `macdrv_win_data`; no change to the child side, the message
protocol, D2's paint order, or DXMT. D1's path is touched only by sharing one target-frame helper
(§4.2b). Ship and measure stage 1 before writing stage 2: T2's per-source counts say what each
stage bought.

### 4.0 Stage 1 = B (S1) · Stage 2 = B′ (S4) · Stage 3 = C (S2, conditional)

### 4.1 Content size is known: it is the creation rect, read twice

The remote content's size only changes through a recreate (§2.1), and a recreate arrives as a new
context id with a new host. So the size the content was created at **is** the content size for the
host's whole life. The swapchain is created in the surface path (`window.c:1304-1334`) from the
child's **window** rect offset into the root (`window.c:1321-1323`, `:1330`; the client rect at
`:1309` is used only for an own window at `:1334` or as the fallback at `:1325` — every cite in this
parenthesis is `window.c`), and the CREATE handler reads
the same window rect (`window.c:1723-1725`) — **but later, in the owner**. Under a drag with
hundreds of creates the child can be resized between the two reads, so the stored size can be one
step stale for that host's life, and the host mis-scaled until the next CREATE retires it. Accepted
as transient; T0 counts the mismatches between the `cross-process child %p -> root %p frame %s`
trace (`window.c:1327`, GPU process) and the `child %p layer frame in root %p = %s` trace
(`window.c:1727`, owner) per context, and T6 compares the stored size against the former. Carrying
the size in the post (`NtUserSetProp` on the child before `NtUserPostMessage`, `NtUserGetProp` in
the handler) removes the race — a protocol change, deferred unless T0/T6 say it fires.

**State.** `NSMutableDictionary<NSNumber*, NSValue*>* _caLayerHostContentSizes` declared beside
`_caLayerHosts` (`:397`), released beside it in `dealloc` (`:554`), lazily created beside `:760`,
set **only** in the non-empty create branch (`:802-805`, from the snapped frame — nothing for the
`CGRectIsNull` root case or the `CGRectIsEmpty` case), removed in `removeCALayerHostView`
(`:856-861`), and cleared in `setRetinaMode:` (`:902-903`, where each host's `contentsScale` flips —
a stored size in points would be 2× off for every surviving host). Beside the size, the **last target frame** —
`NSMutableDictionary<NSNumber*, NSValue*>* _caLayerHostTargetFrames` (`valueWithRect:` / `rectValue`),
same lifecycle sites including the `setRetinaMode:` clear (§4.2). Alternative if a third per-host field arrives (stage 3): subclass —
`@interface WineCALayerHost : CALayerHost` with `contentSize` — so `_caLayerHosts` stays the only
dictionary; not chosen for stage 1 because subclassing a private class is one more unknown.

### 4.2 Reframe = position + scale; `frame` is never read or written on a host again

`CALayer.h` documents `frame` as derived from `bounds`, `anchorPoint`, `position` and `transform`,
and undefined to set under a transform; `masksToBounds` clips in layer space, so a scaled host still
clips at exactly its scaled frame. Therefore all three geometry paths — create (`:803`), reframe
(`:835`) and zero-size (`:824`) — go through **one helper** —
`- (void) placeCALayerHost:(CALayerHost*)host contextId:(CAContextID)cid frame:(CGRect)frame`, whose body is
the snippet below, called from `:803`, `:824` and `:835` — that sets `anchorPoint`, `bounds`,
`position` and `transform`; the zero-size path additionally resets the transform to identity and
hides; the `CGRectEqualToRect(host.frame, frame)` short-circuit at `:835` is replaced by a compare
against the last target frame stored beside the content size (on a transformed layer `frame` reads
back as a float product and the equality test is noise). In `updateCALayerHostFrame`'s reframe
branch (`:827-838`), inside the existing `CATransaction` with actions disabled:

```objc
NSValue* stored = [_caLayerHostContentSizes objectForKey:@(contextId)];
CGSize content = stored ? stored.sizeValue : frame.size;      /* creation size, §4.1 */
const CGFloat px = retina_on ? 0.5 : 1.0;                     /* one device pixel, as the snap */
if (content.width <= 0 || content.height <= 0 ||              /* no usable base (empty create) */
    (fabs(frame.size.width  - content.width)  <= px &&        /* or within a seam of identity: */
     fabs(frame.size.height - content.height) <= px))         /* the background covers that */
    content = frame.size;
BOOL identity = CGSizeEqualToSize(content, frame.size);
host.anchorPoint = CGPointMake(0, 0);   /* top-left: WineContentView is flipped (isFlipped YES, :560);
                                         * T1 traces self.layer.geometryFlipped once to confirm */
host.bounds = (CGRect){ CGPointZero, content };
host.position = frame.origin;
host.transform = identity ? CATransform3DIdentity
                          : CATransform3DMakeScale(frame.size.width  / content.width,
                                                   frame.size.height / content.height, 1.0);
host.edgeAntialiasingMask = 0;          /* a scaled layer antialiases its edges by default:
                                         * a hairline at the window edge while scaled (T4 runs at rest) */
```

The `px` tolerance matters twice: a zero-size creation rect must not make a host invisible for life
(the case `:832-838` keeps working today), and `snap_host_frame_to_view_edges` (`:508-530`) extends a
frame by ≤ `px` only when it reaches the *current* view edge, so after the root grows the same child
rect is up to half a point narrower than the stored snapped size — an exact compare would leave
`sx ≈ 0.9998` and a linear-filtered blur on every page for any child that never recreates. The create
path's `magnificationFilter` (`:767`) is left alone: `CALayer.h` scopes the filters to a layer's own
`contents`, so their effect on a hosted tree is undocumented. Absurd factors (Chromium does create
1x1 widgets; `window.c:2126` special-cases them) are one compositor transform of one texture with no
re-render or memory cost, for one size step — accepted. **Invariant:** a transformed host has
`autoresizingMask == kCALayerNotSizable`; only the root-window branch (`:791-793`) sets a mask, and
that host is never reframed (the root pass skips `child == NULL`, `window.c:1937`).

**Anchor.** `(0,0)` is the min-x/min-y corner of the bounds rect (`CALayer.h`), which is the visual
top-left only in flipped geometry; the content view is flipped (§2.2) and Apple documents only that
the view "is responsible for managing" its backing layer's `geometryFlipped`, so T1 prints
`self.layer.geometryFlipped` once and the choice is measured, not assumed. Frame 14's displacement is
unattributed (§2.2); stage 1 sets the anchor explicitly in both directions, and T7's shrink churns
measure whether that alone removes it — if not, the displacement is not the host's and gets its own
attribution before any "shrink handling" is written.

**Retire timing** is untouched: the replacement still retires the old host at CREATE
(`window.c:1760`), so C26's "never unhosted" property holds. Note that stage 1 makes the retired host
the *good* one, so the CREATE-time gap (replacement transparent then black, no first-frame callback)
becomes the dominant residual; expect T3's leftovers to carry that signature.

### 4.2b Stage 2 — B′: stretch full-client hosts with the root during live resize (S4)

The live-resize signal already exists in stock and needs no new observation, delegate or query:
every `WINDOW_FRAME_CHANGED` carries `in_resize = [self inLiveResize]` (`:3246` → `:2373`,
`macdrv_cocoa.h:400`, consumed at `window.c:2109-2139`), and `windowDidEndLiveResize:` (`:3150-3157`)
posts `WINDOW_RESIZE_ENDED` → `macdrv_window_resize_ended` (`window.c:2313-2317`), which today only
sends `WM_EXITSIZEMOVE` — **nothing re-derives the hosts at the end of a drag**. Both handlers run
on the window's own wine thread (`event.c:375, :524`), the thread that owns `win_data`. An
`OnMainThread` query of `-[NSWindow inLiveResize]` would block the app thread mid-resize and is not
used. Five edits, plus the shared helper below (a sixth change):

1. `macdrv.h`: `unsigned int in_live_resize : 1;   /* WINDOW_FRAME_CHANGED.in_resize; cleared by WINDOW_RESIZE_ENDED */`
   placed **beside core's own `remote_layer_children` field**, not beside `fullscreen : 1` where
   aquadran's hunk lands (`scripts/wineandaqua-dxmt.patch:239-241`), so the generator's invariant 2
   keeps applying.
2. `window.c:1909`: `static void update_remote_layer_frames(struct macdrv_win_data *data, const struct window_rects *old_rects)`
   (the pattern `sync_window_position` uses, `window.c:850`). The pass works in **window-rect
   space** (`root_rect` from `NtUserGetWindowRect(data->hwnd)`, `window.c:1921`; child frames offset by
   `root_rect.left/top`, `window.c:1947`), and by the time it runs the new rects are installed
   (`data->rects = *new_rects` at `window.c:1979`, `sync_window_position` at `window.c:2021`), so the "before this
   move" rect **must** be passed in — the function has no memory of its own. After the
   `OffsetRect(&cr, …)` at `window.c:1947`:

   ```c
   if (old_rects && data->in_live_resize)
   {
       /* B': a child that filled the client area before this move is stretched with the root
        * now, before the app resizes it; its own WindowPosChanged (D1) re-frames it after. */
       RECT old_client = old_rects->client, new_client = data->rects.client;
       OffsetRect(&old_client, -old_rects->window.left, -old_rects->window.top);
       OffsetRect(&new_client, -data->rects.window.left, -data->rects.window.top);
       if (EqualRect(&cr, &old_client)) cr = new_client;
   }
   ```

   Compared relative to the root, never in screen space — a root move shifts every child's screen
   rect while its parent-relative rect is unchanged, so a screen-space compare never matches during a
   top- or left-edge drag. `cr` comes from raw-DPI queries and `data->rects` are "in monitor DPI":
   assert their equality with one TRACE before trusting `EqualRect`. **Which child can match is a
   measurement, not an assumption:** on the 2026-09-03 tree only the full-window browser (`0x2012C`,
   1920x1050 @0,30) equals the root client rect, while frame 09 shows the *page* (the inset sibling)
   lagging — so stage 2 covers S4 only if the full-window browser sits below the page in z; T0
   records the match and the z-order before T2b's threshold means anything.
3. `window.c:2042`: `update_remote_layer_frames(data, &old_rects);` (`old_rects` is the local at
   `window.c:1972`, snapshotted at `window.c:1978` before the new rects are installed).
4. `window.c:2132`, before `release_win_data(data)`: `data->in_live_resize =
   event->window_frame_changed.in_resize;` — written on **every** event, so the bit self-heals; it
   must precede `NtUserSetRawWindowPos` (`window.c:2142`), which is what triggers the full pass. This is why a
   maximized window, whose `windowDidEndLiveResize` posts nothing (`:3152`), cannot leave the
   heuristic armed: each frame-changed event rewrites the bit and `windowWillResize` pins the size
   (`:3325-3328`).
5. `window.c:2313-2317`:

   ```c
   void macdrv_window_resize_ended(HWND hwnd)
   {
       struct macdrv_win_data *data;

       TRACE("hwnd %p\n", hwnd);
       if ((data = get_win_data(hwnd)))
       {
           data->in_live_resize = 0;
           update_remote_layer_frames(data, NULL);   /* re-derive every host from its child's real rect */
           release_win_data(data);
       }
       send_message(hwnd, WM_EXITSIZEMOVE, 0, 0);
   }
   ```

**One shared helper.** D1's child path (`update_remote_layer_frame_for`, `window.c:1884`) reframes
to the child's *actual* rect; a z-only move mid-drag would un-stretch a stage-2 host until the next
root pass. The swapchain-creation comment (`window.c:1313-1317`) already demands that creation
and update compute one frame — factor the target computation (offset into root, then the
full-client substitution when `in_live_resize`) into one helper **both update passes** call. The
CREATE handler keeps the unsubstituted `window.c:1723` rect: the stored content size must be the
swapchain's creation rect (§4.1), so a host created mid-drag records its real bounds and is
stretched by the next root pass — substituting there would re-introduce S1 for exactly the hosts
stage 2 targets and confound T0's race count. "No change to D1" therefore means "D1 calls the
shared helper".

**Latency and the alternative not taken.** Stage 2 covers the strip only after a Cocoa → unix →
Cocoa round trip (AppKit grows the content view synchronously; hosts move when the wine thread
processes `WINDOW_FRAME_CHANGED` → `NtUserSetRawWindowPos` → `WindowPosChanged` → `OnMainThread`).
The zero-latency alternative — `autoresizingMask` on full-client hosts, what the root's own host gets
at `:793` — was rejected because springs-and-struts adjust the *frame* (`CALayer.h`), which does not
compose with stage 1's bounds/transform model. T2b/T3 are the only measurements of whether the round
trip is short enough. An app that lays out on `WM_EXITSIZEMOVE` (not Steam — frame 09 shows children
following mid-drag) sees the end-of-resize re-derive snap hosts back to actual rects; T3's verdict
includes the drag-end frame. **Programmatic resizes (`SetWindowPos`, the churn probe) are not live
resizes**, so churn measures stage 1 only and never stage 2; stage 2's only measurement is a live
drag (§5 T2b; T10 is the churn-side guard). This is a heuristic and is listed with D3's three (exit criterion 6).

### 4.3 Stage 3 — C: re-arm the deferred black on reframe (only if T0's magenta count says S2)

The deferred block (`:773-783`) fires 120 ms after creation. Under a recreate storm a new host can
pass 120 ms before its first frame. Change: keep the dispatch, add a per-id entry
`_caLayerHostLastReframe` (`NSNumber` cid → `@(CFAbsoluteTimeGetCurrent())`, the same
add/remove/dealloc lifecycle as the content size — `CALayerHost` has no such property) written in
`updateCALayerHostFrame`, and have the block re-schedule itself only while
`[_caLayerHosts objectForKey:@(cid)] == deferred` **and** `now − lastReframe < 120 ms`, so a retired
host retains nothing beyond one more period. A host that is still being resized never turns black; a
settled host turns black 120 ms after its last reframe, which is what the seam fix needs. Measured,
not argued: T8 with C alone must move the magenta count.

### 4.4 Which patch each hunk lands in, and how

`updateCALayerHostFrame`, `snap_host_frame_to_view_edges` and the `frame:` form of
`addCALayerHostViewWithContextId` exist only on `core`/`main` (0 hits on `stock`/`aquadran`; the
1-arg `add` and `remove` are stock methods core extends), and `window.c`'s pass, handlers and
`macdrv.h` field are core territory: **stages 1 and 2 are `core` commits.** The deferred background
block is the glue commit (`5d28d7b` is `cocoa_window.m +15` at `@@ -766,6 +766,21 @@`; `git diff
aquadran core -- cocoa_window.m` has no `dispatch_after`), so **stage 3 re-authors the glue commit**
— same subject, the only one on `main`, at its tip (`scripts/regen-winemac-patches.sh:106-108`
refuses otherwise); its `lastReframe` line inside `updateCALayerHostFrame` is a glue insertion into
a core method, the pattern the glue commit already documents, and its rollback is the previous glue
commit, not `core`. Conflict hazard: stage 1's store-size line goes after `:804`, inside
the branch — not under the glue hunk, which spans `:766-786` (`@@ -766,6 +766,21 @@`) — or re-applying glue on the rebuilt `main` conflicts
there. Workflow, every time: commits on `core`, `main` rebuilt as aquadran → core → glue,
`regen-winemac-patches.sh --check` printing three `ok` lines plus the three invariants (GOTCHAS
2026-09-03 "a generator with a relative range"). The generator refuses a commit on `main` after glue.

### 4.5 How to build, install, trace

Build tree `~/cs2-patch/build-1116/wine-1116-vis-build` (configured against `wine-11.16-dxmt`):
`gmake dlls/winemac.drv/winemac.so`. Install with Steam down (the `steam_up` check by prefix, never
by command line) to `~/Applications/CS2dxmt11.app/Contents/SharedSupport/wine/lib/wine/x86_64-unix/winemac.so`
with a dated `winemac.so.bak-<stage>-<date>` beside it; hash = `shasum -a 256 <so> | cut -c1-16`,
recorded in the cell's `config.json` by `cell-fingerprint.sh`. Mutants go through the
`hosting-layer-tests.sh --mutants` pattern (edit → build → install → cell → `git checkout` → rebuild
→ reinstall) or by hand with the same restore; the nested tree is clean after every one.
**`cocoa_window.m` has no `TRACE`** (0 hits; it never includes wine's debug headers): the scale
comes back to `window.c` through out-params on `macdrv_window_update_ca_layer_host_frame`
(`double *scale_x, *scale_y`, filled inside the `OnMainThread` block at `:4335` from
`host.transform.m11/.m22`), and the existing `child %p context %u frame %s` traces at `window.c:1904`
and `window.c:1953` are extended with `creation WxH scale %.3f,%.3f` on channel `macdrv` (`window.c:40`).
The pristine-11.16 compile gate is the one C31's addendum records: `wine-11.16-stockcore` +
`wine-1116-stock-build`, `gmake dlls/winemac.drv/winemac.so`, warning set compared by message text.

## 5. Test plan

**Instruments.** `hosting-layer-tests.sh` (rows: T0 ownership · T1 child move · T2 restack ·
T3/T4 blackout + churn + static · T8 traces; its `--mutants` are the design-gaps M1–M3),
`shimmer-probe.sh` (gains `CHURN_A`/`CHURN_B`/`CHURN_N` env overrides, defaults unchanged),
`livedrag-probe.sh` (`WAIT=1800`), `darkboxes.swift` (gains a magenta classifier
`r ≥ 200, b ≥ 200, g ≤ 60` and colour bands for all four edges), `darkboxes-attrib.py` (gains an S2
magenta column). **Mutants are E1–E7**, not M*, which is the battery's own set. **Modules, hashes
recorded per cell:** baseline `cd79fc46`; pre-D1/D2 `53c9443d`; **diag-pre** (`main` + magenta /
green / blue); **diag-fix** (each stage + the same colours); **prod** (each stage, no colours) —
James judges prod only. Every mutant is applied to real source, built, observed red, then restored
— "argued red" is not red. Churn runs are 40 frames, ×3 where a "→ 0" must be resolvable against a
9/40 baseline (P(0/40 | p ≈ 0.24) ≈ 1.7e-5 in one run; three runs guard against C26's misleading
first 0/40); live drags are 60 frames, normalised **per grow step** because trajectories differ
(C35's own rule for churn). **Fixed drag script for every live drag:** right edge out ~300 px over
~5 s, hold, then top edge up ~150 px; frames classified grow/shrink from `drag-sizes.txt`.

| # | test | pass | mutant (observed red) |
|---|---|---|---|
| T0 | **attribution** — churn half done (§2.3); owed: (a) one churn on **diag-pre** with `WINEDEBUG=+timestamp,+macdrv`, frame mtimes (`stat -f %Fm`), and the root pass tracing the root *client* rect and every hosted child's rect; (b) one churn with the content view's `contents` nil-ed and `layer.backgroundColor` coloured; (c) one live drag by James on diag-pre, scored on the probe's `f*.png` | per-frame S1/S2/S3/S4 split for churn and drag; every S4 frame's mtime falls (± 180 ms) inside a window where the root rect changed and a child rect had not; the S4 strip takes the content view's colour in (b); the trace records which hosted child equals the root client rect and its z-order relative to the page (§4.2b); the count of `window.c:1327`-vs-`window.c:1727` size mismatches per context under the drag (0, or a recorded bound) | none — measurement |
| T1 | **spike, gate** — fixed `CATransform3DMakeScale(1.5, 1.5, 1)` applied in `addCALayerHostViewWithContextId` (after `:803`, so it holds at rest) with `anchorPoint (0,0)` set first, on a throwaway branch off `main`; Library page, no churn, each hosted child in turn as `run_t1` in `hosting-layer-tests.sh` does; TRACE `self.layer.geometryFlipped` once; record the display profile; the module is **not pointer-operable** (visual ≠ HWND rects), reverted before any interactive use, its hash in `config.json` | with `strip_at`/`dchan` from `hosting-layer-tests.sh`: choose X with control contrast > 8 (**X is measured from the host's own origin**, so `1.5X` lands inside the scaled child only for the full-window browser @0,30, not the inset page); after the spike `dchan(strip(after, 1.5X), strip(before, X)) ≤ 8` and `dchan(strip(after, X), strip(before, X)) > 8` for at least one decisive child; the right/bottom third of the page is clipped (`masksToBounds`); the flip TRACE says YES | **gate, not a test** — both strips unchanged (≤ 2) = the host ignores `transform`; B is dead, §3 falls back to C/D, plan re-checked |
| T2a | **churn, stage 1** — diag-fix module, `shimmer-probe.sh churn` ×3 = 120 frames | `Rgreen ≥ 20 %` frames 9–10/40 → **0/120**; black-no-colour **3–13 per 40** as a positive control (churn is not a live resize; this is not a criterion); blue 0; `static` 0 gaps | **E1:** content-size lookup returns `frame.size` (never stored) → green ≥ 5/40 in every run |
| T2b | **live drag, stage 2** — diag-fix module, James, the fixed drag script | among grow-step frames: `Rgreen ≥ 20 %` ≤ 1, black-no-colour ≥ 20 % ≤ 1, worst right band < 20 %; top band black-no-colour 0 in the top-edge segment | E4 (T10) and E1 |
| T3 | **live drag, production module** — same script, James's verdict | right band ≥ 20 % true black in **≤ 2 grow-step frames** (baseline 19/60 on a mixed drag); worst < 20 %; verdict verbatim, including the drag-end frame (rubbery ≤ ~100 ms = the native look; persistent distortion or a snap-back flash = fail) | none beyond T2b's — a human drag is not repeated per mutant |
| T4 | **seam** — the battery's blackout rows, plus one capture *while scaled* (mid-churn) for a hairline at the window edge | interior lum > 40 at each step and **0 BRIGHT edges at 2399x1499** (C29 83/84/112, C32 87/92/113 — the interior varies with the page, the bright count is the invariant), at rest and while scaled | **E2 (restated 2026-09-03, C40):** skip `snap_host_frame_to_view_edges` at `:816` → **≥ 1 host placed at a sub-pixel scale** (a factor in (0.990, 1.000)), `scripts/placement-invariants.py`. ⚠ The original signal — ≥ 1 BRIGHT at 2399x1499 — **cannot discriminate on this build**: the seam the snap covers is also covered by the create path's deferred background, so removing either mechanism still leaves no white. Measured: E2 engaged (172 placements at `scale 0.999,1.000`) with **0 BRIGHT**. The replacement is non-tautological both ways — fixed module **0** sub-pixel placements over **4133** across two independent sessions, E2 **230 of 1104** |
| T5 | **battery + boot** — `hosting-layer-tests.sh` (all its rows) **and `--mutants`** (stage 2 touches `update_remote_layer_frames`), `boot-verify.sh` detached | as C32 (**the battery's own row names**, not this plan's T-numbers): battery T0 disjoint, battery T1 GREEN, battery T2 restack + restore, churn/static 0 gaps, 0 acquire failures, 0 GPU crashes, M1 red / M2 green / M3 ≥ 1 `paint order incomplete`, `VERDICT: PASS` | the battery's own |
| T6 | **no residual scale at rest, and the base is right** — the §4.5 trace; run after T2b's drag and after T7's churns | 3 s after the last size change the last line per surviving context id reads `1.000,1.000`; each surviving host's creation size equals the GPU-process `cross-process child … frame` rect (`window.c:1327`) for the same context id — **not** the host's bounds, which are set from the stored size; no `child NULL` context appears in the reframe trace (`window.c:1937`) | **E3:** store half the creation size → `2.000,2.000` at rest and the page renders doubled |
| T7 | **anchor, both axes, both directions, and frame 14 attributed** — diag-fix module, `CHURN_A=2200x1500 CHURN_B=2400x1500` and `CHURN_A=2400x1360 CHURN_B=2400x1500`, ×1 each (a churn alternates, so each run holds grow and shrink steps), frames classified grow/shrink by PNG size vs the previous frame, the §4.5 trace on; plus T2b's top-edge segment | grow frames: `Rgreen` (width) and `Bgreen` (height) ≥ 20 % → 0; shrink frames: **the trace branch, taken 2026-09-03 (C40)** — ⚠ the band form of this clause is **unfalsifiable**: at lum < 40 the **static control**, a window that is never resized, scores `B ≥ 20 %` in **40 of 40** frames (worst 79.4 %) because the store page is full of dark artwork, so the criterion is satisfied without any resize at all (`scripts/churn-grow-shrink.py` now prints the baseline beside any such count). The plan's own alternative is used instead: **the trace says which layer moved, and none do** — 0 of 906 large hosts changed frame origin across 1930 placements in the height churn, shrink placements being pure scale about a fixed top-left corner (`scripts/placement-invariants.py`). The displacement is therefore not a host-position effect; it was measured **pre-stage-1** (C36) and gets its own attribution before any code; T-band 0 in the top-edge segment | **E5:** anchor at the opposite corner → L- or T-band black ≥ 20 % in ≥ 5 frames of the width churn; **E6: NOT APPLICABLE (2026-09-03)** — it was conditional on T7 attributing the displacement to the host, and T7's trace says no host moves. Recorded per exit criterion 2's own escape clause, with the trace as the reason |
| T8 | **C alone** (only if built) — diag build with stage 1 removed by the named switch (`core` minus the stage-1 commit), churn ×3 | **magenta** (S2) right-band frames → 0 against T0's magenta count | **E7:** no re-arm on reframe → magenta returns to T0's count |
| T9 | **the reference regenerates** — `regen-winemac-patches.sh --check`; the pristine-11.16 compile gate (§4.5) | three `ok` + three invariants; warning set unchanged by message text | — |
| T10 | **stage-2 guard** — T2a's churn on the stage-2 build | the T6 trace shows no scale ≠ 1 emitted by the root pass; the S4 control frames persist (3–13/40); after T2b every host at identity within 3 s (the `windowDidEndLiveResize` re-derive) | **E4:** force `in_live_resize` true (or drop the guard) → churn black-no-colour → ≤ 1/40 and the root pass emits scale ≠ 1 |
| T11 | **root hosts and popups** — open/close a Steam popup on prod during and after a drag, `+macdrv` cell | popup capture non-black; ≥ 1 dead-child prune / drained slot on close as C29; no `child NULL` context in the reframe trace; the game's boot and 1 %-low unchanged (`MetalViewSwapChain` is disjoint: `window.c:1301`, `:4145-4190`) | none — structural (`window.c:1937`, `:790-795`) |

**Fixtures.** The Steam store page for churn (two hosted `CefBrowserWindow` siblings, black artwork
in the lower tiles; `tree` at T0 records which child equals the root client rect); the Library page
for T1; the `edge-post`/`edge-pre` cells as the before-baseline and `m0-colour`/`m0b-colour` as the
attribution baseline; module backups for A/B. **James drags three times minimum** (T0 diag-pre ·
T2b diag-fix · T3 prod including the top edge), across ≥ 2 sessions. If he cannot: T0's live half
is deferred and **stage 2 does not ship** — its only measurement is a live resize; the fallback is a
CGEvent-posted edge drag instrument (new; needs Accessibility permission; validated by
`livedrag-probe.sh` detecting the drag) built before use.

## 6. Exit criteria

1. T0 complete for the live drag and S2 (scorer and attrib extended; numbers in §2.2/§2.3; the
   tree match and z-order for stage 2 recorded); T1 passed, or B abandoned with the spike's frames
   as the reason and the plan re-checked.
2. Stage 1: T2a 0/120, static 0 gaps; T4, T6, T7 green; E1, E2, E3, E5 observed red and
   restored, E6 likewise **if T7 attributed frame 14 to the host** — else recorded as not
   applicable with T7's trace as the reason — nested tree clean (`git status --porcelain` empty),
   `--check` green.
3. Stage 2: T2b and T10 at threshold; E4 red; T3 with James's verdict verbatim in the ledger; T11
   clean.
4. Stage 3 decision recorded either way: built (T8 green, E7 red) or declined with T0's magenta
   count as the reason.
5. T5 battery + its `--mutants` + boot `VERDICT: PASS`; T9.
6. Ledger row (C37 or later) with Config · Measured · Inferred; hashes for diag-pre / diag-fix /
   prod; C35/C36 amended to point at it; issue #7 updated; as-built header on this doc; GOTCHAS
   entry if a test-discovered assumption fell; a row for the full-client stretch in
   `hosting-layer-design-gaps.md` D3 with T0's firing evidence and T2b's S4 count beside it.
7. The wine bug is **not** updated (§2.4).

## 7. Rollback

Owner-side only; the installed module is replaced with a dated backup beside it, as every build has
done (`winemac.so.bak-*`, ten of them today). Revert = copy the backup back with Steam down; the
launcher never references `winemac`, so nothing re-installs a reverted module; no prefix, registry
or DXMT change to undo; no reboot. Source: stage 1/2 commits sit on `core` — `git branch -f core
<previous>` and rebuild `main` per the generator's rule, tags `pre-*` taken first (as on
2026-09-03); stage 3 = the previous glue commit.

## 8. Sequencing

After the M0/M0b attribution (done) and before anything else on the hosting layer: it is the most
user-visible open item, independent of the #6 audit. Order: T1 (one module build plus one Library
cell; if it fails, stop and re-plan) → T0's remaining halves → stage 1 → T2a/T4/T5/T6/T7/T9 →
stage 2 → T2b/T3/T10/T11 → stage 3 only if T0's magenta count warrants → ledger, as-built, issue.

## 9. Non-goals and open questions

- **Not** a Windows-parity change and **not** for upstream (§2.4).
- `inLiveResize` is true only for user edge/corner drags; zoom, the green button, animated
  `setFrame:` and full-screen transitions are not live resizes and stage 2 does not cover them.
- Frame 14's displacement is unattributed until T7 (§2.2); `preservesContentDuringLiveResize`
  returns YES (`:474-478`) and its interplay with Cocoa-driven live resize is unmeasured.
- The content view's surface colour beneath the hosts (S4's "black") — T0(b) attributes it; if it is
  the surface image, a background on the content view's layer is a separate, cheaper question.
- Whether Chromium's Windows build shows a strip on a real Windows machine: nobody here has one;
  the brush table says only that no erase path paints it.
- The ~1-frame gap at each recreate (retire at CREATE, replacement empty until its first present):
  C26 measured it at the probe's resolution; stage 1 makes it the dominant residual; a 60 Hz screen
  recording would say more. Out of scope.
- Pre-existing, not introduced: any process can post `WM_MACDRV_CREATE_REMOTE_LAYER` with a bogus
  id and get a transparent-then-black host over the window. Out of scope.

## Review corrections (triple-check 2026-09-03, pass 1)

Six lenses (architecture, correctness, builder-simulation, platform-facts, security, test-plan
audit), one agent each at the top tier per the project's tier rule, batches of ≤ 4, ≤ 15 tool
calls each, all read-only; the builder ran the real gates (`--check`, `check-experiments.py`,
`bash -n`, `swiftc`, `gmake -n`), all exit 0. Verdicts: five × build-ready-with-fixes and the
test-plan audit **needs-rework (test plan)**, all supplied with text; every correction is folded
into the normative sections above, and the audit's own closing line — "after folding a single
fitted re-check should suffice rather than another fleet" — is the next step (Review log).

- **Wrong cite, wrong caveat (all lenses):** `window.c:1187` is `WM_MOUSEACTIVATE`; the child's
  swapchain is created from its **window** rect offset into the root (`window.c:1321-1330`), the
  same rect the CREATE handler reads (`window.c:1723`). The window-vs-client caveat is gone; the real hazard — the two
  reads are in different processes at different times — is §4.1's race, with T0 counting it.
- **"Windows erases the resized widget black" was an inference from a brush table (correctness):**
  Chromium's `OnEraseBkgnd` returns 1 and never uses the brush (verified from source). §2.4, §2.2
  and C36 now say Windows erases nothing and what it shows is not established; the scope decision
  stands on "no Windows path paints the strip".
- **Frame 14 (correctness):** the band is dark grey, not black (`B = 0.0 %` at lum < 6), and the
  flipped-space `frame` setter cannot explain the displacement; "shrink handling" is replaced by
  attribution in T7 (E6 conditional on the outcome).
- **Stage 2's plumbing exists and its end does not (architecture, builder, platform, security):**
  `in_resize` rides every frame-changed event, `WINDOW_RESIZE_ENDED` reaches
  `macdrv_window_resize_ended`, which today only sends `WM_EXITSIZEMOVE`; §4.2b now names the five
  edits with text, compares in window-rect space relative to the root, passes `old_rects` in,
  latches the bit on every event (self-healing, covers the maximized case), and re-derives at the end.
- **Which child stage 2 can match (test-plan audit):** only the full-window browser equals the root
  client rect, and frame 09 shows the page lagging — so stage 2 helps only if that browser sits
  below the page in z; T0 measures the match and the z-order.
- **Stage 1 typeability (builder, security, platform):** no `contentSizeForHost:` existed; the
  snippet is now real code with the dictionary lookup, the zero-base and `px`-tolerance guards, one
  geometry helper for all three paths, no `frame` reads under a transform, the `edgeAntialiasingMask`
  line, no `magnificationFilter` line (undocumented for hosted trees), the `autoresizingMask`
  invariant, and the retina-flip clearing. Per-host state lifecycle spelled out; the subclass
  alternative recorded.
- **Anchor (architecture, builder, platform):** the snippet said "bottom-left" while the prose said
  top-left; `isFlipped` → YES settles it as `(0,0)` = top-left, with one TRACE in T1 as the measurement.
- **B′ depends on B (architecture)** — a stretched frame without content scaling is S1; §3 says so.
- **Glue workflow (architecture, builder):** stage 3 re-authors the sole glue commit; `macdrv.h`'s
  bit sits beside core's own field; the store-size line avoids the glue hunk.
- **Test plan reworked (test-plan audit — three blockers):** the two mutant observations were
  inverted (`transform = identity` uncovers the strip, so black rises and green cannot return;
  "never store the size" *is* today's path, so green returns and the old T6 stayed green under its
  own mutant); T6's second clause was tautological and its trace had no channel in the `.m` file;
  stage 2 had no mutant and thresholds churn can never meet. Now: E1–E7 with observations that
  distinguish each mutant from the fixed build; T2 split into T2a (churn, stage 1) and T2b (live
  drag, stage 2); T10 as the guard test with E4; T6 compares the stored size against the GPU-process
  trace; T3 normalised per grow step with a fixed drag script; T4's numbers corrected (the invariant
  is 0 BRIGHT at 2399x1499); T5 names the battery's real rows and re-runs its `--mutants`; T8 uses
  magenta; T7 gets probe overrides and a per-frame trace; T11 covers popups and root hosts; the
  fixtures name three module variants and the fallback when James cannot drag; §6 rewritten per stage.
- **Instruments (test-plan audit):** magenta classifier and four-edge colour bands in
  `darkboxes.swift`, an S2 column and store-name sort in `darkboxes-attrib.py`,
  `CHURN_A`/`CHURN_B`/`CHURN_N` in `shimmer-probe.sh` — done in the fold commit, so T0 is runnable.
- **T1 was not executable (builder, test-plan audit):** `pixel-probe strip` returns a colour, not a
  width; the spike now scales at create (holds at rest, no churn confound) on the Library page and
  measures with the battery's `strip_at`/`dchan` contrast test.
- **T6's trace cannot live in the `.m` file (builder, test-plan audit):** out-params to `window.c`,
  channel `macdrv`, extending the existing frame trace.
- **Missing on day one (builder):** §4.5 build/install/hash/trace/compile gate.
- **Cites (correctness):** `retire_superseded_layers` is `window.c:946`; the deferred block is
  `:773-783` everywhere; key paths end at `:4364` / `window.c:1785`; the 417-CREATE figure is the design-gaps
  plan's, not C30's.
- **Evidence hygiene (correctness, test-plan audit):** the `classbg` output existed only in a
  terminal log — saved as `classbg/classbg.txt`; `darkboxes-attrib.py` crashed on the evidence store's
  names — fixed.

### Fitted re-check of the fold (2026-09-03, one agent, Claude Opus 5)

Brief: verify the fold's own edits against the codebase — cites, id consistency, whether the two
code fragments compile, whether every lens correction reached a normative section. It confirmed the
fold (every correction has a normative landing; both fragments compile against `5d28d7b`; E1–E7 and
T0–T11 consistent across §5/§6/§8; the instruments are in `c7afacb`) and found six defects **the
fold itself introduced**, all fixed here:

- **[BLOCKER] T7's shrink criterion could not go red.** The fold wrote frame 14's signature as
  *top-band true black*; §2.2 and C36 measured it as a **bottom** band of **dark grey** (`B = 0.0 %`
  at lum < 6, 67.6 % at lum < 40) with the top ≈138 px of content cut off. The pass was therefore
  already 0 on the baseline and **E6 could never be observed red** — while §6.2 demanded it red
  unconditionally and the correction bullet said it was conditional. T7's shrink pass now names the
  measured signature at lum < 40, E6 is explicitly conditional on T7 attributing the displacement to
  the host, and §6.2 says what to record if it is not.
- **[SHOULD-FIX] The shared helper would have poisoned the stored content size.** §4.2b routed the
  CREATE handler through the helper that substitutes the full client rect during a live resize, while
  §4.1 stores the content size from that same rect — so a host created mid-drag would record the
  *stretched* rect as its creation size, re-introducing S1 for exactly the hosts stage 2 targets and
  confounding T0's race count. The CREATE handler now keeps the unsubstituted `window.c:1723` rect.
- **[SHOULD-FIX] Unqualified `window.c` cites.** The plan's own convention (header) makes a bare
  `:N` mean `cocoa_window.m`, so eleven `window.c` line cites in §1, §4.2b, §4.5, T0 and T6 resolved
  to unrelated lines. All qualified; `:1946` → `window.c:1947` (1946 is the closing brace).
- **[MINOR] The brush index was wrong in both the plan and C36** — the evidence prints `COLOR_0+1`
  (index 0), not `COLOR_WINDOW+1` (index 5). The printed colour `FFFFFF` and the white conclusion
  stand; both corrected.
- **[MINOR] Two artifacts the "real code" claim left unnamed** — the last-target-frame store
  (`_caLayerHostTargetFrames`) and the placement helper's signature.
- **[MINOR] Range and wording slips** — "Five edits" over six, the glue hunk is `:766-786` not
  `:766-781`, the store-size line goes after `:804` inside the branch, T1's `1.5X` holds only with X
  measured from the host's own origin, T5's pass column names the battery's T-numbers not the plan's,
  key paths `:2097-2145` → `:2097-2146`.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-03 | 1b (fitted re-check of the fold) | fold verification (cites · id consistency · compilability · normative landing) | one agent, read-only, 12 calls | Claude Opus 5 (`claude-opus-5`) | cs2 `c7afacb` · nested `main` `5d28d7b` | fold verified; 1 blocker + 2 should-fix + 3 minor **in the fold**, all fixed → **build-ready** |
| 2026-09-03 | 1 (triple-check + fitted extras) | architecture · correctness · builder-simulation · platform-facts · security · test-plan audit | manual agents, ≤ 4 concurrent, ≤ 15 calls each, read-only; builder ran the gates | Claude Fable 5.1 (`claude-fable-5-1`) | cs2 `563130a` · nested `main` `5d28d7b`, `core` `eddf167` | five × build-ready-with-fixes, one needs-rework (test plan); all folded → **build-ready-with-fixes**, superseded by pass 1b |

Key paths: `dlls/winemac.drv/cocoa_window.m` (`WineContentView` host methods `:758-861`, `updateLayer`
`:569-597`, `CAContextSwapChain :4191-4278`, entry points `:4302-4364`, live-resize delegates `:3150`,
`:3246`, `:3362`), `dlls/winemac.drv/window.c` (`:946`, `:1304-1334`, `:1709-1785`, `:1884-1963`,
`:1965-2042`, `:2097-2146`, `:2313-2317`), `dlls/winemac.drv/macdrv.h`, `dlls/winemac.drv/macdrv_cocoa.h:400`,
`scripts/darkboxes.swift`, `scripts/darkboxes-attrib.py`, `scripts/shimmer-probe.sh`,
`scripts/livedrag-probe.sh`, `scripts/hosting-layer-tests.sh`, `scripts/regen-winemac-patches.sh`,
`scripts/win-resize-driver.c` (`classbg`).
