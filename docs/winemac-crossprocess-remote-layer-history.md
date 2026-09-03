# winemac cross-process remote-layer patch — working history (2026-08-29 to 2026-09-02)

> This is the narrative that used to live at the top of `scripts/winemac-crossprocess-remote-layer.patch`
> — six dated addenda describing each fix as it was measured. It was moved here on 2026-09-02 because
> `patch` cannot apply prose hunks and the file's path is what wine bug 60263 links to as the
> implementation. The applyable diff now lives at that path; this file is the record of how it got there.

winemac-crossprocess-remote-layer.patch — the wine half of the cross-process Steam fix.
⚠ AI-AUTHORED. Read this before you read the code.

This patch was written with heavy AI assistance. 3Shain/dxmt's CONTRIBUTING.md cannot accept
AI-authored contributions, so it was never offered as a PR — the findings went upstream as a
report instead: https://github.com/3Shain/dxmt/issues/141#issuecomment-5477055980

It is published here on purpose: this is our port's own record, and anyone should be able to
find it.

It is MIT-licensed like the rest of this repo, so you are welcome to use, adapt or rewrite it
under those terms. Nothing is expected back and there is no need to ask first.

But if you are a dxmt or wine maintainer who intends to write your own implementation,
reading this file is a choice with a consequence — afterwards you cannot cleanly say your work
is AI-free. The issue comment above carries the whole diagnosis (mechanism, faulting
instruction, measurements, falsification tests) with none of the code, which is the version
you probably want.

Apply to the DXMT-patched wine 11.16 tree (after wineandaqua-dxmt.patch and
winemac-crossprocess-child.patch). Pairs with scripts/dxmt-remote-layer-fallback.patch on the
DXMT side; NEITHER half works alone (measured 2026-08-31: stock DXMT + patched winemac still
gives 6 GPU crashes and a black window).

RESULT: Steam's client renders completely and correctly on stock OUT-OF-PROCESS CEF — no shim,
no injected switches, 0 GPU crashes (was 6 every launch). Evidence:
docs/images/steam-crossprocess-complete.png

Rebuild just the module:  gmake dlls/winemac.drv/winemac.so

--- a/dlls/winemac.drv/macdrv_main.c
+++ b/dlls/winemac.drv/macdrv_main.c
@@ before "DECLSPEC_EXPORT struct macdrv_functions_t macdrv_functions =" @@
+/* Exported standalone so DXMT can dlsym() it WITHOUT depending on struct layout.
+ * macdrv_functions_t is C_ASSERT-ed at a fixed size, so adding a member to it is a breaking ABI
+ * change: a DXMT built against the 11-member struct would read past the end of a 10-member one
+ * from a stock winemac and call whatever followed it in memory. A separate symbol degrades safely
+ * instead -- dlsym returns NULL on any winemac without this patch, and DXMT falls back.
+ * (macgameport, 2026-08-31) */
+DECLSPEC_EXPORT macdrv_metal_layer dxmt_acquire_remote_layer(HWND hwnd, macdrv_view *ret_view)
+{
+    return my_dxmt_acquire_remote_layer(hwnd, ret_view);
+}

--- a/dlls/winemac.drv/window.c
+++ b/dlls/winemac.drv/window.c
@@ macdrv_client_surface_acquire_metal_swapchain, the cross-process CHILD branch @@
     /* was: surface->metal_swapchain = macdrv_create_offscreen_swapchain(root, hwnd,
                                            cgrect_from_rect(rect));   <- rect is the CHILD's own
        client rect, i.e. (0,0,w,h), so every hosted layer landed at the root's origin. */
+    /* GEOMETRY: pass the child's rect IN THE ROOT'S SPACE. Computed the same way the update path
+     * further down already does (NtUserGetWindowRect + OffsetRect by the root), so the frame set
+     * at creation and the frame set on every later move agree. WineContentView isFlipped == YES,
+     * so top-left origin matches Win32 and no Y-flip is needed. */
+    RECT child_rect = rect, root_rect;
+    UINT geom_dpi = NtUserGetWinMonitorDpi(hwnd, MDT_RAW_DPI);
+
+    if (NtUserGetWindowRect(hwnd, &child_rect, geom_dpi) &&
+        NtUserGetWindowRect(root, &root_rect, geom_dpi))
+        OffsetRect(&child_rect, -root_rect.left, -root_rect.top);
+    else
+        child_rect = rect;   /* fall back to the old behaviour rather than guess */
+
+    surface->metal_swapchain = macdrv_create_offscreen_swapchain(root, hwnd,
+                                   cgrect_from_rect(child_rect));

