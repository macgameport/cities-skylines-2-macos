# One installer for every game: the shared core, and what is published keyed by Steam app ID

> **Status:** Triple-checked 2026-11-11 — build-ready-with-fixes. Sections 1.1 and 2.1, steps S1 and S2 and
> tests ST1 to ST4 were checked as part of `docs/plans/surviving-mars-install.md` (its passes 1 and 1b), from
> which they were moved on 2026-11-11. What is new here (1.2, 2.2, 2.3, S3, ST5, ST6, SL1, the exit
> criteria) and the split itself were checked the same day by a fitted check: two blockers, folded
> (Review, below). Written 2026-11-11.
>
> **Since (2026-11-13):** the core's exit handler calls a game's `game_cleanup` when the game's file
> defines one, last, after the lock is released and the closing line printed (the Surviving Mars plan's
> 2.2 and M6, on the branch `surviving-mars-install`). Cities: Skylines II defines none, and its
> `test-install.sh` passes unchanged.
>
> **🔧 As-built (2026-11-11):** BUILT: S1 to S4 are done on `simple-install`, and SL1 passed; SL2, the
> installer plan's NL2, ran on 2026-11-12 and met its pass condition, with one finding (that plan's header;
> SF6 and SF7 in section 9 here). S1 is `00108f7`, with `7b102a1`
> for a defect in it found the same evening; S2 is `1df6f27`; S3 is `2577207`. **SL1 passed 2026-11-11**
> (evidence `~/cs2-patch/evidence/shared-installer-SL1-20261111/`, `summary.txt`; ledger row `exp_8f0511`),
> on `c6cbd2d`. Run 1 made the scratch wrapper from the public downloads and installed Steam, then stopped
> at step 5 with exit 1: Steam's own update failed on five starts, because the server it comes from cut
> every transfer from the Studio after 5.4 s (measured with `curl`, six of six; the route was a VPN
> tunnel). With the route changed, run 2 found the wrapper and Steam, went on at step 5, and showed the
> sign-in window after 64 s. James signed in; the game was cloned in (1 s, no disk); the installer saw it
> within one poll, closed Steam in order and exited 0. `boot-verify.sh`: PASS, the main menu after 106 s.
> Then Steam was signed out there, shut down, and the wrapper moved to the Trash; the listings of the home
> folder before and after are the same. What the run showed that is not built is in section 9. **SL1's pasted line, run
> 2026-11-11 from the pushed branch with `--check`:** it fetched `2577207`, reported all six steps OK against
> the Studio's own wrapper, exit 0, and started nothing; with no game named the same bootstrap exited 2 with
> the usage line and fetched nothing. **What stands:** `common/install-core.sh` (420 lines) holds the stages; Cities: Skylines II's
> `scripts/install.sh` is its settings and its own functions (120 lines, from 446); `make-wrapper.sh` and its
> test are in `common/`, with `common/fetch.sh` taken out of it. The divided installer prints what the
> installer of `6a66416` printed in all 96 recorded cases, word for word. **Tests:** the installer's test has
> 105 cases and the transcript, and 33 mutants (its 25, three for the transcript, five new); the wrapper's
> test 63 cases and 11 mutants; the lock test 24 cases and its mutant, its third file now the core; the
> bootstrap's test 40 cases and 10 mutants and the app builder's 48 and 10 (S3 rewrote the first and added
> to the second). Every mutant was applied and seen red on its own case: 57 at S2, and the bootstrap's and
> the app builder's 20 again at S3. The gates of ST7 are green: links (0 unresolved), identifiers
> (at the residual of 9), the experiments ledger, `bash -n`, `test-setup.sh`, `test-launch-feedback.sh` and
> `test-launcher-parity.sh`. **Deviations:** (1) `main` was merged into the branch, not the branch rebased:
> it is published, and a rebase would have needed a forced push. (2) S1's transcript held carriage returns
> from the cases run at a terminal; the repository stores text with plain line ends, so the recorded file
> would not have survived a checkout; they are dropped (`7b102a1`). (3) What 2.1's table calls settings is
> carried by eighteen settings and five functions the game defines (`game_wrapper`, `game_env`,
> `game_running`, `tools_ok`, `words_play`), with `TAKES_DESKTOP` for a setup that takes `--desktop`; the
> report `--check` gives with no wrapper, and the last stage, stay in the game's file. (4) The new cases sit
> before the last recorded one, which judges no run of its own, so it moved to the end of the record: the
> record gained 182 lines and that one line moved; the other 95 records are untouched. (5) The case on the
> core's words does not forbid a bare "step N", which the lock code's own `step 0` call would trip; a second
> case holds that no line of the core says "to step N" or "before step N". (6) The look for another
> wrapper's Steam counts only a process whose open files hold `drive_c`, so a line that merely names
> `steam.exe` is not taken for one (mutant 32). (7) Both steps were written on Fable 5.2, starting from what
> the check's builder lens had built (Opus 5.5), read whole and changed where the folds had moved on: the
> Wine environment, the tools test and the words at Steam's Play button were still one game's inside the
> core. **S3:** the root `install.sh` takes a Steam app ID, finds the folder in `common/games.tsv`, and
> has no default game; `common/make-installer-app.sh` writes the row's ID into the app; the pasted line in
> `README.md`, `cities-skylines-2/README.md` and `cities-skylines-2/INSTALL.md` carries `949230`; no line of
> the root `install.sh` names a folder. (8) The builder already had a variable `ID`, its bundle identifier;
> the first S3 draft reused the name for the Steam app ID, and the builder then refused to rebuild its own
> app. The existing case "built again over its own app" caught it; the new variable is `APPID`, and a case
> now holds the bundle identifier. (9) An ID with no row or no installer exits 2 in both the pasted and the
> checkout case, with the table's games listed by ID and title. (10) The installer plan's guide text in its
> section 2.7 is not rewritten; the documents themselves are, and that plan's header says so. Verify
> against: `install.sh`, `common/make-installer-app.sh`, `common/test-bootstrap.sh`,
> `common/test-make-installer-app.sh`, `common/install-core.sh`, `common/make-wrapper.sh`, `common/fetch.sh`,
> `common/test-make-wrapper.sh`, `common/test-launch-lock.sh`, `cities-skylines-2/scripts/install.sh`,
> `cities-skylines-2/scripts/test-install.sh`, `cities-skylines-2/scripts/test-install.golden`.
>
> Tracking: issue #22. This plan changes the installer of the branch `simple-install`; references to
> `install.sh`, `cities-skylines-2/scripts/install.sh`, `make-wrapper.sh`, `common/make-installer-app.sh`,
> their tests, and `common/test-launch-lock.sh` with the installer as its third file, are as of that branch
> at `6a66416` (the branch has since gained documents only). Every other reference is as of `main` at
> `04936e7`. A path is relative to the repository root. "The installer plan" is
> `docs/plans/simple-install.md`, with its steps N1 to N6 and live steps NL1 to NL5. "The Surviving Mars
> plan" is `docs/plans/surviving-mars-install.md`; MD7 and MD10 are its decisions, and its section 1.4 and
> review hold the measurements and the corrections this plan's moved sections came through. This plan's
> steps are S1 to S4, its tests ST1 to ST7, its live steps SL1 and SL2 and its own decisions SD1 and SD2.

