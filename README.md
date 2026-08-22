# Cities: Skylines II on macOS (Apple Silicon) — free, no CrossOver

Field notes from getting **Cities: Skylines II** running on an **M3 Max / macOS 26**, on a
fully free stack, **including working in-game Paradox Mods downloads** — which was the hard part
and, as far as I can tell, isn't documented anywhere else.

**Status (2026-08-22):** Playable. Renders, saves, mods download *and* load.

## The stack that works

| Layer | What | Why |
|---|---|---|
| Wrapper | **Kegworks / WineskinNavy** app bundle | packaging + prefix |
| Wine | **Wine 10.0 Sikarugir** | a Wine with `winemac.drv` Metal symbols exposed |
| Graphics | **D3DMetal v2.1** | D3D11 → Metal, `feature level 11.1`, honest 28 GB VRAM |
| Game | CS2 `1.6.0f1 (419.d6c6)` via Steam in-prefix | — |

`Direct3D 11.0 [level 11.1]`, no MoltenVK device-loss lottery, no OpenGL.

> An earlier attempt on **Wine 11 + DXVK + private-API MoltenVK** also rendered, but device-lost
> roughly 1 run in 8 — playable by dice roll. D3DMetal is stable. Notes kept in `archive/`.

## Two things worth knowing before you start

1. **Launch `Cities2.exe` directly.** Steam's *Play* button routes through the Paradox Launcher
   and exits before Unity initialises. Start Steam, let it log in, wait for the licence to sync,
   *then* run the exe.
2. **Use native Fullscreen.** `explorer /desktop=` fixes menu-mouse but eats WSAD — keyboard goes
   to the virtual-desktop container. Fullscreen routes both. Toggling display modes mid-session
   also desyncs the cursor.

## Repository layout

| Path | What |
|---|---|
| `docs/patch-inventory.md` | **Start here.** All 17 binary patches, the bug each works around, and which upstream owns it |
| `GOTCHAS.md` | Every trap hit, with root cause |
| `CONFIG-TRIALS.md` | Config permutations tried, with outcomes |
| `MODS-TESTING.md` | The Paradox Mods download investigation |
| `REFERENCES.md` | Upstream projects, recipes, sources |
| `PLAN.md` | Roadmap / open threads |
| `launchers/` | The one live launcher; dead-stack scripts archived with reasons |
| `scripts/` | Minimal reproducers (see `scripts/README.md`) |

| `patches/` | The 16 publishable binary patches + `repatch.sh` |
| `docs/wine-bugs/` | Ready-to-file Wine bug reports for the three root causes |

> **16 of 17 patches are here.** The 17th bypasses a Coherent Gameface licence-signature check that
> fails only because of Wine bug **R3** — publishing a bypass for commercial middleware reads as
> circumvention regardless of intent, so it is withheld. **Until R3 is fixed in Wine, the game will
> not reach the main menu on this stack.** See `docs/wine-bugs/R3-*.md`. No game or middleware
> binary is redistributed here.

## The real finding: the bug is real, and Wine 11 already fixed it

The patches exist because of a genuine defect — but **not the one first assumed**, and it is fixed
upstream. Measured 2026-08-22, same probe under Unity's Mono with a **pristine** `mscorlib`:

| | wine-10.0 | wine-11.0 / 11.15 |
|---|---|---|
| `Marshal.GetLastWin32Error` after P/Invoke | **1525694624 (garbage)** | **0** |
| `Directory.Delete(recursive)` | throws `IOException 0x5af040a0` | OK |
| `File.Delete(nonexistent)` | throws | OK |

**On Wine 11, 5 of the 17 patches become unnecessary** — verified by running the game with them
removed: it boots, mods load, and a **fresh mod download completes** with zero IO errors.

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