--- a/dlls/winemac.drv/cocoa_window.m
+++ b/dlls/winemac.drv/cocoa_window.m
@@ macdrv_window_create_ca_layer_host_view / macdrv_window_update_ca_layer_host_frame @@
     /* ⚠ THIS IS THE ONE THAT REMOVED THE BLACK BAND.
      * frame arrives in WIN32 coordinates (raw pixels); CALayer.frame is in POINTS. On a retina
      * display those differ by 2x, so an unconverted frame is twice the size it should be and its
      * content is pushed down and right -- seen as a black band between Steam's chrome and its page
      * content. Measured: window 1010x600 points, frames arriving as 2020x1200.
      * Convert at the Cocoa entry points, matching the driver's convention that window.c works in
      * Win32 space and the .m side converts. */
-            [(WineContentView*)content_view addCALayerHostViewWithContextId:context_id frame:frame];
+            [(WineContentView*)content_view addCALayerHostViewWithContextId:context_id
+                                                                      frame:cgrect_mac_from_win(frame)];
...
-            [(WineContentView*)content_view updateCALayerHostFrame:context_id frame:frame];
+            [(WineContentView*)content_view updateCALayerHostFrame:context_id
+                                                             frame:cgrect_mac_from_win(frame)];

STILL OPEN, carried from the earlier work and not addressed here:
  * my_dxmt_acquire_remote_layer deliberately leaks the previous client surface. Releasing it on
    the next acquire destroys the layer DXMT is still rendering into and the window goes black.
    Lifetime should be driven by DXMT releasing its swapchain instead.

=====================================================================================
ADDENDUM 2026-08-31 — the two RESIZE defects, both measured, both fixed.

The footer below ("STILL OPEN") described the surface leak; that was closed earlier the same day
by the view-keyed table + dxmt_release_remote_layer. What remained was resize, reported live as
"flickers on resize and with some resize i was able to blackout the child windows" plus white
hairlines at the right and bottom edges. Those are TWO INDEPENDENT bugs, and neither is a race:
both are steady-state and both reproduce on demand.

Instruments built for this (both in scripts/, both reusable):
  win-resize-driver.exe  -- applies EXACT window sizes via SetWindowPos, per-monitor DPI aware so
                            it can request ODD raw pixel sizes; also dumps the Win32 child tree.
  pixel-probe            -- mean RGB of the outermost N columns/rows of a captured window against
                            an interior reference. A 1-device-pixel seam is invisible in a
                            screenshot and unarguable in a measurement.
Reproduce with -DDXMT_RSZ_DEBUG on winemac.drv for the dxmt-rsz trace.

--- a/dlls/winemac.drv/cocoa_window.m
+++ b/dlls/winemac.drv/cocoa_window.m
@@ new helper, and applied at both CALayerHost entry points @@
+/* DEFECT 1 -- the white hairline. Win32 speaks RAW PIXELS, Cocoa speaks POINTS, and on retina that
+ * is a factor of two, so an ODD pixel dimension converts to a HALF point. The NSWindow's content
+ * view is sized in WHOLE points, so a layer that Win32 says reaches the window edge stops exactly
+ * ONE DEVICE PIXEL short of it and the white window surface beneath shows through.
+ *
+ * MEASURED. root 2401x1500 px -> host frame 1200.5x750.0 pt inside a 1201.0x750.0 pt view; the
+ * capture's column x=2401 reads 255,255,255 against an interior of 15,25,36. The axis that is odd
+ * is the axis that shows it: 2401x1500 gives a right-edge line only, 2400x1501 a bottom-edge line
+ * only, 2400x1500 none. All four parity combinations re-measured after the fix: none.
+ *
+ * Extend to the view's edge, and ONLY at the edge -- an interior sibling keeps its exact geometry,
+ * so this can never make two widgets overlap. No-op when retina is off. */
+static CGRect dxmt_fill_view_edges(CGRect frame, CGRect view)
+{
+    if (CGRectIsEmpty(frame) || CGRectIsEmpty(view)) return frame;
+    if (frame.origin.x > 0.0 && frame.origin.x <= 1.0) { frame.size.width  += frame.origin.x; frame.origin.x = 0.0; }
+    if (frame.origin.y > 0.0 && frame.origin.y <= 1.0) { frame.size.height += frame.origin.y; frame.origin.y = 0.0; }
+    if (CGRectGetMaxX(frame) >= view.size.width  - 1.0) frame.size.width  = view.size.width  - frame.origin.x;
+    if (CGRectGetMaxY(frame) >= view.size.height - 1.0) frame.size.height = view.size.height - frame.origin.y;
+    return frame;
+}