## 0. What James asked for (2026-11-11)

"should we have one installer handle everything?" That became one installer with a short list of settings
per game (MD7 of the Surviving Mars plan). At the session's close he asked: "are there any changes to
make the system more elegant or more inline with best practices? is our path to the best solution?" Four
changes were offered and he took them: "Fold all four". Two of them are this plan:

1. The shared installer is built first, as its own plan, before the installer plan's NL2: it needs none of
   the Surviving Mars plan's probes, and the Gatekeeper test and the first release then see the structure
   that stays.
2. What is published names a game by its Steam app ID, not by its folder.

## 1. What is true today (read or measured)

### 1.1 The installer as it is built, and what in it belongs to one game

`cities-skylines-2/scripts/install.sh` (446 lines) is six stages, each skipped when done. What names
Cities: Skylines II in it, or holds only for that game:

- the wrapper's default path and the candidates looked through (`:88-99`, `:209-235`); `CS2_WRAPPER`,
  also exported for setup (`:159`); `CS2_VIA_INSTALLER` (`:445`);
- the game's folder, program and manifest (`:109`, `:157-158`, `:172-181`);
- the Wine environment it exports and the line it starts Steam with (`:146-166`), which are that game's
  launcher's, held to it by `test-install.sh`;
- stage 1's check of the Mac, which is `setup.sh --mac-only` with `--yes` and `--check` passed on
  (`:241-243`); stage 2's test that python3 runs (`:264-273`); stage 6, which is `setup.sh` with `--yes`
  and `--desktop` passed on (`:435-446`), and the list of the installer's own files it looks for first
  (`:439`: `repatch.sh`, `patches`);
- the report `--check` gives when there is no wrapper, which names stages 4 to 6 in its own words
  (`:309-314`);
- the words: the opening line with "about 105 GB free" and "about 100 GB" (`:207`); the free-space caution
  (`:293`, with `NEED_GB` at `:33`); "(about 235 MB)" (`:298`); "about 100 GB and takes hours" (`:382`);
  "Do not press it: it does not work from inside Steam", measured for this game only (`:383-384`); "step 6"
  in three places (`:12`, `:384`, `:437`); the closing line (`:62-75`).

Everything else is about a Mac, a wrapper, Steam, and a game identified by its Steam app ID: the options,
the traps, the lock (taken after stage 3, `:315-318`), the Steam helpers, stage 2's wait for Apple's
tools, stage 4 (Steam's installer, checked and run), and stage 5 (start Steam through its first-start
failure, wait for the download by the manifest, close Steam). `make-wrapper.sh` (177 lines) names the game
in its engine pin (`:18-20`), its default target (`:31`) and its header, which `--help` prints; the rest
makes any wrapper from a template and an engine.

