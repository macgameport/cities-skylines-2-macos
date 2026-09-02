# Cross-process hosting layer — the two design gaps and the three heuristics

**Status: check-it'd 2026-09-02 — needs-rework on D1 as first written; D1 rewritten below from a measurement, D2/D3 corrected; fitted re-check pending before build.** Umbrella:
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
re-create (`WM_MACDRV_CREATE_REMOTE_LAYER`, `window.c:1773`). A child's own `WindowPosChanged`
reaches the driver and is discarded at `if (!data->cocoa_window) goto done;` (`window.c:2002`).
It works today only because CEF re-creates its swapchain on every resize; a `SetWindowPos(child,
HWND_TOP, …)` or a `SWP_NOSIZE` move with the root stationary leaves the hosted layer at its old
rect and z until the root next moves.

**The premise, measured (2026-09-02, cell `exp_9b5030` with `WINEDEBUG=+macdrv`; ledger C30).**
The first draft of this plan said children never get `win_data` and are moved by the GPU process.
Both were wrong, and the check lens caught the first from source. The trace settles the second:

| window | created / hooked by | acquires the remote layer |
|---|---|---|
| root `0x40122` (Steam main) | tid `0130` | — |
| children `0x2011c`, `0x20138` (under the main root) | tid `0130` — `macdrv_create_win_data` runs for them, `win 0x…/0x0` (win_data, no cocoa_window), 25 × `WindowPosChanging`/`Changed` each | tid `01dc` (`my_get_win_data` → NULL → cross-process branch, 7 ×) |
| popup roots (`0x10194`, `0x3018c`, …) and their children | tid `0130`, same pattern | tid `01dc` |

So **every child is owned by the browser's UI thread, the same thread that owns its root and runs
the `WM_MACDRV_CREATE_REMOTE_LAYER` handler**; the GPU process is foreign to the whole tree and
holds no `win_data` for any of it, which is why its acquire takes the cross-process branch. The
owner therefore already observes every child move through its own driver hook — and discards it.
(The 2026-08-31 note in `docs/steam-ui-findings.md` § Diagnosed that "the child is owned by the
GPU process" described hwnd `0x10104` under the fork build; it does not hold for the current stack
and is corrected there.) Two facts the check lens verified in win32u: the hook runs in the window's
**owning thread** — a foreign caller's `SetWindowPos` is marshalled to the owner via
`WM_WINE_SETWINDOWPOS` (`win32u/window.c:4243-4250`) — and `swp_flags` at the hook are the
**effective** flags after `fixup_swp_flags` (`:3934-3956`), so a no-op call already carries
`SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER`.

**Design — one leg, owner-side, no new message.** At the `window.c:2002` exit:
```c
if (!data->cocoa_window)
{
    HWND root = NtUserGetAncestor(hwnd, GA_ROOT);
    BOOL moved = ~swp_flags & (SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER) ||
                 swp_flags & (SWP_SHOWWINDOW | SWP_HIDEWINDOW);
    release_win_data(data);                    /* one global win_data_mutex: never nest */
    if (moved && root && root != hwnd && (data = get_win_data(root)))
    {
        if (remote_layer_children_has(data, hwnd)) update_remote_layer_frames(data);
        release_win_data(data);
    }
    return;
}
```
`remote_layer_children_has` is a value scan of the root's tracking table (small; the same
`CFDictionaryGetKeysAndValues` copy `update_remote_layer_frames` already makes). Cost: one extra
`get_win_data` per child `SetWindowPos` in the owner, nothing on the game path (the game's window
has a `cocoa_window`, so this branch is never entered). The previously planned
`WM_MACDRV_UPDATE_REMOTE_LAYER`, `dxmt_remote_child_live()` scan and GPU-process posting are
**dropped**: the process that would have posted never sees the move, and the process that sees it
already owns the table.

**Not built, recorded as a non-case:** a child owned by a process other than its root's. The trace
shows none in Steam's tree; if one ever appears, its own hook runs in *its* process, and a message
to the root would be needed — the `macdrv_client_surface_update` remote branch in that process is
the natural post point. Detect it with the T0 probe below before designing for it.

