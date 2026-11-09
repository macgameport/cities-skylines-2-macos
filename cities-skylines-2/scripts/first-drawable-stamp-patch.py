#!/usr/bin/env python3
"""first-drawable-stamp-patch.py -- an INSTRUMENT-ONLY build that times a hosted swapchain's life.

    bash scripts/build-winemac.sh <out.so> scripts/first-drawable-stamp-patch.py [--colours [...]]
    (or directly: python3 scripts/first-drawable-stamp-patch.py <cocoa_window.m> [--colours [...]])

`--colours` also applies `diag-colours-patch.py` to the same file, and passes anything after it
straight through (`--colours --noblue`, `--colours --cyan`). S1a wants both in ONE module: the
timing is trace-only and needs no colour, but the same runs are S1b's video source and a build
that paints nothing gives S1b nothing to see. The two patchers touch disjoint anchors -- the
colours patch the backgrounds, this one patches the layer class and the lifecycle -- so this
delegates rather than duplicating, which is also what keeps `build-winemac.sh`'s one-patcher
contract intact.

⚠ `main` only, and it patches cocoa_window.m only -- the same two constraints, for the same
reasons, as `diag-colours-patch.py`. Read that file's header before this one.

WHAT IT IS FOR. The S3 plan's S1a asks two questions that no measurement on disk can answer:

  (i)  how long after the owner hosts a new generation does that generation actually PRESENT?
  (ii) does the child detach the OLD context before or after the new one's first present?

(ii) decides candidate D. If the child detaches early in more than 5 % of generations, D cannot
reach the tail and the plan returns to § 2. Neither question is answerable today: nothing in wine
stamps a first drawable (0 hits for `nextDrawable` / `first drawable` in `window.c`,
`cocoa_window.m`, `macdrv.h`), and `layer-gap.py` -- written believing it measured this -- turned
out to measure the re-create CADENCE instead.

⚠ **THIS BUILDS A DIAGNOSTIC, NOT A CANDIDATE.** It adds a CAMetalLayer subclass and five trace
points and changes no behaviour. It is not on any candidate's path and must never be installed as
a daily driver.

────────────────────────────────────────────────────────────────────────────────────────────────
THE CLOCK, which is the whole difficulty and the thing to check first if a run reads oddly.

S1a needs the child's acquire compared with the OWNER's host-commit (`window.c:1717`). Those are
two processes, so they need one clock. Wine's own `+timestamp` prefix IS that clock -- it is
`NtGetTickCount()` (`ntdll/unix/debug.c:334-336`), which reads `user_shared_data->TickCount`, a
section the WINESERVER maps into every process in the prefix. Same section, same value, all
processes: that is what makes a cross-process comparison legitimate at all.

⚠ But the Cocoa side does NOT get that prefix. `ERR()` (`cocoa_app.h:25`) calls `LogErrorv`, which
is a raw `fprintf(stderr, "err:%s:%s", ...)` (`cocoa_app.m:2402-2412`) and never enters wine's
debug-header machinery. Measured in a real trace (2026-09-06, baseline r1): **300 lines matching
`^err:` with no timestamp at all**, against 35 timestamped `err:` lines from the wine side. So a
stamp emitted the obvious way would land on no clock and be useless for exactly the comparison it
exists to make.

Hence the stamp prints the tick ITSELF. `NtGetTickCount` is `WINAPI`, and on x86_64 `WINAPI` ->
`__stdcall` -> `__attribute__((ms_abi))` (`include/minwindef.h:157`, `include/msvcrt/corecrt.h:112-117`)
with **no unix-lib carve-out**, even though winemac.drv is a `UNIXLIB` (`Makefile.in:2`) built as
native code -- so the declaration below carries the attribute explicitly. Getting that wrong would
not fail the build; it would produce a plausible-looking wrong number.

⚠ **So the number is checked, not trusted.** `tick` is printed in the same milliseconds the trace's
own `sss.mmm` prefix shows, and `scripts/align-trace-video.py --check-clock` REFUSES a run whose
stamp ticks fall outside the range of the trace's own timestamps. Run that before reading any S1a
number. A stamp line reading `tick=0` or a tick nowhere near the trace's is the ABI going wrong,
not the compositor.

WHAT IT EMITS (all via ERR, so `WINEDEBUG=+err` is enough -- the drag harness already passes it):

    stamp create    ctx=%u tick=%u media=%.6f          the child's own create, pairs with :1717
    stamp acquire   ctx=%u tick=%u media=%.6f          FIRST nextDrawable for this generation
    stamp presented ctx=%u tick=%u media=%.6f pres=%.6f drops=%d
                                   the generation's FIRST drawable that really reached the
                                   display; drops = how many were discarded before it
    stamp relpost   ctx=%u tick=%u media=%.6f          the child POSTS release, pairs with :1770
    stamp detach    ctx=%u tick=%u media=%.6f          the child's async teardown actually runs

`media` is `CACurrentMediaTime()`, the mach clock `presentedTime` is expressed in -- the two are
only comparable to each other, which is why every line carries both clocks rather than one.
(macgameport, 2026-09-07)
"""
import os, subprocess, sys, io