The root `install.sh` already takes the game as its first word and hands over to
`<game>/scripts/install.sh` (`:78-85`); it and the installer app name `<game>/INSTALL.md` when they fail
(`install.sh:63`, `common/make-installer-app.sh:95`); `common/make-installer-app.sh` already takes `--game`
and names the app from `common/games.tsv` (`:46-51`). The 14unch3r window shows a game with no app as "Not
set up" and opens its guide (`common/launcher-window.swift:165`, `:755`).

The lock code is held identical in three files by `common/test-launch-lock.sh:19-20`, which finds its
`LOCK=` line at the start of a line (`:34`); the installer's copies of the launcher's Steam helpers are
held identical to the Cities: Skylines II launcher by `cities-skylines-2/scripts/test-install.sh` (its
mutant 19). That test copies one file, `install.sh`, into a scratch repository (`:43`) and puts a stub at
`cities-skylines-2/scripts/make-wrapper.sh` (`:109`); its output holds the scratch folder's random name
and process numbers.

### 1.2 What is published, and by what key

- Nothing is published yet: `origin` has no `release` branch and no release (read 2026-11-11).
- Two things, once published, can never be changed in the copies people hold: the installer app's own
  program, and the line the guides say to paste into Terminal.
- Both name a game by its folder. The app's program runs the bootstrap with the folder as its first word
  (`common/make-installer-app.sh:92`) and prints an address with the folder in it when the fetch fails
  (`:95`). The pasted line has no word after it (`README.md:31`, `cities-skylines-2/README.md:30`,
  `cities-skylines-2/INSTALL.md:17`), so it means the bootstrap's default, which is the literal
  `cities-skylines-2` (`install.sh:18`). The bootstrap takes a folder's name (`:37`), lists folders when
  there is no such game (`:79-80`), and names `<folder>/INSTALL.md` when GitHub has no such ref (`:63`); its
  own header and usage line name the folder and the default (`:7`, `:9`, `:12`, `:32`). One line of the
  guide spells the folder out: `cities-skylines-2/INSTALL.md:55`, the pasted line with `--check`.
- The repository's own rule (`.claude/rules/shared.md`, "keys are opaque, human-readable values are
  labels"): a key is opaque and never changes; a readable name is a label, free to edit; nothing durable
  is derived from a label; and no readable literal is a default, because it makes "nobody said which" and
  "that one" the same thing. A folder's name is a label. The default game is such a literal.
- The key each game already has is its Steam app ID: the first field of its row in `common/games.tsv`
  (949230, 3215050), which the 14unch3r window reads (`common/launcher-window.swift:424-426`). The table
  is two rows of four tab-separated fields; its fourth, a guide's address, holds the folder's name too, and
  `common/make-launcher-app.sh` copies the table into every `14unch3r.app`.

## 2. Design

### 2.1 The shared installer

`common/install-core.sh` is read with `.` by a game's installer after the game's settings are set, and is
never run by itself. The game's file stays the address the bootstrap hands over to
(`<game>/scripts/install.sh`), so the hand-over itself does not change; how the folder is found does (2.2). `set -u`
and the header stay in the game's file, which is what `--help` prints.

The settings a game gives:

| Setting | Cities: Skylines II | Surviving Mars: Relaunched |
|---|---|---|
| title | Cities: Skylines II | Surviving Mars: Relaunched |
| Steam app ID | 949230 | 3215050 |
| folder under `steamapps/common` | `Cities Skylines II` | `Project Spark` |
| program | `Cities2.exe` | `Mars.exe` |
| wrapper, and the variable that names another | `~/Applications/CS2dxmt11.app`, `CS2_WRAPPER` | `~/Applications/SurvivingMars.app`, `SM_WRAPPER` |
| other wrappers looked through | the launcher's list (`find_wrapper`) | none |
| engine: file, bytes, sha256 | `WS12Wine11.0_DXMT-v0.80.tar.7z`, as pinned today | the Wine 10 row of the Surviving Mars plan's 1.3 |
| the Wine environment, and the line Steam is started with | as today, its launcher's | its launcher's (`launch-relaunched.sh:77-84`), with Steam's window shown |
| number of steps, used wherever a step is named | 6 | 7 |
| the opening line's needs | about 105 GB free, a download of about 100 GB | about 20 GB free, a download of about 10 GB |
| the free-space caution, and its threshold | as today, 110 GB | the game about 11 GB and Wine and Steam beside it, 20 GB; the sizes are measured at that plan's ML2 |
| the Wine stage's size | about 235 MB | about 237 MB |
| the download, in words | about 100 GB and takes hours | about 10 GB |
| what to do at Steam's Play button | as today | "Do not press it: this window finishes the install, and the game starts from its own app." |
| the Mac check | `scripts/setup.sh --mac-only`, with `--yes` and `--check` passed on; it exits 0 or 1 | its own `setup.sh`, which also exits 3 (the Surviving Mars plan, 2.5); the core prints "the check of this Mac failed (exit 3)" under setup's words and stops (`cities-skylines-2/scripts/install.sh:261`) |
| the test that Apple's tools work | python3 runs | `nm` runs |
| options passed to setup | `--yes`, `--desktop` | `--yes`; `--desktop` is a wrong option for this game (exit 2) |
| the variable that tells setup the installer runs it | `CS2_VIA_INSTALLER` | `SM_VIA_INSTALLER` |
| the installer's own files looked for before setup | as today | `scripts/setup.sh`, `launch-relaunched.sh`, `make-app.sh`, `tools/frame-fix.exe`, `tools/make-engine.sh`, `tools/fetch-d3dmetal.sh`, `common/make-launcher-app.sh` |
| `game_running` | its launcher's, held identical by test | its launcher's (`launch-relaunched.sh:149`), held identical by test; the game's file sets the `GAME` it reads from the wrapper's path as the launcher sees it |
| closing line | "Cities Skylines II, or 14unch3r" | "Surviving Mars Relaunched, or 14unch3r" |