@@ addCALayerHostViewWithContextId:frame: @@
+    /* the mirrored content can still be one device pixel narrower than the slot (its size is the
+     * odd Win32 rect, the slot is the whole-point view) -- paint that residue BLACK rather than
+     * letting the white window surface through */
+    host.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
+    frame = dxmt_fill_view_edges(frame, self.layer.bounds);

@@ updateCALayerHostFrame:frame: @@
+    frame = dxmt_fill_view_edges(frame, self.layer.bounds);

@@ new method + both entry points now take a `double zpos` @@
+/* DEFECT 2 -- the blackout. Hosted layers were stacked in the order they were CREATED. */
+- (void) setCALayerHostZPosition:(CAContextID)contextId zPosition:(double)zpos
+{
+    CALayerHost* host = [_caLayerHosts objectForKey:@(contextId)];
+    if (host && host.zPosition != zpos)
+    {
+        [CATransaction begin];
+        [CATransaction setDisableActions:YES];
+        host.zPosition = zpos;
+        [CATransaction commit];
+    }
+}

--- a/dlls/winemac.drv/window.c
+++ b/dlls/winemac.drv/window.c
@@ new helper; called from WM_MACDRV_CREATE_REMOTE_LAYER and update_remote_layer_frames @@
+/* DEFECT 2, the cause. Steam's client is TWO SIBLING CefBrowserWindow trees on one root --
+ * measured with win-resize-driver.exe tree:
+ *     root 0x30124 SDL_app "Steam"
+ *       +- 0x1013E CefBrowserWindow 2398x1215 @1,250   TOP sibling     -> hosts child 0x10140
+ *       +- 0x6012A CefBrowserWindow 2400x1500 @0,66    BOTTOM sibling  -> hosts child 0x2011E
+ * NOT parent and child, as their rectangles invite you to assume. CEF recreates a swapchain on
+ * every resize, so any resize that recreated the LOWER browser's surface added its layer LAST and
+ * therefore ON TOP of the upper one -- covering the content with a full-window layer nothing was
+ * drawing into. The client went black and STAYED black, because the next resize recreated it
+ * again. 2400x1500 -> 2399x1499 -> 2400x1500 reproduced it every time (interior luminance 82 ->
+ * 1 -> 0); after the fix the same sequence measures 63 -> 63 -> 113, and 60 alternations at 60ms
+ * finish rendering with the hosted population stable at 3 and 0 GPU crashes.
+ *
+ * Siblings are walked BOTTOM to TOP (GW_HWNDNEXT runs top to bottom) and a window is numbered
+ * before its own children, so a child sits above its parent and an upper sibling sits above the
+ * whole subtree of a lower one. Observed live: 0x2011E -> z2, 0x10140 -> z5, independent of
+ * creation order. */
+static void paint_index_walk(HWND parent, HWND target, int *next, int *found, int depth)
+{
+    HWND kids[64], k;
+    int n = 0, i;
+
+    if (depth > 8) return;
+    for (k = NtUserGetWindowRelative(parent, GW_CHILD); k && n < 64;
+         k = NtUserGetWindowRelative(k, GW_HWNDNEXT))
+        kids[n++] = k;
+    for (i = n - 1; i >= 0; i--)
+    {
+        int mine = (*next)++;
+        if (kids[i] == target) *found = mine;
+        paint_index_walk(kids[i], target, next, found, depth + 1);
+    }
+}
+
+static double dxmt_paint_zpos(HWND root, HWND child)
+{
+    int next = 1, found = 0;
+    if (!root || !child) return 0.0;
+    paint_index_walk(root, child, &next, &found, 0);
+    return (double)found;
+}

