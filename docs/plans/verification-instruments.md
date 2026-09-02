# Verification instruments — a committed boot-verify, probe hygiene, and the live-drag re-run

**Status: check-it'd 2026-09-02 — needs-rework on I1 as first written, rewritten below; fitted re-check pending before build.** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`.

**Why.** On 2026-09-02 the game boot verification took three attempts because the script in use
polled a log at the wrong path, ran the resize driver against the wrong prefix, matched CRLF output
with a `$` anchor, and was killed by a tool timeout that took Steam down with it. Every one of those
is a harness fact, not a game fact, and each cost a launch. The facts are now in `GOTCHAS.md` and
memory; this plan turns them into a script that cannot get them wrong.

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
5. Wait for the launcher; then judge (`--judge-only` runs only this step on a given log dir):
   `VOID` = SceneFlow missing, empty, or first-line timestamp ≤ `t0`; `FAIL` = fresh but lacking
   `MainMenu reached` or `GameManager destroyed`, or `Player.log` `InvalidProgramException` > 0;
   else `PASS`. Mods = `Logs/*.log` with mtime > `t0` minus a fixed engine list
   (`SceneFlow`, `FileSystem`, `Automation`, `Modding`), names are arbitrary. Print the numbers,
   then `GRACEFUL: yes|no` and one `VERDICT: PASS|FAIL|VOID` line; exit code follows the verdict.
6. Never inside a tool call that can time out: run detached with a log, poll from short commands.

## I2 — probe hygiene

| script | change |
|---|---|
| `shimmer-probe.sh`, `livedrag-probe.sh` | build `/tmp/winlist` from `scripts/winlist.swift` when absent, exactly as `pixel-probe` is built; the current "no Steam window" abort on a missing `winlist` is a misdiagnosis |
| `livedrag-probe.sh:24-26` | `rm -f /tmp/kg.png` immediately after the size test; the capture of an arbitrary terminal or Claude window must not outlive the check. Also: a missing `/tmp/winlist` fails at `:24` first, so its misdiagnosis reads "known-good capture failed" (`:26`), not "no Steam window" as in shimmer (`:40`) |
| `pixel-probe.swift:37-44` | the actual failure at 10×10 is a **Range trap** at `:37` (`m = 8`, `8..<2`), not the division — `r / n` traps only at exactly `h == 2m`; and `x = w-1-k` (`:54`) goes negative when `depth > w`. Fix: refuse images with `w < 24 \|\| h < 24` (`too small to probe (WxH)`, exit 4), clamp `m < h/2, < w/2`, and clamp `depth ≤ min(w, h) − 2m`. The threshold is what makes exit 4 reachable at all |
| `win-resize-driver.c` | `list` output is consumed by shell scripts: `_setmode(_fileno(stdout), _O_BINARY)` (+ `<io.h>`, `<fcntl.h>`) as the first statement of `main` (`:100`), before the usage `fprintf` (`:102`); stderr too, since scripts may grep the `STAMP` stream (`:31`). No `printf`→`fputs` change needed. **Keep `tr -d '\r'` in callers permanently**: the `.exe` is gitignored (`.gitignore:34`), so a caller can always be running a binary older than the source |

## I3 — live-drag re-run on the hardened module (human step)

`bash scripts/livedrag-probe.sh` with James dragging a Steam window edge for ≈ 15 s. Acceptance:
0 near-black frames in ≥ 60, ≥ 10 distinct sizes, and the sampling-rate limit restated (one frame
per ≈ 178 ms; a single-frame flash is below it). Records as a ledger row citing the run directory.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | boot-verify passes on the current module | run detached; read the log | `VERDICT: PASS`, `GRACEFUL: yes`, MainMenu + `GameManager destroyed` timestamps > `t0` | three **launch-free** `--judge-only` mutants: the real log dir with `--t0 now` → `VOID` (the stale-run trap the project recorded); an empty dir → `VOID`; a copy with the `MainMenu reached` line deleted → `FAIL` |
| T2 | boot-verify refuses a busy prefix | start Steam via the render cell first, then run | refuses with the pid listed | n/a |
| T3 | ungraceful path is honest | `--hwnd 1` — a **non-window**, so the driver refuses (`:123`, rc 1) and posts nothing (a wrong hwnd that *is* a window would get WM_CLOSE: the accident `GOTCHAS.md` § CRLF records) | falls back to SIGTERM on the game pid; `GRACEFUL: no`, `VERDICT: VOID` (SceneFlow not flushed); launcher prints `Game exited (rc=143)` and shuts Steam down; `.crash` absent (baseline: absent today). Residue: previous run's SceneFlow stays stale, no save in flight. A full boot cycle |
| T4 | winlist auto-build | delete `/tmp/winlist`; run `shimmer-probe.sh static` | builds it and scores 40 frames | n/a |
| T5 | kg.png lifetime | run `livedrag-probe.sh` to the "waiting" prompt, abort | `/tmp/kg.png` absent | n/a |
| T6 | pixel-probe tiny image | 10×10 PNG (below the 24-px threshold) and a 30×30 PNG (above it) | 10×10: `too small to probe` + exit 4, no trap; 30×30: probes normally | n/a |
| T7 | driver LF output | `list` output: `grep -c 'title='` ≥ 1 (positive control — an empty output also gives 0 CRs) and `grep -c $'\r'` = 0; read the counts, not `grep -c`'s exit status (1 on a zero count) | n/a |
| T8 | live drag (I3) | human | acceptance above | n/a |

## Exit criteria
1. `scripts/boot-verify.sh` committed with T1–T3 recorded in its header; `docs/agent-brief.md`
   points at it as *the* way to boot-verify.
2. I2 applied, T4–T7 green.
3. I3 run once on the C29 module and recorded (C-row).

## Rollback
Scripts only; git revert.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | correctness (launcher, driver, probes read line by line) | 1 agent (shared with the hygiene plan), 10 tool calls | claude-fable-5-1 | `c94d9e9` | needs-rework confined to I1's Behaviour block (wrong log path, `&` instead of `setsid`, undefined verdict state and flags, no judge-only mode); I2/I3 build-ready-with-fixes. I1 rewritten above; **a fitted re-check of the rewrite is required before build.** |

**Key paths:** `scripts/steam-render-cell.sh` · `scripts/shimmer-probe.sh` · `scripts/livedrag-probe.sh` ·
`scripts/pixel-probe.swift` · `scripts/win-resize-driver.c` · `scripts/winlist.swift` ·
`~/cs2-patch/launch-cs2-dxmt11.sh` · `GOTCHAS.md` (2026-09-02 entries)
