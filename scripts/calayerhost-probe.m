/* calayerhost-probe.m -- does an opaque CAMetalLayer with NO background composite as NOTHING
 * through a CALayerHost?  The S3 plan's S0, measured directly instead of inferred.
 *
 *   clang -O2 -fobjc-arc -o /tmp/calayerhost-probe scripts/calayerhost-probe.m \
 *       -framework Cocoa -framework QuartzCore -framework Metal
 *   /tmp/calayerhost-probe            # same process publishes and hosts
 *   /tmp/calayerhost-probe --xproc    # a separate process publishes -- wine's actual topology
 *
 * WHY THIS EXISTS RATHER THAN THE BATTERY.  § 4's candidate A removes the black background wine
 * sets on the child's offscreen layer (cocoa_window.m:4339).  Everything downstream of A depends
 * on an UNMEASURED premise: that an `opaque = YES` CAMetalLayer with no background and no drawable
 * composites as nothing.  If it instead composites as an opaque fill, A-drop is INERT and S3's
 * mutant could never be observed red.  The plan's S0 infers this from cyan episodes in a 12-run
 * drag battery; this asks the compositor the question directly.  (§ 2b, the executable-spec cure:
 * when the open question is a MECHANISM, build the artifact and run it.)
 *
 * THE THREE ARMS, hosted SIDE BY SIDE over one saturated GREEN backdrop and read from ONE capture:
 *   black   backgroundColor = black, as wine does today   -> the CONTROL.  Must read black.
 *   drop    no backgroundColor, opaque = YES              -> candidate A --drop.  The question.
 *   nonopq  no backgroundColor, opaque = NO               -> A's fallback form if --drop is inert
 *
 * ⚠ WHY ALL THREE SHARE ONE CAPTURE, and why the first design was wrong.  Measuring the arms in
 * separate captures made the answer indistinguishable from a race: "this layer contributed
 * nothing" and "this layer had not been composited yet" are the SAME green reading.  The first
 * version did exactly that and its control arm came back green on 2 runs in 3 -- intermittently
 * blind, and only detectable because the control existed at all.  Hosting all three at once means
 * every arm has had precisely the same time to commit, and the control's blackness is then a
 * property of the very frame the other two are read from.  The capture is retried until the
 * control is black; if it never is, the run is VOID and says so rather than reporting green.
 * (The C56 rule -- re-read the scorer before believing it -- in a new costume.)
 *
 * It matches DXMT's property rewrite (winemetal_unix.c:1517-1529) -- opaque, framebufferOnly = NO,
 * contentsScale, an explicit drawableSize -- because wine's own construction block is not what
 * ends up running (§ 2.1).
 *
 * ⚠ WHAT IT IS NOT.  No Metal rendering ever happens and no drawable is acquired: the state under
 * test is precisely "a published layer that has never presented".  An in-situ confirmation through
 * the real DXMT pipeline still belongs in the plan's S0.
 * (macgameport, 2026-09-07)
 */
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>

typedef uint32_t CGSConnectionID;
extern CGSConnectionID CGSMainConnectionID(void);

@interface CAContext : NSObject
+ (instancetype)contextWithCGSConnection:(CGSConnectionID)cid options:(NSDictionary *)opts;
@property(nonatomic, retain) CALayer *layer;
@property(readonly) uint32_t contextId;
@end

@interface CALayerHost : CALayer
@property uint32_t contextId;
@end

static const int S = 200;           /* each arm's square */
static const int GAP = 20;
static const int NARM = 3;
static const char *NAMES[NARM] = { "black ", "drop  ", "nonopq" };

/* Build the layer for one arm. Shared by both topologies so the two cannot drift apart. */
static CAMetalLayer *arm_layer(id<MTLDevice> dev, int arm)
{
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = dev;
    layer.framebufferOnly = NO;              /* as DXMT rewrites it */
    layer.magnificationFilter = kCAFilterNearest;
    layer.contentsScale = 1.0;
    layer.drawableSize = CGSizeMake(S, S);   /* DXMT sets one; wine never does */
    layer.anchorPoint = CGPointZero;
    layer.bounds = CGRectMake(0, 0, S, S);
    if (arm == 0)
        layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);  /* today */
    layer.opaque = (arm != 2);
    /* no drawable is ever acquired: that IS the state under test */
    return layer;
}

/* --publish <arm>: be the CHILD. Commit the layer FIRST, then print the id -- the id is the
 * parent's signal that this context is ready to host, and printing it before CA has committed is
 * what made the first cross-process run void. */