The core's functions, in the order a game calls them: begin (options, the opening lines, the wrapper
chosen and checked, the running-game refusal, `caffeinate`), the Mac, Apple's tools, the free-space
caution, the wrapper, the lock, Steam, the game. A game puts its own stages between them and after them,
and gives each stage its number. The report `--check` gives for a Mac with no wrapper is made from the
game's own list of stages, so it names all of them after the wrapper.

Rules for the move:

- **Cities: Skylines II's installer prints and does exactly what it does at `6a66416`**, with the one
  addition of MD10. ST1 holds this on every run of its test, not once.
- The lock is taken where it is taken today, after the wrapper stage, and is held through every later
  stage, a game's own included.
- The lock code in the core is the copy `common/test-launch-lock.sh` holds identical to both launchers;
  that test's third file becomes the core, and the `LOCK=` line stays at the start of a line. The function
  bodies keep the indentation they have, so the 25 mutants of the installer's test still apply.
- The Steam helpers in the core (`_owns`, `webhelper_up`, `steam_family`) stay the copies held identical
  to the Cities: Skylines II launcher; Surviving Mars's launcher spells the same functions differently
  (`launch-relaunched.sh:190-198`) and is not changed for this.
- `game_running`, the wrapper search and the Wine environment are the game's, not the core's.
- Every line the player reads that names a game, a size or a step number comes from a setting. No line of
  the core that is not a comment holds `Cities`, `Skylines`, `Surviving`, `Mars`, `949230`, `3215050`,
  `CS2_`, `SM_`, `CS2dxmt11`, or a number followed by `GB` or `MB`; ST2 greps for these.
- **Another Steam (MD10).** Before the core starts Steam or waits on it, it looks for a Steam for Windows
  that belongs to another prefix on this Mac. If there is one it stops with exit 3 and says which wrapper,
  and that one Steam at a time may use the account. This is in the core, so Cities: Skylines II's
  installer gains it. With `--check` it says that the installer would stop there, and goes on with its
  report. It cannot see another Mac or the Steam of macOS; both games' guides say so (2.3 here, and the Surviving Mars plan's 2.7).

`common/make-wrapper.sh` takes `--engine-url`, `--engine-bytes`, `--engine-sha` and `--wrapper`; without
all four it exits 2. It reads no game's variable and has no default. Its header, which `--help` prints, is
rewritten without a game's name; its other lines name only the files it is given. Each game's engine pin
lives in that game's `scripts/install.sh`; the template's pin stays in `common/make-wrapper.sh`.

`common/fetch.sh` is new, taken out of `make-wrapper.sh`: `fetch <url> <bytes> <sha256> <file>` with
`L1_DOWNLOADS`, and `sha`, for both of its callers, the wrapper script and the Surviving Mars plan's
`tools/fetch-d3dmetal.sh`.

### 2.2 Published by app ID

- **The bootstrap's first word is a Steam app ID**, digits only. Once it has the repository, fetched or
  the checkout it lies in, it finds the row of `common/games.tsv` whose first field is that ID and hands
  over to `<that row's folder>/scripts/install.sh`. Its second word is the ref, as today.
- **There is no default game.** With no word, or a first word that is not digits, nothing is fetched and
  it exits 2. From a checkout it prints that checkout's games that have an installer, each with its ID and
  title. Pasted or from the app, where there is no table yet, it prints the usage line and the front
  page's address, where the games and their IDs are listed. An ID with no row, or whose folder has no
  installer, is found once the table is there (after the fetch, or in the checkout, which does not then
  fall through to a fetch): it prints that table's games and exits 2, where today's "no installer" exits 1
  (`install.sh:79-81`).
