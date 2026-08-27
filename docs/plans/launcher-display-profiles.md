# Launcher display profiles — home (external) vs mobile (built-in) auto-detect

> **Status: Triple-checked 2026-08-27 — build-ready-with-fixes (pass 1, all corrections folded).**
> **Build is gated on James's explicit go** (his ask was plan + check, 2026-08-26 night).
> Tracking: PLAN.md (personal-tier repo).

James, 2026-08-26 (after adopting retina on the built-in panel): *"how do I launch differently if
I am at home vs mobile? is there an auto detect process?"* Home = external monitor (DELL U2424H,
1920×1080 @ 120 Hz, historically the **main** display when docked — GOTCHAS § second-display);
mobile = built-in 3024×1964 retina panel. The two contexts want opposite DRS settings and the game
keeps ONE saved config that follows the last in-game selection (the ratchet, GOTCHAS § "Retina
mode" + addendum).

## 0. Verified facts this design rests on (measured 2026-08-22 → 08-26)

1. **Unity's Screenmanager registry controls the boot-time window size** — three same-night
   measurements **on the built-in panel**: `Use Native=1` → window = hosting display's native
   (r0-1/r0-3/r0-4 booted 3024×1964); Screenmanager 1920×1200 + `Use Native=0` → window
   1920×1200 (r0-2). `reg add` before boot is honored every time.
2. **From-disk edits of the Settings.coc `resolution` tuple do NOT reliably take**: refresh-only
   edit failed 2026-08-22 (GOTCHAS § second-display: "the game still applied 60 Hz"); width/height
   edits fell back to 1920×1200 twice on 08-26. Only the in-game dropdown reliably sets the
   game's runtime value. → **This plan never writes the resolution tuple.** Which store feeds the
   game's *runtime* resolution belief remains partially unmodeled — the design is deliberately
   independent of it (runtime belief measured harmless to the actual window in borderless).
3. **From-disk edits of the DRS block DO take** (functional proof: minScale edit rendered at the
   edited scale, −17 % gpuMs; seven settings-series cells). Current block (fresh read):
   `{enabled: true, isAdaptive: false, upscaleFilter: "ContrastAdaptiveSharpen", minScale: 0.5}`
   — the adopted mobile config. ⚠ Bare `"enabled":` appears 9× in the file — the `isAdaptive`
   adjacency anchor is load-bearing in every regex below.
4. **`Use Native=1` is self-healing against the ratchet** — measured on the built-in (three
   boots); the external direction (docked: window = external's native) is *inference from the
   same mechanism*, expected-pending-T10. On the external the game's CO layer may still believe
   an unmatchable resolution and fall back — measured benign on the built-in.
5. Detection shape (`system_profiler SPDisplaysDataType -json`, captured live): displays are
   entries in `SPDisplaysDataType[].spdisplays_ndrvs[]`; built-in carries
   `spdisplays_connection_type == "spdisplays_internal"`, online flag is
   `spdisplays_online == "spdisplays_yes"` (string), and the main display carries
   `spdisplays_main == "spdisplays_yes"`. Parse with `.get()` defaults — entries/keys may be
   absent (display-less GPU entries; offline externals may drop keys or whole entries).
6. Repo `launchers/launch-cs2-dxmt11.sh` is byte-identical to canonical (diff'd). An edit lands
   in both, same commit.
7. ⚠ Open verification carried into T9: James's in-game 3024×1964 selection is on disk but no
   boot has run after it (verified: no artifact postdates the 23:20 adoption write). If a session
   happens before build night, re-judge this by timestamp — T9 remains valid as a verification
   regardless.
8. Registry value-name portability: the `_h1405027254` suffix is the DJB2-XOR hash of the value
   name — reproduced 6/6 against user.reg — identical on every install; safe in a public repo.
9. Hook-point preconditions: `WINE`/`WINEPREFIX` exported at launcher lines ~59-61, before
   `export WINEDEBUG` (line 66); `PATCH_DIR=` sits **20 lines below** (line 86,
   `"${CS2_PATCH_DIR:-$HOME/cs2-patch}"`), first read at line 118 — hoisting it above the hook is
   a pure reorder, `set -u`-safe.

## 1. Design

**One new file + a ~7-line guarded hook in the canonical launcher.** All logic in the helper; the
hook fails open. The helper is **stateless** (always-assert per boot; sticky-state rejected —
it adds a divergence mode and destroys the every-boot-line-is-an-assertion audit property).
Semantics: **the launcher owns per-context DRS; in-game DRS tweaks last one session** (resolution
selections are untouched and keep working). Escape hatch `CS2_PROFILE=off`, named in INSTALL.md
*and in the helper's own log lines*.

### Helper: `scripts/cs2-display-profile.sh` (repo original) → deployed `~/cs2-patch/cs2-display-profile.sh`

Bash + embedded python3 (house style). Contract:

- Env in: `WINEPREFIX` + `WINE` (from launcher) · `CS2_PROFILE` = `home|mobile|off|` unset=auto ·
  `DRY` =1 → print classification inputs + every action it WOULD take, write nothing, exit 0 ·
  test surface: `CS2_SP_FIXTURE=<file>` substitutes the system_profiler JSON (unit tests),
  `CS2_SETTINGS=<file>` overrides the Settings.coc path (copy-based tests; tests also export
  `WINE=/usr/bin/true` so no real reg add — pointing real wine at a fake prefix would CREATE one).
- `CS2_PROFILE=off` → exactly `Display profile: skipped (CS2_PROFILE=off)`, exit 0, no reads/writes.
- **Game-running guard**: lsof-vs-prefix attribution of any `/Cities2.exe` process (the
  perf-bench.sh pattern) → if live, skip everything: `Display profile: skipped (game running)`,
  exit 0. Covers the unguarded double-launch window.
- **Detect** (auto): `system_profiler SPDisplaysDataType -json` via `subprocess.run(...,
  timeout=10)` — fail-open catches exits, not hangs, and system_profiler wedges exactly at dock
  transitions. Classification over **online** entries (`spdisplays_online == "spdisplays_yes"`):
  - primary rule: the entry with `spdisplays_main == "spdisplays_yes"` decides —
    main external → **home**; main internal → **mobile** (even when docked: `displayIndex 0`
    puts the window on the main display, so main-keying matches where the game actually opens;
    mirrored/Sidecar/AirPlay resolve by whichever is main).
  - no main flag found → fallback: any online non-internal entry → home; else internal → mobile.
  - zero usable entries / parse error / rc≠0 / timeout → skip (fail-open, one warning line).
- **Apply** (idempotent; **if current state already matches the target, write nothing** and log
  `(already set)` — no mtime/backup churn; any failure = warning + exit 0, never non-zero):
  1. Registry, via `subprocess.run(["$WINE", "reg", "add", …], timeout=30)`: value name
     discovered by grepping `user.reg` for `"Screenmanager Resolution Use Native[^"]*"` (guards a
     future game-update rename), falling back to the literal
     `Screenmanager Resolution Use Native_h1405027254` (hash proven deterministic, §0.8) —
     `/t REG_DWORD /d 1 /f` under `HKCU\Software\Colossal Order\Cities Skylines II`. Both
     profiles, every boot (§0.1/§0.4).
  2. Settings.coc DRS block — path derived by glob
     `$WINEPREFIX/drive_c/users/*/AppData/LocalLow/Colossal Order/Cities Skylines II/Settings.coc`
     with realpath dedupe (the other user dirs are symlinks to Wineskin — never hardcode the
     user name), overridable via `CS2_SETTINGS`. Anchored both-state regexes, **non-capturing
     state, captured anchor**:
     - home:   `"enabled": (?:true|false)(,\s*"isAdaptive")` → `"enabled": false\1`
     - mobile: same anchor → `"enabled": true\1` · `"minScale": [0-9.]+` → `"minScale": 0.5` ·
       `"upscaleFilter": "[A-Za-z]+"` → `"upscaleFilter": "ContrastAdaptiveSharpen"`
       (known enum names are alphabetic; a future digit-bearing name = fail-open skip)
     - every regex asserted `== 1` match before writing; any other count (0 or ≥2) → skip the
       file edit entirely (warning), still exit 0. Home leaves minScale/filter as-is (inert
       under enabled:false).
     - Write = backup to **rolling** `Settings.coc.pre-profile` (one file, overwritten only on
       actual writes; historical `.exp-base`/`.bak-*` untouched) → temp file in same dir →
       `os.replace()` (atomic; a mid-write crash can never leave a truncated Settings.coc).
- Output: exactly one stdout line on every path (warnings included — both log sinks merge
  2>&1), always carrying the decision inputs and the escape hatch on skips/warnings, e.g.
  `Display profile: mobile — main display internal (native swapchain + DRS 0.5 CAS)` ·
  `Display profile: home — main display external DELL U2424H (DRS off, native 1:1)` ·
  `Display profile: skipped (<reason>; set CS2_PROFILE=off to silence)`.

### Launcher hook (canonical + repo copy, identical)

`PATCH_DIR=` assignment hoisted to just above the hook (pure reorder, §0.9). Hook inserted after
`export WINEDEBUG`:

```bash
# Display profile (home/external vs mobile/built-in) — docs/plans/launcher-display-profiles.md
# CS2_PROFILE=home|mobile|off overrides auto-detect. Never blocks a launch: missing/failing
# helper = one warning line, boot continues untouched.
if [ -f "$PATCH_DIR/cs2-display-profile.sh" ]; then
  bash "$PATCH_DIR/cs2-display-profile.sh" || echo "WARNING: display-profile step failed — continuing with saved settings"
else
  echo "NOTE: no cs2-display-profile.sh in $PATCH_DIR — display profiles inactive."
fi
```

Boot-cost note: the hook adds ~1 s (system_profiler) + the boot's first wine invocation moves
earlier (cold wineserver start ~1-3 s that would have been paid at the Steam step anyway).

## 2. Out of scope / recorded decisions

- No management of *which display* the game opens on (`displayIndex` untouched); a manual in-game
  selection of a non-main display is out of scope — main-keyed detection assumes displayIndex 0.
- No refresh-rate writes; no exclusive fullscreen; no changes to `launch-cs2.sh`, the windowed
  variant, or the store wrapper.
- Sticky-state rejected (see §1). Warm-vs-cold Steam declined as a test dimension **with
  reason**: the hook runs before the launcher's Steam branch entirely, so its behavior is
  invariant to Steam residency; T9's cold boot covers the hook's only path.
- Security lens waived with reason: no trust boundary (system_profiler is OS-trusted local
  output; helper ships no personal data). ⚠ Publishability: **detection-test fixtures stay out
  of the repo or get scrubbed** — SPDisplaysDataType JSON carries display serial numbers.
- Build commit also updates: GOTCHAS § Retina addendum's "(a) …no launcher assert is needed"
  gains a cross-ref ("superseded by the display-profile helper, which asserts every boot — see
  docs/plans/launcher-display-profiles.md") — that sentence becomes misleading otherwise; and
  the auto-memory index (retina memory's "verify next run" is closed by T9; profiles feature gets
  its own line).

## 3. Test plan

Order matters: **T6 first** (it is the discriminator that rescues T5/T7 from vacuity), then the
rest. All file tests run against copies via `CS2_SETTINGS` with `WINE=/usr/bin/true`; detection
tests inject `CS2_SP_FIXTURE`. Prefix cold for anything touching the real tree (resident Steam
flushes user.reg periodically → false mtime failures).

| # | test | arbiter | when |
|---|---|---|---|
| T1 | detection: captured current JSON | → `mobile` | build night |
| T1b | forced `CS2_PROFILE=home` and `=mobile` with detection stubbed BROKEN (fixture = garbage) | override applied, detection bypassed | build night |
| T2 | synthetic external entry, main=external | → `home` | build night |
| T2b | synthetic external present but `spdisplays_online: "spdisplays_no"`; main internal | → `mobile` | build night |
| T3 | clamshell (internal absent, external main) | → `home` | build night |
| T4 | garbage/empty JSON · rc≠0 · **hang** (fixture cmd = `sleep 60`, timeout fires) | → skip, exit 0, one line each | build night |
| T5 | idempotence on a **perturbed** copy (home-state file, apply mobile): run 1 = asserted diff; run 2 = zero diff + identical output line | distinguishes idempotence from inertness (a same-state pass certifies nothing) | build night |
| T6 | both-state round-trip on a copy: mobile → home → mobile; each intermediate asserted; final byte-identical to start; `Settings.coc.pre-profile` created and matches pre-write state; no `*.tmp` residue | the write path demonstrably fires + backup + atomicity residue | build night |
| T7 | `CS2_PROFILE=off` | exactly `skipped (CS2_PROFILE=off)` (reason pinned — a detection-crash skip must NOT pass); real-tree mtimes unchanged | build night |
| T8 | `bash -n` launcher (both copies) + helper | clean | build night |
| T9 | **mobile E2E**: `CS2_HUD=1 perf-bench.sh rt-profile-mobile` + the retina plan's §4 screenshot loop (display-wake + TCC content probe prep — perf-bench takes no shots itself) | cell log has the profile line · `Player.log` "Window resolution: 3024x1964" (closes §0.7 — but a window≠3024 outcome indicts the Use Native mechanism (§0.1), not this helper: judge separately) · post-run DRS persistence anchored ==1 each · **HUD in the shot reads `1512x982`** (= 0.5 × 3024×1964 — the DRS-0.5 functional arbiter, numeric) with optional sharpness reference vs `rt-shots/rt-b0-*.png` · repatch step still prints "Patches ensured" (semantic proof of the PATCH_DIR hoist) | build night |
| T10 | **home E2E**: first real dock. **James checks:** launcher log shows `Display profile: home — …`; in-game Options shows external native @120 and DRS Disabled. Optional pre-check: `CS2_PROFILE=home DRY=1 bash ~/cs2-patch/cs2-display-profile.sh` before launching — prints classification + would-do, writes nothing. **I check from disk after** (timestamps postdating the dock): Player.log window = external native · Settings.coc `"enabled": false` anchored ==1 · launcher-log line. **Revert trigger:** wrong window/display or DRS still on → `CS2_PROFILE=off` + report; restore per §4. | fail-open until then | first dock |
| T11 | hook fail-open branches, via **dry-eval**: sed-extract the hook block from the real launcher by its comment sentinel, run with `PATCH_DIR=<empty tempdir>` (→ NOTE line) and with a stub helper `exit 1` (→ WARNING line, evaluation continues). No game launch; the "boots normally with helper present" half is carried by T9. | both branches print + continue | build night |

**Red-checks (five — each applied to a copy, observed red, restored green):**
R1 (T2): flip the synthetic external's connection type to internal → must NOT classify home.
R2 (T6): break one anchor (`isAdaptiv`) → helper must skip-not-write.
R3 (T6): duplicate the DRS block in the copy (≥2 matches) → skip-not-write.
R4 (T9): `CS2_PROFILE=off` boot prep run → no profile-applied line.
R5 (T11): the `exit 1` stub helper → WARNING + continue (the never-blocks-a-launch promise,
tested rather than asserted).

## 4. Rollback

- Launcher: `cp` to `launch-cs2-dxmt11.sh.pre-profiles` before the edit (+ repo copy in git);
  restore = one `cp` / `git checkout`. Never edit while the game runs (prefix-cold sweep first).
- Helper: inert without the hook; `CS2_PROFILE=off` or delete disables instantly.
- Settings: restore `Settings.coc.pre-profile` (rolling, asserted by T6) or in-game in 10 s;
  `Use Native=1` is the desired standing value under both profiles — no registry rollback needed.

## 5. Exit criteria

1. T1–T9 + T11 (incl. T1b/T2b) green on build night; **all five red-checks observed red then
   green**; T5 run on a perturbed copy per its arbiter.
2. Canonical + repo launcher byte-identical after the edit; helper committed at
   `scripts/cs2-display-profile.sh`, deployed to `~/cs2-patch/`, **deploy copy byte-identical**;
   `setup.sh` gains the helper cp line (verified absent today — scripts/ is not deployed by it).
3. INSTALL.md documents profiles + `CS2_PROFILE` + DRY; PLAN.md updated; ledger entry; GOTCHAS
   addendum cross-ref (§2); auto-memory index updated; this doc's as-built header; committed +
   pushed. No detection fixture with display serials enters the repo.
4. T10 explicitly handed to James (with the DRY pre-check offer) as the one open verification.
5. Machine state after build night: mobile profile active (= adopted config), prefix cold, no
   bench artifacts dirty, no `*.tmp` residue.

## Review corrections (triple-check 2026-08-27)

Pass 1 (4 lenses: correctness · builder-sim · architecture · test-plan audit; unanimous
build-ready-with-fixes; 1 converged BLOCKER). Folded: **BLOCKER — substitution group defect**
(`\1` bound the state group, emitting `falsetrue` and eating the anchor; now non-capturing state +
captured anchor, both profiles); detection re-keyed on **`spdisplays_main`** (displayIndex 0
follows the main display — presence-keying misclassified docked-with-laptop-main into DRS-off on
the retina panel) with presence fallback + online gate (`spdisplays_yes` literal) + T2b;
**timeouts** on system_profiler (10 s) and reg add (30 s) — fail-open catches exits, not hangs —
with a T4 hang mock; game-running guard (lsof-vs-prefix); atomic temp+`os.replace()` writes;
skip-when-already-set; `DRY=1`; test surface (`CS2_SP_FIXTURE`/`CS2_SETTINGS`/WINE stub — real
wine against a fake prefix would create one); setup.sh confirmed to deploy nothing from scripts/
→ cp line mandated; value-name grep-discovery with proven-deterministic literal fallback (DJB2
6/6); Settings.coc path via user-glob + realpath (symlinked user dirs); T5 redefined on a
perturbed copy (same-state idempotence certifies nothing); T7 reason pinned; five red-checks
(was three) incl. the crashed-helper fail-open mutant; T9 gains the numeric DRS arbiter (HUD
`1512x982`), the shot-mechanism dependency, the §0.7-vs-helper disambiguation, and the
"Patches ensured" hoist check; T10 protocol spelled (James / me / revert trigger); warm-Steam
test dimension declined with reason (hook precedes the Steam branch); PATCH_DIR distance
corrected (20 lines); §0.4 external half re-scoped to inference-pending-T10; §0.7 marked
time-sensitive; boot-latency + filter-regex limits + fixture-PII notes recorded.

## Review log

| date | pass | lenses | method | model | verified-against | verdict |
|---|---|---|---|---|---|---|
| 2026-08-27 | 1 (full) | correctness · builder-sim · architecture · test-plan audit | 4 read-only agents, one batch; corrections folded same session | Fable 5 | `552ca4c` | build-ready-with-fixes |

Key paths: `~/cs2-patch/launch-cs2-dxmt11.sh` (+ repo `launchers/` copy) · `scripts/setup.sh` ·
`scripts/perf-bench.sh` + `scripts/perf-run.sh` · prefix `user.reg` (Screenmanager values) ·
Settings.coc DRS block · GOTCHAS §§ "Retina mode"+addendum / second-display / Settings.coc-edits ·
docs/plans/retina-swapchain-experiment.md (as-built).
