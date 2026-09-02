# Verification instruments — a committed boot-verify, probe hygiene, and the live-drag re-run

**Status: Not yet triple-checked — run `check it` before build.** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`.

**Why.** On 2026-09-02 the game boot verification took three attempts because the script in use
polled a log at the wrong path, ran the resize driver against the wrong prefix, matched CRLF output
with a `$` anchor, and was killed by a tool timeout that took Steam down with it. Every one of those
is a harness fact, not a game fact, and each cost a launch. The facts are now in `GOTCHAS.md` and
memory; this plan turns them into a script that cannot get them wrong.

---

## I1 — `scripts/boot-verify.sh`

**Facts it encodes (all measured 2026-09-02).**
- `SceneFlow.log` lives at `<game dir>/Logs/SceneFlow.log` and is **flushed on graceful exit**, not
  written live. `Player.log` is live (last write ≈ 60 s after launch when the menu is up).
- The launcher (`~/cs2-patch/launch-cs2-dxmt11.sh`) starts Steam, waits for login + licence
  (≈ 96 s to the game process here), runs `Cities2.exe`, and after the game exits shuts Steam down
  itself. Do not shut Steam down from the script.
- The game window is `class=UnityWndClass title=Cities: Skylines II`; `win-resize-driver.exe close`
  (WM_CLOSE) exits it with rc 0 in ≈ 10 s. The driver needs `WINEPREFIX` exported and prints CRLF.
- A process killed by SIGTERM leaves Steam's `.crash` marker; the launcher clears a stale one, but
  the script should never be the thing that creates it: **run detached** (`&` + log file), poll from
  a separate short command.

**Behaviour.** `boot-verify.sh [--dwell N]`: refuse if anything already runs against the prefix;
record `t0`; start the launcher detached with `CS2_QUIET=1`; wait for the game pid (lsof
attribution, ≤ 240 s); dwell (default 120 s) while `Player.log` grows; find the window through the
right prefix, strip `\r`, post WM_CLOSE; wait ≤ 120 s for exit; if still up, SIGTERM the **game**
pid only (never `steam.exe`) and mark the run `UNGRACEFUL`; wait for the launcher; then judge:
`Logs/SceneFlow.log` first-line timestamp > `t0`, `MainMenu reached` present, `GameManager
destroyed` present, `Player.log` `InvalidProgramException` = 0, count of `Logs/Mods_*.log` +
named mod logs written after `t0`. One `VERDICT:` line at the end, `PASS` / `FAIL` / `VOID`, and
the run's numbers on the lines above it. Exit code follows the verdict.

## I2 — probe hygiene

| script | change |
|---|---|
| `shimmer-probe.sh`, `livedrag-probe.sh` | build `/tmp/winlist` from `scripts/winlist.swift` when absent, exactly as `pixel-probe` is built; the current "no Steam window" abort on a missing `winlist` is a misdiagnosis |
| `livedrag-probe.sh:25-26` | `rm -f /tmp/kg.png` immediately after the size test; the capture of an arbitrary terminal or Claude window must not outlive the check |
| `pixel-probe.swift:37-44` | if the margin leaves an empty range or `n == 0`, print `too small to probe (WxH)` and exit 4 instead of dividing by zero; clamp `m` to `< h/2`, `< w/2` |
| `win-resize-driver.c` | `list` output is consumed by shell scripts: emit LF only (`_setmode`/`\n` via `fputs` to a binary-mode stdout), so `title=Steam$` matches without `tr -d '\r'`; keep the CR-stripping in callers for one release |

## I3 — live-drag re-run on the hardened module (human step)

`bash scripts/livedrag-probe.sh` with James dragging a Steam window edge for ≈ 15 s. Acceptance:
0 near-black frames in ≥ 60, ≥ 10 distinct sizes, and the sampling-rate limit restated (one frame
per ≈ 178 ms; a single-frame flash is below it). Records as a ledger row citing the run directory.

---

## Test plan

| # | test | method | pass | mutant |
|---|---|---|---|---|
| T1 | boot-verify passes on the current module | run detached; read the log | `VERDICT: PASS` with MainMenu + graceful exit | point `--log-dir` at an empty dir → `VERDICT: VOID` (not PASS) |
| T2 | boot-verify refuses a busy prefix | start Steam via the render cell first, then run | refuses with the pid listed | n/a |
| T3 | ungraceful path is honest | make WM_CLOSE fail (wrong hwnd via a `--hwnd` override) | falls back to SIGTERM on the game pid, verdict `UNGRACEFUL`, Steam still shut down cleanly by the launcher, no `.crash` marker | n/a |
| T4 | winlist auto-build | delete `/tmp/winlist`; run `shimmer-probe.sh static` | builds it and scores 40 frames | n/a |
| T5 | kg.png lifetime | run `livedrag-probe.sh` to the "waiting" prompt, abort | `/tmp/kg.png` absent | n/a |
| T6 | pixel-probe tiny image | 10×10 PNG | message + exit 4, no crash | n/a |
| T7 | driver LF output | `list` piped to `grep -c $'\r'` | 0 | n/a |
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
| — | not yet checked | — | — | — | — | — |

**Key paths:** `scripts/steam-render-cell.sh` · `scripts/shimmer-probe.sh` · `scripts/livedrag-probe.sh` ·
`scripts/pixel-probe.swift` · `scripts/win-resize-driver.c` · `scripts/winlist.swift` ·
`~/cs2-patch/launch-cs2-dxmt11.sh` · `GOTCHAS.md` (2026-09-02 entries)