## D2 — fixed-capacity paint order

**Current.** `PAINT_ORDER_MAX 64` / `PAINT_ORDER_DEPTH 8` (`window.c:86-87`), `HWND kids[64]` on
the stack per recursion level, a once-per-process `FIXME` when tripped (`paint_order_truncated`).
When truncated, a layer created for a child outside the recorded set gets `have_z == FALSE` and the
Cocoa side leaves `zPosition` at 0 — the layer sits under every sibling, which is the blackout class
the walk exists to prevent, inverted. Steam's root has ~10–20 descendants today (measured with
`win-resize-driver tree`), so the cap is not near, but it is a cap with a wrong failure mode.

**Design: one walk into a growable array; no fixed capacity.** Iterate siblings bottom-up with
`GW_HWNDLAST` then `GW_HWNDPREV` (both supported by `NtUserGetWindowRelative`,
`win32u/window.c:849-856`), recording each window before descending into it — that is Win32 paint
order directly, and it removes the per-level `HWND kids[64]` array (`window.c:112`) and the
"too many siblings" cap without a second walk. The array grows by doubling (`realloc`); allocation
is already on this path (`update_remote_layer_frames` `calloc`s its key/value copies per call,
`window.c:1941-1942`), so this is no new class of cost. Only the depth bound (32) remains, logged
once. `struct paint_order` becomes `{ HWND *hwnds; int count, capacity; BOOL truncated; }` with
`paint_order_free()`. A window appearing mid-walk is missed until the next update; with a single
walk there is no count/fill race to reconcile.

**Alternatives rejected.** Count-then-fill (the first draft): the tree can change between the two
walks, and the overcount case needs its own bound and `truncated` marking. Lazy z per child via the
`GW_HWNDPREV` chain: O(depth × siblings) per child per update, re-walking the same siblings for
every hosted layer — worse than one walk once there are three or more layers.

## D3 — the three heuristics

| heuristic | measured status | decision proposed |
|---|---|---|
| 120 ms deferred black `backgroundColor` (`cocoa_window.m` ≈ 800–825) | load-bearing for the odd-axis seam, and the *deferral* is what stops the menu black-box flash (C18) | **keep locally**; replace the wall-clock with a content signal only if one exists — a check lens should look for a CALayerHost "first frame" callback; if none, the 120 ms stays with the measurement beside it |
| half-device-pixel edge snap (`dxmt_fill_view_edges`, ≈ 71–113) | load-bearing (C12): removing it brings the seam back on the odd axis | **keep locally**; rename for upstream form (other plan) |
| `macdrv_swapchain_set_bounds` + its caller branch in `macdrv_client_surface_update` + prototype | **dead** across every instrumented session (C16); the call is live, only its diagnostic is `#ifdef`'d; class-guarded since 09-02 | **delete** all three pieces — done in the upstream-form plan's cleanup step, which precedes this plan. The 08-31 decision to keep it ("correct in principle") is reversed: a cross-process client resizing a swapchain *in place* has never been observed, and the check lens showed that if the branch ever *did* fire it would change the layer's bounds without the drawable — which the code's own diagnostic defines as stretching. The history doc records the function verbatim |

---

## The C29 battery, defined once (every plan's "matches C29" means exactly this)

| measurement | instrument | pass |
|---|---|---|
| GPU-process crashes, scoped to the launch | `steam-render-cell.sh` (`cef_log` marker) | 0 per cell, 3 cells |
| navigation ×6 (library, friends, settings, store, downloads, library) | `steam://` + winlist capture + `pixel-probe` | each `RENDERED` (capture ≥ 120,000 B) with interior luminance ≥ 20 |
| blackout sequence 2400×1500 → 2399×1499 → 2400×1500 | driver `drive` + `pixel-probe` | interior luminance ≥ 40 at all three steps; 0 bright edges on the odd size |
| churn ×2 + static control, 40 samples each | `shimmer-probe.sh` | 0 gap frames in each |
| popup open, capture, close (WM_CLOSE), main window after | driver `close` + capture + `+macdrv` trace | popup `RENDERED`; ≥ 1 `dxmt-life … draining` line with ≥ 1 dead-child slot; ≥ 1 `gone -- releasing hosted layer` prune; main window `RENDERED` after |
| game boot | `scripts/boot-verify.sh` | `VERDICT: PASS`, `GRACEFUL: yes`, 0 `InvalidProgramException` |