WHAT IS STILL NOT FIXED: nothing found in the resize path by these instruments. The earlier
"flicker" report is not separately measurable now — every capture after a settle is correct, and
a 60x60ms churn ends correct — but a sub-frame flash during a live drag would not show up in a
post-settle capture, so it is UNTESTED rather than fixed. Say that, do not claim more.

=====================================================================================
ADDENDUM 2 — 2026-08-31, DEFECT 3: a 0x0 window stretched over the whole view.

Found by JAMES in ~2 minutes of ordinary use ("when i navigated to library"), immediately after
the scripted resize suite above passed clean. Worth stating plainly: the suite drove GEOMETRY and
never drove CONTENT, so it could not have found this. Navigation is a different axis entirely.

SYMPTOM: Steam's client goes fully black on navigating to the Library. 0 GPU crashes. A resize
does NOT clear it. Navigating back to the store DOES.

MECHANISM: CEF keeps both browsers in the z-order and collapses the inactive one to 0x0.
  while black:   0x1013E / 0x10140  =  0x0        (top sibling, hosted)
  after back:    0x1013E / 0x10140  =  2598x1275
The create path tested `CGRectIsEmpty(frame)` and treated empty as "no child rect was supplied",
which is the ROOT-window case -- so it stretched the layer to the whole content view with an
autoresizing mask. z-order then correctly put that top sibling above the live content, and the
layer had nothing drawn in it. Black. The update path SKIPPED empty frames, so a layer that
became 0x0 while hosted kept its last full-size frame -- the same blackout by a second route,
and the reason a resize could not clear it.

Trace of the exact moment (-DDXMT_RSZ_DEBUG), on the Library navigation:
  HOST update ctx=1003097821 frame=0.0,0.0 0.0x0.0  (was 0.0,92.0 1300.0x637.5)   <- collapsed
  HOST create ctx=2870122112 frame=0.0,0.0 0.0x0.0  (view 1300.0x780.0)           <- empty at birth
  HOST zpos   ctx=2870122112 -> z5  stack: 2870122112(z5) 1003097821(z5) 280041656(z2)
Under the old code that z5 layer became 1300x780 and covered everything.

FIX: `CGRectIsEmpty` cannot distinguish "unknown" from "genuinely zero" -- so stop asking it to.
window.c already passes CGRectNull when no child rect exists, so test THAT first. Three cases:

--- a/dlls/winemac.drv/cocoa_window.m
+++ b/dlls/winemac.drv/cocoa_window.m
@@ addCALayerHostViewWithContextId:frame: @@
-    if (!CGRectIsEmpty(frame)) { host.frame = frame; host.masksToBounds = YES; }
-    else { host.frame = self.layer.bounds; host.autoresizingMask = WidthSizable|HeightSizable; }
+    if (CGRectIsNull(frame))          /* no child rect supplied -- root window, unchanged */
+    { host.frame = self.layer.bounds; host.autoresizingMask = WidthSizable|HeightSizable; }
+    else if (CGRectIsEmpty(frame))    /* the window really is 0x0 -- HIDE it, never stretch it */
+    { host.frame = CGRectZero; host.masksToBounds = YES; host.hidden = YES; }
+    else
+    { host.frame = frame; host.masksToBounds = YES; }

@@ updateCALayerHostFrame:frame: -- an empty frame was silently skipped @@
+    if (host && CGRectIsEmpty(frame) && !CGRectIsNull(frame))
+        host.hidden = YES;            /* became 0x0 while hosted */
+    else if (host && !CGRectIsEmpty(frame) && !CGRectEqualToRect(host.frame, frame))
+    { host.frame = frame; host.hidden = NO; }   /* and un-hide when it gets area again */

@@ both entry points: do NOT run CGRectNull through the retina divide @@
-    frame:cgrect_mac_from_win(frame)
+    frame:CGRectIsNull(frame) ? CGRectNull : cgrect_mac_from_win(frame)

