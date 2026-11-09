# DXMT issue — FILED as [3Shain/dxmt#206](https://github.com/3Shain/dxmt/issues/206)

> **Status: FILED 2026-08-23** (authorship visible on the issue itself; the earlier "post as
> macgameport" premise was a misunderstanding — that is an *organization*, and GitHub issues are
> always authored by a user account; approved before filing). Everything below the rule is the
> issue body as filed (plus any local annotations added since). Follow-ups go in comments on #206.

> ### ⚖️ Upstream AI policy — checked 2026-08-22, and it governs what we may do here
>
> DXMT's `AGENTS.md`: *"AI must not be used to generate code for contributions to this project."*
> `CONTRIBUTING.md` § AI Policy: *"We cannot accept contributions made or co-authored by AI/LLM...
> **You are still free to use AI to do your own research and share your findings with others
> (including the developers, but please don't create a PR).**"*
>
> So: **no PR, no AI-written patch — ever, for this project.** A code fix would have to be written by
> a human, unaided. But filing *this* report is **explicitly the sanctioned channel** — it is research
> shared with the developers, which the policy names as permitted. Precedent:
> [#200](https://github.com/3Shain/dxmt/issues/200) is an AI-assisted report whose author disclosed
> the fact up front and got a maintainer reply. **Disclosing AI assistance in the issue is the
> honest move and matches that precedent.**

**Duplicate check (2026-08-22):** searched `repo:3Shain/dxmt` for swapchain / alt-tab / fullscreen /
focus / freeze. No open issue covers focus-loss freeze. [#48](https://github.com/3Shain/dxmt/issues/48)
is closed prior art; [#26](https://github.com/3Shain/dxmt/issues/26) is frame pacing, not this;
[#141](https://github.com/3Shain/dxmt/issues/141) is the ANGLE/CEF black window, unrelated.

**Title:** `Presents to an HWND's non-newest swapchain are silently never composited (freezes games that recreate swapchains on alt-tab)`

---

## Summary

In exclusive fullscreen, anything that takes focus away from the game — alt-tab, clicking another
window, or a global hotkey raising another app — permanently stops the swapchain's output reaching
the screen. The game keeps running at full speed: it accepts input, simulates, autosaves, renders,
and presents (~250% CPU sustained while "frozen"). The screen updates **exactly once per subsequent
minimize/restore cycle** and is otherwise stuck — so the session is playable blind, one frame per
alt-tab, but never live again. (I originally believed there was no recovery short of
`wineserver -k`; the one-refresh-per-cycle behavior is what actually lets a frozen session be saved
and quit.) The measured mechanism is in "Live-freeze measurements" below: a second swapchain is
created while the window is minimized with an empty client rect, and its layer never enters live
compositing.

It has cost me two play sessions today, the second triggered by accidentally hitting a hotkey that
raised another macOS app. This is the last blocking defect on an otherwise fully playable stack, so
I'm glad to run experiments or test a patch.

**Already tried, so nobody suggests it: `dxgi.handleAltTab = True` does not fix it** (details
below). **A standalone ~150-line reproducer now exists** — see "Minimal reproducer" below; it
needs no fullscreen, no minimize, and no focus change, just two swapchains on one HWND with
presents going to the older one.

## Environment

| | |
|---|---|
| DXMT | **v0.80** (build fingerprint `dxmt-f3e54a65`) |
| Wine | **wine-11.0**, Porting Kit engine `WS12Wine11.0_DXMT-v0.80` |
| macOS | **26.5.2** (25F84) |
| GPU | **Apple M3 Max** (correctly reported by DXMT) |
| Display | DELL U2424H, 1920×1080 **@ 120 Hz**, main; a second display @ 60 Hz is also connected |
| Game | Cities: Skylines II `1.6.0f1 (419.d6c6)` (Steam 949230), Unity, `Direct3D 11.0 [level 11.1]` |
| Translation | Rosetta 2 (x86-64 guest) |

## Steps to reproduce

1. Launch Cities: Skylines II and reach the main menu or an in-game view in **exclusive fullscreen**
   (the game's `displayMode: Fullscreen` — not windowed, not a Wine virtual desktop).
2. Take focus away: alt-tab, click another macOS window, or let any hotkey raise another app. The
   game window minimises.
3. Return to the game (Cmd-Tab or its Dock icon).

**Expected:** the game re-presents and play continues.
**Actual:** the window is composited but its contents never update again. Input is still received —
a click or keypress still registers in game state — but no frame ever reaches the screen. Closing it
took several alt-tab attempts; otherwise `wineserver -k`.

## Observations

Two DXMT lines stand out from the affected sessions. **I have not proven either causes the freeze** —
they are the most suspicious things present, in order.

**1. Both of the code paths that would react to focus loss appear to exclude this game.**

Reading `src/d3d11/d3d11_swapchain.cpp` (`Present1`), there are two reactions to a window going
away, and by my reading CS2 hits neither:

```cpp
bool window_minimized = wsi::isMinimized(hWnd);
if ((window_minimized || desc_.Width == 0 || desc_.Height == 0)
    // MSDN: You will not receive DXGI_STATUS_OCCLUDED if you're using a flip model swap chain.
    && desc_.SwapEffect <= DXGI_SWAP_EFFECT_SEQUENTIAL)
  hr = DXGI_STATUS_OCCLUDED;
bool should_exit_fs = handle_alt_tab_ // At the moment this is still broken for certain games
                      && !fullscreen_desc_.Windowed && !window_minimized && !wsi::isForeground(hWnd);
```

- The occlusion branch is gated on `SwapEffect <= DXGI_SWAP_EFFECT_SEQUENTIAL`. **CS2 requests
  `FLIP_SEQUENTIAL` (3)**, so it never receives `DXGI_STATUS_OCCLUDED`, even minimised. (Per the
  MSDN comment that is correct for flip model — I mention it only to establish that this branch
  cannot be what recovers the game.)
- The fullscreen-exit branch requires `!fullscreen_desc_.Windowed`. **I tried
  `dxgi.handleAltTab = True`** — confirmed loaded (`info: Found config env: dxgi.handleAltTab = True`,
  logged by both modules) — **and the freeze still occurred**, with the game needing a force-kill.
  DXMT logged no `SetFullscreenState` and no occlusion activity at any point in that session.

So on focus loss, `Present1` appears to take neither branch and simply presents into a surface that
is no longer visible; when the window comes back, presentation never resumes.

**Update — this question is now answered** (see "Source-level findings" below): the swapchain *is*
`Windowed == FALSE`. The boot log's `Setting display mode: 1920x1080@120` line is only reachable
through code paths that require exclusive-fullscreen state, and `SetFullscreenState` turns out to
log nothing on success, so the absence of log lines was never evidence either way.

**Three hypotheses tested and eliminated on this machine (2026-08-22).** Recording these so the
search space is smaller for whoever looks next:

| # | hypothesis | how it was tested | result |
|---|---|---|---|
| 1 | The `unsupported swap effect 3` warning means a degraded fallback swapchain | read `d3d11_swapchain.cpp:1114` | **Not a factor.** The warning is cosmetic — the same `MTLD3D11SwapChain` is constructed regardless of swap effect. |
| 2 | `dxgi.handleAltTab` simply needed enabling | set it via `DXMT_CONFIG`, confirmed loaded (`Found config env`, logged by both modules), played and alt-tabbed | **Freeze unchanged.** Matches the inline comment "still broken for certain games". |
| 3 | CS2 never gets `DXGI_STATUS_OCCLUDED` because the branch is gated `SwapEffect <= SEQUENTIAL`, and that missing signal is what strands it | binary-patched the shipped `d3d11.dll`, widening that compiled comparison (`cmp dword ptr [rdi+0x80], 2` + `setl`) so flip-model swapchains reach the same branch; verified in the disassembly; alt-tabbed | **Freeze unchanged.** The missing occlusion signal is not the cause. Patch reverted. |

Hypothesis 3 deliberately contradicted MSDN (flip-model swapchains are not supposed to receive
`OCCLUDED`) purely to see whether the absent signal mattered. It did not, so whatever strands the
game is further down — in how the Metal layer / presenter handles the window being minimised and
restored, rather than in the `Present1` status logic.

**2. The app asks DXGI not to manage window transitions, and the request is ignored:**

```
warn:  MakeWindowAssociation: Ignoring flags 3
```

Flags `3` = `DXGI_MWA_NO_WINDOW_CHANGES (0x1) | DXGI_MWA_NO_ALT_ENTER (0x2)` — the application saying
"I own these transitions." `dxgi_factory.cpp` stores the HWND and drops the flags. Probably harmless,
noted for completeness.

**Retracted from an earlier draft of this report:** I had blamed
`warn: CreateSwapChain: unsupported swap effect 3 with backbuffer size 2`, assuming a silent fallback
to a bitblt swapchain. Reading `d3d11_swapchain.cpp:1114` that warning is **cosmetic** — the same
`MTLD3D11SwapChain` is constructed regardless of swap effect. Not a factor.

**What is *not* in the logs:** no `SetFullscreenState: stub`, no `outstanding buffer hold`, no errors
of any kind at the moment of the freeze. DXMT simply goes quiet while the game's own log keeps
writing. Whatever happens does not announce itself.

## Source-level findings (2026-08-22, second pass)

A deeper read of the v0.80 source, checked against current master (`d31278d`) — none of the code
cited below has changed between the two, so this applies to master as well.

**(a) The swapchain is genuinely exclusive fullscreen.** The boot log line
`info:  Setting display mode: 1920x1080@120` is printed only by `wsi::setWindowMode`
(`src/util/wsi_window_win32.cpp:42`), and every call path to it — `EnterFullscreenMode` (invoked
from the constructor when the app passes a fullscreen desc, `d3d11_swapchain.cpp:203-204`),
`SetFullscreenState(TRUE)`, or `ResizeTarget`'s non-windowed branch — requires
`fullscreen_desc_.Windowed == FALSE`. So Unity's "Fullscreen" maps to DXGI exclusive fullscreen
here, not a borderless window. (And retracting my earlier inference: `SetFullscreenState` logs
nothing on its success paths, so "no SetFullscreenState lines" carried no information.)

**(b) Why `dxgi.handleAltTab` structurally cannot help this game.** Both places that react to
alt-tab are gated on the window *not* being minimized:

- `Present1` (`d3d11_swapchain.cpp:743-744`):
  `should_exit_fs = handle_alt_tab_ && !fullscreen_desc_.Windowed && !window_minimized && !wsi::isForeground(hWnd)`
- `GetFullscreenState` (`d3d11_swapchain.cpp:441-442`): same condition shape.

CS2 — like many D3D11 titles — minimizes its own window when it loses focus. Once the window is
iconic, `window_minimized` is true and `should_exit_fs` can never fire. So for any game that
minimizes on deactivate, the option is inert by construction, which matches my measured null
result and may explain part of the "still broken for certain games" comment at `:743`.

**(c) Where the permanent strand plausibly lives.** With vsync on (this game), every present goes
through `presentDrawableAfterMinimumDuration` (`dxmt_context.cpp`, `EncoderType::Present` case),
on a layer DXMT configures with `displaySyncEnabled = false` (`dxmt_presenter.cpp:19`). Two
observations about that combination:

1. `Presenter::encodeCommands` (`dxmt_presenter.cpp:159-165`) calls `layer_.nextDrawable()` and
   uses `drawable.texture()` with **no nil check** — and the present-execution site doesn't check
   either. `-[CAMetalLayer nextDrawable]` blocks up to ~1s and returns nil when no drawable can be
   delivered. Once nil, every frame degrades to a silent no-op: `Present` keeps returning `S_OK`,
   DXMT logs nothing, the screen never changes. That is exactly the observed behaviour.
2. The window is genuinely miniaturized while unfocused. A drawable presented with
   "after minimum *on-screen* duration" semantics on a layer that is never composited may never
   complete; the pool is small (3 by default), so the few in-flight presents around the
   deactivation could wedge it permanently — after which `nextDrawable` returns nil forever, even
   once the window is back on screen.

I cannot prove (2) from outside the process, but the two mechanism families make opposite,
cheaply-measurable predictions on a frozen instance:

- **no-longer-composited / orphaned layer** → the game keeps rendering at full speed: high CPU,
  no blocked threads in a `sample`;
- **wedged drawable pool** → the encoder thread parks in `nextDrawable` timeouts: near-idle CPU,
  `CAMetalLayer nextDrawable` / semaphore waits in the `sample`.

I have a capture kit ready (5s thread-stack `sample`, per-thread CPU, screen-static check, and a
`WINEDEBUG=timestamp,+macdrv,+display,+event` trace of the whole run) and will attach its artifacts
from the next reproduction. If there is a build, config option, or env toggle you would like
exercised in the same run, name it and I'll include it.

**(d) Environment note on the Wine side.** This Wine is a Porting Kit/Gcenx build carrying the
winemac→DXMT enablement patch (`macdrv_view_create_metal_view` and friends, reached from
`winemetal.so`). The metal view/layer is created once per swapchain and cached for its lifetime
(`d3d11_swapchain.cpp:134`; released only in the destructor). If winemac replaces or disposes the
hosting view anywhere across the miniaturize/restore cycle, DXMT would keep presenting into a
detached layer with no error — the same capture will distinguish this too.

## Live-freeze measurements (2026-08-23) — the mechanism, pinned

I reproduced the freeze under `WINEDEBUG=timestamp,+macdrv,+display,+event`, held it frozen, and
captured a 5-second thread-stack `sample` plus per-thread CPU while the screen was provably static
(two centre-screen captures 4s apart, byte-identical). Full artifacts available on request. What
the run established, in order of importance:

**1. The game only ever "freezes" its screen — nothing else.** While provably static, the process
sustains ~250% CPU, the sim autosaves, and blind input works (I saved and quit a frozen session
from memory of the UI). The render loop is not merely alive but *complete*: the sample shows the
encoder thread actively encoding real draws, command buffers being submitted and completing on the
GPU (`IOGPUCommandQueueSubmitCommandBuffers`), `presentAfterMinimumDuration` firing, and drawables
being presented, collected, and recycled in sub-millisecond transit. **Zero threads wait in
`nextDrawable`** (0 hits in a 65k-line sample). So my earlier "wedged drawable pool" hypothesis is
eliminated by measurement: presents complete; the compositor just never shows them.

**2. Each minimize/restore cycle yields exactly one visible refresh.** Observed live and repeated:
alt-tab away and back, and the screen updates *once* — to a current frame — then sticks again.
That's how a frozen session remains playable-blind. The trace shows six windowing-flawless cycles
(`WINDOW_DID_MINIMIZE` → `WINDOW_DID_UNMINIMIZE` → `SC_RESTORE` → refocus → the game restyling
back to borderless-popup fullscreen → a double display-mode re-assert by DXGI/DXMT ~60ms after
focus), one of them entirely inside the proven-static window — so a *complete, correct restore does
not resume presentation*. The one-shot refresh is the WindowServer sampling the layer's current
surface during the window-order transaction, nothing more.

**3. The trigger is a swapchain created while the window was minimized.** The trace pins the
origin precisely. At the session's first focus loss (t+0ms `WINDOW_LOST_FOCUS`), the game — Unity's
standard exclusive-fullscreen behavior — set `WS_MINIMIZE` and called `ShowWindow(SW_MINIMIZE)`
within 5ms. **600ms later, while the Cocoa window was miniaturized and the win32 client rect was
literally empty `(0,0)-(0,0)`, the game created a second swapchain** (the familiar
`CreateSwapChain: unsupported swap effect 3 with backbuffer size 2` fired a second time), and its
metal view/layer was attached to the window in that state. Both swapchains then stay alive until
process exit (their client surfaces receive paired updates on every window change to the end). The
win32 window, Cocoa window, and both metal views are never recreated — identity is stable
throughout. Everything after that attach behaves exactly as a layer whose live-compositing path was
never established: presents complete into it at full speed; the compositor only samples it during
window-order transactions.

**4. Why the known workaround works, and why my earlier tests failed.** A fullscreen toggle (the
folk remedy from #48) forces a fresh swapchain transition *while the window is visible* — a normal
attach, which composites normally. And the three hypotheses I eliminated earlier (occlusion status,
`handleAltTab`) all operate in `Present1`'s status logic, far above this — consistent with their
null results.

**A falsifiable repro recipe follows from this** — and it removes the "needs a human at the
keyboard" obstacle that blocked my earlier minimal reproducer, because no real focus loss is
required: create a window + swapchain, present normally; `ShowWindow(SW_MINIMIZE)`
*programmatically*; create a second swapchain on the same HWND while minimized (empty client
rect); `ShowWindow(SW_RESTORE)`; present color-cycling frames on the new swapchain and check
whether the screen updates. If the mechanism above is right, the second swapchain's output will be
invisible except for one refresh per subsequent minimize/restore cycle. I'm building this and will
attach results.

**Environment note for interpreting the trace:** each restore produces the double
`Setting display mode: 1920x1080@120` because the game re-asserts exclusive fullscreen twice
(mode-set → no-op restyle + `SWP_FRAMECHANGED` → mode-set again); the display channel confirms no
actual hardware mode change (the mode already matches). Present-time behavior is invisible to the
`macdrv` channel by design — after the one-time metal-view attach, DXMT's presentation path never
crosses winemac again.

## Minimal reproducer — no game needed (2026-08-23)

Following the trace, I built a standalone reproducer and then stripped it. **The freeze does not
need fullscreen, minimize, or a focus change at all.** The minimal recipe (`scripts/minrepro3.c`
— ~150 lines, plain windowed `WS_OVERLAPPEDWINDOW`; source shared on request, and the full recipe
is below):

1. Create a window + swapchain **A** (`FLIP_SEQUENTIAL`, 2 buffers), present solid magenta → visible. ✔
2. Create swapchain **B** on the *same HWND* (window plainly visible throughout), present cycling
   colors on B → visible. ✔
3. Present a red pulse on **A** again, 6 seconds at ~120fps, every `Present` returning `S_OK` →
   **the screen never changes. It stays frozen on B's last frame** (screenshots 3s apart are
   pixel-identical: RGB (32,126,127) both times, while A was being cleared red).
4. Present on **B** again → live immediately.

So: **on one HWND, only the most-recently-created swapchain's layer is composited. Presents to any
older swapchain on that HWND complete successfully, at full frame rate, into a layer that is never
shown again.** No error, no log line, nothing returned to the app.

That is the game's freeze exactly. Cities: Skylines II, like many D3D11 titles, creates a second
swapchain when it loses exclusive fullscreen (the trace shows the second
`CreateSwapChain: unsupported swap effect 3` 600ms after the first focus loss) — but keeps
rendering into the *original* swapchain (each later restore re-asserts fullscreen through the
original chain — the double `Setting display mode` per cycle). From that moment its presents land
in a hidden layer forever: input works, the sim runs, ~250% CPU, and the screen shows a stale
frame that only refreshes once per window-order transaction.

Intermediate data points from the less-stripped variants, in case they help:
- `minrepro.c` (v1): the same two-swapchain sequence but presenting only on the *new* chain
  afterward — no bug, because the new chain's layer is the visible one.
- `minrepro2.c` (v2): full trace mirror (exclusive fullscreen A, self-minimize, B created while
  minimized, DXGI fullscreen re-assert). Same result as v3, plus one more observation: after a
  further minimize/restore cycle, presents to the *visible* chain took between 1 and 4 seconds to
  reach the screen again (stale at +1s, live at +4s) — the window-order transaction seems to
  re-establish compositing for the visible layer with a lag, and never for hidden ones.

Where I'd look (from the outside, having read the v0.80 source): each swapchain creates its own
metal view on the HWND (`d3d11_swapchain.cpp:134` → `CreateMetalViewFromHWND`), and on the Wine
side the newest client view hides the previous one when it attaches; nothing ever unhides the old
view or follows which swapchain the app is actually presenting. A single shared view per HWND, or
flipping visibility to the presenting swapchain's view at present time, would both make the
recipe above behave. (Stated as observations, not a patch — per your AI policy the analysis is
mine to share and the code is yours to write.)

## Failed reproduction attempt — superseded (kept so nobody repeats it)

I wrote a ~150-line DX11 present loop (clear to magenta, log every frame's `Present` HRESULT and
latency, log `WM_ACTIVATEAPP` / `WM_ACTIVATE` / `WM_KILLFOCUS` / `WM_SIZE`) and ran the matrix:
windowed and exclusive-fullscreen × `DISCARD` and `FLIP_SEQUENTIAL`. Focus was stolen with
`osascript` (activating Finder, Cmd-H, and forcing the wine process frontmost first).

**All four configurations kept presenting normally, `Present` returning `S_OK` throughout.** But that
is not evidence against the bug, because in **every** run `WM_ACTIVATEAPP DEACTIVATED` never arrived —
activation messages fire once at startup and never again. The synthetic focus change never crossed
into the Wine window, so the trigger was never actually applied.

That may itself be a clue: when CS2 loses focus in exclusive fullscreen its window genuinely
minimises (macOS-level), which a small windowed app driven by `osascript` never experiences. If you
know a reliable way to drive a real deactivation into a Wine window, I'll happily retry and report
back with a minimal repro.

## A weak control, stated as weak

The same game on the same machine under **D3DMetal + wine-10.0** also misbehaves on focus loss, but
more mildly — cursor desync and a darkened frame rather than a permanent freeze. That is not a clean
control (different renderer *and* different Wine version), so it does not isolate DXMT. I mention it
only because the application appears to do something unusual at focus transitions generally, and
DXMT's handling is the more severe of the two.

## Related issues

- [#48](https://github.com/3Shain/dxmt/issues/48) (closed) is the closest prior art — "doesn't update
  screen contents unless switching fullscreen on/off" — but a different trigger, and its
  `SetFullscreenState: stub` / `outstanding buffer hold` signatures do not appear in my v0.80 logs.
- [#26](https://github.com/3Shain/dxmt/issues/26) is about refresh-rate disagreement causing frame
  *pacing* errors. Not this. For what it's worth I measured frame pacing on this setup and it is
  correct: `Present` at sync interval 1 gives exactly 120 fps on the 120 Hz display, and sync
  interval 2 gives 61 fps.

## Disclosure

This investigation was done with substantial AI assistance — the source reading, the trace
analysis, and the reproducer iterations — following the precedent of #200, where up-front
disclosure got a maintainer reply. Per your `CONTRIBUTING.md` AI policy I'm sharing this as
research only: no PR, and any fix is yours to write. All measurements were taken on my machine
and I'm glad to re-run any of them, test a build, or share the raw artifacts (trace, thread-stack
sample, reproducer source) on request.

Thanks for DXMT — it reports the real GPU where the alternative reports `AMD Compatibility Mode`,
and it's the reason this game runs on a free stack at all.
