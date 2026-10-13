# dxmt#141 — eighth comment: test results for codeWonderland's revision (2026-10-12)

**Status: ✅ POSTED 2026-10-12 19:05 UTC as `iosoceans` — [#6130776980](https://github.com/3Shain/dxmt/issues/141#issuecomment-6130776980).** Replies to
[#6116130711](https://github.com/3Shain/dxmt/issues/141#issuecomment-6116130711) (codeWonderland,
2026-10-11): their `winemac-remote-metal.patch` revised at neutron `6dea13a` against our four items,
with a request to check half-point snapping on Retina and to run the 520-frame resize probe.
Prior: 6101545070 (seventh, `iosoceans`).

**Reply received 2026-10-12 20:15 UTC:** codeWonderland [#6131867235](https://github.com/3Shain/dxmt/issues/141#issuecomment-6131867235) reports both findings reproduced and fixed in `winemac-remote-metal.patch` at neutron `89084b1` (released swapchains parked 250 ms in the sending process; host and swapchain frames through `cgrect_mac_from_win()`), and asks for a re-run of `hosting-layer-tests.sh` and `shimmer-probe.sh` on the 5K display. Re-run 2026-10-13: draft reply in `comment-141-ninth-codewonderland.md`.

## How the measurements were taken

- Their patch was ported to 11.16 on a test branch of the nested winemac repo (`cw-6dea13a`, never on
  `main`); the module was swapped in by `~/cs2-patch/cw-test/run-cw-battery.sh`, which ran
  `scripts/hosting-layer-tests.sh` on the daily module and then the candidate in one session and
  always restored the daily module (verified by full sha256 each phase) and the RetinaMode setting.
- Runs: `~/cs2-patch/cw-test/20261012-{140221,141055}-retina-off`, `20261012-141844-retina-on`.
  The first retina-off run's daily battery was void for T1–T4 (pixel-probe not yet built — fixed in
  `2c00a11`), so the daily-module numbers come from the second run; the candidate's from all three.
- Flagged churn frames were opened by eye (chrome lit / content black, and fully black frames); the
  Retina offset was seen in static frames side by side with the daily module's.
- James read the draft and said to post it. Change ledger 2026-10-12 14:0x–14:30.

## Body (as posted)

Thanks for the revision, and for the clear write-up. I ran it through the probes. Short version: **z-order works, but the resize gaps are still there on our stack, and with Retina on the child layer lands about 45 pt too low.** Details below, so you can judge how much of that is our port.

**What I ran.** Our stack is Wine **11.16** (plus aquadran's DXMT winemac support) with DXMT v0.80. The Mac is an M5 Max running macOS 27.0.1, with a 5K Studio Display at 2560x1440 pt. Your `winemac-remote-metal.patch` at 6dea13a needed a port:
- 9 of its 15 hunks applied as-is, including all the hosting, placement, z-order, pending-queue and table code.
- The rest was two things. Type renames between 11.16 and 11.18 (`macdrv_metal_swapchain` vs `id_WineMetalSwapChain`, and `macdrv_window` vs `WineWindow *`). And your DXMT-facing remote-swapchain path: 11.16 has no `external_*` API, so it went into aquadran's `my_get_win_data` and `my_macdrv_view_*` wrappers, with the same logic.
- Your DXMT patch wasn't needed. The Porting Kit d3d11 build here (v0.80-17-g79f6279) has no cross-process refusal, and our installed winemetal takes DXMT's ordinary path once `get_win_data` returns your swapchain.

Steam's client rendered with text through your path, with no GPU-process crashes. Each battery ran with our module and yours back to back, in one session, on the same Steam store page.

| | ours | yours (ported) |
|---|---|---|
| resize churn, frames with a near-black interior (240 `SetWindowPos` alternations 2400x1500 ↔ 2200x1360 at 60 ms, 40 frames sampled per run) | **0/40, 0/40, 0/40** | **7/40, 8/40, 8/40** |
| churn, frames with a black band ≥20 % along an edge | 4, 3, 4 of 40 | 23, 25, 40 of 40 |
| static control (no churn) | clean | clean with Retina off; see Retina below |
| z-order restack (front the lower `CefBrowserWindow` sibling, then restore) | restacks, returns | **restacks, returns** (delta 46/36/50, back to 5/10/7) |

**1. Moving in place.** Your placement does update an existing host in place, inside a CATransaction with actions disabled. The gaps that remain have the classic signature: Steam's chrome renders and the content area is black, and a few frames are black throughout. In our measurements (C26), resize churn also **creates new child layers**, so each one arrives under a **new context ID**. In your code that's a new host, and the old one is removed when its swapchain is released, which can be before the new layer has drawn. Our fix was to retire the old host only once the new layer's first frame is in, with the release deferred per child. That's a hypothesis about your code, not something I traced in it.

**2. Z-order.** Works. Fronting the lower sibling restacks the content, and restoring brings it back.

**3. Half points.** I couldn't judge this one. With Wine's RetinaMode on, the store content sits about **45 pt low** in static frames too: there's a black band under the URL bar and the bottom bar is covered. Our module, in the same run, places it correctly. 45 pt is about where the child sits in the window in Win32 *pixels*, so I suspect pixel coordinates are reaching the host frame as points somewhere under Retina (`retina_on` halves Win32 → Cocoa). The odd-size rows (2400x1500 → 2399x1499 → 2400x1500) showed no white hairline with your module, but with the content offset that doesn't mean much.

**4.** I didn't see a corner square in any capture.

Caveats: this is your code on 11.16 rather than 11.18. The parts I ported were glue, not the hosting logic, but the Retina conversion helpers may differ between the two. Happy to share the ported diff, or re-run a new revision through the same battery. The probes are `scripts/hosting-layer-tests.sh` and `scripts/shimmer-probe.sh` in the repo linked earlier.

(Analysis and testing done with AI assistance.)
