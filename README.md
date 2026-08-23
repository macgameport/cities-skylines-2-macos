# Cities: Skylines II on macOS (Apple Silicon) — free, no CrossOver

Field notes from getting **Cities: Skylines II** running on an **M3 Max / macOS 26**, on a
fully free stack, **including working in-game Paradox Mods downloads** — which was the hard part
and, as far as I can tell, isn't documented anywhere else.

**Status (2026-08-23):** Playable. Renders, saves, mods download *and* load.

![Cities: Skylines II running on macOS via Wine + DXMT](docs/images/cs2-on-macos.png)

*The game on macOS 26 (M3 Max), x86-64 under Rosetta, rendering through Metal via DXMT — 42.7 FPS
at 1080p. The overlay is Metal's own performance HUD, enabled with `CS2_HUD=1`.*

## Quick start

Own the game on Steam, on an Apple Silicon Mac? Roughly 20 minutes:

```bash
git clone https://github.com/macgameport/cities-skylines-2-macos.git
cd cities-skylines-2-macos
bash scripts/setup.sh
```

`setup.sh` checks your prerequisites, applies the patches, and builds a double-clickable app with
the game's own icon. You need a Wine wrapper with Steam and the game inside it first —
**[INSTALL.md](INSTALL.md) walks through all of it**, including the one in-game setting worth
changing (Display Mode → Fullscreen Window).

## The stack that works

Two stacks work. The **Wine 11 + DXMT** one is the default since 2026-08-22 because it needs
**10 patches instead of 17** — Wine 11 fixed both the Mono garbage-errno defect *and* the bcrypt
signature defect upstream ([the measurement](docs/wine-bugs/FINDING-wine11-fixes-it.md)).

| Layer | Default — **Wine 11 + DXMT** | Fallback — **Wine 10 + D3DMetal** |
|---|---|---|
| Wrapper | Porting Kit app bundle | Kegworks / WineskinNavy app bundle |
| Wine | **Wine 11.0** (`WS12Wine11.0_DXMT-v0.80`) | **Wine 10.0 Sikarugir** |
| Graphics | **DXMT v0.80** — reports the real GPU (`Apple M3 Max`) | **D3DMetal v2.1** — reports `AMD Compatibility Mode` |
| Patches | **10** — the 6 errno patches AND the licence bypass are unnecessary | **17** |
| Proven by | boots, mods load + download, Steam UI, DLC | a 1h40m session, saved city, long-run stability |

Both run CS2 `1.6.0f1 (419.d6c6)` via Steam in-prefix at `Direct3D 11.0 [level 11.1]` — no MoltenVK
device-loss lottery, no OpenGL. The one serious defect — an alt-tab "freeze" in exclusive
fullscreen — was diagnosed here, reproduced in a standalone ~150-line program, and reported
upstream as [dxmt#206](https://github.com/3Shain/dxmt/issues/206) (presents to an HWND's
non-newest swapchain are silently never composited; the game keeps running at full speed while
the screen shows a stale frame). **It does not affect Fullscreen Window (borderless) mode**, and
even a frozen exclusive-mode session is recoverable in-game — full story in `GOTCHAS.md` § alt-tab
and `docs/dxmt-bugs/`.

> An earlier attempt on **Wine 11 + DXVK + private-API MoltenVK** also rendered, but device-lost
> roughly 1 run in 8 — playable by dice roll. D3DMetal is stable. Notes kept in `archive/`.

## Two things worth knowing before you start

1. **Launch `Cities2.exe` directly.** Steam's *Play* button routes through the Paradox Launcher
   and exits before Unity initialises. Start Steam, let it log in, wait for the licence to sync,
   *then* run the exe.
