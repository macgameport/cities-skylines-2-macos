# One wrapper per game — give Surviving Mars its own wrapper, end the three-wrapper split

> **Status: Triple-checked 2026-11-07 — build-ready-with-fixes (pass 1, 4 lenses, needs-rework ×2;
> all corrections folded; fitted re-check passed, its 5 fixes folded).** Written 2026-11-07 from the "is this elegant?" review of the same day.
> Commit hashes in this document are from the private pre-publication history (README, History).
> Tracking: none (this repo had no issue tracker when this was written; cs2 #20 and #21 are the neighbours). Builds on the
> Studio first; the MacBook repeats it (Phase E).
>
> **🔧 As-built (2026-11-07, updated 2026-11-08): BUILT on the Studio (Phases A0–A4b, B, D) and on
> the MacBook (Phase E, 2026-11-08: `split-wrapper.sh` went through after the A0 fix `56d4f30`,
> `make-app.sh` built the app, the launcher ran and closed cleanly; render/saves not separately reported);
> C2 run at 30 s and at 15 s (`92445e3`/`8c72c56`, 5/5 each; default cut 45 → 30 → 15 the same day, `5b311f0`); an eighth test file, `tools/test-make-app.sh`,
> came with the launch-time pull (`c932e47`). Exit criterion 6 (the week-later cleanup of
> S734M's SM leftovers, from ~2026-11-14, both Macs) PENDING.**
> Commits — sm-patch: `4e55fca` make-engine `--install` · `c91436f` `tools/split-wrapper.sh` (A0–A4b,
> run 18:02, log `runs/split-wrapper-20261107-180214.log`, backups `backup/one-wrapper-20261107-180214/`) ·
> `7bec509` launcher (B) · `2f84663` measured conflict recipe · `7c2b5de` archive + README (D); cs2 `602472a`.
> Tests: T1 signed in 27 s, no dump · T2 `StateFlags 4`, build 25579348, 0 bytes; mutant red (validate
> re-fetched exactly the renamed `Licenses/Lua.txt`, 704 B → 1076 B) · T3 Archibald renders; mutant
> (`SM_ENGINE`=2.1 BAK) refused, rc 1, nothing started · T4 exit upload ok (change 34), next sign-in
> `current`; recipe measured (cache deleted → all 10 cloud files re-downloaded in 22 s, no conflict) ·
> T5 7 test files pass, 7 mutants red · T6 boot-verify PASS, S734M content_log 0 lines for 3215050 ·
> T7 0 · T8 parity pass · T10/T11 pass with mutants. **U1 measured** (no validate needed after the move),
> **U2 measured** (the clone signs in with no login). U3, U4 unmeasured.
> Deviations: (1) standalone `make-engine.sh` and `engine/` KEPT — cs2's `CLAUDE.md` documents
> `CS2_ENGINE=~/sm-patch/engine/wine-d3dm30` (C82), which the plan missed; (2) `--rebuild` instead of
> `--replace-bak` (the BAK is kept, so the old name misled); (3) A0's cloud gate = last exit upload `ok`,
> not a second sign-in re-derivation; a sync after it no longer refuses outright (Phase E's first run did:
> a cs2 boot-verify had signed the MacBook's S734M in, which pulled change 34 for the still-registered
> game). Then every save must match its SHA-1 in `remotecache.vdf` and none may lack an entry, because a
> run whose exit upload was skipped leaves the same log; checked against both Studio copies (10/10 match)
> and a cloned copy with one save changed and one added (both flagged); 3 refusal cases + 1 pass case +
> `MUTANT=2`, and the committed script fails exactly those; (4) T5 has seven files, not five (install +
> split tests added); (5) not run: T1's and T6's mutants (T6's would start the measured 10 G download in
> S734M); T9/C2 ran at 30 s, not 15 (see C2: 5/5, the game waits for Steam itself, default kept).
> Verify against: `launch-relaunched.sh` · `tools/split-wrapper.sh` · `tools/make-engine.sh` ·
> `tools/test-*.sh` · `~/Applications/SurvivingMars.app` · cs2 `CLAUDE.md` tenant row.

## 0. Verified facts this design rests on (measured 2026-11-07 unless dated)

**The split today.** Surviving Mars (SM) has three homes:

| what | where | size (`du`, nominal — APFS clones over-report, cs2 GOTCHAS "du lies") |
|---|---|---|
| game files (`Project Spark`) | storefront wrapper `~/Applications/CS2dxmt11-pk110.app`, Steam library | 10 G |
| runtime: prefix, Steam sign-in, saves, settings, mods, Paradox login, cloud cache | `~/Applications/S734M.app` (also cs2's fallback CS2, 96 G of its 101 G) | saves 247 M · `AppData/Roaming/Surviving Mars Relaunched` 10 M (PdxMods: 1 entry) · `AppData/Local/PDX` 12 K |
| engine | `~/sm-patch/engine/wine-d3dm30`: APFS clone of S734M's Wine 10 with CrossOver 26.2's D3DMetal 3.0 swapped in (`tools/make-engine.sh`, `SRC` default at line 20) | 952 M nominal, ~0 on disk |

- S734M's Steam sees the game through a **symlink** `steamapps/common/Project Spark` → the store
  wrapper's folder (`readlink` confirmed) plus a **copied manifest** `appmanifest_3215050.acf`
  (`StateFlags 4`, `buildid` = `TargetBuildID` = `25579348`, `AutoUpdateBehavior 1`), made by
  `ensure_registered()` (`launch-relaunched.sh:196`) and torn down by `drop_registration()` (`:106`,
  which moves the manifest to `runs/`) when the files go missing. The store wrapper's own manifest:
  same build, `AutoUpdateBehavior 0`. The store wrapper is the only updater (`STORE_MANIFEST`,
  `:92`). The registration exists because Steam pulls a game's cloud saves at sign-in only when the
  game is installed in that Steam (header `:45-48`, measured on the MacBook 2026-11-02).
- **A manifest over a missing folder makes that Steam re-download the game.** Measured in cs2
  (GOTCHAS "removing the tree while leaving the manifest makes Steam see 'installed, files missing'
  and fetch the lot again") and guarded in this launcher (`:105-112`). Any step that moves the
  game folder must drop every manifest that pointed at it, in the same step.
- `launch-relaunched.sh` names both foreign wrappers: `APP` (`:66`, default S734M) and `GAME`
  (`:68`, hardcoded to the store wrapper). `make-app.sh:11` hardcodes `GAME_EXE` the same way.
  Code lines naming either wrapper (comments excluded): 3.
- Three `userdata/<acct>/3215050/remotecache.vdf` will exist after the clone (store, S734M, new).
  Only the Steam that has the game installed keeps a live one; S734M's is live today (3146 B,
  written this session), the store's is stale (644 B, 2026-11-01). Stale caches must never be
  copied back over a live one.
- S734M's Steam **downloads on its own**: it auto-updated CS2 there, 5.5 GB, during SM sessions
  (cs2 GOTCHAS 2026-11-02, `AutoUpdateBehavior 0` = always keep updated). The launcher runs it
  `-silent` (`:238`). Whether its storefront UI renders is **unmeasured**; purchases stay on the
  cs2 store wrapper (licences are account-level, cs2 `1c07e6c`).
- **One account holds one online Steam session** (cs2 INSTALL.md): a second Steam signing in
  replaces the first's session; the launcher reports it (`:307-308`) and the exit upload is then
  skipped. Today the shared S734M prefix and its lock serialise the two launchers; after the split
  nothing does.
- cs2 precedents: `scripts/make-steam-shortcut.sh` clones a wrapper (`cp -Rc`, `:59`), refuses while
  a Steam holds the donor prefix (`:52-57`), skips the clone when the target already holds a prefix (`:49`; A0's refusal is this plan's own rule, not a precedent), and strips a game
  from the clone as tree + `appmanifest` together (`:66-68`). `scripts/build-engine-1116.sh:197-203`
  swaps an engine in place with a `-BAK` (`mv wine wine.pk11.0-BAK; cp -R engine wine`); the store
  wrapper carries `wine.sikarugir10-BAK` the same way. cs2 `launchers/launch-cs2-dxmt11.sh:246-317`
  is the update check (markers `# >>> update-check` / `# <<< update-check`, `:252`/`:317`;
  `update_pending` `:259-267` reads `StateFlags` and `TargetBuildID`); `scripts/test-update-check.sh:19`
  sources between the markers and hardcodes `appmanifest_949230.acf`, cs2's launcher path and a stub
  `ensure_patches`. That block carries its own one-arg `acf_field` (`:256-258`); ours is two-arg at
  `:190`, a one-liner that `tools/test-signin-sync.sh:13` extracts with `/^acf_field() /p`.
- The lock code (`LOCK`, `lock_holder`, `acquire_lock`, `release_lock`) is identical in three
  launchers across two repos, guarded by `tools/test-launch-lock.sh` (`cmp`-identical to cs2's).
- `tools/d3dmu.c`, `d3dmu.def`, `pe_patch.py` and the `ENGINE_COMPAT=1` branch of `make-engine.sh`
  are the stopped Wine 11 route (cs2 EXPERIMENTS C83). Nothing runs on them.
- Fixed waits: sign-in poll 40 × 3 s (`:240-243`, breaks on sign-in); `sleep 45` after sign-in
  (`:246`, copied from cs2 where it is the "empirically proven margin" for SteamAPI ownership; no
  env knob exists today); two polls of up to 150 × 2 s (`:254`, `:298`, the second breaks at i ≥ 15
  when nothing appears).
- `tools/test-signin-sync.sh:13` evals `signin_outcome`, `acf_field`, `ensure_registered`,
  `drop_registration` out of the launcher and REFUSES (exit **2**) if any is missing.
- **Measured on a scratch pair (2026-11-07):** `mv <real folder> <symlink to it>` fails with
  `Invalid argument` (mv follows the link and tries to move the folder into itself) and changes
  nothing; `rm -rf <symlink>/` with a trailing slash **deletes the target folder's contents and leaves
  the link**. `unlink <symlink>` then `mv` works and leaves the source gone.
- Both wrappers and `~/sm-patch` are on one APFS volume (`/dev/disk3s1`): `cp -Rc` clones and `mv`
  renames. `cp -c` silently falls back to a full copy across volumes.
- `~/Applications/Surviving Mars Relaunched.app` is the double-click shortcut from `make-app.sh`,
  not a wrapper. The new wrapper's name must not collide with it.
- Live right now, so not a build-day state: S734M's prefix holds `.launcher.lock -> 43037` (a live
  SM session) and a 0-byte `Steam/.crash`; the store wrapper's Steam is also up.

## 1. Design

**Source of truth after the build:** exactly one Steam (the new wrapper's) has 3215050 installed,
so exactly one `remotecache.vdf` is live and exactly one Steam updates the game. The store wrapper
keeps the account's visible storefront and nothing of SM. S734M keeps cs2's fallback CS2 and, for a
week, SM's orphaned data as the rollback.

### Phase A — the wrapper (Studio)

**A0 — preconditions, checked by the build script, not by memory.**
1. No Steam, `wineserver`, `Mars.exe` or `Cities2.exe` holds any of the three prefixes (cs2's
   lsof attribution loop, `make-steam-shortcut.sh:52-57` pattern); no `.launcher.lock` in S734M.
2. The store wrapper's `appmanifest_3215050.acf` reads `StateFlags 4`; the last SM exit's
   `cloud_outcome` was `ok` and the last sign-in's `signin_outcome` was `current` (so "the cloud
   holds the latest change" is true, §4). Record `buildid` now — T2 reads it after the manifest moves.
3. `~/Applications/SurvivingMars.app` does not exist (refuse otherwise).
4. Backups, into gitignored `backup/one-wrapper-<date>/` (manifests carry `LastOwner`, a SteamID64;
   never under `docs/`): both `appmanifest_3215050.acf` (store, S734M), a tarball of S734M's
   `Saved Games/Surviving Mars Relaunched/`, and S734M's `userdata/<acct>/3215050/`.
5. Every destructive command in the script is guarded: `[ "$CLONE" != "$DONOR" ]` and
   `case "$(realpath "$target")" in "$CLONE"/*) ;; *) die ;; esac`. Deleting through a symlink is
   forbidden by construction: links are removed with `unlink`, never `rm -r`.

**A1 — clone.** `cp -Rc ~/Applications/S734M.app ~/Applications/SurvivingMars.app` (seconds).
Assert `stat -f %d` equal for source and clone (same volume; `-c` fell back to a copy otherwise).
Then `rm -f <clone>/prefix/.launcher.lock` and `<clone>/prefix/drive_c/Program Files (x86)/Steam/.crash`.
The clone carries the Steam sign-in, the live `remotecache.vdf`, saves, settings, mods and the
Paradox login with no data movement.

**A2 — strip CS2 from the clone.** Under the clone's `steamapps/` only (realpath-guarded):
`rm -rf common/Cities Skylines II`, `rm -f appmanifest_949230.acf`, `rm -rf shadercache/949230`, and
under the clone's Steam `rm -rf userdata/<acct>/949230` (16 K). Keep `appmanifest_228980.acf`
(Steamworks redistributables). Leave `libraryfolders.vdf` (lists 949230; Steam rewrites it, as
cs2's pattern leaves it). The clone's `common/Project Spark` is
still a symlink to the store folder at this point. Expected nominal size ≈ 5 G.

**A3 — D3DMetal 3.0 in place.** `tools/make-engine.sh --install ~/Applications/SurvivingMars.app`:
builds from the target's own `wine/` (so `SRC` = `<target>/Contents/SharedSupport/wine`; the
existing source gates at `:28-30` and `:39-48` still run), then `mv wine wine.d3dm21-BAK` and copies
the engine in (`build-engine-1116.sh:197-203` pattern). Refuses: no explicit path; a target whose
prefix holds `Cities2.exe` (that is S734M or a cs2 wrapper); a Steam running in the target; an
existing `wine.d3dm21-BAK` unless `--replace-bak`. **On a re-run** (CrossOver updated, say) `SRC` is
the `-BAK` (the 2.1 original), never the installed 3.0 `wine/` — building from the latter would
clone the engine onto itself; the BAK is kept, the current `wine/` replaced (cs2 `:197-204`
pattern). Checks `wine64 --version` and the installed D3DMetal version (`ver()` logic, `:55-56`) in
the result. Standalone mode (`make-engine.sh [out-dir]`) and `~/sm-patch/engine/` are then dead:
remove the `engine/` lines from `.gitignore` and `README.md`, delete the directory, keep
`SM_ENGINE` as an override only. Runs before A4 so T1/T2 run on the final
engine and the originals are still untouched.

**A4 — the game folder, then every manifest that pointed at it, in one step.**
1. Store wrapper's Steam down (A0). `unlink "<clone>/.../common/Project Spark"` (the symlink).
2. `mv "<store>/.../common/Project Spark" "<clone>/.../common/Project Spark"`.
3. Assert `[ -f "<clone>/.../Project Spark/Mars.exe" ] && [ ! -e "<store>/.../Project Spark" ]`.
4. `mv "<store>/.../appmanifest_3215050.acf" ~/sm-patch/runs/appmanifest_3215050.acf.store`
   (moved aside, the project's convention, so its `AutoUpdateBehavior 0` and other fields survive
   for rollback).
5. **A4b — drop S734M's registration** (the BLOCKER both lenses found): with S734M's Steam down,
   `unlink "<S734M>/.../common/Project Spark"` and `mv "<S734M>/.../appmanifest_3215050.acf"
   ~/sm-patch/runs/appmanifest_3215050.acf.s734m`. This is `drop_registration` (`:107-109`) run once
   by hand, before Phase B deletes it. Without it, the first cs2 fallback launch (T6) starts a 10 G
   SM download into S734M.
6. The clone's manifest keeps `AutoUpdateBehavior 1`; the launcher's update check (Phase B) is the
   sole updater (§2). Then start the clone's Steam once and read `StateFlags`: if `4`, done (Steam
   already treated link + manifest as installed); only if not, `steam://validate/3215050` (T2).

### Phase B — the launcher

- Defaults: `APP` → `SurvivingMars.app`; `GAME` → `$SS/prefix/drive_c/Program Files (x86)/Steam/
  steamapps/common/Project Spark` — from `$SS` (`:67`), **not** `$WINEPREFIX`, which is exported only at
  `:72`: the launcher runs under `set -u` (`:65`), so a `$WINEPREFIX` at `:68` dies "unbound variable"
  (builder-sim measured it). `tools/test-game-running.sh` then evals `^(APP|SS|GAME)=` lines, not
  `^GAME=` alone, or it dies the same way (its mutant going red for the wrong reason). `ENGINE` → `$SS/wine`. After the engine is resolved, **check the
  installed D3DMetal version and die below 3.0** ("this wrapper's Wine is still on D3DMetal 2.1 —
  run tools/make-engine.sh --install"), so a skipped or rolled-back A3 is loud, not a black map.
- Delete: `ensure_registered`, `drop_registration`, `STORE_MANIFEST`, `LINK`, the
  `case "$(ensure_registered)"` block (`:228`), the Mars.exe-missing branch that calls
  `drop_registration` (`:112`, its message becomes the install path below), and our one-liner
  `acf_field` (`:190`) — cs2's block brings its own.
- Keep: the lock, `game_running`, `cloud_outcome`, `signin_outcome` (the sign-in sync wait still
  matters: the game is installed here, so Steam pulls at sign-in), `stop_steam`, frame-fix,
  `SM_STEAM_ENGINE` (default = `ENGINE`). Add `stop_steam` before the sign-in-failure `die` (`:244`):
  today a failed sign-in leaves Steam running and the next launch "reuses" it.
- `sleep 45` → `sleep "${SM_LICENCE_WAIT:-45}"` (the knob C2 needs; default unchanged).
- Copy cs2's update check (`launch-cs2-dxmt11.sh:246-317`) between the same markers, with these
  edits, each named here so the copy is reviewable: app id `949230` → `3215050`; `CS2_UPDATE*` env
  → `SM_UPDATE*`; the osascript title → "Surviving Mars: Relaunched"; the `ensure_patches` call
  removed (SM has no patches); `"$WINE" "$STEAM" steam://validate/…` → `"$STEAM_WINE"`; `MANIFEST`
  (`:91`) stays. Copy `scripts/test-update-check.sh` as `tools/test-update-check.sh` with its
  fixture name, launcher path, both `WINE=` subshell lines (→ `STEAM_WINE=`), the `ENSURE_PATCHES`
  expectations and its § 13 cs2 paths adjusted — and **add a `MUTANT=1` mode** (`update_pending() {
  return 1; }`, which must turn its pending/apply cases red): cs2's copy has none, so T5's "all
  mutants exit 1" would otherwise be false for it.
- Header rewrite, the whole top not one paragraph: `:5-14` (prefix = S734M, engine in `engine/`,
  "game files stay where the storefront wrapper's Steam installed them; update them by opening CS2
  Steam Store"), `:23-24` (S734M's AppData), `:58-60` (unregistered behaviour), `:84` ("S734M: Steam
  runs fine on D3DMetal"); "install the game through that Mac's storefront wrapper" (`:27-29`) → the
  install path below; the `:104` die ("Build it: bash ~/sm-patch/tools/make-engine.sh") → `--install
  <wrapper>`; the conflict-clearing recipe (`:38-44`), which
  depends on the store Steam having the game, → the new recipe (§2); the pull-before-play
  paragraph (`:45-55`) → one line. The two messages that send the user to the store wrapper
  (`:264` die, `:305` warning) → the new recipe. Lock comment `:126-133` no longer says the prefix
  is shared with cs2 (it is not, after A4b; the lock stays for self-serialisation).
- Install / reinstall path: `"$STEAM_WINE" "$STEAM" steam://install/3215050` forwarded to the
  `-silent` Steam (cs2's `steam://validate` forwarding is the precedent). **Unmeasured**; the `:112`
  message names it and says so.
- `make-app.sh`: `GAME_EXE` from the new wrapper, **and re-run it**: the shim at
  `~/Applications/Surviving Mars Relaunched.app/Contents/MacOS/launch` bakes the old path, and
  `tools/test-game-running.sh` reads that shim (two of its cases fail against a stale one).
  Scope: the builder-sim's scratch pass was ~170 diff lines in `launch-relaunched.sh`, most of it the
  header; expect that, not a 45-line patch. `tools/test-signin-sync.sh`: drop the
  `ensure_registered`/`drop_registration` evals and cases, and `acf_field` from its eval and
  `for f in` list (`:13-14`; unused there once the registration cases go); header `:2-6` rewritten.
  `tools/test-launch-lock.sh:5-6` and cs2's copy: "shared by cs2 and sm" → no longer; keep the
  parity check.
- MacBook bridge: until its Phase A, `SM_WRAPPER=~/Applications/S734M.app` still works there
  through the symlink, because `GAME` now derives from `$SS`, i.e. from whatever `SM_WRAPPER` selects.

### Phase C — measure before shrinking (optional, each its own commit)

- **C1 (overlay instead of clone): DECLINED.** An env-var overlay moves engine identity out of
  the wrapper into the launcher; anything that runs the wrapper without the launcher (a store
  shortcut, a boot-verify-style test, Steam's own UI) silently gets 2.1 and the black map. After A3
  the "unmodified Wine" exists only as `wine.d3dm21-BAK` (`SM_ENGINE` can point at it). Recorded as
  declined; no probe.
- **C2 (the 45 s):** five launches with `SM_LICENCE_WAIT=15`; pass = five menus with no
  `SteamAPI`/`Platform` error in the game log. Keep 45 if any run fails. Never shorten blind.
  **Run 2026-11-08 (Studio, `tools/licence-wait-probe.sh`): 30 s 5/5 PASS, then 15 s 5/5 PASS —
  Steam initialised and both DLCs owned in all ten. Menu at sign-in + 39 s (15 s wait), + 54 s
  (30 s), + 57 s (45 s; + 68 s when it stalls). Default cut to 15. All ten runs showed a fixed
  13.5 s stall before `Account storage loaded` that 7 of the 23 earlier 45 s runs also have; its
  cause is not identified, and the first reading of the 30 s runs ("the game waits until sign-in
  + 48 s") was wrong — the 15 s runs stall the same 13.5 s and finish at + 33 s.**
- **C3 (the polls):** leave; they bound a hang, the fixed cost is the licence wait.

### Phase D — tidy

- `tools/d3dmu.*`, `tools/pe_patch.py`, the `ENGINE_COMPAT` branch → `tools/archive/wine11/` with
  a 5-line README pointing at cs2 C83. `make-engine.sh` keeps only the refusal; its header `:13`
  and `:16` (S734M untouched; rebuild when S734M's Wine changes) → the wrapper's own Wine.
- Lock code: **decision** — keep three copies + the parity test (two repos cannot source one file
  without a third place to put it).
- `README.md` § *What it assumes* rewritten for one wrapper, naming the wrapper (`SurvivingMars.app`)
  and the shortcut (`Surviving Mars Relaunched.app`) apart, and stating: one Steam on this account
  at a time, across wrappers — the lock no longer enforces it.
- cs2 `CLAUDE.md:23` (the "other tenant" row): SM is in `SurvivingMars.app`, not the storefront
  library + S734M. cs2 `GOTCHAS.md`'s pull-before-play paragraph (2026-11-02 entry, "the launcher
  registers the game") gets a dated superseded note, evidence kept. The copied update-check block's
  cs2 prose ("1.6.0f1 -> 1.6.2f1 was 5.1 GB", the mods message) is stripped.

### Phase E — the MacBook

Same A0–A4b and B on the MacBook (it has the same three wrappers and the same S734M
registration, so A4b applies there too). Its S734M clone brings its own cloud cache; the first
launch there pulls the Studio's latest change. Order: Studio first, play once, exit (upload
verified `ok`), then the MacBook, which needs CrossOver 26 for `--install` and its own `make-app.sh`
re-run. The build script, not the operator, carries A0 and the guards.

## 2. Out of scope / recorded decisions

- **S734M is written, twice, by A4b** (unlink + manifest moved aside) and not otherwise. Its SM
  data (saves, settings, userdata) stays a week as the rollback. The store wrapper loses the game
  folder by A4's move (that *is* the point); rollback is `mv` back.
- **Updater: `AutoUpdateBehavior 1` + the launcher's update check**, not `0`. Measured: a
  long-running Steam with `0` updates a non-running game in the same prefix (cs2 GOTCHAS
  2026-11-02); `steam://validate` runs an update regardless of the flag (cs2 GOTCHAS 2026-10-10).
  **Unmeasured (U3):** whether Steam sets `StateFlags 6` / `TargetBuildID` under `1`; cs2 #17 was
  measured under `0`. The next real SM patch is that test, as cs2 says of its own check.
  cs2's check has modes `ask|apply|skip` (`launch-cs2-dxmt11.sh:21`), default `ask`: a dialog, and
  after 120 s unanswered it launches the installed build. **`SM_UPDATE` keeps that default.** It is
  not "silently stale": the dialog recurs on every launch until the update is applied, and with
  `AutoUpdateBehavior 1` the launcher's `steam://validate` is the only updater, so nothing downloads
  mid-game. `check_game_update` runs after the cloud sign-in-sync wait and before `steam_appid.txt`
  is written: the cloud verdict first, since an apply can take up to an hour.
- **Conflict recipe after the split:** back up, delete the conflicting local files and
  `userdata/<acct>/3215050/remotecache.vdf` in the new wrapper, sign in → Steam pulls (T4's mutant
  measures exactly this and writes the recipe). The alternative, `steam://rungameid/3215050` for
  Steam's own keep-local/cloud dialog, needs the UI (unmeasured).
- **Not** unifying with the daily CS2 prefix: blocked (C83). **Not** touching cs2's fallback CS2.
- Build-day rule: **one Steam at a time on the account.** The sequence T1 → T2 → T3 → T4 runs the
  new wrapper's Steam alone; T6 (S734M) runs after T4's exit upload is `ok` and the new wrapper's
  Steam is down. A "Session Replaced" during T4 voids T4, it does not fail it.
- The clone's `steamapps/libraryfolders.vdf` and `userdata/<acct>/config/localconfig.vdf` still
  list 949230; Steam rewrites them at first boot. T1 expects the rewrite.
- Purchases and DLC browsing stay on the cs2 store wrapper.

## 3. Test plan

| # | test | pass | mutant (must go red) |
|---|---|---|---|
| T1 | clone boots: `wine64 steam.exe -silent`, fresh `LogOnResponse 'OK'` in `connection_log.txt`, no new dump, `libraryfolders.vdf` rewritten without 949230 | signed in ≤ 90 s, no re-login prompt (U2 measured here) | clone with `config/loginusers.vdf` removed → no sign-in |
| T2 | manifest reconciled: `StateFlags 4` and `buildid` = the value recorded in A0; `content_log` shows no 3215050 download (U1 measured here) | 0 bytes downloaded | rename one small game file before `steam://validate/3215050` → validate re-fetches exactly that file (`content_log`), buildid unchanged → restore |
| T3 | launcher end-to-end on the new wrapper: menu, load Archibald, Ramp overlay renders (screencapture of CGWindowID, `game-input.exe click`) | map visible | `SM_ENGINE` → `wine.d3dm21-BAK` → black map; and launcher without `SM_ENGINE` after `mv wine.d3dm21-BAK wine` → dies with the D3DMetal-version message, no launch |
| T4 | cloud both ways: exit → `cloud_log` "Upload complete, result OK", ChangeNumber +1; next launch → `signin_outcome` `current`/`pulled` | both verdicts, no Session Replaced | `remotecache.vdf` removed → sign-in re-pulls (record the exact log lines; they become the §2 recipe) |
| T5 | `tools/test-*.sh` (now five, with `test-update-check.sh`) all exit 0; `MUTANT=1` all exit 1, after the registration functions are gone | 5/5 and 5/5 | `test-signin-sync.sh` left unchanged → `REFUSED: ensure_registered not found in the launcher`, exit **2** |
| T6 | cs2 fallback: `CS2_WRAPPER=~/Applications/S734M.app CS2_LAUNCHER=~/cs2-patch/launch-cs2.sh bash scripts/boot-verify.sh`; S734M has no `appmanifest_3215050.acf`; S734M `content_log.txt` shows no 3215050 lines after the run | VERDICT: PASS + both asserts | A4b skipped (manifest left) → `content_log` shows a 3215050 download start (stop Steam with `-shutdown` at once; restore from `runs/`) |
| T7 | no foreign wrapper in code or messages: `grep -v '^[[:space:]]*#' launch-relaunched.sh make-app.sh \| grep -c 'CS2dxmt11-pk110\|S734M\|CS2 Steam Store'` (the die at `:112` and the note at `:229` name the store shortcut) | 0 (today: 5) | — |
| T8 | lock parity: cs2 `scripts/test-launch-lock.sh` | 0 failures | one copy edited → parity FAIL |
| T9 (C2) | 5 launches at `SM_LICENCE_WAIT=15` — **run 2026-11-08 at 30 s and at 15 s: 5/5 PASS each, default cut to 15 (C2)** | 5/5 clean menus | — (a failure is the result) |
| T10 | `make-engine.sh --install` refusals: no path; a wrapper whose prefix holds `Cities2.exe`; a running Steam; an existing `-BAK` | each refused, nothing written | guard removed → it proceeds on a scratch wrapper holding a fake `Cities2.exe` |
| T11 | A0 preconditions: run the build script with S734M's Steam up | refuses before any write | — |

Mutants are applied to real files and observed red, then restored ("argued red" is not red).
Stuck-update recovery, if T2's validate ever leaves `StateFlags ≠ 4`: restore the manifest from
`backup/`, delete `steamapps/downloading/3215050`, start Steam, re-read.

## 4. Rollback

- A1–A3 touch only the clone: rollback = delete `SurvivingMars.app`.
- A3 (engine): `mv wine wine.d3dm30 && mv wine.d3dm21-BAK wine` in the new wrapper.
- A4: `unlink` the clone's (now real) folder is NOT the step — `mv` the folder back to the store
  wrapper, `mv runs/appmanifest_3215050.acf.store` back (its `AutoUpdateBehavior 0` intact).
- A4b: `mv runs/appmanifest_3215050.acf.s734m` back and re-create the symlink — or run the old
  launcher once; its `ensure_registered` (`:196-214`) does both, once the folder is back in the store.
- Phase B: `git revert`; the old launcher works against S734M once A4/A4b are rolled back.
- Saves: the cloud holds the latest change (A0 §2 guarantees it at the start); S734M's leftovers
  hold the local copy for a week; `backup/` holds the tarball.
- Exit criterion 6 names its deletions now, with the same guards: under `<S734M>/.../users/Wineskin/`
  only `Saved Games/Surviving Mars Relaunched`, `AppData/Roaming/Surviving Mars Relaunched`,
  `AppData/Local/PDX/SDK/surviving_mars_relaunched`; under its Steam only `userdata/<acct>/3215050`
  and `shadercache/3215050`. Never `common/Cities Skylines II`, never `appmanifest_949230.acf`.

## 5. Exit criteria

1. SM launches from `SurvivingMars.app` to a rendered Archibald with the Ramp overlay (T3), on the
   Studio and the MacBook.
2. Cloud sync works both ways from the new wrapper (T4), including one Studio → MacBook handoff.
3. `launch-relaunched.sh` and `make-app.sh` name no other wrapper in code (T7); registration code
   is gone; all launcher tests and their mutants pass (T5, T8, T10, T11).
4. cs2's fallback still boot-verifies on S734M with no SM manifest and no SM download (T6).
5. `README.md` describes the one-wrapper setup; `make-engine.sh --install` is the one engine
   mechanism (C1 declined); cs2 `CLAUDE.md:23` updated.
6. After one week of play: the §4 leftovers in S734M deleted, the store wrapper confirmed free of
   3215050, sizes recorded by measured delta (`df` before/after, not `du`).

## Review corrections (triple-check 2026-11-07)

Pass 1 (architecture · security + blast-radius · correctness + platform-facts · builder-simulation).
Verdicts: build-ready-with-fixes · needs-rework · build-ready-with-fixes · needs-rework. Folded,
with the judgment calls named:

- **B1 (both architecture and security):** the original A3 left S734M with a manifest over a
  dangling symlink — the measured 10 G re-download. Now A4b, and §2/§4 say S734M is written twice.
- **B2 (security), measured on a scratch pair before folding:** `mv` onto the symlink fails
  harmlessly; `rm -rf link/` deletes the game. Now the A4 sequence and the A0 guards.
- **S1 / A1 preconditions (security, architecture):** A0, with backups into `backup/`.
- **Updater "or" (architecture):** decided for `AutoUpdateBehavior 1` + the launcher check; U3 recorded.
- **C1 (architecture):** declined, reasons in Phase C.
- **A4 before A3 (architecture):** adopted; phases renumbered (engine = A3, move = A4).
- **Store manifest delete → move aside; record `buildid` in A0 (architecture).**
- **`acf_field` collision + `test-signin-sync.sh` (architecture):** folded into Phase B.
- **Five hidden edits in the copied update check (correctness):** named in Phase B.
- **`SM_LICENCE_WAIT` did not exist (correctness):** Phase B adds it.
- **Header paragraphs `:27-29` and `:38-44`, messages `:264`/`:305` (correctness, security S3):**
  Phase B; the recipe is decided in §2 and measured by T4's mutant.
- **cs2 `CLAUDE.md:23` (correctness):** Phase D.
- **T2's mutant was a data path (security S2):** replaced with the one-file rename.
- **`--install` could land on S734M (security S4) / `ENGINE` default falls silently to 2.1
  (architecture):** refusals in A3 (T10) and the version check in Phase B (T3's second mutant).
- **One Steam at a time; lock no longer serialises the account (security M1, architecture):** §2
  build-day rule and the README line in Phase D.
- **M2 failed sign-in leaves Steam up (security):** `stop_steam` before the die, Phase B.
- **Clone sanity: same device, target exists, inherited lock/.crash (security M3/M4):** A0/A1.
- **Minor corrections:** engine 952 M; `build-engine-1116.sh:197-203` cited by line; T5's REFUSED
  exit is 2; the 40 × 3 s sign-in poll listed; T7 counts code lines; name collision with the
  shortcut recorded; doc-rot list in Phases B and D; `libraryfolders.vdf` rewrite expected in T1;
  MacBook bridge named; exit criterion 6 names paths and uses measured deltas.
- **Builder-simulation (landed after the first fold, folded in the same session):** `GAME` from
  `$WINEPREFIX` at `:68` dies under `set -u` → built from `$SS` (Phase B, T5); `test-game-running.sh`
  eval and the `make-app.sh` re-run (Phase B); T7 extended to "CS2 Steam Store"; `SM_UPDATE`
  default and `check_game_update` placement decided (§2); the copied test gets a MUTANT mode so T5's
  arithmetic holds; `--install` re-run semantics and the retirement of `engine/` (A3); strip list +
  `userdata/<acct>/949230` (A2); header line list `:5-14`, `:23-24`, `:58-60`, `:84`, `:104`
  (Phase B); cs2 GOTCHAS superseded note and copied-block prose (Phase D); CrossOver 26 on the
  MacBook (Phase E); its quiescence-gate blocker was already A0.
- **Rejected:** none. **Unmeasured, kept visible:** U1 (validate over a moved folder — T2), U2
  (clone signs in without a new login — T1), U3 (`AutoUpdateBehavior 1` surfaces a pending update —
  the next SM patch), U4 (the `steam://install/3215050` path Phase B ships in the `:112` message:
  probe = forward it once with the game already installed and read `content_log`, expecting no
  download and no error; the first real reinstall is the full test), the storefront UI on this engine
  (no probe; nothing ships on it).

## Review log

| date | pass | lenses | method | model | verified-against | verdict |
|---|---|---|---|---|---|---|
| 2026-11-07 | 1 (full) | architecture · security + blast-radius · correctness + platform-facts · builder-simulation | 4 read-only agents, one batch; B2 measured inline on a scratch pair; corrections folded same session | Fable 5.1 | sm-patch `1cb313f` · cs2 `906b7a4` | needs-rework ×2 → all four folded |
| 2026-11-07 | fitted re-check | fold verification: every correction's normative home · new cites · `$SS`/`set -u` and `unlink`+`mv` re-measured in scratch · T7 count · renumbering · stale phrases | 1 read-only agent | Fable 5.1 | sm-patch `44314ed` · cs2 `906b7a4` | build-ready-with-fixes (1 fold defect + 3 cites + U4 folded) |

Key paths: `launch-relaunched.sh` · `make-app.sh` · `tools/make-engine.sh` · `tools/test-signin-sync.sh` ·
`tools/test-launch-lock.sh` · cs2 `scripts/make-steam-shortcut.sh` · cs2 `scripts/build-engine-1116.sh` ·
cs2 `launchers/launch-cs2-dxmt11.sh` § 2b + `scripts/test-update-check.sh` · cs2 `CLAUDE.md:23` ·
`~/Applications/S734M.app` and `CS2dxmt11-pk110.app` layouts.