VERIFIED: store -> library -> friends -> downloads -> library -> store, all six render
(2.8-4.6 MB captures, interior luminance 38-115, none black), 0 GPU crashes.

=====================================================================================
ADDENDUM 3 — 2026-08-31: one regression of my own, and one claim withdrawn.

(A) REGRESSION, introduced by Addendum 2 and live for about an hour: Steam's FRIENDS LIST
    rendered fully black (20,420 B capture, interior luminance 0). Found by James, again in
    ordinary use.

    Addendum 2 added "hide a zero-area layer". The un-hide was written as one branch:
        else if (host && !CGRectIsEmpty(frame) && !CGRectEqualToRect(host.frame, frame))
        { host.frame = frame; host.hidden = NO; }
    ...so un-hiding only happened when the FRAME CHANGED. Trace of the failure:
        create ctx=1274046919 frame 300.0x650.0
        update frame   0.0x0.0                      -> hidden = YES          (brief 0x0)
        update frame 300.0x650.0 (was 300.0x650.0)  -> EQUAL, branch skipped, stays hidden
    The frame returned to a value it already held, so the guard suppressed the un-hide forever.

    LESSON, and it is the general one: VISIBILITY AND GEOMETRY ARE INDEPENDENT STATE. Do not
    gate a change to one on a change to the other. Fixed by splitting the tests, and by zeroing
    the frame on hide as a second net:
+        if (host && CGRectIsEmpty(frame) && !CGRectIsNull(frame))
+        { host.hidden = YES; host.frame = CGRectZero; }
+        else if (host && !CGRectIsEmpty(frame))
+        {
+            if (!CGRectEqualToRect(host.frame, frame)) host.frame = frame;
+            if (host.hidden) host.hidden = NO;
+        }
    VERIFIED: Friends List 20,420 B / lum 0  ->  274,680 B / lum 38, rendering completely
    (avatar, name, FRIENDS header, GROUP CHATS, all text legible).

(B) CLAIM WITHDRAWN — macdrv_swapchain_set_bounds() IS DEAD CODE.

    The first addendum above says CAContextSwapChain "sets its layer bounds ONCE at init ... seen
    live as stale strips of old content, black boxes in a corner, and sometimes a wholly black
    content area", and adds macdrv_swapchain_set_bounds to fix it. THAT FUNCTION HAS NEVER RUN.
    Its only caller is macdrv_client_surface_update()'s remote-layer branch, and across five
    instrumented sessions that branch logged ZERO firings (SURF-UPD=0, CONTENT=0) while
    HOST create/update logged 67, 120, 184 and 101 respectively. CEF resizes by DESTROYING and
    RECREATING the swapchain, so the in-place resize path is simply never taken.
    Whatever improved in that build came from the two changes beside it. Kept, annotated, not
    credited. This is the "never assert a code behavior you have not run" rule, self-inflicted.

(C) SHIMMER — partially answered. James reports that resizing now shimmers the BACKGROUND art
    while foreground images stay clear. It is NOT the compositor stretching our layers: the only
    path that could stretch one is (B), which never executes, and the instrumented SCALE check
    logged 0 stretch events. What the trace DOES show is churn — 24 scripted resize steps
    produced 101 HOST creates and 83 removes across the two browsers, i.e. layers are constantly
    un-hosted and re-hosted, and the window shows whatever is behind during each gap. That is a
    HYPOTHESIS, not a finding: it has not been tested. A fix would mean holding the retired host
    layer until its replacement is confirmed hosted, which is a design change, not a tweak.

=====================================================================================
ADDENDUM 4 — 2026-08-31: hardening pass. Six defects found by re-reading the code above,
not by any failure. Plan: docs/plans/hosting-layer-hardening.md

D1 QUADRATIC WALK ON THE HOT PATH (the worst one). dxmt_paint_zpos() walked the ENTIRE window
   tree from the root, and was called INSIDE update_remote_layer_frames()'s per-layer loop — so
   every WindowPosChanged cost layers x full_tree_walk, each node an NtUserGetWindowRelative
   syscall, on the path that fires continuously while a window is dragged. Replaced with one
   walk per update into a flat paint-ordered array, then an index lookup per layer. The create
   path handles a single child and builds the same order once, which is what it did before.

