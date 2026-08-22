# Open threads

Current stack: **Wine 11.0 + DXMT** (Porting Kit wrapper), default since 2026-08-22 — 11 patches
instead of 17. **Wine 10 Sikarugir + D3DMetal** stays as the proven fallback. Both are playable with
mods downloading and loading; both have working Steam clients. See `README.md` for how it works and
`docs/patch-inventory.md` for the patch-by-patch breakdown.

## Top user-facing defect: the alt-tab freeze

Switching away from exclusive fullscreen — alt-tab **or just clicking outside the window** — freezes
the render on the default stack: input still registers, the surface never re-presents, and recovery
needs a force-kill (`wineserver -k`), which can leave a `.crash` marker that blocks the next launch.
Wine 10 + D3DMetal misbehaves too, but more mildly (cursor desync, darkening).

Best candidate, logged by DXMT at startup and still unproven: `CreateSwapChain: unsupported swap
effect 3` — `DXGI_SWAP_EFFECT_FLIP_DISCARD`, the flip-model swapchain that handles occlusion and
focus transitions. No upstream DXMT issue covers it (searched 2026-08-22), so **filing one with the
measurements from this repo is the highest-value next move** — it is now the main thing standing
between this stack and "just works". Interim: use the windowed launcher for sessions where you need
to switch away, and don't click out of fullscreen.

## Highest value: fix it upstream in Wine

Three Wine defects account for **11 of the 17** patches. Fixing any of them upstream retires
patches for every macOS user, not just this machine. Reproducers are in `scripts/` and run under
the game's exact Unity Mono **without launching the game**, which makes them directly attachable to
a bug report.

| ID | Defect | Retires |
|---|---|---|
| **R1** | `GetLastError` returns garbage after file APIs — on success *and* on the failure return, so callers can't distinguish "not found" from a real error | 8 patches |
| **R2** | `CreateFile` returns handle `0` for a **valid** open file; .NET's `SafeHandleZeroOrMinusOneIsInvalid` then judges it invalid | 2 patches |
| **R3** | `BCryptVerifySignature` fails on valid ECDSA signatures | 1 patch — and it is the only patch with a licensing problem, so fixing R3 removes that issue entirely |

**Not filed yet.** This is the single most useful thing left to do.

## Report upstream to Paradox

`patch_lockleak` works around a genuine PdxSdk defect, not a Wine one:
`FileIO::CreateFileStream`'s state machine has two `catch` clauses and **no `finally`**, and the
catch handler never disposes the lock acquired at IL `0x78`/`0x82` — though the FileNotFound path at
`0x120` does. Any IO exception leaks that path's lock permanently; the next waiter dies on
`GetLockToken`'s timeout. Windows just rarely throws there, so it hides. Clean fix upstream: dispose
in the handler, or wrap in `finally`.

## Known-unresolved, low severity

- **Fullscreen-toggle cursor desync.** Toggling fullscreen ↔ windowed mid-session drops the game out
  of exclusive fullscreen (a macOS title bar appears); render resolution and window geometry stop
  matching and cursor coordinates shift. Workaround: set Fullscreen and don't toggle.
- **Graphics settings must be set in-game.** Hand-editing `Settings.coc` to flip an `enabled` flag
  without its accompanying parameters produces an "on but zeroed" profile (e.g. SSGI with
  `raySteps: 0`) that the game reports as `Custom` and does not restore across a display-mode
  change. Use Options → Graphics.
- **D3DMetal unsupported-API notices** at startup (`NumClassInstances > 0`, `GetSharedHandle`,
  timestamp queries). One-time init messages, not per-frame; no observed impact.
- **Rosetta horizon.** The entire stack is x86-64 under Rosetta 2, and macOS 26 now surfaces a
  deprecation notice ([Apple 102527](https://support.apple.com/en-us/102527)) — coming, not in
  effect. Apple's stated plan: full Rosetta through macOS 27, then a reduced subset "for older
  games" in macOS 28+, with no word on whether Wine-style use qualifies. Nothing to do today;
  plan-B territory (ARM-native Wine/FEX or whatever exists by then) around late 2027.

## Not worth doing

- **Reviving the DXVK/MoltenVK stack.** Archived in `archive/`. D3DMetal is stable where it was not.
- **CrossOver.** Licence expired 2026-08-21. The free stack matched it and then exceeded it.
- **`patch_pdxsdk_io`.** Masks failures instead of fixing them; breaks boot on empty mod state.
- **The four rejected lock patches.** All chased a deadlock that does not exist. See
  `docs/patch-inventory.md` §5.
