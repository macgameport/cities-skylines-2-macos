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

**Up front, so nobody wastes time on it: I could not build a minimal reproducer.** Details in
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

**1. The swapchain is created with a swap effect DXMT rejects, and falls back silently:**

```
warn:  CreateSwapChain: unsupported swap effect 3 with backbuffer size 2
```

Swap effect `3` is `DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL` (checked against `dxgi.h`:
`DISCARD = 0, SEQUENTIAL = 1, FLIP_SEQUENTIAL = 3, FLIP_DISCARD = 4`), `BufferCount = 2`. The flip
model is the path that defines behaviour across occlusion and focus transitions — exactly the
transition that breaks. If the silent fallback is a bitblt-model swapchain, occlusion handling would
differ from what the application assumes. I have not verified what DXMT actually falls back *to*, so
this is a hypothesis.

**2. The app asks DXGI not to manage window transitions, and the request is ignored:**

```
warn:  MakeWindowAssociation: Ignoring flags 3
```

Flags `3` = `DXGI_MWA_NO_WINDOW_CHANGES (0x1) | DXGI_MWA_NO_ALT_ENTER (0x2)`. So the application is
explicitly saying "don't monitor the message queue, don't handle Alt+Enter — I own these
transitions," and that is not honoured. For a bug specifically about focus transitions, an ignored
"I own focus transitions" request seems at least as interesting as the swap effect.

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
