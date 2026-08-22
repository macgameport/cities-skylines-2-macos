# Contributing

Mostly a personal field log, but corrections and confirmations are welcome — especially:

- **Different hardware / macOS versions.** Everything here is verified on one M3 Max. Whether it
  holds on M1/M2/M4 or other macOS releases is genuinely unknown.
- **Upstream fixes.** If a Wine release fixes R1/R2/R3 (see `README.md`), that retires patches —
  please say so and I'll mark them obsolete rather than leaving dead workarounds documented as live.
- **Game updates.** A CS2 update moves IL offsets. Every patch pattern-matches and refuses rather
  than corrupting, so the failure is loud — but the offsets then need re-deriving.

## House rules earned the hard way

1. **Don't assert behaviour you haven't read.** Several dead ends here came from inheriting a
   plausible-sounding diagnosis. The biggest one — a "reader→writer deadlock" that four patches
   chased — *did not exist*; reading the IL showed mutually exclusive branches.
2. **Verify against disk, not the UI.** A mod that looks installed may not be. Check bytes.
3. **Timestamps matter.** Only judge a run whose log start postdates the change being tested.
   Stale-run readings caused at least two wrong conclusions.
4. **In-place byte patches over relocation.** Same byte count means no branch-target, offset or
   exception-clause shifts. Relocating a `.ctor` breaks early-init resolution specifically.
5. **Check stack balance on both branch paths** before applying, or you get "Invalid IL" at runtime.
6. **Boot-verify anything touching `mscorlib`.** It's on the boot path.

## Out of scope

Licence-check circumvention. One patch in the private set bypasses a middleware signature check
that fails *only* because Wine's `BCryptVerifySignature` is broken — the licence itself is valid and
present. That tool is deliberately not published here; **fixing the Wine bug is the correct route**
and removes the need for it. Please don't send PRs adding it.
