# Agent brief — read this first

One screen. A subagent receives the project `CLAUDE.md` and the memory *index* in its prompt
(measured 2026-09-02: two review lenses quoted their own), but not this conversation, the memory
bodies, or the shortcuts — so everything below would otherwise be re-derived by grep, or guessed. Full detail:
`CLAUDE.md`, `EXPERIMENTS.md`, `GOTCHAS.md` (headings only — it is 2,500 lines, never read whole).

## What this project is

macOS port notes for Cities: Skylines II under Wine + DXMT. Personal-tier: **no phases, no
SPEC.md**; GitHub Issues ARE enabled (umbrella issues for multi-item work). Durable record = this
repo + its issues + `~/cs2-patch/change-ledger.txt`.
Patch scripts live in `~/cs2-patch/`, deliberately outside the repo.

## Evidence rules — the ones that bite

1. **A result without its config is an anecdote.** Every render cell runs
   `scripts/cell-fingerprint.sh --strict` first; it writes `config.json` beside the result and
   refuses on a precondition that would void the run. No `config.json` → `UNREVIEWED`, not a result.
2. **Do not cite a pre-2026-08-30 cell as evidence.** 41 of 43 ran with no font library and are
   marked `VOID-LIBS` in `EXPERIMENTS.md`. Check the ledger's index before quoting any cell.
3. **Three columns, never fused: Config · Measured · Inferred.** When a premise falls, retract the
   *inference* and keep the *measurement*.
4. **Never assert a code behavior you have not opened.** Counts are `grep -c`, not impressions.

## Traps that produce a wrong answer rather than no answer

- **Never attribute a wine process by command line.** Webhelper children and a self-restarted
  `steam.exe` all carry Windows-style argv. Attribute by open files against the **prefix**:
  `lsof -p <pid> | grep -q "<prefix>"`.
- **Never `kill -9` Steam.** It leaves a 0-byte `.crash` marker that makes the next launch exit 1.
  Use `steam.exe -shutdown`, then `WINEPREFIX=<prefix> wineserver -k`.
- **Read the real exit code.** `<cmd> | tail` reports *tail's* status — a failing gate announces
  itself as exit 0. This has bitten builds, suites, and a precondition script in this repo.
- **Never edit a `launch-cs2*.sh` while the game is running.** Bash reads scripts incrementally; a
  mid-run edit shifts byte offsets and produces a bogus syntax error.
- **Judge runs by timestamp** — only read a run whose `SceneFlow.log` first line postdates the change.
- **Boot-verify with `bash scripts/boot-verify.sh`, detached, and read its `VERDICT:` line.** Never
  hand-roll a boot check: the `Logs/SceneFlow.log` path (written live; only `GameManager destroyed`
  is exit-only), the driver's CRLF output, the
  right prefix and the process-group kill are all encoded there (three attempts without it,
  2026-09-02). `--selftest` exercises every judge branch with no launch; `--judge-only DIR --t0 EPOCH`
  judges an existing run.

## Privacy — the repo is public

- **Never commit a screenshot.** `*.png` is gitignored except `docs/images/`, which is the publish
  path and needs a deliberate check first: Steam windows carry the **persona name** (top-right and
  as a nav item) and the **avatar**.
- Keep Steam IDs, `[U:1:<n>]`, real usernames and absolute `/Users/<name>` paths out of committed
  files — use `$HOME`, `$WINEUSER`, `<REDACTED>`.
- Cell `stdout.txt` / `windows.txt` were audited clean and are quotable. Evidence (including PNGs)
  lives in `~/cs2-patch/evidence/`, outside the repo.
- `known-good.png` captures an arbitrary browser window — never retain it.

## If you run `gh`

Claude's Bash tool runs **bash** and does not source `~/.zshrc`, so bare `gh` posts as the wrong
identity. Always: `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh …`, and verify with `gh auth status`
before anything public.

No `CLAUDE.local.md` at the repo root is not a broken checkout: it is gitignored, so it exists
only in the worktree that created it — you are on a fresh clone or a **git worktree** (this
harness can hand a subagent its own). Do not push or post until identity is set up; the rule
above is the mechanics either way.
