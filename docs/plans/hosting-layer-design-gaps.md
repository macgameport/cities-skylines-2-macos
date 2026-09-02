# Cross-process hosting layer — the two design gaps and the three heuristics

**Status: Not yet triple-checked — run `check it` before build.** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`, installed module `310f13d03e27732d`, source tree
`~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/` (line numbers below are against it).

**Scope:** the three things the 2026-09-02 review left open *in the mechanism itself*: (D1) a
child that moves or re-orders without a swapchain re-create is never re-placed; (D2) the paint-order
walk has a fixed capacity and a layer created while it is truncated gets no z; (D3) three
heuristics that a maintainer would question. Not in scope: upstream form (separate plan), the
DXMT side (separate plan).

---

## D1 — child-only moves never reach the host

**Current.** Hosted frames and z are refreshed from exactly two places: the root's own
`macdrv_WindowPosChanged` (`window.c:1983`, via `update_remote_layer_frames`) and a swapchain
re-create (`WM_MACDRV_CREATE_REMOTE_LAYER`, `window.c:1764`). A child's own `WindowPosChanged`
returns at the first line — `if (!(data = get_win_data(hwnd))) return;` (`window.c:1992`) —
because children never get `win_data`. It works today only because CEF re-creates its swapchain on
every resize; a `SetWindowPos(child, HWND_TOP, …)` or a `SWP_NOSIZE` move with the root stationary
leaves the hosted layer at its old rect and z until the root next moves.

**Facts the design rests on (verified 2026-09-02).**
- win32u calls the driver hook for *every* window, children included, from `apply_window_pos`
  (`dlls/win32u/window.c:2470`), in the process that performed the `SetWindowPos`.
- For Steam, the children are created and moved by the **GPU process**; the root lives in the
  **browser process**. So the owner (browser) can never observe a child move through its own hook;
  the GPU process can, and it already knows which children it has hosted remotely: they are the
  `client->hwnd` values in `remote_layer_surfaces` (`macdrv_main.c`, view-keyed table).
- The driver already has a private message channel from the GPU process to the root:
  `WM_MACDRV_CREATE_REMOTE_LAYER` / `WM_MACDRV_RELEASE_REMOTE_LAYER` (`macdrv.h:97-100`), posted
  with `NtUserPostMessage`, handled under the root's `win_data`.

**Design.** A third message, same channel:
1. `macdrv.h`: append `WM_MACDRV_UPDATE_REMOTE_LAYER` to the enum after `RELEASE`.
2. `macdrv_main.c`: `BOOL dxmt_remote_child_live(HWND hwnd)` — under `remote_layer_mutex`, scan
   `remote_layer_surfaces` values for `client->hwnd == hwnd` (also `pending_by_child` keys, so a
   child whose surface is between release and re-create still reports). Declared in `macdrv.h`.
3. `window.c:1992`: before the early return —
   `if (!data) { if (dxmt_remote_child_live(hwnd)) post UPDATE to NtUserGetAncestor(hwnd, GA_ROOT) with wParam = hwnd; return; }`.
   Only when `swp_flags` changed position, size or z (`!(SWP_NOMOVE && SWP_NOSIZE && SWP_NOZORDER)`).
4. Owner handler, next to the CREATE/RELEASE cases: `get_win_data(hwnd)` → if
   `remote_layer_children` has an entry whose value is the child → `update_remote_layer_frames(data)`
   (all layers; the cost is the same walk the root move already pays). A child that died in flight
   is pruned by the existing rect-failure path.

**Rate.** One posted message per child `SetWindowPos`. CEF's steady state produces none; a drag
produces root moves (already handled) plus whatever CEF does to children, which today is
re-creation. No per-frame work is added on the game path: the game's window has `win_data`, so the
new branch is never reached.

**Alternatives rejected.** (a) Polling child rects from the root on a timer — adds a timer to a
driver that has none, and still misses z. (b) Making the owner subscribe through wineserver
notifications — no such mechanism exists for foreign windows. (c) Doing nothing — correct for CEF
today, and the first question a maintainer asks.

## D2 — fixed-capacity paint order

**Current.** `PAINT_ORDER_MAX 64` / `PAINT_ORDER_DEPTH 8` (`window.c:86-87`), `HWND kids[64]` on
the stack per recursion level, a once-per-process `FIXME` when tripped (`paint_order_truncated`).
When truncated, a layer created for a child outside the recorded set gets `have_z == FALSE` and the
Cocoa side leaves `zPosition` at 0 — the layer sits under every sibling, which is the blackout class
the walk exists to prevent, inverted. Steam's root has ~10–20 descendants today (measured with
`win-resize-driver tree`), so the cap is not near, but it is a cap with a wrong failure mode.

**Design: count, then fill; no fixed capacity.** Two walks: the first counts descendants (depth
bound 32, logged once if hit), the second fills a heap array of exactly that size. Allocation is
already on this path (`update_remote_layer_frames` `calloc`s its key/value copies per call), so a
second `calloc` of N pointers is no new class of cost. `struct paint_order` becomes
`{ HWND *hwnds; int count; BOOL truncated; }` with `paint_order_free()`. The create path handles one
child and pays the same two walks; acceptable (it runs once per swapchain create, not per frame).

**Alternative considered.** Lazy z per child by walking the `GW_HWNDPREV` chain to the root — no
array at all, but O(depth × siblings) per child per update, and it re-walks the same siblings for
every hosted layer; worse than one counted walk once there are three or more layers.

## D3 — the three heuristics

| heuristic | measured status | decision proposed |
|---|---|---|
| 120 ms deferred black `backgroundColor` (`cocoa_window.m` ≈ 800–825) | load-bearing for the odd-axis seam, and the *deferral* is what stops the menu black-box flash (C18) | **keep locally**; replace the wall-clock with a content signal only if one exists — a check lens should look for a CALayerHost "first frame" callback; if none, the 120 ms stays with the measurement beside it |
| half-device-pixel edge snap (`dxmt_fill_view_edges`, ≈ 71–113) | load-bearing (C12): removing it brings the seam back on the odd axis | **keep locally**; rename for upstream form (other plan) |
| `macdrv_swapchain_set_bounds` + its caller in `macdrv_client_surface_update` + prototype | **dead** across every instrumented session (C16); now class-guarded and `#ifdef`'d | **delete** all three pieces. The 08-31 decision to keep it ("correct in principle") is reversed on the grounds that a cross-process client resizing a swapchain *in place* has never been observed, the code path carries a warning and an upstream objection, and the history doc records the function verbatim |

