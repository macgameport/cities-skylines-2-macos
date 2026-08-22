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

> **This repo contains notes and launchers — not the binary patches themselves.** The patch
> scripts live outside it. Nothing here modifies or redistributes any game or middleware binary.

## The real finding: most of this is three Wine bugs

Nearly every patch exists to work around one of:

- **R1** — `GetLastError` returns **garbage** after file APIs, so callers can't tell "not found"
  from a real failure. *(8 patches)*
- **R2** — `CreateFile` returns **handle 0 for a valid file**; .NET's `SafeHandleZeroOrMinusOneIsInvalid`
  judges it invalid. *(2 patches)*
- **R3** — `BCryptVerifySignature` fails on valid ECDSA signatures. *(1 patch)*

**Fix those three upstream in Wine and 11 of 17 patches evaporate.** Deterministic reproducers for
R1/R2 are in `scripts/` and run under the game's exact Unity Mono without launching the game.

One bug is *not* Wine's: a leaked file lock in the Paradox SDK — a method with two `catch` clauses
and no `finally`, whose handler never releases the lock it took. Any IO exception leaks that path's
lock permanently and the next waiter dies on a timeout. See `docs/patch-inventory.md` §5.

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
