# DRAFT — DXMT issue: focus loss in exclusive fullscreen freezes presentation

> **Status: DRAFT, not filed.** Nothing has been posted to
> [3Shain/dxmt](https://github.com/3Shain/dxmt). Everything below the line is the proposed issue
> body. Read the "Before filing" checklist at the foot first — one cheap experiment would make this
> report substantially stronger.

Duplicate check (2026-08-22): searched `repo:3Shain/dxmt` for swapchain / alt-tab / fullscreen /
focus / freeze. **No open issue covers focus-loss freeze.** Nearest neighbours:

| # | state | why it is not this |
|---|---|---|
| [#48](https://github.com/3Shain/dxmt/issues/48) | closed | Same *class* — "doesn't update screen contents unless switching fullscreen on/off" — but a different trigger (never presents past frame 1) and its log signature `SetFullscreenState: stub` / `outstanding buffer hold` does **not** appear in ours. Older DXMT. Worth citing as prior art. |
| [#26](https://github.com/3Shain/dxmt/issues/26) | open | ProMotion V-Sync: refresh-rate *disagreement* causing frame **pacing** errors, not a freeze. Relevant to this machine (120 Hz) but a different failure. |
| [#141](https://github.com/3Shain/dxmt/issues/141) | open | ANGLE `SwapChain11` → `EGL_BAD_ALLOC`, Steam CEF black window. Unrelated to focus loss. (See the correction note in `GOTCHAS.md` — this project long mis-cited #141 as a "cross-process swapchain" issue. It is not.) |

---

## Title

`Exclusive fullscreen: losing window focus permanently freezes presentation (input still registers)`

## Body

**Summary.** In exclusive fullscreen, anything that takes focus away from the game — alt-tab, or
simply clicking on another window — permanently stops the swapchain presenting. The game itself
keeps running: it accepts input, its own log keeps advancing, and the process stays healthy. The
screen never redraws again. There is no recovery from inside the game; the session has to be killed
with `wineserver -k`.

This is the last blocking defect on an otherwise fully playable stack, so I am happy to run further
experiments or test a patch.

### Environment

| | |
|---|---|
| DXMT | **v0.80** (build path fingerprint `dxmt-f3e54a65`) |
| Wine | **wine-11.0**, Porting Kit engine `WS12Wine11.0_DXMT-v0.80` |
| macOS | **26.5.2** (25F84) |
| GPU | **Apple M3 Max** (correctly reported by DXMT) |
| Display | built-in, 1920×1080 @ **120 Hz** (ProMotion) |
| Game | Cities: Skylines II `1.6.0f1` (Steam 949230), Unity, `Direct3D 11.0 [level 11.1]` |
| Translation | Rosetta 2 (x86-64 guest) |

### Steps to reproduce

1. Launch the game and let it reach the main menu or an in-game view, in **exclusive fullscreen**
   (the game's `displayMode: Fullscreen`, not windowed and not a Wine virtual desktop).
2. Click any other macOS window, or alt-tab away. The game window minimises.
3. Return to the game (Cmd-Tab, or its Dock icon).

**Expected:** the game re-presents and play continues.
**Actual:** the window is composited but its contents never update again. Input is still being
received — a click or key still registers in the game's own state — but no frame ever reaches the
screen. Only `wineserver -k` ends it.

### Observations

These are the DXMT lines I can tie to the affected session. I want to be explicit that **I have not
proven any of them causes the freeze** — they are what stands out, in order of how suspicious they
look to me.

**1. The swapchain is created with a swap effect DXMT rejects, and falls back silently:**

```
warn:  CreateSwapChain: unsupported swap effect 3 with backbuffer size 2
```

Swap effect `3` is `DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL` (verified against `dxgi.h`:
`DISCARD = 0, SEQUENTIAL = 1, FLIP_SEQUENTIAL = 3, FLIP_DISCARD = 4`), with `BufferCount = 2`. The
flip model is the path that defines behaviour across occlusion and focus transitions, which is
exactly the transition that breaks here. If the fallback is a bitblt-model swapchain, I would expect
occlusion handling to differ from what the app assumes — but I have not verified what DXMT falls
back *to*, so this is a hypothesis, not a diagnosis.

**2. The app asks DXGI not to manage window transitions, and DXMT ignores the request:**

```
warn:  MakeWindowAssociation: Ignoring flags 3
```

Flags `3` = `DXGI_MWA_NO_WINDOW_CHANGES (0x1) | DXGI_MWA_NO_ALT_ENTER (0x2)` (from `dxgi.h`). So the
application is explicitly saying "do not monitor the message queue, do not handle Alt+Enter — I own
these transitions," and DXGI here does not honour it. For a bug that is *specifically* about focus
transitions, an ignored "I own focus transitions" flag seems worth a look.

**3. Display-mode churn.** One session logged 16 × `Setting display mode: 1920x1080@120`. The mode
is correct and stable (no 60/120 flapping), so I do not think this is [#26](https://github.com/3Shain/dxmt/issues/26)
— but the repetition suggests mode-set work is being redone rather than recognised as a no-op.

**What I did *not* find:** no `SetFullscreenState: stub`, no `outstanding buffer hold`, no
`cross-process swapchain` messages, and no errors at all at the moment of the freeze — the log
simply goes quiet on the DXMT side while the game's own log keeps writing. Whatever happens, it does
not announce itself.

### A weak control, stated as weak

The same game on the same machine under **D3DMetal + wine-10.0** also misbehaves on focus loss, but
more mildly: cursor desync and a darkened frame rather than a permanent freeze. That is not a clean
control — different renderer *and* different Wine version — so it does not isolate DXMT. I mention
it only to say the app is doing something unusual at focus transitions generally, and DXMT's
handling is the more severe of the two.

### What would help

If you can tell me what DXMT falls back to for an unsupported swap effect, I can test whether
forcing the app onto `DXGI_SWAP_EFFECT_DISCARD` avoids the freeze — that would isolate (1) cleanly.
I can also run a minimal DX11 app rather than a 90 GB game if a small reproducer is more useful.

---

## Before filing — checklist

1. **Get a minimal reproducer.** This repo already has `scripts/dxtest.c` (minimal DX11
   clear-to-magenta). Build it for the wine-11 prefix, run it fullscreen, click away, and see
   whether presentation stops. If it reproduces, the issue becomes "here is a 60-line repro"
   instead of "here is a Unity game" — worth far more to a maintainer. If it does **not**
   reproduce, that is equally informative and this draft needs rewriting around what differs.
2. **Capture a clean log of the freeze alone.** The current evidence is spread across a session that
   also included a force-kill. Run once, freeze it deliberately, capture `WINEDEBUG` output from
   that run only, and attach it.
3. **Try the swap-effect experiment** if a way exists to force `DISCARD` (Unity command line, or a
   d3d11 override) — the answer decides whether observation (1) leads anywhere.
4. **Decide on posting.** Filing is a public post under James's GitHub account; nothing goes up
   without an explicit go-ahead. Issue [#200](https://github.com/3Shain/dxmt/issues/200) in that repo
   shows the maintainer engages well with detailed reports that separate measurement from
   speculation — which is the standard this draft tries to meet.
