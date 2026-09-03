# Verification instruments — a committed boot-verify, probe hygiene, and the live-drag re-run

**Status: BUILT 2026-09-03 — I3 done 16:36 (ledger C34) · check-it'd 2026-09-02 — build-ready-with-fixes (pass 2; I1 was rewritten after a needs-rework pass 1, then re-checked).** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`.

> **🔧 As-built (2026-09-03):** **built** — I3, the human live-drag step (T8), done 2026-09-03 16:36, ledger C34. Shipped in one
> commit: `scripts/boot-verify.sh` (I1, plus a `--selftest` that runs every judge branch with no
> launch); the whole I2 table — winlist auto-build in both probes, `kg.png` deleted right after its
> size test, `pixel-probe` size guard (exit 4) + margin/depth clamps + `strip <x> <w>`, the driver's
> `move <hwnd> <dx,dy> [async]` verb and binary-mode (LF) stdio; driver rebuilt and deployed to
> `~/cs2-patch/win-resize-driver.exe`, `pixel-probe` and `winlist` rebuilt in `/tmp`. **Measured:**
> T1 PASS (run `~/cs2-patch/boot-verify/20260902-191156`: game +105 s, MainMenu 19:15:32, graceful,
> exit 0; `--selftest` 8/8) · T2 REFUSED, pid listed, exit 2 · T3 **FAIL + GRACEFUL: no**, exit 1
> (see deviation 3) · T4 winlist rebuilt, abort = `no SDL_app top-level Steam window` · T5 `kg.png`
> absent; mutant (rm dropped) → present, restored · T6 10×10 → `too small to probe (10x10)` exit 4,
> 30×30 probes, depth 100 clamps to 14 · T7 2 `title=` lines, 0 CR on stdout and stderr,
> `title=Steam$` matches raw · T9 child `0x1013E` (CefBrowserWindow) origin 1,122 → 121,122 → 1,122;
> strip 15,25,36 vs 200,200,200 on the synthetic edge, five strips read on a real capture.
> **Deviations:** (1) macOS ships no `setsid`; the launcher is detached with perl `POSIX::setsid`
> (same session semantics; the DYLD purge on that SIP exec is harmless because the launcher
> re-exports at `:63`). (2) T2's fixture as written (`cp /bin/sleep` + `exec -a`) does not register
> on macOS 26; as executed it is a symlink named `wineserver` to `/bin/sleep` (GOTCHAS 2026-09-03).
> (3) **SceneFlow.log is written live**, not flushed on exit: T3 left a fresh 67-line log ending
> 11 s before the SIGTERM, so a killed run judges FAIL + GRACEFUL: no, and VOID is reached only when
> nothing was written this run. The I1 fact and the T3 expectation both came from the 2026-09-02
> wrong-path polling; the judge's branches are unchanged. (4) A failed `close` goes straight to
> SIGTERM — the 120 s wait applies only after a posted WM_CLOSE. (5) `GRACEFUL: unknown` on a VOID
> run with no override, rather than reporting a stale log's exit as this run's. **Exit criteria:**
> 1 ✓ · 2 ✓ · 3 ✓ (I3 done, C34) · 4 ✓. **Verify against:** `scripts/boot-verify.sh` (header TESTS block),
> `scripts/win-resize-driver.c`, `scripts/pixel-probe.swift`, `scripts/shimmer-probe.sh`,
> `scripts/livedrag-probe.sh`, `docs/agent-brief.md`, `CLAUDE.md` § Where things live.

**Why.** On 2026-09-02 the game boot verification took three attempts because the script in use
polled a log at the wrong path, ran the resize driver against the wrong prefix, matched CRLF output
with a `$` anchor, and was killed by a tool timeout that took Steam down with it. Every one of those
is a harness fact, not a game fact, and each cost a launch. The facts are now in `GOTCHAS.md` and
memory; this plan turns them into a script that cannot get them wrong. The ad-hoc scripts that
worked on 2026-09-02 are preserved at `~/cs2-patch/harness-2026-09-02/`
(`boot2.sh` is the seed; this plan supersedes its detachment and verdict handling).

---

## I1 — `scripts/boot-verify.sh`

**Facts it encodes (all measured 2026-09-02; the check lens verified each against the launcher
and the driver source).**
- `SceneFlow.log` lives at
  `$WINEPREFIX/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/Logs/SceneFlow.log`
  — **not** under `$GDIR` (the Steam install dir, which has no `Logs/`). It is **flushed on graceful
  exit**, not written live: the first line carries a full `[YYYY-MM-DD HH:MM:SS,mmm]` timestamp,
  `MainMenu reached` appears once, `GameManager destroyed` marks a graceful exit. `Player.log`
  contains no `MainMenu` string and its mtime is the exit time, so it is not a dwell condition.