p = sys.argv[1]

# --colours first, so a zero-match in EITHER patcher fails the build before anything is compiled.
# Its exit status is read directly and never through a pipe -- the same trap build-winemac.sh
# documents, where a `python3 patch.py | sed` reported the pipe's status and hid a "FAIL: 0 matches".
if '--colours' in sys.argv:
    i = sys.argv.index('--colours')
    rc = subprocess.run([sys.executable,
                         os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                      'diag-colours-patch.py'), p] + sys.argv[i + 1:]).returncode
    if rc != 0:
        sys.exit("FAIL: diag-colours-patch.py exited %d" % rc)

s = io.open(p, encoding='utf-8').read()


def sub(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit("FAIL %s: %d matches (want 1)" % (label, n))
    s = s.replace(old, new)
    print("  ok %s" % label)


# 1. The subclass, and the one declaration that puts the child on wine's clock. Placed immediately
#    before CAContextSwapChain because that is its only user.
sub("@interface CAContextSwapChain : NSObject <WineMetalSwapChain>",
    """/* ─── S1a INSTRUMENT (issue #13). Diagnostic only; changes no behaviour. ───────────────────
 *
 * NtGetTickCount is WINAPI == __stdcall == ms_abi on x86_64 (minwindef.h:157, corecrt.h:112),
 * and that holds even here, in a UNIXLIB compiled as native code. Declared with the attribute
 * rather than by including winternl.h, whose Windows types do not coexist with Cocoa's. If this
 * ABI were wrong the build would still succeed and the ticks would be garbage, which is why
 * align-trace-video.py --check-clock refuses a run whose ticks miss the trace's own range. */
extern unsigned int __attribute__((ms_abi)) NtGetTickCount(void);

#define STAMP(what, ctx) ERR(@"stamp " what " ctx=%u tick=%u media=%.6f\\n", \\
                             (unsigned int)(ctx), NtGetTickCount(), CACurrentMediaTime())

/* A CAMetalLayer that reports its FIRST drawable per generation, and when that drawable was
 * presented. DXMT acquires through the layer object wine hands it (winemetal_unix.c:1496-1498,
 * `[layer nextDrawable]`), so a subclass is on the path -- unlike the glue's own
 * WineMetalLayer hook (dxmt_objc.m:38-72), which fires only when the layer's delegate is a
 * WineMetalView and this layer never has one.
 *
 * Only the first ACQUIRE per generation is stamped: there are ~300 generations in a drag and
 * every one of them acquires repeatedly, so stamping all of them would bury the signal and slow
 * the very path being timed.
 *
 * ⚠ PRESENT is different, and the first version of this instrument got it wrong. It stamped the
 * presentedTime of the FIRST drawable only -- but `presentedTime` is **0 when the drawable was
 * never presented** (dropped or discarded; addPresentedHandler: fires on retire either way), and
 * measured on the first live row **175 of 234 first drawables came back 0**. Reading that as "this
 * generation never presented" is wrong whenever a LATER drawable of the same generation did, and
 * at 75 % it is not a corner case -- it would have decided (i) on three quarters bad data. So a
 * handler is attached to every drawable until one reports a nonzero presentedTime, and the stamp
 * carries `drops=` -- how many were discarded first, which is a datum in its own right.
 *
 * ⚠ The handler references ivars, so under MRR it RETAINS the layer until it fires. That is
 * transient (a handler runs on present or on drop, within a frame or two) and it retains the
 * LAYER, not the CAContextSwapChain -- so the swapchain's dealloc, where `detach` is stamped, is
 * not delayed and metric (ii) is unaffected. The flag is read and written from the render thread
 * and a Metal-internal thread without a lock; the worst case is a duplicate `presented` line,
 * which is visible in the output, and the analysis keeps the FIRST per context id. */
@interface WineStampMetalLayer : CAMetalLayer
{
    unsigned int stampContextId;
    BOOL sawFirst;
    BOOL presentedStamped;
    int drops;
}
- (void) setStampContextId:(unsigned int)cid;
@end

@implementation WineStampMetalLayer

- (void) setStampContextId:(unsigned int)cid
{
    stampContextId = cid;
    STAMP("create", cid);
}

- (id<CAMetalDrawable>) nextDrawable
{
    id<CAMetalDrawable> d = [super nextDrawable];
    unsigned int cid = stampContextId;

    if (!d) return d;

    if (!sawFirst)
    {
        sawFirst = YES;
        STAMP("acquire", cid);
    }
    /* Keep attaching until one drawable actually reaches the display. addPresentedHandler: is
     * public on MTLDrawable (macOS 10.15.4+); the block runs on a Metal-internal thread. */
    if (!presentedStamped)
    {
        [d addPresentedHandler:^(id<MTLDrawable> pd) {
            if (presentedStamped) return;
            if (pd.presentedTime > 0)
            {
                presentedStamped = YES;
                ERR(@"stamp presented ctx=%u tick=%u media=%.6f pres=%.6f drops=%d\\n",
                    cid, NtGetTickCount(), CACurrentMediaTime(), pd.presentedTime, drops);
            }
            else
                drops++;
        }];
    }
    return d;
}

@end

@interface CAContextSwapChain : NSObject <WineMetalSwapChain>""",
    "stamp subclass + the ms_abi tick declaration")

# 2. The swapchain builds the subclass instead of a plain CAMetalLayer. Nothing else about the
#    layer changes -- DXMT rewrites its properties afterwards either way
#    (dxmt_presenter.cpp:16-21 -> winemetal_unix.c:1517-1529).
sub("    offscreen_layer = [[CAMetalLayer alloc] init];",
    "    offscreen_layer = [[WineStampMetalLayer alloc] init];   /* S1a instrument */",
    "swapchain allocates the stamp layer")

# 3. The context id is not known until the CAContext hands it over, and that is inside the
#    OnMainThread block -- so the layer is told its id there, not at construction. DXMT cannot
#    have acquired yet: macdrv_swapchain_get_layer is what gives it the layer, and that is only
#    reachable after this initialiser returns.
sub("        context_id = [remote_context contextId];",
    """        context_id = [remote_context contextId];
        [(WineStampMetalLayer *)offscreen_layer setStampContextId:context_id];   /* S1a */""",
    "context id handed to the stamp layer")

# 4. The child's RELEASE post -- the owner's side of this is window.c:1770, and pairing the two
#    gives the post-to-handle delay S1a (ii) needs.
sub("    if (context_id) macdrv_release_remote_layer(hwnd, context_id);",
    """    if (context_id) STAMP("relpost", context_id);   /* S1a */
    if (context_id) macdrv_release_remote_layer(hwnd, context_id);""",
    "stamp the child's release post")

# 5. The detach itself. § 2.5 (a) is explicit that RELEASE at the owner is only an UPPER bound on
#    the hold, because the child tears the context down asynchronously afterwards -- so the thing
#    D actually depends on is when THIS block runs, not when the post went out.
sub("""    OnMainThreadAsync(^{
        [context setLayer:nil];""",
    """    OnMainThreadAsync(^{
        STAMP("detach", cid);   /* S1a: the real end of the hold, not the post (§ 2.5 (a)) */
        [context setLayer:nil];""",
    "stamp the child's detach block")

# 6. ...which needs the id captured before the block, since context_id is an ivar of an object
#    that is being deallocated and must not be touched from the async block.
sub("""    CAContext *context = remote_context;
    CAMetalLayer *layer = offscreen_layer;
    macdrv_metal_device dev = device;""",
    """    CAContext *context = remote_context;
    CAMetalLayer *layer = offscreen_layer;
    macdrv_metal_device dev = device;
    unsigned int cid = context_id;   /* S1a: captured by value -- self is gone when the block runs */""",
    "capture the context id for the detach block")

io.open(p, 'w', encoding='utf-8').write(s)
print("  written")
