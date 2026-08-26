# Claude Instructions — cs2 (macOS CS2 port notes)

Personal/throwaway-tier project: **no issue tracker, no phases, no SPEC.md.** Skip the
issues-per-item ritual. Durable record = this repo + `~/cs2-patch/change-ledger.txt`.

## Where things live

| What | Path |
|---|---|
| Patch scripts + ledger | `~/cs2-patch/` (**outside this repo**, deliberately) |
| Canonical launcher (**default**) | `~/cs2-patch/launch-cs2-dxmt11.sh` — Wine 11 + DXMT. Repo copies are thin wrappers (macOS TCC blocks app bundles from executing scripts in `~/Documents`) |
| Canonical launcher (fallback) | `~/cs2-patch/launch-cs2.sh` — Wine 10 + D3DMetal |
| Apply all patches | `bash ~/cs2-patch/repatch.sh dxmt11` (10 patches) · `… free` (17, Wine 10) · no arg = the dead CrossOver bottle |
| Shortcut | `~/Applications/Cities Skylines II.app` → runs the **dxmt11** launcher with `CS2_QUIET=1`. Revert = one `SCRIPT=` line in `Contents/MacOS/launch` |
| Store shortcut | `~/Applications/CS2 Steam Store.app` → opens Steam **visibly** in the storefront wrapper (`CS2dxmt11-pk110.app`, wine 11.0 — the 11.16 engine black-screens Steam's UI). Built by `scripts/make-steam-shortcut.sh` (also creates the wrapper by APFS clone if absent) |
| Game prefix (default) | `~/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix` |
| Game prefix (fallback) | `~/Applications/S734M.app/Contents/SharedSupport/prefix` |
| Game logs | `<prefix>/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/` (the other user dirs in the prefix are symlinks to `Wineskin`) |
| RE toolchain | `~/cs2-patch/revenv` (dnfile + capstone + pefile) |
| Disassemble | `~/cs2-patch/revenv/bin/python3 ~/cs2-patch/dis_pdx.py <dll> <Type> <Method>` |

## Rules specific to this project

- **Never edit a `launch-cs2*.sh` while the game is running.** Bash reads scripts incrementally;
  a mid-run edit shifts byte offsets and corrupts the parse (produces a bogus syntax error).
- **Several wrappers legitimately run Steam at once** (dxmt11 + store wrapper + S734M). Never
  attribute a Steam process by COMMAND LINE: webhelper children always carry Windows-style argv,
  and a steam.exe restarted by its own updater does too — a `pgrep -f "<App>.app.*steam.exe"`
  sweep missed a live logged-in Steam (2026-08-24). Attribute by open files against the PREFIX:
  `lsof -p <pid> | grep -q "<prefix>"`; the launchers' `steam_exe_up`/`steam_family` helpers are
  the reference (prefix, not wine dir — an engine can serve a foreign prefix).
- **Same-account Steams swap ONE online session** ("Session Replaced"); the running game survives
  the swap and takes the session back on its next launch (GOTCHAS 2026-08-24). A store wrapper
  showing NO CONNECTION mid-game is correct behavior, not a bug.
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

## Deliberate deviations from sibling-repo practice

- **`.claude/rules/` in `.prettierignore`** (from meritmap, declined 2026-08-26) — Python / C / shell (20 py, 17 sh, 16 c); no package.json anywhere, so prettier can never run here. The guard exists because a repo `.prettierrc` whose `printWidth` differs from the global source's default 80 makes format-on-commit fight the session-start sync forever (diagnosed in meritmap, where it had run since 2026-08-14). Adopted in bespoke-tr, isnotus and homeOne, which have a JS toolchain that could grow a `.prettierrc`. Here it would configure a tool that will never exist. **Revisit if this repo ever gains a `package.json`.**