- The launcher (`~/cs2-patch/launch-cs2-dxmt11.sh`) runs `Cities2.exe` in the foreground (`:194`),
  captures the game's rc, and after it returns shuts Steam down itself (`:200-232`: `-shutdown`,
  `wineserver -k` fallback, prefix-attributed stray sweep). Do not shut Steam down from the script.
  It clears a stale `.crash` marker on its fresh-start branch (`:156`), the branch a boot-verify
  always takes. It always exits 0 (`:234`); the game's rc is only in its `Game exited (rc=N)`
  line (`:200`). With `CS2_QUIET=1`, `die` shows a **modal** `osascript` alert (`:44`) — a failed
  login would hang there; with `QUIET=0` and stdin from `/dev/null`, `read -n1` fails and the
  launcher exits 1 at once. **Run with `QUIET=0` and `</dev/null`.**
- The game window is `class=UnityWndClass title=Cities: Skylines II`. `win-resize-driver.exe
  close` **posts** `WM_CLOSE` (`:142`) after an `IsWindow` refusal (`:123`, rc 1) and returns 0
  immediately (`:143`); the game exits ≈10 s later. The driver needs `WINEPREFIX` exported and
  prints CRLF (every line is CRT `printf`; strip `\r`). Its `pid=` field is a **Win32** pid, never
  a `kill` target.
- **Detach with `setsid`**, not `&`: a plain `&` leaves the launcher in the tool's process group,
  which is exactly what a tool timeout killed on the first attempt (taking Steam with it and
  leaving the `.crash` marker). `setsid bash ~/cs2-patch/launch-cs2-dxmt11.sh </dev/null >LOG 2>&1 &`
  is safe here: the launcher re-exports `DYLD_FALLBACK_LIBRARY_PATH` itself before the Steam line
  (`:63`), and its "never `nohup`/`setsid`" rule (`:157-162`) is about that line, not about how the
  launcher is started. Append `EXIT:<rc>` to LOG from the wrapper so the code survives detachment.

**Behaviour.** `boot-verify.sh [--dwell N] [--hwnd HEX] [--judge-only DIR --t0 EPOCH]`.
1. Refuse if anything runs against the prefix: pgrep candidates `steam|wine|Cities2|wineserver`,
   then the launcher's `_owns` test (`:101`) — never `lsof +D` over a 91 GB prefix. List the pids.
2. Record `t0`; start the launcher detached as above; wait ≤ 240 s for a game pid (lsof
   attribution). If the launcher pid disappears first → `VOID`, quoting its `ERROR:` line.
3. Fixed dwell (default 120 s).
4. Find the window through the right prefix, strip `\r`, `close` it (or `--hwnd HEX`); treat
   driver rc ≠ 0 as close-failed. Wait ≤ 120 s for the game pid to exit; if still up, SIGTERM the
   **game** pid only (never `steam.exe`) and set `GRACEFUL: no`.
5. Wait for the launcher; then judge (`--judge-only DIR --t0 EPOCH` runs only this step):
   `VOID` = no judged artifact for this run — SceneFlow missing, empty, or first-line timestamp
   ≤ `t0`; `FAIL` = fresh but lacking `MainMenu reached` or `GameManager destroyed`, or
   `Player.log` `InvalidProgramException` > 0; else `PASS`. **`GRACEFUL` is derived from the log
   by the judge** (`GameManager destroyed` present → `yes`); a launch-time SIGTERM fallback in
   step 4 overrides it to `no`. So a fresh-but-truncated log is `FAIL` + `GRACEFUL: no`, while a
   SIGTERM'd run leaves the *previous* SceneFlow in place → stale → `VOID` + `GRACEFUL: no`
   (that is T3). Mods = `Logs/*.log` with mtime > `t0` minus a fixed engine list
   (`SceneFlow`, `FileSystem`, `Automation`, `Modding`), names are arbitrary. Print the numbers,
   then `GRACEFUL: yes|no` and one `VERDICT: PASS|FAIL|VOID` line; exit code follows the verdict.
6. Never inside a tool call that can time out: run detached with a log, poll from short commands.

## I2 — probe hygiene