static int publish_mode(int arm)
{
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    if (!dev) { fprintf(stderr, "no Metal device\n"); return 2; }
    CAContext *cactx = [CAContext contextWithCGSConnection:CGSMainConnectionID() options:@{}];
    cactx.layer = arm_layer(dev, arm);
    [CATransaction flush];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
    printf("%u\n", cactx.contextId);
    fflush(stdout);
    [[NSRunLoop currentRunLoop] run];
    return 0;
}

/* Mean RGB of the middle of one arm's square within the captured window image. A BAND, not a
 * pixel: one pixel cannot tell a transparent layer from a sampled seam (the C59 lesson). */
static BOOL arm_rgb(CGImageRef img, int arm, int *r, int *g, int *b)
{
    size_t w = CGImageGetWidth(img), h = CGImageGetHeight(img);
    if (w < 64 || h < 64) return NO;
    /* The capture may be Retina-scaled, so work in fractions of the image, not in points. */
    double sx = (double)w / (NARM * S + (NARM + 1) * GAP), sy = (double)h / (S + 2 * GAP);
    double cx = (GAP + arm * (S + GAP) + S / 2.0) * sx, cy = (GAP + S / 2.0) * sy;
    int half = (int)(S * 0.25 * (sx < sy ? sx : sy));
    size_t bpr = w * 4;
    uint8_t *buf = calloc(h, bpr);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf, w, h, 8, bpr, cs, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), img);
    long sr = 0, sg = 0, sb = 0, n = 0;
    for (int y = (int)cy - half; y < (int)cy + half; y++)
        for (int x = (int)cx - half; x < (int)cx + half; x++) {
            if (x < 0 || y < 0 || x >= (int)w || y >= (int)h) continue;
            uint8_t *p = buf + (size_t)y * bpr + (size_t)x * 4;
            sr += p[0]; sg += p[1]; sb += p[2]; n++;
        }
    CGContextRelease(ctx); CGColorSpaceRelease(cs); free(buf);
    if (!n) return NO;
    *r = (int)(sr / n); *g = (int)(sg / n); *b = (int)(sb / n);
    return YES;
}

static CGImageRef capture_window(int winid, NSString *png)
{
    NSTask *t = [[NSTask alloc] init];
    t.launchPath = @"/usr/sbin/screencapture";
    t.arguments = @[@"-x", @"-o", [NSString stringWithFormat:@"-l%d", winid], png];
    [t launch]; [t waitUntilExit];
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:png],
                                                      NULL);
    if (!src) return NULL;
    CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
    CFRelease(src);
    return img;
}

static BOOL is_black(int r, int g, int b) { return r < 40 && g < 40 && b < 40; }
static BOOL is_green(int r, int g, int b) { return g > 150 && r < 100 && b < 100; }

