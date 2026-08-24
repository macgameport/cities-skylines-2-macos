# Build a wine-11.16 + DXMT engine, validate CS2 on a cloned wrapper

**Status: Triple-checked 2026-08-23 — build-ready-with-fixes (pass 1). Corrections folded; see
`## Review corrections` and the Review log.**

Goal: retire the alt-tab freeze ([dxmt#206](https://github.com/3Shain/dxmt/issues/206)) by
assembling our own engine — **stock wine 11.16 built from source + the DXMT binaries we already
run** — and validating a full CS2 session on an APFS-cloned wrapper before touching the daily
install.

Non-goals: rebuilding DXMT from source (LLVM-15 toolchain burden; binaries are copied instead);
portable/redistributable engine packaging (repack is a follow-up — see §8's recording-vs-publishing
split); touching the Wine 10 + D3DMetal fallback (S734M stays as-is).

## 1. Facts this plan builds on (all measured on this machine, 2026-08-23)

| Fact | Evidence |
|---|---|
| Wine 11.16 fixes the non-newest-swapchain compositing defect; the fix is **upstream** | minrepro3 under WineForge 0.6.0.3 (wine-11.16 + DXMT v0.80): red pulse animates on the older chain, 3 consistent runs. The 11.15→11.16 upstream window contains exactly two candidate commits — `1a1d1f3f3` *"winemac.drv: Hide client_view when flushing window surfaces"* (in the winemac path) and `2293b0e8c` *"win32u: Keep unused client surfaces around and reuse them"* (its reuse machinery is reachable only from win32u's GL/VK paths) — **both are in the stock tarball**, so the stock build carries the fix whichever it is. G1 confirms empirically. |
| Stock 11.16 file IO is clean (the 10-patch stack stays 10) | from-source minimal build: probe 44 OK / 7, zero garbage errno (`docs/wine-bugs/measurement-stock-wine11.16.txt`) |
| The DXMT winemac patch applies to 11.16 | `patch -p1 --dry-run` of `scripts/wineandaqua-dxmt.patch`: 9/9 files, zero fuzz |
| The PE cross-toolchain exists here | brew mingw-w64 GCC 16.1.0, both `x86_64-` and `i686-w64-mingw32-gcc` |
| **brew's freetype/gnutls are arm64-only; the PK engine bundles x86_64 dylibs** | `file` on `/opt/homebrew/opt/{freetype,gnutls}/lib/*.dylib` → arm64; on the PK engine's `lib/{libfreetype.6,libgnutls.30,libMoltenVK}.dylib` → x86_64, with unversioned `-l` symlinks present. An x86_64 build must link the PK dylibs; headers come from brew (arch-neutral). |
| ffmpeg/gstreamer are NOT needed | PK engine's `winedmo.so`/`winegstreamer.so` link `@rpath` dylibs the bundle doesn't contain — they cannot load in today's working baseline |
| steam.exe is 64-bit (PE32+) | `file` on the installed Steam; only off-path helpers (uninstaller, crash reporters, fossilize) are PE32 |
| The 10 patches are engine-independent | they live in the game's `mscorlib.dll` (and sibling dlls) inside the prefix, not in the engine. The mscorlib delta specifically is fshandle-only: 4 bytes at `0x1668c4` |
| PK's DXMT presents via win32u client surfaces, with no private glue **at the PE boundary** | recon trace: `macdrv_client_surface_update/present` on two surfaces per HWND; PK↔stock-11.16 `win32u.dll` PE export diff = 0/0; no unix-side exports of `macdrv_functions`/bare symbols (dlopen+dlsym probed: all NULL). ⚠ Scope caveat: the unix-side `.so` ABI (where `winemetal.so` sits) is *not* stable across Wine releases and was not measured — G1 is the arbiter, not this row. |
| PK's DXMT is a fork build | `v0.80-17-g79f6279`; commit not found in 3Shain/dxmt |

**Prediction (settled by gate G1):** PK's DXMT binaries should work on the stock 11.16 build. If
not, the fallback is WineForge's plain-v0.80 DXMT binaries, whose winemac-side needs are met by the
aquadran patch we compile in (the combination already proven on 11.16). Their *wine* was the broken
half, never their DXMT.

## 2. Decisions (settled — do not relitigate during build)

- **Build now**, don't wait for Porting Kit (James, 2026-08-23).
- **Validate on an APFS clone**; the daily `CS2dxmt11.app` is untouched until promotion (James,
  2026-08-23). This also confines the prefix-forward-migration risk: a prefix that has booted
  11.16 must never run under the 11.0 engine again — only the clone's ever does.
- **Staged build:** pass 1 is `x86_64`-only — the arch the probe build already proved — so G1 (the
  only plan-killing question) is answered as early as possible. The `i386,x86_64` full build is
  pass 2, run only after G1 is green. Costs one extra configure+build in the success case; saves
  the whole i386 debugging tail in the failure case.
- **Compile the aquadran patch in** even though PK binaries may not need it: it only adds an
  exported shim, costs nothing when unused, and makes the WineForge-v0.80 fallback viable in the
  same engine.
- **Promotion is a RENAME, not a config edit** (§8): the wrapper name `CS2dxmt11.app` is the key
  every script resolves against; the engine version is a label and lives in the engine's `version`
  file. `CS2e1116.app` exists only during validation.
- **Link PK's x86_64 dylibs** for freetype/gnutls/MoltenVK (brew's are arm64); brew supplies
  headers only. **No ffmpeg, no gstreamer, no SDL** (proven unused / out of scope).

## 3. Prerequisites

| What | Where / how verified |
|---|---|
| wine 11.16 source | `/tmp/wine-11.16` (present, pristine — patch a COPY, §4). If lost: winehq tarball, 45 MB; compare sha256 against winehq's published checksum after download. |
| mingw PE compilers | `/opt/homebrew/bin/{x86_64,i686}-w64-mingw32-gcc` (16.1.0) |
| bison ≥ 3.8 / gmake | `/opt/homebrew/opt/bison/bin/bison` (3.8.2, keg — must be prepended to PATH) · `gmake` 4.4.1 |
| **pkg-config** | **MISSING — `brew install pkgconf` first.** Without it (and without the explicit `*_CFLAGS/_LIBS` vars in §4) configure **hard-aborts** on freetype; gnutls would degrade **silently** to "no schannel support" = broken Steam TLS. |
| x86_64 link libraries | the PK engine's `lib/` (`PKLIB` below): freetype, gnutls(+deps), MoltenVK, brotli — all x86_64, verified by `file` |
| DXMT binaries (primary) | PK engine: `lib/wine/{x86_64-unix/winemetal.so, x86_64-windows/{d3d11,dxgi,winemetal}.dll, i386-windows/{d3d11,dxgi,winemetal}.dll}` |
| DXMT binaries (fallback) | WineForge 0.6.0.3 DMG, `github.com/Alien4042x/WineForge`. **Before mounting:** `shasum -a 256 WineForge.dmg` must equal `ada28bd6b4be81aac69669a3af0e383380e116b130469c55066dfb5e9956ecbf`; on mismatch, stop — don't force. Extract `lib/dxmt/` only, discard their wine. |
| Patch | `scripts/wineandaqua-dxmt.patch` (in this repo) |
| Disk | ~3.5 GB build tree per arch + ~1.5 GB installed engine + ~1 GB fresh prefix, all under /tmp or `$HOME`. ⚠ /tmp does not survive reboot: a mid-project reboot means re-download + re-copy + re-patch (~30 min). Accepted. |
| Display | G1's harness screenshots the screen: **display awake + unlocked**, region (100,100)-(900,700) unobstructed. (Demonstrated 2026-08-23: a locked display aborts the run cleanly now.) |

## 4. Build — pass 1 (x86_64 only, fastest path to G1)

```bash
brew install pkgconf
# patch a COPY — /tmp/wine-11.16 stays pristine (it produced the §1 clean-IO measurement)
cp -Rc /tmp/wine-11.16 /tmp/wine-11.16-dxmt
cd /tmp/wine-11.16-dxmt && patch -p1 < $HOME/Documents/github/cs2/scripts/wineandaqua-dxmt.patch
# NOTE: patch must land BEFORE configure — it modifies dlls/winemac.drv/Makefile.in.

PKLIB="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/wine/lib"
mkdir -p /tmp/wine-1116-build-p1 && cd /tmp/wine-1116-build-p1
PATH="/opt/homebrew/opt/bison/bin:$PATH" \
../wine-11.16-dxmt/configure \
  --prefix=/tmp/engine-1116 \
  --host=x86_64-apple-darwin --enable-archs=x86_64 \
  --without-x --without-gstreamer --without-sdl --without-cups --without-dbus \
  --without-inotify --without-krb5 --without-netapi --without-opencl --without-pcap \
  --without-pcsclite --without-usb --without-v4l2 \
  CC="clang -arch x86_64" CXX="clang++ -arch x86_64" \
  LDFLAGS="-L$PKLIB" \
  FREETYPE_CFLAGS="-I/opt/homebrew/opt/freetype/include/freetype2" \
  FREETYPE_LIBS="-L$PKLIB -lfreetype" \
  GNUTLS_CFLAGS="-I/opt/homebrew/opt/gnutls/include" \
  GNUTLS_LIBS="-L$PKLIB -lgnutls" \
  ac_cv_lib_soname_freetype=libfreetype.dylib \
  ac_cv_lib_soname_gnutls=libgnutls.dylib
```

The two `ac_cv_lib_soname_*` cache vars are required, not optional (**found at G0, 2026-08-23**):
PK's dylibs carry pathless install names, and configure's soname extraction then captures a whole
`otool -L` line — tab, version parenthetical and all — into `SONAME_LIBFREETYPE`/`_LIBGNUTLS`.
Wine would `dlopen()` that garbage at runtime and silently lose fonts + schannel, the exact
failure this gate exists to catch. Bare names are correct: the launcher's
`DYLD_FALLBACK_LIBRARY_PATH` resolves them against the engine's `lib/`, same as PK's own engine.

**GATE G0 — configure prints no summary table; verify from its outputs, and STOP on failure:**

```bash
grep -E 'SONAME_LIBFREETYPE|SONAME_LIBGNUTLS|SONAME_LIBMOLTENVK' include/config.h  # all three present
grep -n 'enable_winemac_drv' config.log | tail -1                                  # must end =yes
# re-read configure's closing warning list: any "libgnutls ... no schannel support" = STOP.
# (freetype missing is a HARD configure error — it cannot pass silently.)
```

Record these lines into `docs/wine-bugs/measurement-engine1116.txt` (§11). Then:

```bash
PATH="/opt/homebrew/opt/bison/bin:$PATH" gmake -j12 install   # ~25 min (measured for this config)
```

If the build fails inside `dlls/winemac.drv`, the patch's field references no longer match
winemac — stop and re-derive, don't force. (The patch's `C_ASSERT`s pin its own DXMT-facing shim
ABI, not wine's structs; wine-side drift surfaces as ordinary compile errors on the named fields.)

**Pass 2 (only after G1–G3 are green):** fresh build dir, same invocation but
`--enable-archs=i386,x86_64` (uses `i686-w64-mingw32-gcc`; new-WoW64 — PE-side only, no 32-bit
unix libs involved). ≈45–60 min, unmeasured. Re-run the §5 overlay including the i386 DXMT dlls,
then G4. If the i386 build breaks and the fix isn't obvious: waive per §10, stay x86_64-only.

## 5. Assemble the engine

`gmake install` (with `--prefix=/tmp/engine-1116`) lays out `bin/{wine,wineserver}`,
`lib/wine/{x86_64-unix,x86_64-windows[,i386-windows]}` (PE dlls **and** exes — wineboot, services,
explorer live here), and `share/wine/{wine.inf,nls,fonts,winmd}`. Wine resolves everything
relative to the binary (`dladdr` → `bin/`↔`lib/wine`↔`share/wine`), so the tree is relocatable
into the wrapper later. Then overlay:

```bash
E=/tmp/engine-1116
PK="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/wine"
ln -s wine "$E/bin/wine64"                      # launcher hard-requires bin/wine64 (and checks -x)
cp "$PK/lib/wine/x86_64-unix/winemetal.so" "$E/lib/wine/x86_64-unix/"
for d in d3d11 dxgi winemetal; do
  cp "$PK/lib/wine/x86_64-windows/$d.dll" "$E/lib/wine/x86_64-windows/"
done                                            # pass 2 adds the same loop for i386-windows
cp -R "$PK"/lib/*.dylib "$E/lib/"               # freetype/gnutls/deps/MoltenVK (x86_64)
cp -R "$PK"/share/wine/gecko "$PK"/share/wine/mono "$E/share/wine/" 2>/dev/null \
  || echo "no bundled gecko/mono — use WINEDLLOVERRIDES=\"mscoree,mshtml=\" for the fresh prefix"
printf 'wine stock 11.16 + DXMT (self-built)\n' > "$E/version"
```

**Pre-G1 self-consistency check** (separates "assembly wrong" from "fork binding failed"):

```bash
"$E/bin/wine64" --version                        # must print wine-11.16
ls -la "$E"/lib/wine/x86_64-unix/winemetal.so "$E"/lib/wine/x86_64-windows/{d3d11,dxgi,winemetal}.dll
otool -L "$E/lib/wine/x86_64-unix/winemac.so" | grep -i freetype   # resolves against $E/lib or PKLIB
```

(Hand-copying from the build tree instead of `gmake install` is a fallback only; its manifest is
`loader/wine`, `server/wineserver`, `dlls/*/*.so`, `dlls/*/{x86_64,i386}-windows/*`,
`programs/*/{x86_64,i386}-windows/*`, `loader/wine.inf` → `share/wine/`, `nls/*.nls` →
`share/wine/nls/`, `fonts/*` → `share/wine/fonts/`.)

## 6. Smoke ladder — fresh prefix, no game files at risk

Fixture prep (identical to the §1 stock-11.16 baseline: the symlinked mscorlib is the live
10-patch one, whose mscorlib delta is fshandle-only — the six errno-tolerance patches are absent,
which is what makes G3 meaningful):

```bash
export CS2_WINE=/tmp/engine-1116/bin/wine64 CS2_PREFIX=$HOME/.e1116-prefix
export WINEESYNC=1 WINEMSYNC=1                  # match the launcher's environment
mkdir -p "$HOME/.e1116-prefix/drive_c/Program Files (x86)/Steam/steamapps/common"
ln -s "$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II" \
      "$HOME/.e1116-prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
```

The G-probes write only under the fresh prefix's `C:\` (verified for the baseline run); the game
dir is touched read-only.

| # | Test | Command | PASS |
|---|---|---|---|
| G1 | DXMT binding + freeze fix | **Control first, same session, display awake:** `bash scripts/run-minrepro3.sh /tmp/g1-control` with the seams UNSET (daily engine) → computed verdict must be `STALE (bug PRESENT)`. Then with the seams set as above: `bash scripts/run-minrepro3.sh /tmp/g1-new` | control = STALE **and** candidate = `LIVE (fix PRESENT)` — both computed by the harness (hardened 2026-08-23: timeouts abort, snapshots abort on failed capture, verdict computed from pixels). First run: take one full-screen screenshot to confirm the fixed crop still lands inside the client area. |
| G2 | Win32 errno | `x86_64-w64-mingw32-gcc -O2 -o scripts/errtest.exe scripts/errtest.c` (not yet compiled), then `"$CS2_WINE" scripts/errtest.exe 'C:\errprobe'` | 9/9 correct |
| G3 | Mono file IO | `"$CS2_WINE" scripts/monohost.exe scripts/filetest_net.exe` | **44 OK / 7, zero garbage-errno**; save the full output into the measurement file |
| G4 | 32-bit PE (pass 2 only) | `i686-w64-mingw32-gcc -O2 -o scripts/errtest32.exe scripts/errtest.c`, run it | same 9/9 bar as G2 — a real outcome, not "didn't explode". Waivable per §10. |

**Branch at G1:** control ≠ STALE ⇒ the harness isn't discriminating today (display/layout
changed) — fix the harness question first, conclude nothing. Candidate not LIVE with a good
control ⇒ the fork's binding didn't survive: swap in WineForge's v0.80 DXMT binaries (§3, verify
sha first) and rerun. If THAT fails too, stop — the proven combination has regressed; re-derive,
don't force.