| script | change |
|---|---|
| `shimmer-probe.sh`, `livedrag-probe.sh` | build `/tmp/winlist` from `scripts/winlist.swift` when absent, exactly as `pixel-probe` is built; the current "no Steam window" abort on a missing `winlist` is a misdiagnosis |
| `livedrag-probe.sh:24-26` | `rm -f /tmp/kg.png` immediately after the size test; the capture of an arbitrary terminal or Claude window must not outlive the check. Also: a missing `/tmp/winlist` fails at `:24` first, so its misdiagnosis reads "known-good capture failed" (`:26`), not "no Steam window" as in shimmer (`:40`) |
| `pixel-probe.swift:37-44` | the actual failure at 10×10 is a **Range trap** at `:37` (`m = 8`, `8..<2`), not the division — `r / n` traps only at exactly `h == 2m`; and `x = w-1-k` (`:54`) goes negative when `depth > w`. Fix: refuse images with `w < 24 \|\| h < 24` (`too small to probe (WxH)`, exit 4), clamp `m < h/2, < w/2`, and clamp `depth ≤ min(w, h) − 2m`. The threshold is what makes exit 4 reachable at all |
| `win-resize-driver.c` — **new verb `move <hwnd> <dx,dy>`**: a **delta** in pixels applied in the parent's client space (`GetWindowRect` → `MapWindowPoints(HWND_DESKTOP, parent)` → `SetWindowPos(x+dx, y+dy, SWP_NOSIZE\|SWP_NOZORDER)`); cross-process, marshalled to the owner thread; `SWP_ASYNCWINDOWPOS` variant if a cell hangs. One spelling in every plan: `move <hwnd> +120,+0` | needed by the design-gaps plan's T1; test: `move` then `rects` readback shows the screen-space origin moved by exactly (dx,dy), `move` back restores it |
| `pixel-probe.swift` — **new mode `strip <x> <w>`** (mean RGB of columns x..x+w over the interior rows) | needed by the design-gaps plan's T1/T2; test: on a capture with a known vertical edge, the strip left of the edge and the strip right of it differ by > 8/channel |
| `win-resize-driver.c` | `list` output is consumed by shell scripts: `_setmode(_fileno(stdout), _O_BINARY)` (+ `<io.h>`, `<fcntl.h>`) as the first statement of `main` (`:100`), before the usage `fprintf` (`:102`); stderr too, since scripts may grep the `STAMP` stream (`:31`). No `printf`→`fputs` change needed. **Keep `tr -d '\r'` in callers permanently**: the `.exe` is gitignored (`.gitignore:34`), so a caller can always be running a binary older than the source |

## I3 — live-drag re-run on the hardened module (human step)

> **Done 2026-09-03 16:36 — C34.** Module `cd79fc463795939f`: 60 frames with 60 distinct window sizes, interior luminance min 76 / median 90 / max 113, 0 gaps. Evidence: cell `livedrag-setup3` (`drag-*.png`, `drag-sizes.txt`).

