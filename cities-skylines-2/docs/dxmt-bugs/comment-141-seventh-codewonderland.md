# dxmt#141 — seventh comment: reply to codeWonderland's implementation (2026-10-10)

**Status: ✅ POSTED 2026-10-10 19:52 UTC as `iosoceans` — [#6101545070](https://github.com/3Shain/dxmt/issues/141#issuecomment-6101545070).** Replies to
[#6099014253](https://github.com/3Shain/dxmt/issues/141#issuecomment-6099014253) (codeWonderland,
2026-10-10 15:19 UTC): an independent cross-process child-swapchain implementation in
`codeWonderland/neutron` (`tools/wine-dxmt/winemac-remote-metal.patch`, 412 lines;
`tools/dxmt-patch/cross-process-swapchain.patch`, 21 lines), tested on Gcenx 11.18.

Prior: 5400445243 · 5403561498 · 5458926046 · 5466938536 (`jvspearman`) · 5477055980 + 5477128209 ·
5481901941 (`iosoceans`).

## Before posting

- `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status` must say **`iosoceans`** (checked 2026-10-10).
- Every claim below about their patch was verified by reading it (ledger 2026-10-10 15:3x), and every
  number is one this project measured on Steam's own windows — nothing is argued from theory.
- No code in the body. Their work can become a PR once #152 (relicensing pause) settles; ours cannot
  at all (AI-assisted, which `CONTRIBUTING.md` rules out), so the useful thing to hand over is the
  test list, not a competing patch.

---

Nice — that is the same route I ended up on (foreign hwnd → offscreen `CAContext` swapchain handed
to DXMT as the view, owner hosts it over the child's client rect in the root's content view,
pending queue until the owner has a Cocoa window), in a far smaller form, and the capability
symbol plus the `drawableSize`-following layer subclass are both better than what I did. Since
yours can become a PR once #152 settles and mine cannot (it is AI-assisted, which CONTRIBUTING
rules out), here is the list of things Steam's client did to my version
of exactly this design, each one measured rather than guessed, so you can test for them before
offering it:

1. **Re-placing on `WindowPosChanged` removes and re-adds the host.** Stock
   `addCALayerHostViewWithContextId:` calls `removeCALayerHostView:` first, so every child move or
   resize is a short un-hosted gap. On a Steam window resize that showed as a shimmer in **5.0 %**
   of 520 sampled frames; retiring the old host only when the *new* layer's first frame is in, and
   deferring the release per child, took it to **0.0 %**. Updating the existing host's frame in
   place instead of re-adding avoids it entirely.
2. **`addSublayer` stacks hosts in insertion order, and that is not Win32 paint order.** Steam's
   client is two *sibling* `CefBrowserWindow` trees on one root, and CEF recreates its swapchain on
   resize, so a resize that recreated the lower browser put its full-window host over the content:
   black, and it stayed black. Repro: resize the Library page 2400×1500 → 2399×1499 → 2400×1500.
   Fix was giving each host a `zPosition` from the Win32 z-order.
3. **Retina half-points.** Win32 speaks raw pixels and Cocoa points, so an odd pixel dimension is a
   half point and a host that Win32 says reaches the window edge stops one device pixel short: a
   white hairline on the odd axis only (2401×1500 right edge, 2400×1501 bottom edge, 2400×1500
   neither). Snapping the host frame to the view edge fixes it.
4. **Fixed 32-slot tables drop silently when full**, and the pending table only shrinks on a
   RELEASE message, so a child that dies before its owner shows a window stays queued forever. Steam
   churns many short-lived popups; worth a sweep or a growable container.
5. The DXMT side: agreed on the export check. In my build the refusal was left in place and only
   gated by an environment variable precisely because, without the wine half, it crashes rather
   than failing.

The full write-ups, with the probes used to measure each, are in the repo linked earlier
(`GOTCHAS.md`: "CALayerHost z-order is INSERTION order", "Retina turns an ODD Win32 pixel size into
a HALF POINT", "A 'hold until the next event for the same key' cache leaks"), and the stock-wine
form of the winemac half is attachment 82030 on
[wine bug 60263](https://bugs.winehq.org/show_bug.cgi?id=60263) if a maintainer there wants a
second implementation to compare against. Happy to run your patch through the same probes if useful.

(Same disclosure as my earlier comments here: this analysis was AI-assisted; the measurements
are from my own machine. Not asking for anything to be merged.)