**Branch at G3:** garbage errno on a stock build contradicts the §1 measurement — suspect the
assembly (wrong mscorlib state, wrong symlink) before suspecting wine.

## 7. Game validation — on the clone

**Preconditions, in order (a torn clone fails V1 for reasons unrelated to the engine):**

1. Game closed. Daily Steam shut down: `steam.exe -shutdown` via the daily wrapper (never
   `kill -9` — `.crash` marker trap); then `pgrep -f "CS2dxmt11.app.*steam.exe" | wc -l` must be 0.
2. **Launcher fix synced:** the repo launcher now passes `CS2_GAME_DIR="$GDIR"` to repatch.sh
   (fixed 2026-08-23 — without it, every clone launch silently re-patched the *daily* wrapper,
   falsifying §11's isolation criterion). Run `bash scripts/setup.sh` once to install it to
   `~/cs2-patch/` (it backs up the old launcher; that backup is the rollback).

```bash
cp -Rc "$HOME/Applications/CS2dxmt11.app" "$HOME/Applications/CS2e1116.app"   # ~97 GB tree —
#   APFS clonefile: near-zero new space, but the tree walk takes real minutes; let it finish
mv "$HOME/Applications/CS2e1116.app/Contents/SharedSupport/wine"{,.pk11.0-BAK}
cp -R /tmp/engine-1116 "$HOME/Applications/CS2e1116.app/Contents/SharedSupport/wine"
```

- Launch the clone explicitly: `CS2_WRAPPER=$HOME/Applications/CS2e1116.app bash
  $HOME/cs2-patch/launch-cs2-dxmt11.sh` (auto-detect still prefers the daily app, so a plain
  double-click keeps using the old stack during validation).
- **Patch state:** verify by byte-diff, never by re-running patchers (one-way trap):
  `cmp -l` of the clone's `mscorlib.dll` vs `mscorlib.dll.bak` → exactly 4 bytes at `0x1668c4`.
- First boot updates the clone's prefix to 11.16 (expected, one-time).
- Record the baseline before first clone boot: the daily wrapper's current `SceneFlow.log`
  path + timestamp (V2 diffs against it), and clone-creation time (§11's isolation measurement).

| # | Test | PASS |
|---|---|---|
| V1 | Steam boots, logs in, library renders | client usable (re-confirms the dxmt#141 negative on 11.16) |
| V2 | Game boots to main menu | no licence errors, no new ⚠ markers vs the recorded baseline SceneFlow.log |
| V3 | City load + 10 min play | stable; FPS within ~10% of the 42.7 baseline **at the baseline settings** (1080p, Global=Custom, DynamicRes=Automatic, AA=Low SMAA, Clouds=Med, Fog=on, Volumetrics=Low, AO=Med, GI=Off, Reflections=Med, DoF=Off, MotionBlur=Off, Shadows=Low, Terrain/Water/LOD/Texture=Med — the ledger's measured 42.7 config), HUD via `CS2_HUD=1` |
| V4 | **Exclusive Fullscreen + alt-tab** | **no freeze across ≥5 cycles via Cmd-Tab AND ≥5 via click-outside-the-window** (both trigger paths, spaced out — the original trigger involved a ~600ms-delayed second swapchain) |
| V5 | Game Mode in exclusive fullscreen | HUD reports Game Mode On (Off in borderless today); record FPS delta |
| V6 | In-game Paradox Mods download — fixture: **Move It (74324_36) + its UIL dep (74417_17)**, the probe's own fixture mods | (a) mod content present on disk under the clone prefix's `pdx_mods` cache; (b) enabled in a playset, next boot reaches MainMenu with no PdxSdk NRE hang. Check disk, not the UI. |
| V7 | Second-display / refresh-rate | no blackout regression (GOTCHAS § second display) |
| V8 | Save, quit, relaunch, load | save intact. (Saves written here live only in the clone — disposition at §9.) |
| V9 | **Fullscreen Window (borderless) still works** | alt-tab clean in borderless too — it's the documented fallback mode and must not regress |
| V10 | Prefix self-containment after first boot | `grep -c 'CS2dxmt11.app' <clone>/…/prefix/system.reg` trends to 0 for font/mono paths — else retiring the old wrapper later breaks font registration (§8) |

## 8. Promotion (after V1–V10 green)

**Promotion is a rename, with everything shut down (both Steams, game closed):**

```bash
mv "$HOME/Applications/CS2dxmt11.app"  "$HOME/Applications/CS2dxmt11-pk110.app"
mv "$HOME/Applications/CS2e1116.app"   "$HOME/Applications/CS2dxmt11.app"
```

Every hardcoded default — `find_wrapper`, `repatch.sh`, the probe/diag scripts, `setup.sh`, the
generated shortcut — now resolves to the new engine with zero edits, `make-shortcut.sh` can be
re-run any time without reverting anything, and rollback is the symmetric name swap.

1. **Data story (the §9 fine print):** the rename is lossless at promotion time. Afterwards,
   saves/mods/settings accumulate in the promoted wrapper's prefix
   (`…/prefix/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/`).
   A later rollback = symmetric rename **plus copy that data directory back** (it is
   engine-independent game data; copying the whole *prefix* back is prohibited — it has booted
   11.16). Rollback is trivial until the first post-promotion save; after that it requires the
   data copy. Decide retirement (delete `CS2dxmt11-pk110.app`) after **one week of daily play**,
   gated on: no V-class regressions, and `grep -rl CS2dxmt11-pk110 $HOME/Documents/github/cs2
   ~/cs2-patch` shows nothing depending on the retired name. Deletion is the plan's only
   irreversible step.
2. Launcher comment: exclusive Fullscreen becomes recommendable again; borderless remains the
   documented fallback (edit only with the game closed).
3. **Docs — each its own checkbox, not a bundle:** `README.md` (stack + FPS if changed) ·
   `INSTALL.md` (see 4) · `PLAN.md` (fold outcome) · `GOTCHAS.md` (new traps) ·
   `docs/wine-bugs/README.md` (standing probe action status) · `~/cs2-patch/change-ledger.txt` ·
   memory files · **as-built header on THIS doc** · dxmt#206 report posted, **comment URL
   recorded in the ledger**.
4. **Record vs publish (two different decisions):** the exact configure line, the as-executed
   assembly manifest, and DXMT binary provenance are recorded in-repo **unconditionally** (this
   doc's §4–§5, corrected to as-built). Whether INSTALL.md *recommends* self-building to
   strangers is a separate, later decision, gated on the portable-repack follow-up (§ Non-goals)
   — a brew-headers + PK-dylibs recipe is reproducible but not yet package-clean.

## 9. Rollback map

| After step | Rollback |
|---|---|
| `brew install pkgconf` | benign; leave it |
| Patched source copy | `rm -rf /tmp/wine-11.16-dxmt` — the pristine `/tmp/wine-11.16` was never touched |
| Build/assembly | delete `/tmp/wine-1116-build-p1`, `/tmp/engine-1116` — nothing installed outside /tmp |
| Launcher/setup sync (§7.2) | restore the `.bak` `setup.sh` made, or `git revert` the repo commit |
| Smoke ladder | `rm -rf $HOME/.e1116-prefix` (the game-dir symlink inside is just unlinked by rm, not descended — but eyeball it first anyway) |
| Clone validation | `rm -rf $HOME/Applications/CS2e1116.app` — daily app untouched. ⚠ V6/V8 wrote mods+saves into the clone: copy `…/AppData/LocalLow/Colossal Order/Cities Skylines II/` back first, or explicitly accept the validation session as disposable. |
| Engine swap in clone | `mv wine.pk11.0-BAK` back (or just delete the clone) |
| Promotion | symmetric rename swap; if any post-promotion saves exist, copy the LocalLow data dir back too (§8.1) |
| Retirement (delete the -pk110 app) | **irreversible** — gated in §8.1, last step only |

## 10. Risks / open questions

- **Fork-binding survival (G1)** — the headline unknown; both outcomes handled in §6. The §1
  evidence is PE-boundary only; the unix-side ABI is unmeasured by design (G1 is cheaper than
  proving it statically).
- **i386 PE build breakage** — confined to pass 2 by the staged build; waiver = stay
  x86_64-only, note it in the measurement file and §11 (steam.exe is 64-bit; the PE32 set is
  off-path; V1–V8 arbitrate).
- **Dependency coupling** — the engine links the PK engine's dylibs (copied into the engine's own
  `lib/`, so it survives PK upgrades) and brew headers at build time only. The old "brew-path
  coupling" risk is gone with the arm64 finding's fix.
- **G1 environmental preconditions** — display awake + unlocked (a locked display now aborts
  cleanly instead of fabricating pixels; demonstrated live 2026-08-23).
- **Prefix forward-migration surprises** — first 11.16 boot mutates the clone's prefix; confined
  to the clone by design.
- **Game Mode claim (V5)** — hypothesis; V5 measures it, a negative changes nothing else.

## 11. Exit criteria

1. **G0–G4 recorded** in `docs/wine-bugs/measurement-engine1116.txt`: G0's three grep lines +
   winemac=yes; G1's control verdict, candidate verdict, and all five RGB tuples for both runs;
   G2's 9/9 output; G3's full probe output + the mscorlib state used; G4's output **or** an
   explicit waiver note per §10. **Redaction pass before commit** (no `Z:\Users\<name>` — that
   leak class was found and scrubbed from three earlier measurement files this session).
2. V1–V10 pass, V4 exercised hard (both trigger paths), FPS + Game Mode recorded.
3. Promotion by rename done; §8.3's doc list each updated; as-built header on this doc; #206
   informed with the comment URL recorded.
4. **Daily wrapper untouched pre-promotion, measured not asserted:**
   `find "$HOME/Applications/CS2dxmt11.app" -newer <clone-timestamp-file> | wc -l` = 0 (record a
   timestamp file at clone time; the §7.2 launcher fix is what makes this achievable).
5. The as-executed recipe (configure line, assembly manifest, DXMT provenance) recorded in-repo
   regardless of the publish decision.

## Review corrections (triple-check 2026-08-23)

Six lenses (architecture, security, correctness, builder-simulation, platform-facts, test-plan
audit; 3× Opus + 3× Sonnet subagents + inline spot-checks against `3d6eb8e`). Verdicts: 4×
build-ready-with-fixes, 2× needs-rework (platform-facts, architecture). All blockers verified
inline and folded:

- **arm64/x86_64 dependency mismatch** (platform): brew freetype/gnutls can't link into an x86_64
  build; configure hard-aborts (freetype) / silently drops schannel (gnutls). Folded: §4's
  explicit `*_CFLAGS/_LIBS` + `LDFLAGS=-L$PKLIB`; G0 rewritten as concrete greps.
- **Fix attribution** (platform): 2293b0e's reuse path is GL/VK-only. Resolved inline: the
  11.15→11.16 winemac window also contains `1a1d1f3f3` (client_view visibility); both candidates
  upstream → premise stands, §1 reworded, G1 remains the arbiter.
- **`--prefix` missing / assembly manifest unbootable** (builder-sim): as written, install went to
  /usr/local and the hand-copy omitted `programs/*.exe`, `share/wine`, gecko/mono. Folded: §4–§5
  rebuilt around `gmake install --prefix` + overlay + pre-G1 self-check.
- **Launcher re-patched the daily wrapper on every clone run** (architecture): repatch call lacked
  `CS2_GAME_DIR`. **Fixed in the repo launcher this session**; §7.2 syncs it before validation.
- **No save-data story across promotion/rollback** (architecture): folded as §8.1 + §9 rows;
  promotion switched to rename (also dissolves the make-shortcut.sh hand-edit conflict found by
  correctness + builder-sim).
- **G1 harness could fabricate verdicts** (test-plan): `waitfor` returned success on timeout and
  the printed VERDICT was a hardcoded string. **Fixed in `scripts/run-minrepro3.sh` this
  session** (abort on timeout/failed capture, computed verdict, engine seams); the failure mode
  demonstrated itself live on a locked display minutes later. Control-run protocol added to G1.
- Adjudicated: builder-sim's endorsement of the "C_ASSERTs catch wine drift" sentence **rejected**
  in favor of platform-facts' refutation (asserts pin the shim's own ABI); sentence corrected in
  §4. Staged-build (architecture) adopted; G4 moved to pass 2 with a real 9/9 bar (test-plan).
- Hygiene (security + architecture): WineForge sha verification made an explicit pre-mount step;
  `Z:\Users\<name>` leak found in three committed measurement files and scrubbed this session.

## Review log

Key paths: `scripts/wineandaqua-dxmt.patch` · `scripts/{minrepro3.c,run-minrepro3.sh,errtest.c,monohost.c,filetest_net.cs}` · `docs/wine-bugs/` · `launchers/launch-cs2-dxmt11.sh` · `$HOME/cs2-patch/{launch-cs2-dxmt11.sh,repatch.sh}` · `/tmp/wine-11.16` (volatile)

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-08-23 | full (pass 1) | architecture · security · correctness · builder-sim · platform-facts · test-plan | 6 subagents + inline spot-checks; blockers re-verified inline | 3× Opus, 3× Sonnet | `3d6eb8e` | **build-ready-with-fixes** (corrections folded same session) |
