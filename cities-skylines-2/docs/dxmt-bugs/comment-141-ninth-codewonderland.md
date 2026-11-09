# dxmt#141 — ninth comment: re-run of codeWonderland's 89084b1 on the 5K display (2026-10-13)

**Status: ✅ POSTED 2026-10-13 17:28 UTC as `iosoceans` — [#6151319832](https://github.com/3Shain/dxmt/issues/141#issuecomment-6151319832).** James said "post it". Replies to
[#6131867235](https://github.com/3Shain/dxmt/issues/141#issuecomment-6131867235) (codeWonderland,
2026-10-12 20:15 UTC): `winemac-remote-metal.patch` at neutron `89084b1` (released swapchains parked
250 ms, owner removes the old host 250 ms late, host and swapchain frames through
`cgrect_mac_from_win()`), with a request to re-run `hosting-layer-tests.sh` and `shimmer-probe.sh` on
a real 2x display. Prior: [#6130776980](https://github.com/3Shain/dxmt/issues/141#issuecomment-6130776980)
(eighth, `iosoceans`).

## How the measurements were taken

- Patch downloaded with James's OK (`~/cs2-patch/third-party/neutron-89084b1/`, sha256 `af843ff1fbce8212`).
  Only the delta from `6dea13a` was ported, as branch `cw-89084b1` (`c911de5`, TEST ONLY) on top of
  `cw-6dea13a` in the nested winemac repo: the deferred host removal (`cocoa_window.m`), the host
  frame through `cgrect_mac_from_win` (`window.c`), and the parking plus the swapchain-size conversion
  in `macdrv_main.c`, where the port's remote-swapchain code lives. Module `winemac-cw-89084b1.so`,
  500064 B, built clean.
- `~/cs2-patch/cw-test/run-cw-battery.sh` with `CAND=` the new module, Retina off then on, our daily
  module first and theirs second in each session; daily module restored and checked by sha256 each
  phase, RetinaMode removed after. Runs `~/cs2-patch/cw-test/20261013-091514-retina-off` and
  `20261013-092231-retina-on`.
- By eye: static frames side by side (ours, theirs today, theirs `6dea13a` yesterday); contact sheets
  of all 40 churn frames per module; the T2 frames; the 2399x1499 right and bottom edges at 4x, with
  per-column and per-row maximum luminance. The T2 "restored" delta of 11 on theirs with Retina on is
  the store carousel having changed slides, not a placement miss.
- Code read while the battery ran: stock `CAContextSwapChain initWithHwnd` already calls
  `setBounds:cgrect_mac_from_win(bounds)` in 11.16 (pristine `2ef2d1a`) and in wine-11.18
  (`cocoa_window.m:3780`), so the new conversion in `create_remote_swapchain` applies it twice under
  RetinaMode. Change ledger 2026-10-13 01:43–09:40.

## Body (as posted)

Thanks for the fix and the write-up. I re-ran the battery on the 5K Studio Display (2x backing) against 89084b1. Short version: **the resize gaps are gone in both modes, the Retina placement now matches ours, and I see no hairline at the odd size.**

**Port.** Only the delta from 6dea13a went on top of the earlier 11.16 port. As you predicted, the parking landed in the `my_macdrv_view_release_metal_view` wrapper (plus `create_remote_swapchain`, which in the port lives next to it). `cgrect_mac_from_win()` and `clock_gettime()` were available as-is.

| | ours | yours, 89084b1 | yours, 6dea13a (last run) |
|---|---|---|---|
| churn, near-black interior, Retina off | 0/40 | **0/40** | 7/40, 8/40 |
| churn, near-black interior, Retina on | 0/40 | **0/40** | 8/40 |
| churn, black band ≥20 % along an edge, Retina off | 6/40 | 21/40 | 23/40, 25/40 |
| churn, black band ≥20 % along an edge, Retina on | 8/40 | 14/40 | 40/40 |
| static, Retina on | clean | **clean** | content ~45 pt low |
| z-order restack, both modes | restacks, returns | restacks, returns | restacks, returns |

**Retina.** In static frames your content now lands exactly where ours does, with no band under the URL bar.

**Half points.** With RetinaMode on, at 2399x1499 Win32 pixels (1199.5 pt), there's no light hairline on the right or bottom edge with your module. At the right edge your content reaches one device pixel further than ours does. So item 3 looks fine to me.

**Edge bands.** These are churn frames where the window has grown before the child's next frame arrives, so the background shows along the growing edge. Ours has them too, at a lower rate, and run-to-run noise is a few frames (ours read 3–4 of 40 last time). I haven't looked into why the rates differ. In your table the two columns are identical in every row. On our probe the edge count has always run well above the interior count, so does your copy count the same thing for both?

**One small thing in the code.** `create_remote_swapchain` now passes `cgrect_mac_from_win(...)` to `macdrv_create_offscreen_swapchain`, but `CAContextSwapChain`'s `initWithHwnd:bounds:` already calls `setBounds:cgrect_mac_from_win(bounds)` (in stock 11.16 and in 11.18). So under Retina the initial layer bounds are halved twice. It's probably invisible, because `WineRemoteMetalLayer`'s `setDrawableSize:` resets the bounds as soon as the renderer sets a drawable size. That may be why it didn't show up in any capture.

(Analysis and testing done with AI assistance.)