2. **Set Display Mode to Fullscreen Window (borderless).** It looks identical to exclusive
   fullscreen, routes mouse and keyboard correctly, and is immune to the alt-tab freeze
   ([dxmt#206](https://github.com/3Shain/dxmt/issues/206)). Avoid `explorer /desktop=` (it eats
   WSAD — keyboard goes to the virtual-desktop container) and avoid exclusive Fullscreen unless
   you never switch apps — and if it does freeze there, alt-tab refreshes the screen one frame
   per cycle, so you can blind-navigate Options → Graphics → Display Mode → Fullscreen Window
   and it comes back live. No force-kill needed.

## Repository layout

| Path | What |
|---|---|
| `INSTALL.md` | **Start here to play.** Step-by-step from nothing to a working game |
| `docs/patch-inventory.md` | All 17 binary patches, the bug each works around, and which upstream owns it |
| `GOTCHAS.md` | Every trap hit, with root cause |
| `CONFIG-TRIALS.md` | Config permutations tried, with outcomes |
| `MODS-TESTING.md` | The Paradox Mods download investigation |
| `REFERENCES.md` | Upstream projects, recipes, sources |
| `PLAN.md` | Roadmap / open threads |
| `launchers/` | The one live launcher; dead-stack scripts archived with reasons |
| `scripts/` | Minimal reproducers + `make-shortcut.sh` (builds the double-clickable launcher app, icon extracted from your own `Cities2.exe`) — see `scripts/README.md` |

| `patches/` | The 16 publishable binary patches + `repatch.sh`. The Wine 11 path needs 10 of them, **all present** |
| `docs/wine-bugs/` | Ready-to-file Wine bug reports for the three root causes |

> **Wine 11 needs 10 patches, and all 10 are here.** ✅ **R3 is fixed upstream** (measured
> 2026-08-22): with the Coherent Gameface licence bypass fully removed, wine-11.0 verifies the
> ECDSA signature correctly and the game reaches the main menu and loads a city with zero licence
> errors. So the one patch this repo withholds — a signature-check bypass, withheld because
> publishing one reads as circumvention regardless of intent — **is not needed on the default
> stack**. It remains necessary on the Wine 10 + D3DMetal fallback, which is therefore the
> incomplete path here (16 of its 17). See `docs/wine-bugs/R3-*.md`. No game or middleware binary
> is redistributed.

## The real finding: the bug is real, and Wine 11 already fixed it

The patches exist because of a genuine defect — but **not the one first assumed**, and it is fixed
upstream. Measured 2026-08-22, same probe under Unity's Mono with a **pristine** `mscorlib`:

| | wine-10.0 | wine-11.0 / 11.15 |
|---|---|---|
| `Marshal.GetLastWin32Error` after P/Invoke | **1525694624 (garbage)** | **0** |
| `Directory.Delete(recursive)` | throws `IOException 0x5af040a0` | OK |
| `File.Delete(nonexistent)` | throws | OK |

**On Wine 11, 7 of the 17 patches become unnecessary** — the six errno-tolerance ones plus the
licence bypass — each verified by running the game with them removed: it boots, mods load, a
**fresh mod download completes** with zero IO errors, and the main menu is reached with zero
licence errors.

Two things this project got wrong first, both disproven by measurement and documented in
[`docs/wine-bugs/`](docs/wine-bugs/):

- **It is not raw Win32.** Bug [60220](https://bugs.winehq.org/show_bug.cgi?id=60220) was filed
  against `kernel32` and closed INVALID: `GetLastError` is **9/9 correct** on both Wine versions
  (`scripts/errtest.c`). The corruption is in **Mono's P/Invoke last-error capture**.
- **`CreateFile` never returns handle 0.** 3200 concurrent opens, short and long paths, both Wine
  versions — never once (`scripts/handletest.c`, `scripts/longpathw.c`).

`patch_fshandle` is **still required on Wine 11** — the handle-0 defect and the garbage-errno defect
are separate bugs, and only the latter is fixed.

One bug is **not Wine's**: a leaked file lock in the Paradox SDK — a method with two `catch` clauses
and no `finally`, whose handler never releases the lock it took. Any IO exception leaks that path's
lock permanently. See [`docs/patch-inventory.md`](docs/patch-inventory.md) §5.

## Credit

This only works because of other people's free work:

- **[Paul the Tall / Porting Kit](https://www.portingkit.com/)** — supplied the missing piece: a
  Wine with `winemac.drv` Metal symbols exposed. **If this repo is useful to you, donate to them.**
- **[3Shain / DXMT](https://github.com/3Shain/dxmt)** — open D3D11→Metal; carried an earlier
  working stack
- **[Gcenx](https://github.com/Gcenx)** — the macOS Wine builds
- **Wineskin / Sikarugir / Kegworks** — the wrapper and engine lineage
- **[manolz1/cities2-gptk-fix](https://github.com/manolz1/cities2-gptk-fix)** and
  **mbeckenbach/Cities-Skylines-2-MacOS-Patcher** — the original DLL fixes
- **Apple** — D3DMetal

## Scope and legality

Notes and tooling for running **software you already own** on your own machine. No game binaries,
no middleware, no circumvention tooling is distributed here. Cities: Skylines II is © Colossal
Order / Paradox Interactive; Coherent Gameface © Coherent Labs; other marks belong to their owners.

See `LICENSE` (MIT, with an explicit third-party carve-out).