- **How the table is used.** A checkout is known by this file being a real file with `common/games.tsv`
  beside it, since it can no longer look for a named game's folder (`install.sh:48`). The row's folder is
  checked against the pattern for a folder's name before it is put in a path. The builder checks that the
  row's ID is digits before it writes it into the program.
- **The installer app carries the ID.** `common/make-installer-app.sh` keeps `--game <folder>`, which is
  how the person building it says which row; what it writes into the app's program is that row's ID.
- **No folder in an address that is printed without the table.** The app's line for a withdrawn installer
  (`common/make-installer-app.sh:95`) and the bootstrap's line for a missing ref (`install.sh:63`) name
  the repository's front page, `https://github.com/macgameport/1launcher`, where the games are listed.
- **The guides' pasted line gains its words:** `... install.sh)" 1launcher-install 949230`, and for
  Surviving Mars `3215050`.
- **The rule's own test.** In a scratch copy, a game's folder is renamed and its row's second and fourth
  fields changed: the same ID still reaches its installer. An app built before the rename still works,
  because all it hands the bootstrap is the ID and the ref.
- What stays a published address: `install.sh` at the root of the `release` branch, and the names
  `macgameport` and `1launcher`, as the installer plan says (its 2.7). A game's title, which names the
  app's file, is a label on that file: a new title is a new build of the app, and old copies go on working.

### 2.3 What this plan leaves alone

- Surviving Mars's installer, setup and guide: the Surviving Mars plan, built on this one.
- 14unch3r's "Not set up" tile (MD8 there). The guide's address in the table's fourth field holds the
  folder and is copied into `14unch3r.app`; setup makes that copy afresh; it is left as it is, for that
  slice.
- Cities: Skylines II's installer gains two things besides the move: MD10's stop for another wrapper's
  Steam, with a sentence in `cities-skylines-2/INSTALL.md` and in its header's list of exit codes
  (`cities-skylines-2/scripts/install.sh:14-15`), and the ID in its pasted line.
- `make-wrapper.sh` is not a published address, so its move needs no forwarding file. The documents that
  name it are changed with it: `cities-skylines-2/scripts/README.md`, `cities-skylines-2/GOTCHAS.md:3055`
  and `:3083`, and one line in the installer plan's as-built header.

## 3. Steps

- **S1. `cities-skylines-2/scripts/test-install.golden` is recorded from the installer of `6a66416`**,
  before a line is moved. ST1. The same commit says in the installer plan's NL2 note that NL2 follows this
  plan.
- **S2. `common/fetch.sh`, `common/make-wrapper.sh`, `common/install-core.sh`, and Cities: Skylines II's
  installer reduced to its settings, in one commit**, since the installer calls the wrapper script and
  holds the engine pin; the lock test's third file becomes the core in the same commit; and MD10's check.
  ST2, ST3, ST4.
- **S3. Published by app ID:** the bootstrap, with its header and usage line; the app builder; and the
  pasted line wherever a document has it: the three places of 1.2, `cities-skylines-2/INSTALL.md:55`, and
  the installer plan's guide text. ST5, ST6.
- **S4. SL1, then the as-built header;** the installer plan's NL2 follows on this structure (SL2).

It is built on `simple-install`, after that branch is rebased on `main`. The builder lens of the Surviving
Mars plan's check built S2 once in a scratch tree, with the 96 cases passing; what it changed is kept in
that game's `runs/check-builder-sim-20261111/` and is a head start, not the design.

## 4. Test plan

Every test runs with `HOME` at a scratch folder and every outside program a recording stub. Each mutant is
applied to the real source, seen red, and removed; a mutant whose line is gone refuses with exit 2.