D2 SILENT TRUNCATION. `HWND kids[64]` and `depth > 8`, neither logged: exceed either and layers
   silently got z-order 0. Both now ERR() exactly once per build (guarded so a deep tree cannot
   spam a per-frame path). An unlogged cap reads as "we ordered everything" when we did not.

D3 AMBIGUOUS SENTINEL. dxmt_paint_zpos() returned 0.0 for "not found" AND as a legitimate
   bottom-most position, so a lookup miss silently slammed a layer to the back. Now
   paint_order_zpos() returns BOOL with the index by out-param, and a `zpos_valid` flag travels
   to the Cocoa side, which leaves zPosition untouched when we do not know it.

D4 MAGIC THRESHOLD. dxmt_fill_view_edges() hardcoded 1.0 point. The quantity that matters is ONE
   DEVICE PIXEL — 0.5 pt on retina, 1.0 otherwise — so it is now derived from retina_on. The old
   value also snapped rects a whole point from the edge on retina, closing a two-device-pixel gap
   an app may have asked for.

D5 ALIASING IN THE DEFERRED BACKGROUND. The block re-looked-up the context id, so a remove+create
   of the same id inside the 120 ms would paint the replacement's background early — the very
   flash the deferral exists to prevent. It now captures the CALayerHost and tests identity.

D6 pending_release IS STILL ONE GLOBAL SLOT — deliberately NOT changed. It is a delay, not a
   lifetime design, and the proper fix (hold the retired host until its replacement is confirmed
   hosted) rests on the UNTESTED churn hypothesis. Building on that before measuring it is how
   you aim a good fix at the wrong mechanism. See the plan, phase 2b.

VERIFIED on the rebuilt module: seam 0 bright edges on all four parities; blackout sequence
2400x1500 -> 2399x1499 -> 2400x1500 measures 54 -> 43 -> 80 interior luminance; navigation and
the Friends List render; 40-alternation churn ends clean; no truncation logged; 0 GPU crashes.

=====================================================================================
ADDENDUM 5 — 2026-08-31: the shimmer, measured and closed.

T1 (docs/plans/hosting-layer-hardening.md) finally isolated it. Capture DURING a scripted churn,
against an identically-sampled static control:

  build                       samples  near-black frames  rate    interior lum min
  pre-fix                          40                  2  5.00%                   0
  + retire-on-create              160                  2  1.25%                   0
  + per-child deferred release    320                  0  0.00%                  28

The dark frames are DIAGNOSTIC, not merely dark: Steam's chrome (menu bar, nav, URL bar, bottom
bar) renders perfectly with the ENTIRE content area black. That is the content browser's layer
with nothing to show. At churn rate during a drag, that is the shimmer.

TWO CHANGES, and the second only became findable after the first:

(1) RETIRE ON CREATE, NOT ON DESTROY (window.c, retire_superseded_layers()). Removal used to be
    driven by the old swapchain dying; the replacement arrived later on its own message, and
    nothing was hosted in between. Now the replacement is added first and its predecessors for
    the same child are dropped after, so the child is never unhosted. 5.00% -> 1.25%.

(2) THE DEFERRED RELEASE IS NOW PER CHILD HWND (macdrv_main.c), not one global slot. This is the
    only lever that can keep CONTENT alive across a recreate: CAContextSwapChain's dealloc
    releases the remote CAContext, so a CALayerHost whose context is gone has nothing to show and
    keeping the host hosted cannot help. Deferring the client_surface release defers the dealloc,
    which defers the context destruction. With one global slot, browser A's release drained
    browser B's held context early. Keyed per child, a context now survives until the NEXT
    release for that same child, which by construction is after its successor was acquired.
    1.25% -> 0.00% across 320 samples (p ~ 0.018 against the prior rate).

⚠ A DESIGN THAT WAS KILLED BY READING BEFORE BUILDING: "keep the orphaned host alive until a
  successor lands" cannot work. dealloc does `[context setLayer:nil]; [context release]`, so the
  host has no content source to preserve. Checking that saved building the wrong fix.

