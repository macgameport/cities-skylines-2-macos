# Build a wine-11.16 + DXMT engine, validate CS2 on a cloned wrapper

**Status: NOT YET CHECKED — run `check it` on this doc before building.**

Goal: retire the alt-tab freeze ([dxmt#206](https://github.com/3Shain/dxmt/issues/206), fixed
upstream by wine `2293b0e` in 11.16) by assembling our own engine — **stock wine 11.16 built from
source + the DXMT binaries we already run** — and validating a full CS2 session on an APFS-cloned
wrapper before touching the daily install.

Non-goals: rebuilding DXMT from source (LLVM-15 toolchain burden; binaries are copied instead);
portable/redistributable engine packaging (v1 links brew dylib paths — repack is a follow-up);
touching the Wine 10 + D3DMetal fallback (S734M stays as-is).

## 1. Facts this plan builds on (all measured on this machine, 2026-08-23)

| Fact | Evidence |
|---|---|
| Wine 11.16 fixes the non-newest-swapchain compositing defect | minrepro3 under WineForge 0.6.0.3 (wine-11.16 + DXMT v0.80): red pulse animates on the older chain; 3 consistent runs |
| Stock 11.16 file IO is clean (the 10-patch stack stays 10) | from-source minimal build: probe 44 OK / 7, zero garbage errno (`docs/wine-bugs/measurement-stock-wine11.16.txt`) |
| The DXMT winemac patch applies to 11.16 | `patch -p1 --dry-run` of `scripts/wineandaqua-dxmt.patch` on the 11.16 tree: 9/9 files, zero fuzz |
| The PE cross-toolchain exists here | brew mingw-w64 GCC 16.1.0, both `x86_64-` and `i686-w64-mingw32-gcc` present |
| ffmpeg/gstreamer are NOT needed | PK engine's `winedmo.so`/`winegstreamer.so` link `@rpath` dylibs the bundle doesn't contain — they cannot load in today's working baseline |
| steam.exe is 64-bit (PE32+) | `file` on the installed Steam; only off-path helpers (uninstaller, crash reporters, fossilize) are PE32 |
| The 10 patches are engine-independent | they live in the game's `mscorlib.dll` inside the prefix, not in the engine |
| PK's DXMT presents via win32u client surfaces, with NO private glue | recon trace (`WINEDEBUG=+macdrv` minrepro3 run): `macdrv_client_surface_update/present` on two surfaces per HWND; PK↔stock-11.16 `win32u.dll` PE export diff = 0/0; no unix-side exports of `macdrv_functions`/bare symbols anywhere (dlopen+dlsym probed: all NULL); DXMT PE dlls import only standard dlls |
| PK's DXMT is a fork build | `v0.80-17-g79f6279`; commit not found in 3Shain/dxmt |

**Prediction (to be settled by gate G1):** because the fork's binding uses interfaces that are
identical between wine 11.0 and 11.16 at the PE boundary, PK's DXMT binaries should work on the
stock 11.16 build. If not, the fallback is WineForge's plain-v0.80 DXMT binaries, whose winemac-side
needs are met by the aquadran patch we compile in (that combination is the one already proven on
11.16 — it produced the minrepro3 fix measurement). Their *wine* was the broken half, never their
DXMT.

## 2. Decisions (settled — do not relitigate during build)

- **Build now**, don't wait for Porting Kit (James, 2026-08-23).
- **Validate on an APFS clone** of the wrapper; the daily `CS2dxmt11.app` is untouched until
  promotion (James, 2026-08-23). This also dodges the prefix-downgrade problem: once a prefix has
  booted under 11.16, rolling it back to a 11.0 engine is not a supported direction — the clone
  eats that risk, the daily prefix never does.
- **Compile the aquadran patch in** even though PK binaries may not need it: it only adds an
  exported shim (`macdrv_functions`), costs nothing when unused, and makes the WineForge-v0.80
  fallback viable in the same engine.
- **Both PE archs** (`i386,x86_64`), matching PK. **No ffmpeg, no gstreamer, no SDL** in v1
  (proven unused / controllers out of scope). **Freetype + gnutls required** (fonts; Steam TLS).

## 3. Prerequisites

| What | Where / how verified |
|---|---|
| wine 11.16 source | `/tmp/wine-11.16` (present; if lost: winehq tarball, 45 MB — re-download and unpack) |
| mingw PE compilers | `/opt/homebrew/bin/{x86_64,i686}-w64-mingw32-gcc` (16.1.0) |
| bison ≥ 3.8 | `/opt/homebrew/opt/bison/bin/bison` (3.8.2; Apple's 2.3 is too old — keg path must be on PATH) |
| gmake | `/opt/homebrew/bin/gmake` (4.4.1) |
| freetype, gnutls | brew, installed |
| **pkg-config** | **MISSING — `brew install pkgconf` first.** Without it configure silently skips freetype/gnutls and the engine ships with broken fonts + no Steam TLS. |
| DXMT binaries (primary) | current PK engine: `…/CS2dxmt11.app/Contents/SharedSupport/wine/lib/wine/{x86_64-unix/winemetal.so, x86_64-windows/{d3d11,dxgi,winemetal}.dll, i386-windows/{d3d11,dxgi,winemetal}.dll}` |
| DXMT binaries (fallback) | WineForge 0.6.0.3 DMG, `github.com/Alien4042x/WineForge`, sha256 `ada28bd6b4be81aac69669a3af0e383380e116b130469c55066dfb5e9956ecbf` — extract `lib/dxmt/` only, discard their wine |
| Patch | `scripts/wineandaqua-dxmt.patch` (in this repo) |
| ~12 GB free in /tmp | build tree ≈ 3.5 GB for one arch; two archs more. ⚠ /tmp does not survive reboot. |

## 4. Build

```bash
brew install pkgconf                     # prereq gap found 2026-08-23
cd /tmp/wine-11.16 && patch -p1 < $HOME/Documents/github/cs2/scripts/wineandaqua-dxmt.patch
mkdir -p /tmp/wine-1116-engine-build && cd /tmp/wine-1116-engine-build
PATH="/opt/homebrew/opt/bison/bin:$PATH" \
../wine-11.16/configure \
  --host=x86_64-apple-darwin --enable-archs=i386,x86_64 \
  --without-x --without-gstreamer --without-sdl --without-cups --without-dbus \
  --without-inotify --without-krb5 --without-netapi --without-opencl --without-pcap \
  --without-pcsclite --without-usb --without-v4l2 \
  CC="clang -arch x86_64" CXX="clang++ -arch x86_64"
# GATE G0 — read the configure summary before building:
#   freetype: yes · gnutls: yes · Mac driver: yes · archs include i386
#   (the probe build passed --disable-winemac-drv --without-freetype --without-gnutls; this one
#    must NOT — a silently-skipped dep here is a broken engine later)
PATH="/opt/homebrew/opt/bison/bin:$PATH" gmake -j12        # ~25 min single-arch; expect more for two
```

Notes: the aquadran patch's `C_ASSERT`s make any winemac struct drift a **compile error** — if the
build fails inside `dlls/winemac.drv/macdrv_main.c`, that is the layout guard firing; stop and
re-derive, don't force. On this host configure demands both `--host` and `--enable-archs` or it
hunts for an aarch64 PE compiler (measured 2026-08-23).

## 5. Assemble the engine

Target layout (mirrors PK so the launcher works unchanged):

```
/tmp/engine-1116/
  bin/wine64            # wine 11 WoW64 builds ship bin/wine — symlink wine64 -> wine
  bin/wineserver
  lib/wine/x86_64-unix/     # all built .so
  lib/wine/x86_64-windows/  # all built PE dlls  + DXMT {d3d11,dxgi,winemetal}.dll (overwrite)
  lib/wine/i386-windows/    #  "        "        + DXMT i386 variants (overwrite)
  lib/*.dylib           # copied from the PK engine: freetype, gnutls(+deps), brotli, MoltenVK
  version               # "wine stock 11.16 + DXMT (self-built)"
```

Build it with `gmake install DESTDIR=` into a staging dir or copy from the build tree
(`loader/wine`, `server/wineserver`, `dlls/*/x86_64-windows/*.dll`, `dlls/*/*.so` — verify the
actual output paths at build time rather than trusting this list). Then overwrite the seven DXMT
files from the PK engine, and copy `winemetal.so` into `lib/wine/x86_64-unix/`.

Dylib note: our .so files link brew paths (`/opt/homebrew/...`) — fine for this machine (v1).
The PK-copied dylibs cover whatever expects `@rpath`/`DYLD_FALLBACK_LIBRARY_PATH` resolution
(the launcher already adds `$SS/wine/lib` to the fallback path).

## 6. Smoke ladder — fresh prefix, no game files at risk

All against `WINEPREFIX=$HOME/.e1116-prefix` (fresh; wine refuses prefixes under /tmp). For the
Mono probe, symlink the game dir into the prefix the same way the stock-11.16 probe did.

| # | Test | Command core | PASS |
|---|---|---|---|
| G1 | DXMT binding + freeze fix | minrepro3 via the new engine's `bin/wine64` (adapt `scripts/run-minrepro3.sh` env: point `SS` at the engine + new prefix) | window renders; **P2B ≠ P2B2 and red reaches screen** (on 11.0 they were byte-identical) |
| G2 | Win32 errno | `errtest.exe` | 9/9 correct |
| G3 | Mono file IO | `monohost.exe filetest_net.exe` (game's own runtime) | **44 OK / 7, zero garbage-errno** |
| G4 | 32-bit PE | any PE32 exe (e.g. Steam's `steamerrorreporter.exe`) | starts (exit code ≠ wine-loader error) |

**Branch at G1:** no window / no D3D11 device / all-black ⇒ the fork's binding didn't survive.
Swap in WineForge's v0.80 DXMT binaries (see §3) and rerun G1. If THAT fails too, stop — the
combination proven on 2026-08-23 has regressed and needs re-derivation, not force.

**Branch at G3:** garbage errno on a *stock* build would contradict the 2026-08-23 measurement —
suspect the assembly (wrong mscorlib state, wrong prefix symlink) before suspecting wine.

## 7. Game validation — on the clone

```bash
# clone (APFS: near-instant, near-zero space; -c = clonefile)
cp -Rc $HOME/Applications/CS2dxmt11.app $HOME/Applications/CS2e1116.app
# swap the engine inside the CLONE only
mv $HOME/Applications/CS2e1116.app/Contents/SharedSupport/wine{,.pk11.0-BAK}
cp -R /tmp/engine-1116 $HOME/Applications/CS2e1116.app/Contents/SharedSupport/wine
```

- Launcher targets the clone explicitly: `CS2_WRAPPER=$HOME/Applications/CS2e1116.app bash
  $HOME/cs2-patch/launch-cs2-dxmt11.sh` (find_wrapper's auto-detect order still prefers the daily
  app, so normal double-click behavior is unchanged during validation).
- **Patch state:** the clone inherits the correct 10-patch mscorlib. Verify by **byte-diff against
  `mscorlib.dll.bak`** (4 bytes, all fshandle: `0x1668c4` `0x0e→0x2b`) — **never** re-run patchers
  to "check" (they apply, not inspect; one-way trap, learned 2026-08-23). `repatch.sh` takes
  `CS2_GAME_DIR` if patching is ever needed on the clone.
- **One Steam at a time:** before booting the clone, `steam.exe -shutdown` in the daily wrapper
  (never `kill -9` — `.crash` marker trap); scope any pgrep by wrapper name
  (`pgrep -f "CS2e1116.app.*steam.exe"`). Second login of the same account kicks the first.
- First boot updates the clone's prefix to 11.16 (expected, one-time, silent or a wineboot dialog).

Checklist (each row = measured, not assumed; judge only runs whose logs postdate the change):

| # | Test | PASS |
|---|---|---|
| V1 | Steam boots, logs in, library renders | client usable (also re-confirms the dxmt#141 negative on 11.16) |
| V2 | Game boots to main menu | no licence errors, no new ⚠ markers vs baseline `SceneFlow.log` |
| V3 | City load + 10 min play | stable; FPS within ~10% of the 42.7 baseline (HUD, `CS2_HUD=1`) |
| V4 | **Exclusive Fullscreen + alt-tab, repeatedly, + click-outside** | **no freeze — the whole point** |
| V5 | Game Mode in exclusive fullscreen | HUD reports Game Mode On (it's Off in borderless); note FPS delta |
| V6 | In-game Paradox Mods download (the §11 `PrepareFolderForPatching` path) | mod downloads + loads; check disk, not the UI |
| V7 | Second-display / refresh-rate gotcha | no blackout regression (GOTCHAS § second display) |
| V8 | Save, quit, relaunch, load | save intact |

## 8. Promotion (after V1–V8 green)

1. Point the daily shortcut at the clone: edit `~/Applications/Cities Skylines II.app/Contents/
   MacOS/launch` to export `CS2_WRAPPER=$HOME/Applications/CS2e1116.app` (one line, next to
   `SCRIPT=`; game closed — never edit launch scripts while running).
2. Launcher comment: exclusive Fullscreen becomes recommendable again; borderless remains the
   fallback note for PK-11.0 users.
3. Docs: README (stack description + measured FPS if changed), INSTALL (self-built-engine section
   or "still PK 11.0 for strangers" — see decision below), PLAN.md (fold this plan's outcome),
   GOTCHAS (anything new), `docs/wine-bugs/README.md` (the standing probe action's status),
   ledger entry, memory files.
4. Report the working combination on dxmt#206 (stock 11.16 + which DXMT binaries + game-level
   confirmation) — closes the loop for the maintainer and for anyone landing there.
5. **Decision for James at this point:** publish `scripts/build-engine-1116.sh` + INSTALL section
   so strangers can reproduce, or keep the public recommendation at PK 11.0 + borderless until a
   public clean-base engine exists. (The repo's audience currently installs via Porting Kit.)
6. Retirement of the old engine/wrapper: keep `CS2dxmt11.app` untouched for ≥1 week of daily play
   on the clone, then decide.

## 9. Rollback map

| After step | Rollback |
|---|---|
| Build/assembly | delete /tmp dirs — nothing installed |
| Smoke ladder | `rm -rf $HOME/.e1116-prefix` (⚠ unlink the game-dir symlink first — it points at the real install) |
| Clone validation | `rm -rf $HOME/Applications/CS2e1116.app` — daily app never touched |
| Engine swap in clone | `mv wine.pk11.0-BAK` back (but simpler: delete the clone) |
| Promotion | revert the one `CS2_WRAPPER=` line in the shortcut |

## 10. Risks / open questions

- **Fork-binding survival (G1)** — the headline unknown; both outcomes are handled in §6.
- **i386 PE build breakage** — mingw 16.1 building wine 11.16's i386 side is untested here. If it
  fails and the fix isn't obvious: drop to `--enable-archs=x86_64` and accept G4 as a known
  limitation (steam.exe is 64-bit; the PE32 set is off-path — V1–V8 are the real arbiter).
- **Brew-path coupling** — engine breaks if brew upgrades/removes freetype/gnutls majors. Accept
  for v1; note in ledger.
- **Prefix forward-migration surprises** — first 11.16 boot mutates the clone's prefix. That risk
  is confined to the clone by design.
- **Game Mode claim (V5)** — "exclusive fullscreen ⇒ Game Mode eligible" is a hypothesis from the
  HUD's borderless reading; V5 measures it, and a negative result changes nothing else.

## 11. Exit criteria

1. G1–G4 pass with recorded outputs (a `docs/wine-bugs/measurement-engine1116.txt`).
2. V1–V8 pass, with the alt-tab test (V4) exercised hard, and FPS recorded.
3. Daily shortcut promoted; docs + ledger + memory updated; dxmt#206 informed.
4. A rollback path exists at every stage and the daily wrapper was never modified pre-promotion.

## Review log

Key paths: `scripts/wineandaqua-dxmt.patch` · `scripts/{minrepro3.c,run-minrepro3.sh,errtest.c,monohost.c,filetest_net.cs}` · `docs/wine-bugs/` · `$HOME/cs2-patch/{launch-cs2-dxmt11.sh,repatch.sh}` · `/tmp/wine-11.16` (volatile)

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | not yet checked |
