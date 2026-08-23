# DXMT issue — READY TO FILE (blocked on account auth)

> **Status: not filed.** Approved for filing 2026-08-22, to be posted as **macgameport** on
> [3Shain/dxmt](https://github.com/3Shain/dxmt). `gh` on this machine is authenticated only as
> `jvspearman`, and authenticating another account requires a browser flow only James can complete:
>
> ```
> gh auth login --hostname github.com --web
> ```
>
> Once `gh auth status` lists `macgameport` as active, file it with:
>
> ```
> gh issue create --repo 3Shain/dxmt \
>   --title "Exclusive fullscreen: losing window focus permanently freezes presentation (input still registers)" \
>   --body-file docs/dxmt-bugs/DRAFT-focus-loss-freeze.md
> ```
>
> (strip this header block first — everything below the rule is the issue body)

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

**Title:** `Exclusive fullscreen: losing window focus permanently freezes presentation (input still registers)`

---

## Summary

In exclusive fullscreen, anything that takes focus away from the game — alt-tab, clicking another
window, or a global hotkey raising another app — permanently stops the swapchain presenting. The
game keeps running: it accepts input, its own logs keep advancing, the process stays healthy. The
screen never redraws again. There is no recovery from inside the game; the session has to be ended
with `wineserver -k`.

It has cost me two play sessions today, the second triggered by accidentally hitting a hotkey that
raised another macOS app. This is the last blocking defect on an otherwise fully playable stack, so
I'm glad to run experiments or test a patch.

**Already tried, so nobody suggests it: `dxgi.handleAltTab = True` does not fix it** (details
below), and **I could not build a minimal reproducer.** Details in
"Failed reproduction attempt" below — the short version is that a small DX11 app never receives the
focus-loss event at all, so the trigger can't be applied synthetically. The game is currently the
only reproducer I have.

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

**What I could not determine from outside:** whether CS2's swapchain is actually
`Windowed == FALSE`. The game reports `Applying resolution: 1920x1080x120Hz Fullscreen` and sets
`displayMode: Fullscreen`, but Unity's "Fullscreen" can map to a borderless fullscreen *window*. If
it does, `handle_alt_tab_` could never apply here regardless of the setting — which would explain
both the null result above and the total absence of fullscreen logging. If you can tell me what to
look for (or point me at a debug build/env var that logs the swapchain's fullscreen state), I'll
measure it and report back.

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

## Failed reproduction attempt (so you don't repeat it)

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

Thanks for DXMT — it reports the real GPU where the alternative reports `AMD Compatibility Mode`,
and it's the reason this game runs on a free stack at all.