int main(int argc, const char **argv)
{
    @autoreleasepool {
        BOOL xproc = NO;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--publish") && i + 1 < argc)
                return publish_mode(atoi(argv[i + 1]));
            if (!strcmp(argv[i], "--xproc")) xproc = YES;
        }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        int WW = NARM * S + (NARM + 1) * GAP, WH = S + 2 * GAP;
        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(60, 60, WW, WH)
                      styleMask:NSWindowStyleMaskBorderless
                        backing:NSBackingStoreBuffered defer:NO];
        win.backgroundColor = [NSColor blackColor];
        win.opaque = YES;
        NSView *v = win.contentView;
        v.wantsLayer = YES;
        v.layer.backgroundColor = CGColorCreateGenericRGB(0.0, 1.0, 0.0, 1.0);   /* the backdrop */
        [win orderFrontRegardless];

        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        if (!dev) { fprintf(stderr, "no Metal device\n"); return 2; }

        NSMutableArray *pubs = [NSMutableArray array];
        NSMutableArray *ctxs = [NSMutableArray array];
        for (int arm = 0; arm < NARM; arm++) {
            uint32_t cid = 0;
            if (xproc) {
                NSTask *pub = [[NSTask alloc] init];
                pub.launchPath = [[NSBundle mainBundle] executablePath];
                pub.arguments = @[@"--publish", [NSString stringWithFormat:@"%d", arm]];
                NSPipe *pipe = [NSPipe pipe];
                pub.standardOutput = pipe;
                [pub launch];
                NSData *d = [pipe.fileHandleForReading availableData];
                cid = (uint32_t)[[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] intValue];
                [pubs addObject:pub];
            } else {
                CAContext *c = [CAContext contextWithCGSConnection:CGSMainConnectionID() options:@{}];
                c.layer = arm_layer(dev, arm);
                [ctxs addObject:c];
                cid = c.contextId;
            }
            if (!cid) { fprintf(stderr, "arm %d got no context id\n", arm); return 2; }
            CALayerHost *host = [CALayerHost layer];
            host.contextId = cid;
            host.anchorPoint = CGPointZero;
            host.bounds = CGRectMake(0, 0, S, S);
            host.position = CGPointMake(GAP + arm * (S + GAP), GAP);
            [v.layer addSublayer:host];
        }

        printf("\n  topology: %s\n", xproc ? "CROSS-PROCESS (separate publishers; this process hosts)"
                                           : "same-process (publishes and hosts here)");

        /* Retry the WHOLE capture until the control is black. All three arms are in every frame,
         * so a valid frame is one where the control has committed -- and the other two are then
         * read from that same frame, with the same amount of time behind them. */
        int rgb[NARM][3] = {{0}};
        BOOL valid = NO;
        int attempt = 0;
        for (; attempt < 25 && !valid; attempt++) {
            [CATransaction flush];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
            CGImageRef img = capture_window((int)win.windowNumber, @"/tmp/s0-arms.png");
            if (!img) continue;
            BOOL ok = YES;
            for (int a = 0; a < NARM; a++)
                if (!arm_rgb(img, a, &rgb[a][0], &rgb[a][1], &rgb[a][2])) ok = NO;
            CGImageRelease(img);
            if (ok && is_black(rgb[0][0], rgb[0][1], rgb[0][2])) valid = YES;
        }

        if (!valid) {
            printf("  VERDICT: VOID -- the CONTROL arm never read black in %d captures, so this\n"
                   "           probe cannot see the difference it exists to measure. Nothing about\n"
                   "           the other arms may be read from this run.\n", attempt);
            /* Say WHY where it is knowable. A publisher that died takes its context with it, and
             * a missing context reads exactly like a transparent one -- which is the whole failure
             * this probe is built to refuse. Naming it turns a mystery into a fact. */
            int dead = 0;
            for (NSTask *p in pubs) if (!p.isRunning) dead++;
            if (dead)
                printf("           CAUSE: %d of %lu publisher process(es) are no longer running --\n"
                       "           a dead publisher's context is gone, and gone reads as green.\n",
                       dead, (unsigned long)pubs.count);
            else if (pubs.count)
                printf("           All %lu publishers are still alive, so this is not a dead\n"
                       "           publisher -- suspect the window server not compositing the host.\n",
                       (unsigned long)pubs.count);
            printf("           Last capture RGB: control %d,%d,%d · drop %d,%d,%d · nonopq %d,%d,%d\n",
                   rgb[0][0], rgb[0][1], rgb[0][2], rgb[1][0], rgb[1][1], rgb[1][2],
                   rgb[2][0], rgb[2][1], rgb[2][2]);
            for (NSTask *p in pubs) { if (p.isRunning) [p terminate]; }
            return 1;
        }

        printf("  valid capture after %d attempt(s) -- control is black, so this frame can be read\n",
               attempt);
        printf("  arm      backgroundColor      opaque   centre RGB      reading\n");
        printf("  ---------------------------------------------------------------------------\n");
        for (int a = 0; a < NARM; a++) {
            const char *reading = is_green(rgb[a][0], rgb[a][1], rgb[a][2])
                                      ? "GREEN through -> contributed NOTHING"
                                  : is_black(rgb[a][0], rgb[a][1], rgb[a][2])
                                      ? "BLACK -> the layer filled the area"
                                      : "neither -- re-read before believing it";
            printf("  %s   %-18s   %-6s   %3d,%3d,%3d     %s\n", NAMES[a],
                   a == 0 ? "black (as today)" : "none", (a != 2) ? "YES" : "NO",
                   rgb[a][0], rgb[a][1], rgb[a][2], reading);
        }

        printf("\n  VERDICT: ");
        if (is_green(rgb[1][0], rgb[1][1], rgb[1][2]))
            printf("A --drop is SOUND. With no background, an opaque CAMetalLayer that has never\n"
                   "           presented composites as NOTHING -- measured in the same frame in which\n"
                   "           the control filled black. Build A/D on it.\n");
        else if (is_black(rgb[1][0], rgb[1][1], rgb[1][2]))
            printf("A --drop is INERT: the layer fills opaque black even with no background set.\n"
                   "           A must become the deferred `opaque = NO` form -- see the nonopq arm.\n");
        else
            printf("NEITHER -- re-read the probe before believing it (the C56 rule).\n");

        for (NSTask *p in pubs) { [p terminate]; [p waitUntilExit]; }
        return 0;
    }
}