Measured 2026-09-02 on `310f13d03e27732d`: 0/0/0 crashes; six navigations 1.2 MB / 147 KB / 851 KB-class / 1.58 MB / 515 KB / 1.2 MB; 83 / 84 / 112 with 0 edges; 0 / 0 / 0 gaps; 5 drains, 5 prunes; boot 16:25:25. A rerun is not "identical"; it is inside these bounds.

## Test plan

Instruments: `scripts/win-resize-driver.c` (needs one new verb, `move <hwnd> <x,y>` →
`SetWindowPos` with `SWP_NOSIZE|SWP_NOZORDER`; the existing `front` already does `HWND_TOP` with
`SWP_NOMOVE|SWP_NOSIZE`, and its `SWP_SHOWWINDOW` is stripped for a visible window. Cross-process
`SetWindowPos` is permitted — win32u has no ownership check — and is marshalled to the owner
thread; it blocks until the owner pumps, `SWP_ASYNCWINDOWPOS` if a cell ever hangs),
`scripts/pixel-probe.swift` (needs a `strip <x> <w>` mode: mean RGB of an arbitrary column strip —
today it only probes the outermost edges and one interior reference), `scripts/steam-render-cell.sh`,
`scripts/shimmer-probe.sh`, the boot-verify script from the instruments plan. Targets come from the
`WM_MACDRV_CREATE_REMOTE_LAYER child %p` TRACE and `tree`'s `pid=` column.

