# dxmt#141 — fifth comment: retract the glyph claims (drafted 2026-08-30)

Prior comments: 5400445243 · 5403561498 · 5458926046 · **5466938536** (the one this corrects).

Status: **DRAFTED, NOT POSTED.** Posting is James's call — it is a public correction on someone
else's issue tracker.

**Why it is owed.** Comment 5466938536 went out 2026-08-30 05:33 UTC. An audit the same day found
that 41 of 43 render cells — including every cell in that comment's tables — had run with **no font
library**: wine could not resolve `libfreetype.dylib`, printed one line, and continued with no font
backend. That configuration renders art and no glyphs on its own, which is precisely the observation
the comment attributes to in-process GPU. A second confound hit the same cells: the webhelper shim
was installed in `cef.win7x64` while this client runs `cef.win64`, so `--shim-args` never reached
CEF and the switch-labelled rows may not have had their switch applied at all.

mikey92 is running these configs daily. If they read "in-process GPU costs you text" and it is
actually "your wine has no FreeType", that is a wasted week on their side too.

---

@mikey92 @3Shain — correcting [#5466938536](https://github.com/3Shain/dxmt/issues/141#issuecomment-5466938536).
An audit of my own harness a few hours after posting it found a confound that invalidates the glyph
column of that table, and I would rather flag it than let anyone chase it.

**What was wrong.** 41 of my 43 render cells ran with **no font library at all**. Wine could not
resolve `libfreetype.dylib`, printed its one-line `Wine cannot find the FreeType font library`
notice, and carried on with no font backend. Nothing in my logs or captures made that visible after
the fact, and a client with no font backend **draws art and no glyphs** — which is exactly the
symptom I was attributing to in-process GPU.

So every "zero glyphs" in that table is explained without invoking a GPU mode:

| row in #5466938536 | status now |
|---|---|
| `DXMT` + `--in-process-gpu` → "renders, zero glyphs" | **glyph claim withdrawn** — 14–33 FreeType failures in that cell |
| `DXMT` + `--single-process` → "renders, 1,810,329 B, zero glyphs" | **glyph claim withdrawn** — 17 FreeType failures; the 1.8 MB render stands |
| `--use-angle=swiftshader` → "renders art, no glyphs" (from 08-24) | **glyph claim withdrawn**, same reason |

**A second confound, and it is the more embarrassing one.** My shim was installed in `cef.win7x64`.
This client runs `cef.win64`. So `--shim-args` was accepted, logged, and **silently never reached
CEF** — the switch-labelled rows may have been ordinary launches wearing a label. I have since moved
the shim to `cef.win64` and confirmed it live (`steamwebhelper.exe` now spawns
`steamwebhelper_real.exe` children), so a genuine CPU-raster cell is possible for the first time.
I have not run one yet; when I do I will post it as a measurement, not an inference.

**What in that comment still stands.** The confound is font-specific and does not touch
black-versus-renders judgments or anything measured outside Steam:

- **§2/§3 — the feature-level table** (DXMT `S_OK` / FL 11_1 vs vanilla wined3d
  `DXGI_ERROR_UNSUPPORTED` / FL 9_3). That is `dxgiprobe`, a standalone PE, which resolves its
  libraries normally. Unaffected.
- **§4 — out-of-process on vanilla wined3d: one GPU child, zero crashes, window still black,
  byte-identical across the GL and Vulkan renderers.** A black window is not a font symptom.
- **§5 — the `AppDefaults`-keyed-on-file-name trap.** Re-verifiable mechanism, unaffected.
- **§6 — the notpop/steam-on-m1-wine reading**, and that the fork does not fix the client here.
- **The retraction in §1** (a module load is not a working implementation) stands as written.

**The general lesson, since this is the second retraction I have posted to this thread.** Both times
the error was the same shape: I recorded *what I concluded* and not *the configuration I measured it
under*, so when a premise fell there was no way to tell which results survived. Every cell here now
writes a `config.json` beside its result — engine, prefix, library resolution, shim placement, which
`cef` dir is live, foreign-Steam count — and a cell whose libraries do not resolve is refused rather
than run. Three of my own probes have since turned out to be blind (`wine notepad` logs zero
FreeType failures even with the path unset; `ps eww` cannot read another process's environment on
macOS 26 and returns empty for a sentinel you own; my own precondition check validates the harness's
environment rather than the target's). Each returned a clean, confident, wrong answer.

**Still open, and the honest state of it.** I do not yet know why this engine loses FreeType *only*
under Steam. Eliminated so far: the engine (both mine and Porting Kit's resolve a bare
`dlopen("libfreetype.dylib")` once their own `wine/lib` is on the DYLD path), architecture
(Homebrew's copy is arm64 and could never have been loaded by an x86_64 wine), and variable priority
(`DYLD_LIBRARY_PATH`, searched first, changes nothing — 61 and 59 failures with it set). If anyone
running Steam under wine on macOS wants to check their own client for this, it is one line:

```
grep -c "cannot find the FreeType font library" <your Steam stdout/log>
```

Anything non-zero and your client has been rendering without a font backend, whatever else you were
measuring.