---

## Test plan

Instruments: `scripts/win-resize-driver.c` (needs a new verb `move <hwnd> <x,y>` → `SetWindowPos`
with `SWP_NOSIZE|SWP_NOZORDER`, and `top <hwnd>` → `HWND_TOP` with `SWP_NOMOVE|SWP_NOSIZE`; both
cross-process, which Win32 permits), `scripts/pixel-probe.swift`, `scripts/steam-render-cell.sh`,
`scripts/shimmer-probe.sh`, the boot-verify script from the instruments plan.

| # | test | method | pass | mutant (apply to real source, observe red, restore green) |
|---|---|---|---|---|
| T1 | child-only move re-places the layer | Steam up; `tree` to find the top browser child; capture; `move <child> +120,+0`; wait 500 ms; capture | the content column that was at x is now at x+120 (pixel-probe on a 20-px strip: mean RGB of the strip matches the pre-move strip 120 px to the left, within 8/channel) | comment out the `NtUserPostMessage` in step 3 → capture unchanged (layer stays) |
| T2 | child-only z change re-stacks | two overlapping children (Steam's store + the Friends List docked? if none overlap, use the D2 mutant harness) ; `top <lower child>` | the raised child's content is visible in the overlap region | as T1 |
| T3 | no regression: blackout sequence | `2400x1500 → 2399x1499 → 2400x1500` | interior luminance > 40 at every step, 0 bright edges | n/a (regression) |
| T4 | no regression: churn ×2 + static control | `shimmer-probe.sh churn` twice, `static` once, 40 samples each | 0 gap frames | n/a |
| T5 | D2: no capacity | build with `PAINT_ORDER_DEPTH` forced to 2 as the mutant for the *depth* bound; the count/fill has no breadth cap to mutate | with the real code: `paint order incomplete` FIXME never logged under Steam; with the depth mutant: FIXME logged once, and every hosted layer still gets a z (the fill records what it reached) | the old fixed array restored with MAX=4 → layers beyond get no z → a blackout on churn (the C13 signature) |
| T6 | D3: `set_bounds` deletion is behaviour-neutral | Steam battery (T3, T4, navigation ×6, popup open/close) | identical results to C29 | n/a — the function had 0 firings; the test is that nothing depended on it |
| T7 | game boots | boot-verify script | `MainMenu reached`, graceful exit, 0 `InvalidProgramException` | n/a |
| T8 | lifetime traces still clean | `WINEDEBUG=+err,+macdrv` on one cell | 0 `acquire_metal_swapchain FAILED`, drains and prunes still fire on popup close | n/a |

## Exit criteria
1. T1 and T2 green with their mutants observed red and restored.
2. T3–T8 match or beat C29.
3. `struct paint_order` has no compile-time capacity; only the depth bound remains and it logs.
4. `macdrv_swapchain_set_bounds` is gone from the tree, the prototype and the patch; C16 updated to
   say it was removed.
5. Patches regenerated from the tree, dry-run applied to a fresh base, byte-compared; C30 in the
   ledger with the cells named.

## Rollback
One file swap: the installed module's previous build sits beside it as
`winemac.so.bak-preaudit-20260902-155549` (the C29 build is `310f13d0…`; back it up the same way
before installing). Source: the tree will be git-tracked by the upstream-form plan; until then,
`*.pre-<step>` copies beside each file.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | not yet checked | — | — | — | — | — |

**Key paths:** `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/{window.c,cocoa_window.m,macdrv_main.c,macdrv.h}` ·
`~/cs2-patch/build-1116/wine-11.16/dlls/win32u/window.c` (hook call site) · `scripts/win-resize-driver.c` ·
`scripts/winemac-crossprocess-remote-layer.patch`