| # | test | method | pass | mutant (apply to real source, observe red, restore green) |
|---|---|---|---|---|
| T0 | the ownership premise still holds on the build under test | one `+macdrv` cell; bucket `WindowPosChanging`/`Changed` tids per hosted child against the tid emitting `cross-process child … -> root` and the tid running the CREATE handler | every hosted child's hook tid == the CREATE-handler tid (owner); the acquiring tid never emits a hook for any of them | n/a — a premise probe; if it fails, D1 needs the message leg |
| T1 | child-only move re-places the layer | Steam on the **Library** page (the Store's autoplaying video would give false reds); take a hosted child from the CREATE trace (browser-owned, e.g. the `0x2011c` kind); **negative control first**: the strip at x+120 must differ from the strip at x by > 8/channel before the move, else the content is uniform and the test is void; capture; `move <child> +120,+0`; `rects <child>` readback proves the Win32 rect moved (instrument validation — a broken `move` must not read as a red mutant); wait 500 ms; capture; then **one resize** and a third capture; `move` it back | two-sided: the strip at the child's left edge (`strip` mode) now reads the child's content at x+120 **and** the old location no longer does (within 8/channel); the post-resize capture still renders | comment out the `update_remote_layer_frames` call in the new branch → both captures identical; restore. **Pre-registered:** if the mutant is *silent* while `rects` confirms the move, CEF re-created its swapchain on the move — that is a finding about D1 (the move path is unnecessary for CEF), not a harness failure; record it as such |
| T2 | child-only z change re-stacks | Steam's two `CefBrowserWindow` siblings overlap by construction (2398×1215 @1,250 inside 2400×1500 @0,66); measure the overlap region's mean RGB with the top sibling on top, `front <lower sibling>`, measure again, `front <upper sibling>`, measure a third time | the region changes to the lower sibling's signature and back (> 8/channel each way) | its own mutant: comment out the root lookup in the new branch (leave the move path) → the region does not change; restore |
| T3 | no regression: blackout sequence | `2400x1500 → 2399x1499 → 2400x1500` | interior luminance > 40 at every step, 0 bright edges | n/a (regression) |
| T4 | no regression: churn ×2 + static control | `shimmer-probe.sh churn` twice, `static` once, 40 samples each | 0 gap frames | n/a |
| T5 | D2: no capacity | build with `PAINT_ORDER_DEPTH` forced to 2 as the mutant for the *depth* bound; the growable walk has no breadth cap to mutate. **Observation channel:** the z assignment is a `TRACE` in core (the upstream-form plan converts the former `HOST zpos` instrument line to one `TRACE`), read with `+macdrv` | with the real code: `paint order incomplete` FIXME never logged under Steam; with the depth mutant: FIXME logged once, and every hosted layer above the cut still gets a z in the trace | the old fixed array restored with MAX=4, **with the cap placement pre-registered from a `tree` dump so a hosted child is provably past index 4**; the mutant run must show the `too many windows in the tree` FIXME or it proved nothing → a blackout on churn (the C13 signature) |
| T6 | D3: `set_bounds` deletion is behaviour-neutral (executed in the upstream-form plan; re-verified here) | the C29 battery above | inside the battery's bounds | n/a — the function had 0 firings; the test is that nothing depended on it |
| T7 | game boots | boot-verify script | `MainMenu reached`, graceful exit, 0 `InvalidProgramException` | n/a |
| T8 | lifetime traces still clean | `WINEDEBUG=+err,+macdrv` on one cell | 0 `acquire_metal_swapchain FAILED`; ≥ 1 drain with ≥ 1 dead-child slot and ≥ 1 prune on popup close; 0 `ERR` lines from our code | n/a |
| T9 | edge: show/hide of a child | `SetWindowPos(child, SWP_HIDEWINDOW)` then `SWP_SHOWWINDOW` via a driver verb (or a popup that hides itself) | recorded as a **known pre-existing gap**: the gate refreshes geometry, but `update_remote_layer_frames` does not consult `WS_VISIBLE`, so a hidden child's layer stays visible. Out of scope here; the test documents the behaviour, pass = no crash, no `ERR`, and the note in the plan | n/a |

## Exit criteria
1. T0 confirms the ownership premise on the build under test; T1 and T2 green with their mutants observed red and restored.
2. T3–T8 inside the C29 battery bounds defined above (one set of numbers, not two).
3. `struct paint_order` has no compile-time capacity; the walk is `GW_HWNDLAST`/`GW_HWNDPREV`; only the depth bound remains and it logs.
4. `macdrv_swapchain_set_bounds` is gone from the tree, the prototype and the patch; C16 updated to
   say it was removed.
5. Patches regenerated from the tree, dry-run applied to a fresh base, byte-compared; C30 in the
   ledger with the cells named.

## Sequencing
**Order across the umbrella: instruments (plan 5) → upstream form (plan 2) → this plan → DXMT
side (plan 3); repo hygiene (plan 4) is independent.** This plan needs the `move` verb, the
`strip` mode and `boot-verify.sh` from plan 5, and the git history (with `set_bounds` already
deleted and the z `TRACE` in place) from plan 2.

## Rollback
One file swap: the installed module's previous build sits beside it as
`winemac.so.bak-preaudit-20260902-155549` (the C29 build is `310f13d0…`; back it up the same way
before installing). Source: the git history from the upstream-form plan.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | architecture + correctness (win32u hook path, lock order, enum range, D2/D3 facts, driver verbs) | 1 agent, 16 tool calls | claude-fable-5-1 | `c94d9e9` | needs-rework — D1's hook point was dead code (children *do* get `win_data`) and its process premise was wrong; D2's two-walk race; D3 sound. Then an inline measurement on the existing `+macdrv` trace (cell `exp_9b5030`) showed every child is owner-created (tid `0130`), which reduced D1 to the one-leg owner-side design above. D1/D2/tests rewritten; **fitted re-check required before build.** |

**Key paths:** `~/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv/{window.c,cocoa_window.m,macdrv_main.c,macdrv.h}` ·
`~/cs2-patch/build-1116/wine-11.16/dlls/win32u/window.c` (hook call site) · `scripts/win-resize-driver.c` ·
`scripts/winemac-crossprocess-remote-layer.patch`