BOOT-VERIFIED on the final module (winemac is on the game's boot path): SceneFlow 07:56:32 ->
"MainMenu reached" 07:57:35, 0 InvalidProgramException, 6 mods. Judged by a timestamp that
postdates the install — the first attempt matched a STALE 06:14 log and was nearly reported as
a pass.

=====================================================================================
ADDENDUM 6 — 2026-08-31: style pass, measured against winemac's own conventions.

Checked rather than assumed. Our code vs the file it lives in:
  Allman braces (opening brace on its own line)   MATCHES
  no tabs introduced                              MATCHES (the file's only 2 tabs are pre-existing,
                                                   in a comment at window.c:923)
  no `//` comments introduced                     MATCHES — 0 across all three files
  ERR/TRACE rather than fprintf in shipped code   MATCHES (5 uses; the only `fprintf` outside the
                                                   -DDXMT_RSZ_DEBUG block is the word inside a comment)
  lines <= 100 columns                            3 VIOLATIONS, now fixed:
    - the two ca_layer_host entry-point signatures ran to 129/130 cols; wrapped, and their
      declarations in macdrv_cocoa.h with them
    - one PRE-EXISTING wine line hit 119 cols only because our new guard indented it a level
      further; wrapped rather than left as collateral

The rebuilt module hashes to 49746334d0875733 — BYTE-IDENTICAL to the pre-reformat build. The
style pass provably changed no behaviour, so nothing needed re-verifying.

Still knowingly divergent from wine's house style, and stated so it is a choice rather than an
oversight: the comments are far longer than wine's. That is deliberate here — this project
requires measurements to live next to the code they justify — and it is the first thing that
would have to be cut in half for upstream.

=====================================================================================
ADDENDUM 7 — 2026-09-02: the comment/provenance form pass, and the measurements it evicted.

Pass (a) of docs/plans/winemac-reference-upstream-form.md § 2: strip handle tags, dates and the
one EXPERIMENT banner from the five winemac.drv files, and cut comment volume toward wine's own
rate by moving EVIDENCE here and leaving REASONS in the code. Comments only — no code byte was
touched. Counts on the project's own added lines (git diff aquadran..form, five files):

  macgameport handle tags   9 -> 0
  EXPERIMENT headers        1 -> 0
  dated lines              22 -> 0
  comment-only added lines 241 -> 96   (28.7% -> 13.8% of added lines; 24.0% -> 11.6% vs stock)

BYTE-IDENTITY: THE PLAN'S T1 PREMISE IS FALSE FOR window.c, AND HERE IS WHY.

The pass was supposed to rebuild to the same sha256 as the pre-pass module (acbf3156..., the
unsigned build-dir artifact). It does not: the rebuilt module is 4f4cafae..., same 503,800 bytes.
No code changed. The cause is window.c:1328 (pre-pass), wine's own

    assert(client->funcs == &macdrv_client_surface_funcs);

in impl_from_client_surface(). macOS `assert` expands to __assert_rtn(__func__, __FILE__,
__LINE__, ...), so the line number is baked into the object as an immediate. Removing 32 comment
lines above it moved the assert from line 1328 to 1296, and the immediate moved with it.

Measured, not argued -- four independent checks:
  * cocoa_window.o and macdrv_main.o rebuild BYTE-IDENTICAL (bf9db14e..., 61ebc8fd...). Those two
    files contain no assert(); the only assert() in the three edited files is the one above.
  * window.o differs in EXACTLY 5 bytes -- cmp -l positions 27987, 28035, 28083, 28131, 28179,
    each 0x30 -> 0x10, the low byte of 1328 (0x530) becoming 1296 (0x510). Five copies because
    impl_from_client_surface() is inlined at five call sites, each carrying its own immediate.
  * Compiled with -DNDEBUG (assert removed, same flags otherwise), the pre-pass and post-pass
    window.c produce a BYTE-IDENTICAL window.o (7d019631...). Nothing but the assert differs.
  * Warning set unchanged: 36 warnings, identical text, before and after.

So the behaviour is provably unchanged, and the changed bytes are the line number an assertion
failure would print -- which SHOULD move, because the line moved. T1's gate for a comment pass
needs restating as "byte-identical under -DNDEBUG" (or "identical except the assert __LINE__
immediate") for any file containing an assert(). Freezing the line number instead would mean
padding the file to preserve a count, which is a worse artefact than the difference it hides.

MEASUREMENTS EVICTED FROM COMMENTS, kept here so the reasons stay checkable. Only the ones not
already recorded above; anything already in Addenda 1-6 was dropped as duplication.

(1) retire_superseded_layers() -- the gap measurement in full. T1 of
    docs/plans/hosting-layer-hardening.md drove 240 scripted resize steps and took 40 captures
    DURING the churn: 35 distinct frames, 2 of them with a black content area (chrome -- menu bar,
    nav, URL bar, bottom bar -- rendering perfectly with nothing in the middle). A 40-capture
    static control on the same window produced ONE distinct frame and zero black ones. The rate
    table in Addendum 5 is the summary of this; the step count, the distinct-frame count and the
    static control were only in the code.

(2) The deferred black background -- WHY IT IS STILL THERE. Removing it outright was tried and
    re-measured, and the white seam comes straight back, exactly on the odd axis:
        2400x1500 -> 0 bright edges    2401x1500 -> 1
        2400x1501 -> 1                 2401x1501 -> 2
    So it is load-bearing and dxmt_fill_view_edges() alone is NOT enough. (Addendum 4/D4 records
    the retina threshold fix; it does not record that the background survives it.)

(3) The deferred black background -- WHY IT IS DEFERRED, and by how much. 120 ms, on
    dispatch_get_main_queue(). backgroundColor paints the WHOLE layer and a hosted layer is
    visible from the moment it is added, before the remote CAContext has presented anything, so
    setting it at creation flashed a full black rectangle on every newly hosted layer. Reported
    live as "black box lag as I mouse back and forth over the menus" -- each menu is its own popup
    window, so each one hosts a fresh layer.

(4) The three-case frame test -- the first measurement, before the 0x0 case was known: with every
    host stretched to the whole content view, inserting a second host at the bottom of the stack
    measured BLACK. That is what motivated positioning and clipping hosts to a real child rect.

(5) macdrv_swapchain_set_bounds() -- the five instrumented sessions named. Addendum 3(B) says
    "five instrumented sessions"; they were resize-diag, -fix, -final, -ship, and the popup runs.

(6) Surface keying -- why by VIEW and not by HWND: the client re-acquires the same HWND several
    times. Measured 16 distinct windows, 4 acquires each.

(7) pending_by_child -- the dead-child leak, found by the 2026-09-02 review pass rather than by a
    failure: every closed popup menu parked one swapchain forever, because a destroyed child never
    releases again and nothing swept its slot.

(8) The WINPOS instrument's original question, now that its comment no longer states it: a black
    band persisted between Steam's chrome and its page content after creation geometry had been
    ruled out (children sit at the root origin), so the update path was instrumented to find which
    layer was misplaced or missing. Answer was the Win32-pixels -> Cocoa-points conversion,
    Addendum 1.

(9) The CONTENT/SCALE instrument line: with kCAFilterNearest a STRETCHED layer makes photographic
    background art shimmer while flat UI and text stay crisp, which is the reported symptom in
    Addendum 3(C) exactly -- which is why that instrument prints the drawable-to-bounds ratio.
    It logged 0 stretch events, so it eliminated rather than confirmed.

(10) The deferred-by-one release -- the symptom that motivated it, before T1 measured anything.
     An immediate release deallocs the CAContextSwapChain and posts WM_MACDRV_RELEASE_REMOTE_LAYER,
     un-hosting the layer at once, and a client that resizes by destroying a swapchain and creating
     a new one then has nothing hosted between the two. Observed live as flicker on resize, and as
     a permanently black child when the ordering was unlucky. Addendum 5 records the rate table
     that followed; this was the observation the deferral was built from.

WHAT DELIBERATELY STAYED IN THE CODE: the reason for every non-obvious branch -- why a child's
rect is converted to the root's space, why a zero-area layer is hidden rather than stretched, why
visibility and geometry are tested separately, why layers are stacked by Win32 paint order, why
the superseded layer is retired only after its replacement is in the tree, why the surface table
is keyed by view, and why the release is deferred by one. The incidents behind them are here; the
reasons are there. The DXMT_RSZ instrument blocks are untouched apart from their tags and dates --
pass (b) removes them wholesale.