| # | Test | What it shows | Mutants, each must turn it red |
|---|---|---|---|
| ST1 | In `test-install.sh`, on every run: each case's name, result and whole output, with the scratch folder's name and process numbers replaced, compared with `test-install.golden`: the 96 cases as recorded from the installer of `6a66416`; a case added later (MD10's) enters the file from its first run, in the commit that adds it | the installer's words and results are those of `6a66416`, case by case; a changed golden file is a change of that game's words, seen in review | "is open." made "is opened." in the core (the test's own greps pass it; measured); one exit code changed; a stage's skip test inverted |
| ST2 | `cities-skylines-2/scripts/test-install.sh`, its 96 cases: the core copied into the scratch repository beside the game's file, the wrapper stub moved to `common/`, the mutant helpers applied to both files | the installer still does what NT3 showed; the engine pin reaches the wrapper script as its three options; new cases: another prefix's Steam stops it with exit 3 (MD10), with `--check` it only says so, and with none it goes on | its 25 mutants, each applied where its line now lives; new: one of the core's forbidden words put into it; a setting read before it is set; MD10's check removed |
| ST3 | `common/test-make-wrapper.sh`, the 59 cases moved and changed as the builder lens changed them: the options always given, the engine pin set by the case, its `fetch.sh` copied beside it | as NT1; and: no engine options exits 2, each two of three exits 2, no `--wrapper` exits 2, `CS2_WRAPPER` is not read, a wrong option among right ones exits 2. The Surviving Mars plan's ML1 measured that the Wine 10 archive unpacks to the same top folder with the same two programs, so the existing fixture's layout holds for it | its 10 mutants (the tenth now on the template's sha256); new: a default engine put back |
| ST4 | `common/test-launch-lock.sh`, its third file the core | the lock code is identical in the core and both launchers | its own mutant |
| ST5 | `common/test-bootstrap.sh`, its cases changed to give an ID, its fixtures given a `common/games.tsv`, and its recorder made to print the game's folder | an ID reaches the folder of its row; with no word, or a first word that is not digits, it exits 2 and fetches nothing: pasted it prints the usage line and the front page, from a checkout that checkout's games with their IDs and titles; an ID with no row, or with no installer in its folder, prints the table's games and exits 2, after the fetch when pasted and with no fetch from a checkout; with a game's folder renamed and its row changed, the same ID reaches it; a row whose folder is not a plain folder's name is refused; the line for a missing ref names the front page and no folder | its 5 mutants; new: a default game put back; a folder's name accepted as the first word; the folder taken from the word and not from the table; a table of IDs to folders written into the bootstrap; the list printed by fetching first |
| ST6 | `common/test-make-installer-app.sh`, with cases added | the app's program holds the row's ID and no second field of `common/games.tsv`; a row whose ID is not digits is refused before anything is written; the `.command` hands the bootstrap the ID and the ref and nothing else (the recorder shows `1launcher-install 949230 release`), which with ST5's renamed-folder case is the whole of "an app built before the rename still works"; the line for a withdrawn installer names the front page; every `install.sh)"` in a README or an `INSTALL.md` is followed by `1launcher-install` and that document's game's ID | its 7 mutants; new: the folder written into the program; the folder put back into the address; the ID dropped from one document's line |
| ST7 | The gates: `common/check-links.py`, `common/check-identifiers.sh` at its residual of 9, `cities-skylines-2/scripts/check-experiments.py`, `bash -n` on every script, and the installer plan's other suites (`test-setup.sh`, the three launcher suites) | nothing else moved | none: they are gates |

## 5. Live steps, each on James's word

- **SL1. Cities: Skylines II's installer after the move, on the Studio.** With no game, Steam or launcher
  running and the real game's `StateFlags` 4: the installer with `--no-setup` into a scratch wrapper, the
  game cloned in while it polls, `boot-verify.sh` to the main menu, as the second half of NL1 did; then
  Steam signed out there and the wrapper to the Trash. And the pasted line from the pushed branch, with
  the branch in both places, run once with `--check`:
  `.../1launcher/simple-install/install.sh)" 1launcher-install 949230 simple-install --check`.
- **SL2. The installer plan's NL2**, the Gatekeeper test, with the app built by this plan's builder.

## 6. Exit criteria

- S1 to S3 are committed; ST1 to ST7 pass; every listed mutant was applied and seen red, with the count in
  the as-built header.
- Cities: Skylines II's installer prints what the recorded transcript holds in all 96 cases.
- Nothing the installer publishes names a game's folder: the built app's program holds no second field of
  `common/games.tsv` (ST6); `git grep -nE 'cities-skylines-2|surviving-mars-relaunched' -- install.sh`
  finds nothing; and every `install.sh)"` in a README or an `INSTALL.md` is followed by
  `1launcher-install` and that document's game's ID (ST6).
- SL1 passed.
- The as-built header is written, and the installer plan's header points here.

## 7. Rollback

- The move is one revert while nothing later is built on it: the installer of `6a66416` is whole in the
  history, and ST1 shows on every run that the two behave alike.
- The app ID in the bootstrap is free to change until the first release, and after it only by a new
  `installer-<n>`; that is why it is done before NL3.
- SL1 leaves nothing: its wrapper is a scratch one, signed out and trashed.

## 8. Decisions, each James's

| # | Decision | Decided |
|---|---|---|
| MD7 (the Surviving Mars plan) | One shared installer, not a second script held alike by a test | 2026-11-11, as recommended |
| MD10 (the Surviving Mars plan) | The installer stops when another wrapper's Steam is open on this Mac, for both games | 2026-11-11, "Accept both" |
| SD1 | What is published names a game by its Steam app ID; there is no default game | 2026-11-11, "Fold all four" |
| SD2 | This plan is built first, on `simple-install`, before the installer plan's NL2 | 2026-11-11, "Fold all four" |

## 9. Found at SL1 (2026-11-11), SL2 (2026-11-12), the Surviving Mars plan's ML2 (2026-11-13) and its build (2026-11-13): not planned in detail, not checked, not built

SL1 passed, and its first run showed five things a new player would meet. None is a fault of the split: the
installer of `6a66416` behaves the same. They belong before the first release (the installer plan's NL3),
each with its test, and this section needs a check before any of it is built. SL2 added SF6 and SF7; ML2
of `docs/plans/surviving-mars-install.md` (its 1.4 and 5a) added SF8 and saw SF1 a second time.

| # | What was seen | What is wanted |
|---|---|---|
| SF1 | A new Steam downloads its own update (305 MB) from one server, `cdn.steamstatic.com`. With that path cut, the installer started Steam five times in 90 s and then printed twenty lines of Steam's log and "Steam did not start after 5 tries" | The installer knows this case from Steam's log ("Steam needs to be online to update"), does not start Steam again for it, tests the server once with a short transfer of its own, and says in one sentence that the connection to Valve's server keeps being cut, and to open the installer again later |
| SF2 | James, after it worked on another route: "so we need a warning about vpns? can we check for that and popup that it may interfere?" The same VPN had carried the same update that morning | No warning for a VPN as such. In SF1's sentence, and only when the Mac's default route is a tunnel, the advice to change the VPN's server or pause it. A line in the installer's window, not a box (James, 2026-11-11, to the wording below: "ok"); a box is looked at again only if SF3 finds that Steam's own error box cannot be hidden and would cover that window |
| SF3 | Steam's updater draws its own windows, and its "Fatal Error" box, on every start; James saw it fail "many many times" and asked whether the progression can be hidden | Measured first: whether Steam's updater can be kept off screen in a new prefix. If it can, the installer prints one progress line of its own, read from Steam's log; if not, its words say what will be seen |
| SF4 | In step 4 `curl: (18) Transferred a partial file` was printed as curl wrote it: the first of the two addresses of Steam's installer failed and the second worked | Nothing of curl's on screen when the next address works; the installer's own sentence when none does |
| SF5 | At the wrapper's first start macOS showed: "App Update Required. This version of "CS2fresh" includes a component that will not open in macOS 28, the next major release. An update may be available on the developer's website." James: "don't forget this." `cities-skylines-2/README.md` warns of macOS 28; the quick way in `INSTALL.md` and the installer say nothing of the notice | One line in the installer where Wine first starts, and one sentence in the guide's quick way: the notice is expected, nothing needs updating, and the Mac must stay on macOS 27 (issue #16) |
| SF6 | At SL2, the one approval of the downloaded app was stranded. After Open Anyway and the second dialog macOS showed a Touch ID box; its button that falls back to the password was pressed, the approval's request was set aside and never completed, and macOS kept the app held before its first instruction. Every later open ended in Finder's "not responding" until the held process was ended from Terminal. The approval itself had been recorded: the next open ran with no dialog. One run; that the button caused it is inferred | Decided first, by James (the installer plan's ND1): the app is published, or only the pasted line is. If the app is: the guide says to use Touch ID or to type the password in the box that is shown, and says what to do when Finder reports the app as not responding. What that is for a player who does not use Terminal (Force Quit, logging out, a restart) is measured first, not assumed |
| SF7 | At SL2 the game was one build newer than the patches (26404411, 1.6.4f1): `patch_cohtml.py` found no pattern, nine of ten scripts finished, both apps were built, and the window ended "setup finished with 1 problem(s)" and "The install stopped. The lines above say why. Open the installer again to carry on from that step." Opening it again gives the same result until the project publishes a new pattern | Words for this case that say what is true: the game updated, one fix is not yet available for the new build, everything else is in place, whether the game can be played meanwhile, and where to look for news. Decided first: whether such a run counts as stopped |
| SF8 | At ML2 `make-wrapper.sh` stood at "making the Wine prefix (about 30 s)" for 85 minutes. The prefix was complete within a minute; the template's `wineskinlauncher WSS-wineprefixcreate` then waits until no process named `wineserver` runs anywhere on the Mac (`killall -0 wineserver` in its own loop), and a storefront Steam was open in another wrapper. It returned with exit 0 23 s after that Steam was quit. SL1, SL2, NL1 and NL2 did not show it because no other Wine ran | Measured first: whether the wait can be avoided (the prefix made with the engine's own `wineboot` instead of the template's program, or that program told to return), or only announced. Then either the installer does not wait, or before that step it names what is running (another game's wrapper, the Steam app, CrossOver) and says to quit it, and says so again if the step runs long. Its test starts a second Wine before the step |
| SF9 | Found 2026-11-13 while the Surviving Mars plan's M6 was built: `cities-skylines-2/scripts/test-install.sh` fails now and then. Of 9 runs on the Studio (5 on the core as it was, 4 with one line added to its exit handler), 4 failed, in two ways, each seen with and without the line. One: "the Mac kept awake while it runs" read 0, because the installer starts `caffeinate` in the background and the stub's line can land after the installer exits; the test now waits up to 3 s for it. Two: the transcript gained a line `install-core.sh: child setpgid (<n> to <n>): Operation not permitted`, bash's own, from `start_steam`'s `set -m` (`common/install-core.sh:144`). **Not known:** whether a player can see that line in a real install, and why the call is refused | The cause of the second, measured: whether it needs a shell with no terminal (the test's), and whether the line can reach a player. Then either the line is kept out of the installer's output or `start_steam` gets its own process group another way. Until then a red run of that test whose only difference is that line is this finding, not a changed word |

**SF1 and SF2, the words (put to James on 2026-11-11, who answered "ok"; not checked, not built).** With the
default route on a tunnel:

```
  !! Steam could not download its own update: the connection to Valve's server keeps being cut.
     This Mac is using a VPN, which may be the cause. Change the VPN's server or pause it,
     then open the installer again. It carries on from this step.
```

Seen a second time at ML2 (2026-11-12, Wine 10 with D3DMetal 3.0, the Surviving Mars wrapper): the default
route was the same VPN's tunnel, Steam's update reached about 21 MB of 336 MB in 83 s and then every package
"failed after 0 bytes"; a transfer of one package by `curl` was cut after 1.1 MB and after 12.9 MB. With the
VPN paused the next day the same transfer completed (94 MB in 3.6 s) and Steam updated in one start. New
for SF1: the Steam left at its error box did not close on `-shutdown` within 30 s; `wineserver -k` closed
it and left Steam's 0-byte `.crash` marker, which the next start must clear.

With no tunnel, the first line and then: `Open the installer again in a few minutes. It carries on from this
step.` The words say "may be the cause" because SL1 did not measure whether the VPN's exit or Valve's server
did the cutting. They are shown only after the failure and after the installer's own short transfer to the
server has failed too; a VPN that works is never mentioned.

## Review

Sections 1.1 and 2.1, step S2 and tests ST1 to ST3 were checked as part of the Surviving Mars plan: four
lenses, then a fitted check of the fold, on 2026-11-11. The corrections that concern them are in that
plan's "Review corrections": R3 (the recorded transcript), R4 (each game's Wine environment), R5 (the
places where the flow crosses stages), R15 (another Steam), R21 (one commit; the wrapper test is not a
plain move), and its second-pass rows S5 and S6. Its builder lens built step S2 and ran ST2 and ST3.

### Second-pass re-check (2026-11-11): the split and what is new

One agent, briefed to check the commit that made this plan and nothing else. It read every claim of 1.2 in
the code and found each true; it found the moved sections whole but for one sentence; and it found two
blockers and nine smaller defects in the fold, all folded above:

| # | Defect | Folded into |
|---|---|---|
| F1 | **Blocker.** With no word, or a word that is not digits, 2.2 promised a list of games "before anything is fetched"; pasted or from the app there is no table before the fetch | 2.2 ("There is no default game"), ST5 |
| F2 | **Blocker, shared with the Surviving Mars plan.** Its MD5 still sent NL2 ahead "as planned" while this plan puts NL2 after itself; the installer plan's own NL2 note said the same | that plan's MD5; S1 here; the installer plan's header on the branch |
| F3 | SL1's pasted line would have fetched `release`, which does not exist yet | SL1 |
| F4 | ST6's last case could not be made in that test's world | ST6 |
| F5 | The exit criterion on folder names passed before S3 was done, and no test held the ID in the guides | exit criteria, ST6 |
| F6 | Two published places with the folder were missed: `cities-skylines-2/INSTALL.md:55` and the bootstrap's own header and usage | 1.2, S3 |
| F7 | What `common/fetch.sh` is, and where the template's pin stays, were lost in the move | 2.1 |
| F8 | The table's fourth field holds the folder and is copied into every `14unch3r.app` | 1.2, 2.2 (the rule's own test), 2.3, exit criteria |
| F9 | Smaller: how a checkout is known once no folder is named; the row's folder and ID checked before use; counts of cases and mutants; a mutant that did not prove the renamed-folder case; the fixtures ST5 needs; two citations; step names that clashed with the other plan's second-pass rows | 1.2, 2.2, ST5, ST6, Review |

## Review log

Key paths: `install.sh`, `common/` (`make-installer-app.sh`, `games.tsv`, `test-bootstrap.sh`,
`test-make-installer-app.sh`, `test-launch-lock.sh`), `cities-skylines-2/scripts/` (`install.sh`,
`make-wrapper.sh`, `setup.sh`, `test-install.sh`, `test-make-wrapper.sh`), `cities-skylines-2/INSTALL.md`,
`README.md`, `cities-skylines-2/README.md`.

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-11 | 1 and 1b, as part of the Surviving Mars plan | four lenses, then a fitted fold check | see that plan's Review log | Fable 5.2, and Opus 5.5 for the builder | `04936e7` and `8465248` on `main`, `6a66416` on `simple-install` | build-ready-with-fixes |
| 2026-11-11 | 2 | fitted check of the split and of 1.2, 2.2, 2.3, S3, ST5, ST6 | one agent; both blockers re-read in the code by the planner | Fable 5.2 for the check and its fold | `3f80932` on `main`, `7ef565f` on `simple-install` | build-ready-with-fixes |