`bash scripts/livedrag-probe.sh` with James dragging a Steam window edge for ≈ 15 s. Acceptance:
0 near-black frames in ≥ 60, ≥ 10 distinct sizes, and the sampling-rate limit restated (one frame
per ≈ 178 ms; a single-frame flash is below it). Records as a ledger row citing the run directory.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | boot-verify passes on the current module | run detached; read the log | `VERDICT: PASS`, `GRACEFUL: yes`, MainMenu + `GameManager destroyed` timestamps > `t0` | five **launch-free** `--judge-only` fixtures: the real log dir with `--t0 now` → `VOID` (the stale-run trap the project recorded); an empty dir → `VOID`; a zero-byte `SceneFlow.log` → `VOID`; a copy with the `MainMenu reached` line deleted → `FAIL`; a copy with `GameManager destroyed` deleted → `FAIL` + `GRACEFUL: no`; a `Player.log` copy with one `InvalidProgramException` line → `FAIL` |
| T2 | boot-verify refuses a busy prefix | **launch-free fixture**: a process whose argv matches the candidate set and holds a prefix file open — `cp /bin/sleep /tmp/wineserver-fake; (exec 3<"$PREFIX/system.reg"; exec -a wineserver /tmp/wineserver-fake 300) &` — then run | refuses, lists that pid, exit code 2 | n/a |
| T3 | ungraceful path is honest | `--hwnd 1` — a **non-window**, so the driver refuses (`:123`, rc 1) and posts nothing (a wrong hwnd that *is* a window would get WM_CLOSE: the accident `GOTCHAS.md` § CRLF records) | falls back to SIGTERM on the game pid; `GRACEFUL: no`, `VERDICT: VOID` (SceneFlow not flushed); launcher prints `Game exited (rc=143)` and shuts Steam down; `.crash` absent (baseline: absent today). Residue: previous run's SceneFlow stays stale, no save in flight. A full boot cycle |
| T4 | winlist auto-build | **launch-free**: Steam down, delete `/tmp/winlist`; run `shimmer-probe.sh static` | `/tmp/winlist` exists afterwards and the abort is the `SDL_app`/"no Steam window" one, not a winlist failure | n/a |
| T5 | kg.png lifetime | **launch-free**: Steam down, run `livedrag-probe.sh` — it captures `kg.png` before the Steam-window check, so it reaches that abort | `/tmp/kg.png` absent after the abort | drop the `rm` → file present |
| T6 | pixel-probe tiny image | `sips`-made 10×10 PNG (below the 24-px threshold) and a 30×30 PNG (above it) | 10×10: `too small to probe` + exit 4, no trap; 30×30: probes normally | n/a |
| T7 | driver LF output | rebuild the driver and **deploy it to `~/cs2-patch/win-resize-driver.exe`** (the path the probes hardcode; the `.exe` is gitignored), then `list` against that binary: `grep -c 'title='` ≥ 1 (positive control — an empty output also gives 0 CRs) and `grep -c $'\r'` = 0; read the counts, not `grep -c`'s exit status (1 on a zero count) | n/a |
| T8 | live drag (I3) | human | acceptance above | n/a |
| T9 | `move` verb + `strip` mode (the design-gaps plan's fixtures) | `move` a Steam child by +120, `rects` readback, `move` back; `strip` on a capture with a known vertical edge | readback origin changes by exactly +120 and returns; the two strips differ by > 8/channel | n/a |

## Exit criteria
1. `scripts/boot-verify.sh` committed with T1–T3 recorded in its header, and every judge branch
   exercised by a `--judge-only` fixture (T1's five): stale or missing or empty SceneFlow → `VOID`;
   no `MainMenu reached` → `FAIL`; no `GameManager destroyed` → `FAIL` + `GRACEFUL: no`;
   `InvalidProgramException` ≥ 1 → `FAIL`. `docs/agent-brief.md` points at it as *the* way to
   boot-verify.
2. I2 applied, T4–T7 green.
3. I3 run once on the C29 module and recorded (C-row).
4. `move` and `strip` deployed and T9 green — they are prerequisites of the design-gaps plan.

## Sequencing
**First** in the umbrella order (instruments → upstream form → design gaps → DXMT side): every
other plan's boot check and the design-gaps tests depend on what this plan builds.

## Rollback
Scripts only; git revert.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | correctness (launcher, driver, probes read line by line) | 1 agent (shared with the hygiene plan), 10 tool calls | claude-fable-5-1 | `c94d9e9` | needs-rework confined to I1's Behaviour block (wrong log path, `&` instead of `setsid`, undefined verdict state and flags, no judge-only mode); I2/I3 build-ready-with-fixes. I1 rewritten. |
| 2026-09-02 | 1b | cross-plan test-plan audit | 1 agent, 10 tool calls | claude-fable-5-1 | `310e631c` | adequate-with-fixes — launch-free fixtures for T2/T4/T5, the driver deployed before T7, ownership of the `move` verb and `strip` mode. Folded. |
| 2026-09-02 | 2 (fitted re-check of the fold) | one agent over the rewritten sections, cites re-verified against the code and the trace | 1 agent, 11 tool calls | claude-fable-5-1 | `276f43d5` | build-ready-with-fixes — every launcher cite re-verified (`:41-49`, `:63`, `:101`, `:156`, `:157-162`, `:194`, `:200`, `:234`), the SceneFlow path exists; fixes were the VOID/FAIL split in the judge (resolved: judge derives `GRACEFUL`, truncated → `FAIL`), the `move` contract (delta, parent-client space), the missing fixtures. **Cleared for build, first in umbrella order.** |

**Key paths:** `scripts/steam-render-cell.sh` · `scripts/shimmer-probe.sh` · `scripts/livedrag-probe.sh` ·
`scripts/pixel-probe.swift` · `scripts/win-resize-driver.c` · `scripts/winlist.swift` ·
`~/cs2-patch/launch-cs2-dxmt11.sh` · `GOTCHAS.md` (2026-09-02 entries)
