# Claude Instructions — cs2 (macOS CS2 port notes)

Personal/throwaway-tier project: **no issue tracker, no phases, no SPEC.md.** Skip the
issues-per-item ritual. Durable record = this repo + `~/cs2-patch/change-ledger.txt`.

## Where things live

| What | Path |
|---|---|
| Patch scripts + ledger | `~/cs2-patch/` (**outside this repo**, deliberately) |
| Canonical launcher | `~/cs2-patch/launch-cs2.sh` — repo copy is a thin wrapper (macOS TCC blocks app bundles from executing scripts in `~/Documents`) |
| Apply all patches | `bash ~/cs2-patch/repatch.sh free` (17 patches; no arg = the dead CrossOver bottle) |
| Shortcut | `~/Applications/Cities Skylines II.app` → runs the launcher with `CS2_QUIET=1` |
| Game prefix | `~/Applications/S734M.app/Contents/SharedSupport/prefix` |
| Game logs | `<prefix>/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/` (the other user dirs in the prefix are symlinks to `Wineskin`) |
| RE toolchain | `~/cs2-patch/revenv` (dnfile + capstone + pefile) |
| Disassemble | `~/cs2-patch/revenv/bin/python3 ~/cs2-patch/dis_pdx.py <dll> <Type> <Method>` |

## Rules specific to this project

- **Never edit `launch-cs2.sh` while the game is running.** Bash reads scripts incrementally;
  a mid-run edit shifts byte offsets and corrupts the parse (produces a bogus syntax error).
- **Never `kill -9` Steam.** It leaves a 0-byte `.crash` marker that makes the next launch exit 1.
  Use `steam.exe -shutdown`; fall back to `WINEPREFIX=<prefix> wineserver -k`. The launcher clears
  a stale `.crash` on startup.
- **Don't hand-edit `Settings.coc` for graphics.** Flipping `enabled` without the accompanying
  parameters yields an "on but zeroed" profile the game reports as `Custom` and won't restore
  across a display-mode change. Set graphics in-game.
- **Judge runs by timestamp.** Only read a run whose `SceneFlow.log` first line postdates the change.
- **Check disk, not the UI**, for anything mod-related.
- Boot-verify after touching `mscorlib` — it's on the boot path.

## Personal info

Repo is intended to be publishable. Keep Steam IDs, `[U:1:<n>]` account ids, real usernames and
absolute `/Users/<name>` paths **out of committed files** — use `$HOME`, `$WINEUSER`, `<REDACTED>`.
