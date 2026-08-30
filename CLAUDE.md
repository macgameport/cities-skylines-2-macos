# Claude Instructions — cs2 (macOS CS2 port notes)

Personal/throwaway-tier project: **no issue tracker, no phases, no SPEC.md.** Skip the
issues-per-item ritual. Durable record = this repo + `~/cs2-patch/change-ledger.txt`.

## Where things live

| What | Path |
|---|---|
| Patch scripts + ledger | `~/cs2-patch/` (**outside this repo**, deliberately) |
| Canonical launcher (**default**) | `~/cs2-patch/launch-cs2-dxmt11.sh` — Wine 11 + DXMT. Repo copies are thin wrappers (macOS TCC blocks app bundles from executing scripts in `~/Documents`) |
| Canonical launcher (fallback) | `~/cs2-patch/launch-cs2.sh` — Wine 10 + D3DMetal |
| Display-profile helper | `~/cs2-patch/cs2-display-profile.sh` — the dxmt11 launcher runs it pre-boot: retina + DRS per *main* display (mobile = retina on + DRS 0.5 CAS · home/external = retina off, native 1:1). `CS2_PROFILE=off\|home\|mobile`, `DRY=1` preview. Repo original: `scripts/`; design: `docs/plans/launcher-display-profiles.md` |
| Apply all patches | `bash ~/cs2-patch/repatch.sh dxmt11` (10 patches) · `… free` (17, Wine 10) · no arg = the dead CrossOver bottle |
| Badge patch (**`Game.dll`, outside repatch.sh**) | `~/cs2-patch/patch-modconflict-badge.py` — kills the per-boot mod keybind ⚠ badges; the dxmt11 launcher re-ensures it pre-boot (step 0b, fail-open), so a game update self-heals. Run via `~/cs2-patch/revenv/bin/python3`; no args = verify, `apply` = patch (refuses unless the game is down). Repo original: `scripts/`; mechanism + the IL rules it earned: `GOTCHAS.md` |
| Shortcut | `~/Applications/Cities Skylines II.app` → runs the **dxmt11** launcher with `CS2_QUIET=1`. Revert = one `SCRIPT=` line in `Contents/MacOS/launch` |
| Store shortcut | `~/Applications/CS2 Steam Store.app` → opens Steam **visibly** in the storefront wrapper (`CS2dxmt11-pk110.app`, wine 11.0 — the 11.16 engine black-screens Steam's UI). Built by `scripts/make-steam-shortcut.sh` (also creates the wrapper by APFS clone if absent) |
| Game prefix (default) | `~/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix` |
| Game prefix (fallback) | `~/Applications/S734M.app/Contents/SharedSupport/prefix` |
| Game logs | `<prefix>/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/` (the other user dirs in the prefix are symlinks to `Wineskin`) |
| Agent brief | `docs/agent-brief.md` — hand to every subagent; they inherit no auto-loaded memory |
| Experiment ledger | `EXPERIMENTS.md` — conclusions register + run index. Read the register at `wake up`; `python3 scripts/check-experiments.py` at `button up` |
| Evidence store | `~/cs2-patch/evidence/<cell>/` (**outside this repo** — window PNGs carry the persona name). `/tmp/steam-cell-*` is volatile; `scripts/salvage-cells.sh` moves + sanitises |
| RE toolchain | `~/cs2-patch/revenv` (dnfile + capstone + pefile) |
| Disassemble | `~/cs2-patch/revenv/bin/python3 ~/cs2-patch/dis_pdx.py <dll> <Type> <Method>` |

## Rules specific to this project

- **Never edit a `launch-cs2*.sh` (or `cs2-display-profile.sh`) while the game is running.** Bash
  reads scripts incrementally; a mid-run edit shifts byte offsets and corrupts the parse
  (produces a bogus syntax error).
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

## GitHub identity — this project is deliberately separated (2026-08-30)

`macgameport` is an **organization**; `iosoceans` and `jvspearman` are both owners, and **both
memberships are private** (the org's public member list is empty), so nothing publicly links them.
The separation is forward-looking only — the 169 existing commits keep their `macgameport`
authorship on purpose, and the already-posted dxmt#141 comments stay under `jvspearman`.

| layer | mechanism | effect |
|---|---|---|
| git commits | `includeIf gitdir:~/Documents/github/cs2/` → `~/.gitconfig-cs2` | this project commits as `iosoceans <iosoceans@pm.me>`; everything else stays `jvspearman`. Survives a fresh clone. |
| `gh` CLI | separate config dir `~/.config/gh-cs2` | keeps `~/.config/gh` (jvspearman) untouched |
| git push/fetch | `credential.https://github.com.helper` in `~/.gitconfig-cs2` → `gh auth git-credential` with the project config dir | **pushes** as `iosoceans` too, not just commit authorship. Without it git uses the default keychain credential and pushes to this PUBLIC repo appear in the personal account's activity feed. Other repos keep `osxkeychain`. |
| interactive shell | `gh()` wrapper in `~/.zshrc` | any `gh` run from inside the project tree uses the project config dir automatically |

⚠ **Agents: the zsh wrapper does NOT apply to you.** Claude's Bash tool runs **bash** and does not
source `~/.zshrc`, so `gh` from a tool call will use the DEFAULT config — i.e. **post as
`jvspearman`**. When running `gh` for this project, set it explicitly:

```bash
GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh issue comment ...
```

⚠ **Before posting anything publicly, verify who you are**: `GH_CONFIG_DIR="$HOME/.config/gh-cs2"
gh auth status`. The four dxmt#141 comments went out as `jvspearman` because nothing enforced this
at the time.

⚠ `iosoceans@pm.me` is written into every future commit and is **publicly visible** in this public
repo — a deliberate choice (project address, not a personal one). The private alternative is
`322706496+iosoceans@users.noreply.github.com`. For GitHub to attribute commits to the account, the
address must be **verified** on it.

## Experiments — read the ledger before designing a test (2026-08-30)

**`EXPERIMENTS.md` is the standing record of what we have tested and how much to trust it.**
`GOTCHAS.md` holds *patterns*; the ledger holds *runs, their config, and the claims resting on
them*. They are different jobs — do not merge them.

- **`wake up`** — read the ledger's **Conclusions register** (the `C<n>` table). Not the whole
  file, and never `GOTCHAS.md` whole. It is the index of what is already settled, `PARTIAL`,
  `UNREVIEWED`, or `RETRACTED`, so a session does not re-run a finished experiment or build on a
  withdrawn one.
- **`button up`** — run `python3 scripts/check-experiments.py`. It exits non-zero on drift and is
  the freshness gate: unrecorded cells, evaporated evidence, stale counts, and any
  `SUPPORTED`/`PARTIAL` claim resting on a run the evidence marks VOID.
- **Spawning a subagent?** Point it at **`docs/agent-brief.md`** first — one screen carrying the
  evidence rules, the process-attribution and `kill -9` traps, the exit-code trap, the privacy
  rules and the `GH_CONFIG_DIR` requirement. A subagent inherits none of this file, so without the
  brief it re-derives the project by grep and re-raises settled findings.
- **Every render cell runs `scripts/cell-fingerprint.sh --strict` first.** It records the config
  beside the result and refuses the run on a precondition that would void it. A cell without a
  `config.json` is `UNREVIEWED`, not a result.
- **Three columns, never fused: Config · Measured · Inferred.** When a premise falls, retract the
  *inference* and keep the *measurement*. Fusing them into prose is what cost a week.

**Why (the incident):** on 2026-08-30 an audit found **41 of 43** render cells had run with no font
library — wine could not resolve `libfreetype.dylib`, printed one line, and continued with no font
backend, which renders art and no glyphs. A week had gone into eliminating fonts, rasterisation,
texture formats, occlusion and compositing. Two more confounds sat in the same runs: the shim was
installed in a `cef` dir Steam does not use (so `--shim-args` silently never applied), and the
harness's `ps`/window capture were not prefix-filtered, so another wrapper's Steam could supply a
**false PASS**. None were detectable afterwards, because nothing recorded the config a result was
measured under.

## Personal info

Repo is intended to be publishable. Keep Steam IDs, `[U:1:<n>]` account ids, real usernames and
absolute `/Users/<name>` paths **out of committed files** — use `$HOME`, `$WINEUSER`, `<REDACTED>`.

**Test artifacts (audited 2026-08-30 — full table in `EXPERIMENTS.md` § Privacy):**

- `stdout.txt` / `windows.txt` — verified clean (only `C:\` / `Z:\` wine-internal paths). Quotable.
- `win-*.png` — Steam client windows carry the **persona name twice** (top-right, and as a nav
  item) plus the avatar. Evidence store only, **never committed unmasked**.
- `known-good.png` — a capture of whatever browser/terminal window was frontmost. **Not retained**;
  only its byte size is. It is the largest accidental-disclosure surface in the harness and its
  only datum is "the capture worked". `scripts/salvage-cells.sh` drops it automatically.
- Evidence lives in **`~/cs2-patch/evidence/`**, outside the repo, same reasoning as
  `change-ledger.txt`. `/tmp` is volatile — salvage before a reboot eats the week's evidence.
- **Cheapest durable fix:** the Steam persona name is a *label*, freely editable. Set it to
  something generic while doing capture work and new captures are clean at source. A mask you got
  wrong is worse than no mask, because it looks safe.

## Deliberate deviations from sibling-repo practice

- **`.claude/rules/` in `.prettierignore`** (from meritmap, declined 2026-08-26) — Python / C / shell (20 py, 17 sh, 16 c); no package.json anywhere, so prettier can never run here. The guard exists because a repo `.prettierrc` whose `printWidth` differs from the global source's default 80 makes format-on-commit fight the session-start sync forever (diagnosed in meritmap, where it had run since 2026-08-14). Adopted in bespoke-tr, isnotus and homeOne, which have a JS toolchain that could grow a `.prettierrc`. Here it would configure a tool that will never exist. **Revisit if this repo ever gains a `package.json`.**
