# Open threads

Current stack: **Wine 10 Sikarugir + D3DMetal** in a Kegworks wrapper. Playable; mods download and
load. What follows is what's still unresolved — see `README.md` for how it works and
`docs/patch-inventory.md` for the patch-by-patch breakdown.

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
