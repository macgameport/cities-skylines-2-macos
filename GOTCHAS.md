# CS2-on-macOS gotchas — all stacks (2026-07 → 2026-08)

> **Read the stack labels.** This is a cumulative log across **four** stacks tried between
> 2026-07-03 and 2026-08-22: CrossOver (licence now expired), GPTK/Apple D3DMetal, Wine 11 +
> DXVK/MoltenVK (abandoned — device-lost ~1 run in 8), and the current **Wine 10 Sikarugir +
> D3DMetal**. Many entries describe stacks that are no longer in use; they are kept because the
> underlying Wine behaviour usually still applies. Entries mentioning DXVK, MoltenVK or
> `VK_ERROR_DEVICE_LOST` are **historical** unless they also mention D3DMetal.
> Current setup: [`../README.md`](README.md) · Patch detail: [`docs/patch-inventory.md`](docs/patch-inventory.md)

> **Every section has been audited against the 2026-08-30 library audit — so a section with no
> `Ledger:` banner is "audited, unaffected", NOT "not yet looked at".** All 60 were classified; the
> 24 that carry a banner are all in the Steam-UI thread, which now lives in
> [`docs/steam-ui-investigation.md`](docs/steam-ui-investigation.md) with its index below. If you add
> a section, classify it, and re-run `python3 scripts/check-experiments.py` — it reads both files as
> one corpus and fails if the index misses a section.
>
> The audit found three confounds in the Steam-UI cells, and they bite different claims:
>
> | confound | what it breaks | what it does NOT break |
> |---|---|---|
> | **no font library** — wine could not resolve `libfreetype.dylib`, printed one line, continued with no font backend | any claim about **text / glyphs** | black-vs-rendered judgments; a missing font backend draws art, it does not blank a window |
> | **shim in the wrong `cef` dir** — installed in `cef.win7x64`, Steam runs `cef.win64` | any claim about **injected switches** (`--shim-args`) | cells that injected nothing |
> | **unfiltered `ps` / window capture** — another wrapper's Steam could supply the window | any **PASS** read off a window capture alone | a claim corroborated by a counter that only our patched engine emits |
>
> So the load-bearing distinction throughout this file is **"did it render at all?" (mostly survives)**
> versus **"did it render text?" (mostly void)**. Source-derived and standalone-PE results
> (C3, the `dxgiprobe` work) are untouched by all three. Full register: [`../EXPERIMENTS.md`](EXPERIMENTS.md)


Hard-won traps from getting Cities: Skylines II running for free on macOS 26 / M3 Max.
Context: the wider community says this is impossible (see REFERENCES.md) — so these are mostly undocumented.

---

## Rendering

### 1. The "black screen" is dead OpenGL, not a broken GPU
macOS 26 has degraded OpenGL to the point Wine's **default `d3d → wined3d → OpenGL`** path can't
render — `glClear` throws `GL_INVALID_FRAMEBUFFER_OPERATION`. **Everything renders black.**
- **Fix:** force **DXVK** (`d3d → DXVK → Vulkan → MoltenVK → Metal`). Bypasses GL entirely.
- Diagnostic: a 60-line DX11 "clear to magenta" test (`dxtest.c`) renders black on builtin d3d11,
  **magenta** with DXVK installed. That one test proves the whole approach.

### 2. GDI 2D windows DO render; only hardware GL is dead
`wine notepad` shows a normal white window. So plain Win32 dialogs render (that's why Steam's
"Steam Service Error" native dialog appears while its CEF UI is black). Only accelerated **GL** is broken.

### 3. ⚠ CORRECTED 2026-08-28 — wined3d's Vulkan renderer no longer crashes; it just doesn't help
**Original claim (DXVK era, kept for history):** setting `HKCU\Software\Wine\Direct3D\renderer =
vulkan` makes wined3d use Vulkan… and it crashes (`dxtest` exits, apps die). DXVK is the only
working accelerated path.
**Re-measured on the self-built stock 11.16 engine:** it initialises cleanly — `err:winediag:
wined3d_dll_init Using the Vulkan renderer`, MoltenVK 1.2.10 creates its VkInstances, and **zero**
`GL_INVALID_FRAMEBUFFER_OPERATION` (the GL renderer throws that from `glClear` on the very same
binary, see §2). So "it crashes" is stale. What is still true is that it **buys nothing here**:
Steam's CEF is byte-identically black on the GL and Vulkan renderers alike (108,343 B both times),
because the wall is presentation, not rasterization — see § "Taking DXMT out of Steam's path".

### 4. DXVK must be the macOS fork, and the FULL build
Use **Gcenx/DXVK-macOS v1.10.3** (last version supporting Vulkan 1.2 — MoltenVK doesn't expose the
extensions upstream DXVK 2.x needs). Install the **full** tarball (has `dxgi.dll`); the "-repack"/"-builtin"
variants **lack dxgi** → `D3D11CreateDevice` fails with **exit 53**. Copy `x64/{d3d11,dxgi,d3d10core,d3d9}.dll`
into `prefix/drive_c/windows/system32` and set those 4 `DllOverrides = native`.

### 5. VK_ERROR_DEVICE_LOST = GPU hang; MoltenVK crashes hard by default
CS2's heavy loading hangs the Metal GPU → `DxvkSubmissionQueue: VK_ERROR_DEVICE_LOST`, hard crash.
- **`export MVK_CONFIG_RESUME_LOST_DEVICE=1`** — documented workaround (Wine doesn't handle device-lost).
- Also try `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1`.
- **Keep `dxgi.maxDeviceMemory = 16384` + `dxgi.maxSharedMemory = 16384` in `dxvk.conf`.** It IS effective (shows
  in the DXVK "Effective configuration" dump). NOTE: it does NOT change what CS2's `Player.log` reports
  (`VRAM: 128 MB` regardless) — Unity reads the adapter differently — but keep it set; it's harmless and honest for
  a 36 GB unified M3 Max. (Earlier theory that the 128 MB report was the map-load killer was WRONG — see #5c. The
  map loads fine at "128 MB" once mods are off.)
- **Bundled MoltenVK is already the newest** — 1.4.1 (2025-11-30), the latest official release. Swapping in a
  "newer" MoltenVK is not an option; this is the tooling ceiling, not an outdated-layer problem. (The community
  DXVK-patched MoltenVK in REFERENCES.md is based on the *older* 1.1.9 → a downgrade, untried.)

### 5c. The map-load device-loss was MODS, not VRAM (SOLVED) ⭐
Turning **mods off** is what got past the loading screen. With subscribed mods present, CS2 runs **background
downloads + Virtual-Texturing "background processing of materials"** at the menu — GPU/CPU/disk churn. Starting a
map load *on top of* that stacked GPU work → `VK_ERROR_DEVICE_LOST`. Disable mods (see #5d) and let the menu go
quiet (notifications finished) before loading. Then the load completes: audio, ~206k objects, clean asset unload.

### 5d. Disable mods via files (menu hangs, so edit directly)
Mods live in `…/Cities Skylines II/.cache/Mods/`. To force-off without the (hang-prone) in-game menu:
- `playset_config.json` — set every `"isEnabled":true` → `"isEnabled":false` (game CLOSED; it rewrites on exit).
- Delete `pdx_mods/.downloading` to stop a pending download resuming mid-test.
- Check `Logs/Modding.log`: `Active Playset (none)` + `Enabled Mods (none)` = confirmed off. (An inactive playset
  already means mods don't LOAD even if listed enabled — but downloads still churn until disabled/finished.)

### 5e. Killing the "Wine window keeps reopening" + a device-lost/hung game
After a device-loss the game hangs (cursor still changes = OS-level alive, but GPU gone → black). Leftover
`explorer.exe /desktop` + Steam repaint = the window that keeps popping back. Kill the whole stack cleanly:
`WINEPREFIX=~/cs2-mac/prefix "…/Wine Staging.app/…/bin/wineserver" -k` then `pkill -9 -f cs2-mac; pkill -9 -f steamwebhelper`.

### 5f. Device-loss moved to the FIRST GAMEPLAY FRAME (current blocker)
With mods off + VRAM set, the load survives — but the **first full-city frame render** device-losts (audio plays,
screen black, `waitForIdle failed`). This is the single heaviest GPU moment (whole scene at once). `Player.log` is
clean; the `err:` only shows in the **terminal**. Levers (in `Settings.coc`, game closed): **shadows off**
(`ShadowsQualitySettings.enabled=false` — the biggest pass + a MoltenVK weak spot), **`maxLightCount` 4096→256**,
**`minScale` 0.5→0.3**. AND load the **smallest/flattest NEW map**, not a built save (10× lighter first frame).

### 5a. Mouse clicks not registering → virtual-desktop mode (SOLVED)
At the rendered menu, clicks didn't register (Wine input-routing quirk in exclusive-FS). **Fix: launch inside
a Wine virtual desktop** — `wine explorer /desktop=CS2,<W>x<H> Cities2.exe`. Input routes correctly there.

### 5b. Virtual-desktop resolution MUST match the game's render resolution (cursor offset)
With a virtual desktop sized differently from the game's internal resolution (e.g. desktop 1600x1000 vs game
1512x982), the cursor hit-test is **offset** — you can't click bottom-edge UI like **SELECT MODE**. Match the
`/desktop=CS2,WxH` to the game's actual render res (1512x982 here) and clicks land where the cursor is.

### 6. The game ignores `-screen-fullscreen 0` / `-screen-width` after first run
Once CS2 has a saved settings file it uses **its** resolution/window mode (`Exclusive FS: 1`, its saved res),
ignoring command-line graphics flags. To change graphics you must edit the saved settings (`Settings.coc` —
plain JSON), not the CLI.

### 6a. Keep `displayMode` = "Fullscreen" — "Windowed" THRASHES the display and device-losts
Editing `Settings.coc` `displayMode` to `"Windowed"` looked like the fix for input, but CS2 effectively
ignores it and **cycles display modes** on startup — each mode-set re-inits the swapchain and reliably
triggers `VK_ERROR_DEVICE_LOST` before the menu. `"Fullscreen"` does a single mode-set and reaches the
menu cleanly. Solve input with virtual-desktop mode (#5a below), NOT windowed mode.

### 6b. "Everything is too dark to see" has TWO unrelated causes — check gameplay first
Both were hit on this stack within two days, and only one is a port defect:
1. **Night, because the day/night cycle is on** — a *gameplay* setting, not rendering.
   **Options → Gameplay → day/night visual → off** (writes `"dayNightVisual": false` under the
   `Gameplay Settings` block of `Settings.coc`). Fixed it instantly on 2026-08-22. The key is
   **absent** from the file until the toggle is first used, so its absence is the default-on state.
2. **A washed-out, permanently dim scene at any hour** — `SSGIQualitySettings enabled: false`, a
   leftover MoltenVK GI-off mitigation that no longer applies (fixed 2026-08-21).
**Tell them apart before debugging:** is it dark *at a particular time of day* (cause 1) or dark
*always* (cause 2)? Neither is a renderer bug — don't go near DXMT/D3DMetal for either. Confirmed
non-defect on 2026-08-22: lighting keys byte-identical to the known-good stack, zero shader errors,
zero exceptions in `Player.log`.

---

## Steam client

### 7. Steam's CEF UI renders BLACK — ✅ STALE: it RENDERS on the D3DMetal stack (2026-08-22)
**Superseded.** Launched visibly (`steam.exe -no-cef-sandbox`, no `-silent`) on the current stack
(Wine 10 Sikarugir + D3DMetal, Steam build 1785799196): the full client UI — library, store shelves,
account menu — renders correctly. Screenshot-verified. Two facts that reframe the old diagnosis:
- **steam.exe picks the webview render path itself, per wrapper — and both paths work.** On the
  D3DMetal wrapper every webhelper launch back to 2026-07-05 (`logs/webhelper.txt`) carries
  `--no-sandbox --in-process-gpu --disable-gpu` (renderers on swiftshader ANGLE = software CEF); no
  config file, registry key, or wrapper sets those — steam.exe adds them. On the **Wine 11 + DXMT**
  wrapper it adds NO such flags: CEF runs a real `gpu-process`, and the UI renders anyway (verified
  2026-08-22, store page + promo popup), so `whwrapper_ipgpu.c` stays unused.
  ⚠️ **Correction (2026-08-22):** earlier notes — including a commit made the same day — cited
  [3Shain/dxmt#141](https://github.com/3Shain/dxmt/issues/141) as "DXMT lacks cross-process
  swapchains." **It is not that issue.** #141 is *"ANGLE `SwapChain11` fails with `EGL_BAD_ALLOC`
  (Steam CEF black window)"* — i.e. it tracks **this very black-window symptom**, on DXMT v0.74 +
  wine 11.5, and it is still open. The string `cross-process swapchain` appears **nowhere** in this
  project's logs; it survived only in prose. Since Steam's UI renders fine here on **v0.80 +
  wine-11.0**, we hold a genuinely useful upstream data point: #141 does not reproduce on v0.80.
  Worth posting there.
- **The July black screen happened with these SAME flags** — so the flags were never the fix or the
  culprit. It stopped reproducing somewhere across the engine swap (→ Sikarugir/D3DMetal) and the
  Steam client updates since; the exact cause was not isolated.
Interactivity confirmed 2026-08-22: store browsed, an expansion purchased, and its download started
from inside the client (Cloud Status: Up to date). Same-day check on the Wine 11 + DXMT wrapper:
renders there too (cached login OK in ~20 s, store fully drawn). Launching the game from Steam's Play button remains WRONG regardless — see #10, and
the shortcut's launcher is what re-applies the patches after exactly this kind of update.
The original record (DXVK 1.10.3 era, 2026-07), kept for history: compositor blamed on a missing
shared-texture interface *[2026-08-22: that GUID `f8fb5c27` is `ID3D11Texture1D` — benign
type-discovery]*; tried and failed then: `-cef-disable-gpu[-compositing]`, `WINEDLLOVERRIDES=dcomp=`,
virtual desktop, Big Picture (`-gamepadui`), per-app builtin d3d11, a mingw steamwebhelper.exe
wrapper. **All black at the time.**
- **CDP login** (`cdp.py` + `CS2 Steam Login.command`) is hereby demoted from required workaround to
  fallback — the normal Steam window should now handle fresh logins. Keep the scripts.

### 8. steamwebhelper hangs on OLD Wine — needs Wine 9+
GPTK's Wine 7.7 → "steamwebhelper is not responding," no login possible. Wine 11 fixes it. This is why
GPTK (Apple's toolkit) is a dead end for anything needing the modern Steam client.

### 9. Don't zero-out steamservice.exe to stop its crash
Steam's file verification catches a 0-byte `steamservice.exe`, re-downloads the whole client, and enters
an update loop. Instead: it's harmless (Proton disables it too) — click **Cancel** on the "requires
maintenance" dialog, or suppress via `HKCU\Software\Wine\WineDbg\ShowCrashDialog=0`.

---

## Launch / Steamworks

### 10. `steam -applaunch <id>` makes CS2 exit before Unity — launch the exe DIRECTLY
`-applaunch` kills the game early (no Player.log). Instead run `Cities2.exe` directly with
`steam_appid.txt`=949230 in the game dir + these env vars so SteamAPI connects to the running client:
`SteamAppId=SteamGameId=SteamOverlayGameId=949230`.

### 11. Launching the game too soon after Steam login = platform-init crash (the WORST red herring)
`[SceneFlow] platform service integration failed` → 100k+ NullReferenceException → `fatal://error`.
Looks like a game bug; it's a **Steam license-sync RACE**. SteamAPI can't verify ownership until Steam has
~40–60s of uptime after login. **Fix: sleep 40s after `[U:1:<nonzero>]` appears in connection_log, THEN launch.**
Add an auto-retry if `platform service integration failed` shows in the first ~12s.

### 12. Disable the Steam overlay — it crashes the game under Wine
`WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d"`.

### 13. CS2 bundles its own VC++ runtime — no vcredist/winetricks needed
`VCRUNTIME140/MSVCP140` load from `Cities2_Data/Plugins/x86_64/`. Don't waste time installing redists.

---

## Login automation (CDP)

### 14. Steam's login form is React — setting `.value` isn't enough
Use the native setter + dispatch `input`+`change` events, or React ignores it:
`Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set.call(el, val)` then dispatch.

### 15. Auto-login works after the first CDP login (cached token)
Once logged in once, Steam auto-connects headless on subsequent launches (no UI needed). The black CEF
UI stops mattering — the game launches via direct exe + the cached session.

### 16. Email vs mobile-app Steam Guard is an ACCOUNT setting, not a login-flow choice
If the mobile authenticator is enabled, Steam *requires* the app; "Enter a code instead" = the app's code,
not email. To go email-only: remove the authenticator from the account (→ email Steam Guard; ~15-day trade hold).

---

## Paradox Mods download (2026-07-06)

> Full testing plan + idea checklist in **MODS-TESTING.md**. These are the hard-won traps.

### 17. handle-0 is NOT a generic Wine bug, and it does NOT block a normal FileStream ⭐ (CORRECTED 2026-07-06)
**Earlier framing was wrong.** We assumed "Wine's `CreateFile` returns handle 0 for valid files → blocks mod downloads."
Deterministic reproducers (repo `scripts/`, runnable over Bash — no game boot) disproved it. On the identical Wine, a
plain CreateFile/FileStream create+write+open+read to the exact `.cache/Mods/pdx_mods/.downloading/74324_36/content.bin`
path **works with a proper nonzero handle** under EVERY runtime tested — raw Win32 (CrossOver 26.2 + Sikarugir Wine 10),
MS .NET CLR, standard Mono 6.12, **and CS2's own `MonoBleedingEdge/mono-2.0-bdwgc.dll`** (run via `scripts/monohost.exe`).
stdin state (closed / /dev/null / detached) is irrelevant too. So the mod-download blocker is **not** a generic handle-0.
- The **settings-read** handle-0 that `patch_longfile` addresses IS separately real (`Colossal.IO.LongFile.GetFileHandle`)
  — but that method must use a *different* open than a normal CreateFile, since our reproducers never surface handle-0.
- **Patching .NET to accept handle-0 still doesn't work** (kept as documented dead ends, NOT in `repatch.sh`):
  `patch_safehandle.py` (global `IsInvalid`) breaks boot (kernel handles use 0/NULL for FAILURE → null deref);
  `patch_filestream.py` (NOP FileStream.Init throws) breaks boot (accepting handle-0 → garbage reads → NRE).
- **★ REAL ROOT CAUSE (2026-07-07): the errno-0 / FindNextFile end-of-directory false-positive in `System.IO.Directory`
  ops — a DIRECTORY bug, not a file-handle bug.** Unmasked `PdxSdk.log` (unpatched game) shows the download failing on
  `PrepareFolderForPatching` → `IOException: "Success"` (Wine returns ERROR_SUCCESS(0), Mono misreads as error) + the
  nested `.metadata\` dir never created → `CreateFileStream` → `DirectoryNotFoundException`. Same class as
  `patch_colossal_io`'s FindNextFile fix, but PdxSdk uses raw unpatched `System.IO.Directory`. This is why file reproducers
  all passed — wrong op. Fix at the RIGHT layer (pre-create full nested dirs, or patch Mono Directory FindNextFile).
  `patch_pdxsdk_io` masked the WRONG layer (→ hang + boot NRE). Full detail in **MODS-TESTING.md**.
- **Reproducer cheatsheet:** CO wine = `CX_ROOT=<CrossOver> CX_BOTTLE=Steam WINEDEBUG=-all "$CX/bin/wine" <exe>`
  (use `CX_BOTTLE`, NOT `WINEPREFIX`); macOS has **no `timeout`**; Sikarugir wine needs `arch -x86_64` + the wrapper's
  `Frameworks/*.dylib` copied into `SharedSupport/wine/lib` (libinotify @rpath). `monohost.exe` runs ANY managed assembly
  under the game's exact Unity mono — reuse it for the flag/async follow-ups.

### 18. Playset activation IS patchable (and safe) — but masking turns fail-fast into a silent hang
`patch_pdxsdk_io.py` (PDX.SDK.dll `ResultFactory.CreateIoResultFromException` → `set_Success`) makes the playset
**activate** and mods **queue** (reach "Preparing… 2.0%"). BUT it masks the disk-op failure
as success, so the download pipeline **waits forever for a fake-success completion** → silent "Preparing 2%" hang, no log
(vs. the pre-patch fast-fail that logged `IOERR_101` and gave up after 2 rounds). It's a net cosmetic win, not a fix.

### 18b. ⚠️ `patch_pdxsdk_io` BREAKS BOOT when the mod-cache state is empty/minimal (regression, 2026-07-07)
Same masking bites at **startup**: with an empty `.cache/Mods` (no `playset_config.json`, empty `pdx_mods`),
`Colossal.PSI.PdxSdk.PdxSdkPlatform.Initialize()` does a disk op that legitimately fails → the patch fakes success with a
**null** payload → `Initialize` derefs it → `[PdxSdk][Create] Fatal error during SDK initialization: NullReferenceException`.
Cascade: PdxSdk init NRE → `[Modding]` NRE → `Colossal.IO.AssetDatabase.get_instance()` returns null → `[SceneFlow][FATAL]`
in `GameManager.UpdateModdingBacktraceAttributes()` → **main thread hard-blocks in `NtWaitForSingleObject`, never reaches
MainMenu**. On 2026-07-06 this DIDN'T happen because the mod state existed (the disk op succeeded, no mask triggered).
**Proven:** revert `PDX.SDK.dll` from `.bak` → game reaches MainMenu (58s) clean. **So there's a bind: WITH the patch =
boot NRE (empty mod state); WITHOUT = boots fine but playset won't activate (no queue → nothing to download).**
**Current shipped state (2026-07-07 03:0x): PDX.SDK.dll is UNPATCHED (reverted) so the game BOOTS + plays vanilla. Do NOT
blindly re-run `repatch.sh` / `patch_pdxsdk_io` — it re-breaks boot until the mod-cache state is restored.**
**Path to test downloads next session:** boot UNPATCHED → menu → Paradox Mods → subscribe the 4 mods (rebuilds a valid
`playset_config.json` + mod-cache so Initialize's disk op succeeds) → re-apply `patch_pdxsdk_io` → reboot (should boot now
that the state exists) → Paradox Mods → Library → trigger download → run `scripts/capture-hang.sh` for the async-stall test.

### 19. In-game mod downloads are the GAME's PdxSdk, NOT the launcher's CPatch
Download activity logs to LocalLow `Logs/PdxSdk.log`. The Paradox Launcher's `cpatch.log` is **only the launcher
self-updater** (xdelta on `launcher-v2` node_modules from `api.paradox-interactive.com`) — zero `pdx_mods` ops. Don't
chase cpatch. Also: the queue only actively processes while the **in-game Paradox Mods → Library screen is open**
(main-menu notifications are just persisted "queued" state).

### 20. Sideload is blocked — the mod API needs AWS SigV4 signing
Manual install seems attractive (bypass the broken downloader) but: the mod **file manifest** (`repository.json`) requires
an **AWS SigV4-signed** request to `api.paradox-interactive.com` — a bearer token 403s (`"Invalid key=value pair … hashed
with SHA-256 … Authorization header"`). CDN content blobs (`modscontent.paradox-interactive.com`) are public, but their
exact paths live only in that signed manifest. And GitHub (`yenyang/CS2-MoveIt`) is **source-only** — no release DLL, and
a CS2 code mod can't be built here. **Only real path to sideload: copy `pdx_mods/<id>_<ver>/` from a native Windows CS2.**
Mod map: Move It=74324_36 (dep: UIL), UIL=74417_17, Anarchy=74604_39, Traffic=80095_28.

### 21. Async testing: only interpret a run that POSTDATES the change
Cost me real time this session — I twice concluded a patch "failed" (and once reverted a good one) from a **stale**
game run that predated the patch. **Rule:** stamp each patch change in `~/cs2-patch/change-ledger.txt`; only interpret a
run whose `Logs/SceneFlow.log` first-line timestamp is **after** the change. A run that started before = stale, draw no
conclusion. (I can't see message send-times, so message order lies.)

### 22. ✅ ROOT CAUSE of the mod-download wall: Unity-Mono `Directory.Delete(recursive)` is broken on Wine
**Supersedes the #18/#18b whack-a-mole.** Isolated with `scripts/monohost.exe` (runs a managed assembly under CS2's
exact Unity Mono) + `scripts/filetest_net.cs` — no game launch, no GUI, no async-timing ambiguity.
- **Symptom in PdxSdk.log:** `IOERR_101: IOERROR - IOError - Success` on `.cache\Mods\pdx_mods\.downloading\<id>`.
  "Success" is `strerror(0)` — a **stale/garbage Win32 last-error**.
- **What actually breaks:** `Directory.Delete(path, recursive:true)` throws `IOException` **and does not delete the dir**
  (`GONE=False`), *even on an empty dir*. Non-recursive `Delete(x,false)`, `File.Delete`, `GetFiles`,
  `GetDirectories`, `CreateDirectory`, and **manual recursion** all work fine.
- **Mechanism (mscorlib `System.IO.FileSystem.RemoveDirectoryRecursive`, IL mapped):** after the `FindNextFile`
  end-of-dir, Wine leaves `GetLastError` garbage (not 0, not 18=`ERROR_NO_MORE_FILES`), so CoreFX's post-loop error
  check at IL `0x154`–`0x163` **throws before reaching `RemoveDirectoryInternal(topDir)`** at IL `0x170` (the real
  removal, which works standalone). That's why an empty dir throws with the dir still present.
- **THE FIX = `patch_dirdel.py`:** NOP the one spurious `throw` (mscorlib file offset `0x15461f`, `0x7a`→`0x00`).
  Execution then falls through to the real removal. **Proven:** post-patch the probe flips [5][6][7] to
  `no throw / GONE=True` across empty, nested, and file-bearing trees. Boot-safe (recursive delete isn't on the boot
  path; mscorlib byte patch only). Now wired into `~/cs2-patch/repatch.sh`.
- **Why #18b's `patch_pdxsdk_io` was the WRONG layer:** it forced `IOResult.Success=true`, masking a delete that never
  happened → downstream "waits forever" (#18) and boot NRE on empty mod-state (#18b). Removed from `repatch.sh`.
- **Every failing download op is a recursive delete** (`PrepareFolderForPatching` = clear folder,
  `CleanupTempFileStorage`, `CleanupAndLogResult`, `LocalStorage.Delete`); **none are Move/Copy** (`CopyRepoFiles`
  never errors). So `patch_dirdel` alone should unblock the whole pipeline.
- **`Directory.Move` is NOT broken** (corrects the prior "whack-a-mole" belief). Probe [10] MoveCheck: simple AND
  nested (`.metadata`) moves both complete (`MOVED=True`, no throw). The earlier "nested Move throws" ([9]) was a
  **flawed test** — it moved into a *nonexistent parent* (`baseDir\mm2\sub`, `mm2` never created), which throws
  `DirectoryNotFound` on real Windows too. So recursive `Directory.Delete` is the *only* Wine-garbage-errno op on the
  download path. Only residual: `File.Delete(nonexistent)` throws garbage but effectively succeeds (file's gone) —
  never seen in the download logs.
- **⚠️ LIVE TEST (04:19, postdates patch): patch_dirdel is NECESSARY-BUT-NOT-SUFFICIENT.** The download STILL fails —
  `PrepareFolderForPatching → IOException "Success"` on `.downloading\<id>`. It's a real fix for the success-path
  recursive delete, but that was never the download's blocker. **Kept** (boot-safe, harmless, fixes a genuine bug) but
  re-labeled: NOT the mod-download fix.

### 22b. THE ACTUAL download killer: Wine garbage-errno on file-op FAILURE/EDGE paths (not success paths)
Probe [13] cracked it: the ops that throw the "Success"/"Unknown error" `IOException` are the **failure/edge cases**, not
normal ops:
- `Directory.GetDirectories/GetFiles/Delete` on a **nonexistent** dir → garbage `IOException` (should be `DirectoryNotFound`)
- `Directory.Delete` / `File.Delete` on a dir/file with an **open handle** → garbage (should be `SharingViolation`)
- (`Directory.Exists(nonexistent)` correctly returns False; enumeration of the same path throws garbage.)

**Mechanism:** Wine leaves `GetLastError` uninitialized on the *non-success* return of file APIs, so Mono builds a garbage
`IOException` ("Success" = `strerror(0)`) instead of the correct **typed** exception. PdxSdk's download code distinguishes
benign "not found" from fatal errors — but every edge case is now an indistinguishable garbage `IOException`, so it aborts.
This is a **broad surface** (matches the 2026-07-07 03:4x "not 3 sites, the whole file-API failure path" read), NOT one
patchable op. Ruled out: thread context (main vs ThreadPool/Task identical), the specific path (real dot-parent + spaces
enumerates fine in isolation), wrong-mscorlib (only one; game loads the patched one).
- **No download-progress logging at all** in the failing run → content may not even be fetching (upstream signing/network,
  cf. #20 AWS SigV4) → `.downloading\<id>` left empty/absent → enumerate-nonexistent → garbage errno. Worth confirming.
- **Realistic fixes:** (a) central errno-sanitize at the Wine/Mono boundary — risky, may mask *real* failures; (b) the
  **sideload from a Windows CS2** (#20) remains the only reliable way to actually get the mod folders on disk.
- **Harness for the next attempt:** filetest_net.cs now has [10] Move/File.Delete, [11] ClearFolder replica, [12] thread
  context, [13] nonexistent/open-handle — rebuild w/ bottle `Framework64/v4.0.30319/csc.exe`, run via monohost.

## SOLVED since first draft (2026-07-04)
- **Mouse clicks** — virtual-desktop mode + matched resolution (#5a, #5b). Clicks register; SELECT MODE reachable.
- **Reaching the main menu reliably** — Fullscreen displayMode (#6a) + 40s license wait (#11) + Low preset (#5b).
- **MoltenVK version question** — already on latest (1.4.1); not a lever (#5).

## OPEN ITEMS (not yet solved as of 2026-07-04)
- **VK_ERROR_DEVICE_LOST is non-deterministic on map load** — the "final boss." Menu + mode-select reached
  reliably; loading an actual map still device-losts on some launches. Everything cheap has been tried
  (RESUME_LOST_DEVICE, arg buffers, Low graphics, no mem cap, matched res, latest MoltenVK). Remaining levers:
  drop adaptive `minScale` below 0.5, smaller virtual desktop, reboot for clean GPU state, or accept the ceiling.
- Current graphics preset (`Settings.coc`): volumetrics/clouds/fog/SSAO/SSR/DoF/motion-blur all off, shadows
  1024, terrainCastShadows off, adaptive DynamicResolutionScale (minScale 0.5), LOD 0.4, Fullscreen.

## Second display gets blacked out by the game → REFRESH-RATE mismatch (2026-08-22)

**Symptom:** launching the game in exclusive fullscreen blanks the *other* monitor too, so you
cannot use anything else while it runs.

**Cause:** the display and the game disagreed about refresh rate, so Wine performed a display
**mode change** to take the screen:

    main display (DELL U2424H) : 1920x1080 @ 120.00 Hz
    game was asking for        : 1920x1080 @  60 Hz

A mode change on a captured display disturbs the whole display arrangement, which is what blanks the
second monitor.

**Fix — set the game's refresh rate to match the display**, so no mode change is needed:
Options → Graphics → **Screen Resolution → `1920 x 1080 x 120Hz`**. Confirmed: with 120 Hz selected,
**the black overlay on the second screen is gone.**

⚠ **Confound, stated honestly:** `CaptureDisplaysForFullscreen="N"` was written to
`HKCU\Software\Wine\Mac Driver` in the same session, so the two were not isolated. The timing
points at the refresh rate (the overlay stopped when 120 Hz was selected in-game, after launch), but
either or both may be contributing. Keep both.

**Set it in-game, not by editing `Settings.coc`.** Editing `refreshRate.numerator` 60000→120000 in
the file did **not** take effect — the game still applied 60 Hz on the next launch. Only the
in-game Screen Resolution control actually changed it. Another instance of the rule that this
project keeps re-learning the hard way.

## "Failed to read settings … Invalid handle" ⚠ markers are ABSENT FILES, not broken settings (2026-08-22)

**One error per settings file that does not exist yet — on both stacks, with `patch_fshandle`
applied.** Wine 11 + DXMT logged 4 (5 mods, 2 with `.coc` files → 3 mods + keybinds absent);
Wine 10 + D3DMetal logged 3 (4 mods → 2 + keybinds). None of the reported GUIDs exists on disk.

Wine's handle-0 defect makes a *not-found* open indistinguishable from an *invalid handle*, so the
first read of an absent settings file surfaces as an IO error rather than "no file, use defaults".

**Cosmetic.** The visible symptom is an exception dialog on exit. Don't debug it as a patch failure:
verify `fshandle` is applied (4 differing bytes vs `mscorlib.dll.bak`), then count mods lacking a
`.coc`; if the numbers match, it is this. `fshandle` remains necessary — it fixes reads of files
that *do* exist, which is why keybinds persist at all.

⚠️ **Two corrections to earlier versions of this entry, both measured 2026-08-22:**

1. **"Open the mod's settings once and the error clears" is FALSE.** Viewing a panel writes nothing;
   the `.coc` appears only when a setting is actually *changed*. A whole session spent in those
   panels produced no new files.
2. **The ⚠ badges are NOT this bug.** They are **keybinding conflicts**, and they have nothing to do
   with Wine, DXMT or the port — the same mods do this on Windows. The disproof is on disk:

   | mod | has `.coc`? | ⚠ badge? |
   |---|---|---|
   | Traffic | **yes** | **yes** |
   | Move It | yes | no |
   | Anarchy | no | **yes** |
   | Easy Zoning · Unified Icon Library | no | no |

   Missing-file and badge don't correlate at all. What *does* explain it is the binding state:
   `Traffic.coc` holds three actions (`RemoveIntersectionConnections`, `RemoveUTurnConnections`,
   `RemoveUnsafeConnections`) all with an **empty `m_Path`** — unbound. `MoveIt.coc` holds exactly
   one key, `"HasShownMConflictPanel": true` — its M-key conflict was acknowledged, so no badge. And
   `Settings.coc` → `Keybinding Settings` holds three **vanilla** shortcuts, also unbound: Map Tile
   Purchase Panel, Relocate Selected Object, Toggle Selected Object Active.

   **Fix it in Options → KEYBINDS by assigning keys** (or accepting the mod's conflict panel). This
   is game configuration, not a port defect — don't chase it through Wine.

**2026-08-25 update — the dialog can also fire MID-SESSION, at mod-options open.** First boot after
adding 5 mods: 8 GUID errors in Player.log (the new mods' settings + keybind stores, none on disk —
the count scales with mod additions, still cosmetic), and opening Find It's options page raised the
same IOException as a mid-session dialog (CONTINUE / SAVE & QUIT / QUIT). **CONTINUE is safe** — the
mod runs on defaults. Each mod's error stops once its settings file exists, i.e. after any of its
settings is actually changed (viewing alone writes nothing, per correction 1 above).

## Mod keybinding defaults are extractable offline — and the conflicts were fixed on disk (2026-08-25)

Mod default chords live in `SettingsUIKeyboardBinding` attribute blobs, not strings —
`scripts/dump-binding-attrs.py` (dnfile, run via `~/cs2-patch/revenv`) parses them, using
Game.dll for the BindingKeyboard enum map. **Calibration:** the ctor bools are positional —
b1=alt, b2=ctrl, b3=shift (anchored on Move It Ctrl+Z undo + Find It Ctrl+F search). Vanilla
declares nothing via attributes (Game.dll yields zero rows) — vanilla chords come from docs/UI.

Measured collisions in the 10-mod set (game 1.6.0f1): Find It Random **Ctrl+R** ⟷ Traffic lane
connector **Ctrl+R** · Traffic priorities-display **Ctrl+S** ⟷ vanilla quicksave · Traffic's
remove-connection trio ships **unbound** because its Ctrl+1/2/3 defaults collide with Traffic's
own priorities quick-set · **PageUp/PageDown** triple-booked (vanilla surface/underground ·
Move It raise/lower · Anarchy elevation). BB / Line Tool / Plop / InfoLoom / AIL declare zero
keybindings.

**Disk fix protocol (applied 2026-08-25, backups `*.bak-keybinds-20260825-120139`):** edit only
files the game itself wrote — `.coc` format is `Header\r\n` + 4-space JSON with `\n` bodies and
a `\r\n` after the final `}`; mod entries are keyed by settings **property name** (from the
dump); rebind = complete binding object (`m_Path` + `m_Modifiers`), modifier entries
`{"m_Name": "modifier", "m_Path": "<Keyboard>/ctrl|alt|shift"}`. Applied: Settings.coc three
emptied vanilla actions → Ctrl+Shift+M/R/A · Traffic trio → Ctrl+Alt+1/2/3 + display toggle →
Ctrl+Alt+S · FindIt Random → +alt (Ctrl+Alt+R). **Never create a `.coc` a mod hasn't written
yet** (header name is unverifiable — a wrong guess risks its settings load): Anarchy has none,
so its PageUp/Down badge stays until someone rebinds once in-game to mint the file.

## Apple/⌘ binds as Ctrl in-game — rebinding chords from the Mac keyboard (2026-08-25)

`user.reg` → `[Software\\Wine\\Mac Driver]` carries `"LeftCommandIsCtrl"="Y"` +
`"RightCommandIsCtrl"="Y"` (and both Option keys are Alt). So in any keybinding capture the game
receives **⌘ as Ctrl**: pressing ⌘⇧F stores Ctrl+Shift+F, and the chord then works from the Mac
keyboard as Apple+Shift+F. First use: Find It's search default (plain Ctrl+F, shipped with a
conflict ⚠) was rebound to ⌘⇧F — `FindIt.coc` `SearchKeyBinding` now carries `shift`+`ctrl`
modifiers over the default `f`, which is exactly that chord as the game spells it.

## ✅ SOLVED by wine 11.16 — alt-tab freeze is presentation, NOT refresh rate (2026-08-22; kept for the mechanism)

**Separate problem from the one above, and NOT fixed by matching refresh rate.** After switching away
and back, the game accepts input (one action registers) but **the screen never redraws**.

**Measured:** matching the refresh rate did *not* reduce mode-change churn — it went from 9 to **25**
(`Setting display mode` in wine stderr, 12@120 + 13@60) while the game sat correctly at 120 Hz. So
the churn is not driven by the mismatch, and an earlier version of this entry claiming otherwise was
wrong.

**The two startup warnings are NOT the cause.** `unsupported swap effect 3` is cosmetic — the same
`MTLD3D11SwapChain` is built regardless (source read, `d3d11_swapchain.cpp:1111`). Swap effect 3 is
**`DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL`** — *not* `FLIP_DISCARD`, which is 4. (Verified against
mingw's `dxgi.h`: `DISCARD=0, SEQUENTIAL=1, FLIP_SEQUENTIAL=3, FLIP_DISCARD=4`. An earlier version
of this entry said `FLIP_DISCARD`; that was the same guess-the-constant error as the `f8fb5c27`
misidentification. Check the header.) `MakeWindowAssociation: Ignoring flags 3` = the game asking
DXGI not to manage window transitions; DXMT ignores everyone's flags there, so it distinguishes
nothing.

**Source-level state (2026-08-22, late session — v0.80 ≡ master `d31278d` in all cited files):**

- **The swapchain IS exclusive fullscreen (`Windowed == FALSE`).** The boot line
  `Setting display mode: 1920x1080@120` is printed only by `wsi::setWindowMode`
  (`wsi_window_win32.cpp:42`), and every path to it requires exclusive-fullscreen state. Closes the
  draft report's open question. Corollary: `SetFullscreenState` logs NOTHING on success, so
  "no SetFullscreenState lines" was never evidence — don't re-make that inference.
- **`dxgi.handleAltTab` is structurally inert for CS2**: both reaction sites
  (`d3d11_swapchain.cpp:743-744` and `:441-442`) require `!window_minimized`, and CS2 minimizes
  itself on focus loss. Explains the measured null result. Worth telling upstream.
- **MEASURED 2026-08-23 (diag run + held freeze + 5s `sample`): the mechanism is pinned.**
  - **Only the screen freezes.** Frozen process sustains ~250% CPU; sim autosaves; blind save/quit
    works. The sample shows the COMPLETE present pipeline running: encoder encoding real draws, GPU
    submits/completes, `presentAfterMinimumDuration` firing, drawables recycling sub-millisecond.
    **Zero `nextDrawable` waits in 65k sample lines → the wedged-drawable-pool theory is dead.**
  - **One visible refresh per minimize/restore cycle** (user-verified, repeatable): the WindowServer
    samples the layer's current surface once during each window-order transaction, otherwise
    ignores every present. This is what makes blind save/quit possible — one frame per alt-tab.
  - **Trigger, traced to the millisecond:** at the FIRST focus loss the game (Unity standard
    behavior) sets WS_MINIMIZE + `ShowWindow(SW_MINIMIZE)` within 5ms — then **600ms later creates
    a SECOND swapchain while the window is miniaturized with client rect (0,0)-(0,0)** (second
    `CreateSwapChain: unsupported swap effect 3` in the trace); its metal view/layer attaches in
    that state and never enters live compositing. Both swapchains stay alive to process exit; the
    win32/Cocoa window and both metal views are never recreated. Six windowing-flawless restore
    cycles (one *inside* the proven-static window) changed nothing — the restores were never the
    problem; the layer's compositing link was never established at birth.
  - Explains dxmt#48's folk remedy (fullscreen toggle = fresh attach while visible = normal
    compositing) and the windowed launcher's immunity (no minimize → no swapchain recreation).
  - **REPRODUCED STANDALONE same day (`scripts/minrepro3.c` + `run-minrepro3.sh`), and stripped
    further than expected: no fullscreen, no minimize, no focus change needed.** The minimal
    recipe: two swapchains on one HWND; presents to the OLDER one complete at full fps/S_OK but
    never reach the screen (screenshots byte-identical across 6s of 120fps red presents); presents
    to the newest chain show instantly. So the defect is: **only the most-recently-created
    swapchain's layer on an HWND is composited** — each swapchain gets its own client view and the
    newest view hides the previous one forever. CS2 freezes because Unity creates a recovery
    swapchain on alt-tab but keeps rendering into the ORIGINAL. ⚠ v1's lesson: present to the OLD
    chain when testing this — presenting to the new one shows nothing wrong (that false-negative
    cost one iteration).
  - **✅ FIXED IN WINE 11.16 (measured 2026-08-23).** The reproducer passes under WineForge 0.6.0.3
    (wine-11.16 + DXMT v0.80): the old swapchain's presents composite and animate. Since that DXMT
    is OLDER than ours, the fix is Wine's — `2293b0e` (client-surface reuse), which is in 11.16 but
    NOT 11.15. Upgrading the engine would retire this defect; the 10-patch stack would need
    re-validating on 11.16 first.
  - **Filed upstream 2026-08-23 as [dxmt#206](https://github.com/3Shain/dxmt/issues/206)** (AI
    assistance disclosed; no PR per their policy). **CLOSED 2026-08-24 by 3Shain as
    "duplication of [#183](https://github.com/3Shain/dxmt/issues/183)"** — that one line was the
    only maintainer response. #183 is still open, so anything further on this defect goes there.
  - Diagnostic kit that produced this: `scripts/diag-launch-dxmt11.sh` (WINEDEBUG trace) +
    `scripts/capture-freeze.sh` run while frozen. ⚠ The canonical launcher hard-set
    `WINEDEBUG=-all` and silently ate the first diag run's trace — it now respects a caller's
    `WINEDEBUG` (fixed 2026-08-23).

**Prior art upstream:** [#48](https://github.com/3Shain/dxmt/issues/48) (closed) is the same class —
"doesn't update screen contents unless switching fullscreen on/off" — but a different trigger, and
its `SetFullscreenState: stub` / `outstanding buffer hold` signatures do **not** appear in our v0.80
logs. No open issue covers focus-loss freeze (searched 2026-08-22). Draft report:
`docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`.

**Both stacks misbehave on alt-tab** (D3DMetal/Wine 10 gave cursor desync and darkening; DXMT/Wine 11
gives this freeze), so it is not renderer-specific.

**RESOLVED FOR DAILY PLAY (2026-08-23, Option-2 test):**
- **Fullscreen Window mode is IMMUNE.** Tested in-city: alt-tab back and forth freely, input
  routes correctly, no freeze. This is now the recommended display mode. (The old "windowed
  thrashes display modes" gotcha #6a was the DXVK-era stack — does not apply to DXMT.)
- **Frozen in exclusive Fullscreen? Recover in-game, no force-kill:** blind-navigate (one
  alt-tab refresh per step) Options → Graphics → Display Mode → Fullscreen Window → Apply.
  The screen comes back LIVE. Trace shows NO new swapchain at the toggle — the game simply
  switches to presenting its windowed chain, which is the visible one. Mechanism confirmed
  from a second angle.
- Exclusive Fullscreen remains freeze-on-alt-tab **on the wine 11.0 wrappers** (`CS2dxmt11-pk110`,
  `S734M`). On the daily 11.16 engine it is fixed — see the ✅ line above. The fix came from Wine,
  not from dxmt#206, which the maintainer closed as a duplicate.

**Old practical rule (superseded): don't alt-tab out of exclusive fullscreen.** Use the windowed launcher
(`explorer /desktop=`) for sessions where you must switch between the game and a terminal; use
fullscreen for playing.

## Building a Wine engine from source for this stack (2026-08-23)

Five traps, each hit live while building the stock-11.16 + DXMT engine. All are encoded in
`scripts/build-engine-1116.sh`; this is why each line is there.

1. **brew's freetype/gnutls are arm64-only — an x86_64 Wine cannot link them.** Configure does a
   real link test: freetype failure is a *hard abort*, gnutls failure is a **silent** downgrade to
   "no schannel support" (= Steam TLS broken, discovered much later). Installing `pkgconf` does
   not help. Fix: pass `FREETYPE_LIBS`/`GNUTLS_LIBS` pointing at an existing wrapper's x86_64
   dylibs, with brew's (arch-neutral) headers.
2. **Pathless install names poison the recorded soname.** Those donor dylibs have install names
   like `libfreetype.dylib` with no path, so configure's soname extraction captures the *entire*
   `otool -L` line — tab, version parenthetical and all — into `SONAME_LIBFREETYPE`. Wine then
   `dlopen()`s that garbage at runtime and silently loses fonts + TLS. Fix:
   `ac_cv_lib_soname_freetype=libfreetype.dylib ac_cv_lib_soname_gnutls=libgnutls.dylib`.
   **Gate on `include/config.h` after configure — never trust "configure exited 0".**
3. **The build itself needs `DYLD_FALLBACK_LIBRARY_PATH`.** Build-time tools (`sfnt2fon`) link the
   same pathless name and die with `dyld: Library not loaded` partway through `fonts/`. Set it on
   the `gmake` line, not just at runtime.
4. **Run the one-time prefix update controlled, before the first launcher run.** A fresh 11.16
   prefix fires the wine-mono updater dialog; under a `-silent` Steam boot it has nowhere to
   present, everything queues behind it, and the *launcher* reports a bogus "Steam did not
   auto-login (token expired)". Tell: an idle `rundll32 …InstallHinfSection… wine.inf` at 0% CPU.
   Fix: `WINEDLLOVERRIDES="mscoree=;mshtml=" wine64 wineboot -u` first (~15 s).
5. **`gmake install` needs `--prefix`**, or it targets `/usr/local`. And a hand-copied engine is
   not bootable: it also needs `programs/*/*-windows/*` (wineboot, services, explorer) and all of
   `share/wine/` (wine.inf, nls, fonts) — `install` handles both; a naive `dlls/` copy does not.

## Two self-inflicted measurement bugs found by review, not by failure (2026-08-23)

Both had been silently wrong for a while; both were caught by adversarial review of a plan, then
fixed and *demonstrated* wrong the same session.

- **`run-minrepro3.sh` could fabricate a verdict.** `waitfor()` ended in `echo` on timeout, so it
  returned **success** — every `waitfor X && snap` fired regardless, sampling stale desktop
  pixels from a run that had already died. The printed `VERDICT:` line was a hardcoded string, not
  a computed result. Fixed: timeouts return 1 and abort, a failed/empty `screencapture` aborts,
  and the verdict is computed from the sampled RGB (`STALE`/`LIVE`/`INCONCLUSIVE`). Minutes after
  the fix a locked display made it abort cleanly — the old version would have printed
  "BUG REPRODUCED" over nothing. **Any harness that prints a conclusion it didn't compute is a
  liability.**
- **The launcher re-patched the wrong wrapper.** `launch-cs2-dxmt11.sh` called `repatch.sh`
  *without* `CS2_GAME_DIR`, so with `CS2_WRAPPER=` pointing anywhere else it patched the default
  wrapper while reporting success for the one it launched. Harmless-looking (patches are
  idempotent) until you run two wrappers — then a game update silently leaves the running one
  unpatched. The correct idiom already existed in `setup.sh`; only the launcher omitted it.

## AppleScript applet `progress` renders NO window on macOS 26 — use an AppKit panel (2026-08-23)

Building the dock-launch progress window, both canonical applet patterns produced a running
process with **zero windows** (System Events `windows` = empty, confirmed on two builds):

- stay-open applet (`osacompile -s`) setting `progress total steps` from `on run` and updating in
  `on idle` — no window, ever;
- plain applet with the whole poll loop inside `on run` (`repeat`/`delay`, the classic pattern
  that historically kept the panel alive) — still no window.

The `progress` properties execute without error; the panel simply never materializes. Fix that
shipped: a ~80-line Swift AppKit floating panel compiled by `make-shortcut.sh` at bundle-build
time (`xcrun swiftc`, CLT ships it), `.accessory` activation policy so it never takes focus or a
dock icon, `orderFrontRegardless()` + `.floating` + `.canJoinAllSpaces` for visibility. Verified
end to end the same night: renders, live milestone tracking from the launcher log, self-dismisses
2 s after the game process appears.

## `pgrep -f` self-match: your own watcher becomes "the game is running" (2026-08-23)

The shim's `pgrep -f 'Cities2.exe'` matched a *monitoring script* whose command line contained
the string (a background watcher polling for game exit) — so a dock click concluded "already
running", refused to launch, and showed nothing. The same trap the steamwebhelper rule documents,
now measured from the other side: **any** wrapper/watcher/editor whose argv mentions the pattern
is a false positive.

Scope on structure the real process must have and casual mentions won't: the game's argv is a
unix path, so match `'/Cities2.exe'` **with the leading slash** (watchers say `Cities2.exe`
bare). Applied in the shim's already-running check, its `GPID` capture, and the Swift panel's
game-up probe. Corollary: a test harness that greps for a process by name must never put that
name in its own command line unescaped (`pkill` excludes itself; `pgrep -f` does not).

## Resolution scaling on this stack: what works and what structurally cannot (2026-08-24)

Adjudicated live in one session (HUD + Settings.coc reads + relaunches). The traps:

- **The in-game Screen Resolution dropdown is INERT in Fullscreen Windowed.** Unity borderless
  always uses desktop resolution; the choice saves to `Settings.coc` but the swapchain never
  follows (verified across a relaunch: saved 1280×720, HUD input stayed 1920×1080). Resolution
  choices only bite in exclusive Fullscreen (mode-change/blanking class — see the refresh-rate
  section) or plain Windowed.
- **Consequently `DXMT_METALFX_SPATIAL_SWAPCHAIN` cannot downscale-render in borderless** — input
  is pinned at desktop res, so any factor >1 is supersampling (measured: softer AND slower — three
  resample passes for world text). MetalFX itself works (HUD `Scaling: Spatial` lines) — it's the
  display mode that kills the use case, not DXMT.
- **CS2 street names are painted onto roads in the 3D world, not drawn as UI** — any internal-
  resolution scaling (DRS included) softens them. "DRS keeps UI sharp" is true for menus/panels
  and useless for road text.
- **DRS Constant defaults to 50% scale** (`minScale: 0.5`, `EdgeAdaptiveScaling`) — brutal at
  1080p. The scale slider is double-gated: DRS must be *Constant* AND "SHOW ADVANCED" toggled.
- **Anti-aliasing was the actual jaggedness fix**: Low→High SMAA at native, cost ~1-2 FPS.
  Settings.coc also carries `outlinesMSAA: MSAA8x`.
- Reading `Settings.coc`: it is a title line + MULTIPLE concatenated JSON objects — `json.loads`
  fails with "Extra data"; use `JSONDecoder.raw_decode` in a loop. (Reading is fine; the standing
  rule against hand-EDITING it is unchanged.)

## Settings.coc: complete value edits ARE honored — the trap is PARTIAL flips (2026-08-24)

Refines the standing "never hand-edit Settings.coc" rule after a controlled experiment (game
closed, backup taken, one surgical value swap, functional verification):

- Edited `minScale` 0.75→0.5 in the DRS block. The game booted clean, **rendered at the edited
  scale** (benchmark gpuMs 40.5→33.7 avg, −17%, far beyond the ~11% run spread — functional
  proof, not just file survival), preserved the value through its exit rewrite, menu uncorrupted.
- The original 2026-08-22 trap stands for its actual mechanism: flipping an `enabled` flag whose
  companion parameters are absent/zeroed produces the "on but zeroed" Custom profile. **Complete,
  self-consistent value edits with the game closed are safe.** Always: backup first, edit with
  unique-anchor regexes asserting exactly one match, verify persistence after the next run.
- This unlocks autonomous settings A/B: `~/cs2-patch/perf-runs/settings-series.py` (edit → bench
  → verify → restore per cell). Menu label ↔ file value mappings are enums/floats, e.g. the menu's
  "AMD FidelityFX Super Resolution 1.0" saves as `upscaleFilter: "EdgeAdaptiveScaling"` (Unity's
  EASU name); other filter enums: CatmullRom, ContrastAdaptiveSharpen, TAAU.

## Steam Play button / Paradox Launcher — re-tested 2026-08-24: runs now, still doesn't deliver a game

The historical claim ("routes via the Paradox Launcher and exits before Unity initialises") is
stale in mechanism: on the 11.16 stack, `steam.exe -applaunch 949230` (the Play-button path) now
boots the full launcher — bootstrapper → `Paradox Launcher.exe` v2.2026.6 → Chromium UI window +
settings + update checks. It then dies on its own IPC: `cpatch took too long to connect`,
`set-auth-token command timed out`, `Socket server is not connected` (launcher-v2 logs under
`AppData/Local/Paradox Interactive/launcher-v2/logs/`). Unattended outcome unchanged: no game.
Community reports (M4, presumably CrossOver/Whisky-lineage Wine) of Play "just working" are
plausible — different Wine, different localhost-socket behavior — and do not replicate on stock
Wine 11.16. Direct `Cities2.exe` launch remains this stack's reliable path. Open question: does
the launcher's window render + does its own Play work when clicked (needs an attended try).

## Steam's visible UI — the CEF investigation (2026-08-24 → 2026-08-30)

> **Moved to [`docs/steam-ui-investigation.md`](docs/steam-ui-investigation.md)** — 32 sections,
> 1,641 lines, one open investigation rather than a set of standing traps. This table is the index
> and it is the part you want: every section, in order, with the status the 2026-08-30 audit gave
> it. **Trust the status column, not the section titles** — many titles say "ELIMINATED" or
> "SOLVED" and are retracted by the banner directly beneath them in the detail file.
>
> `VOID` / `RETRACTED` = do not build on it. `PARTIAL` = one half survives, the banner says which.
> `SUPPORTED` = still believed. No status = audited, unaffected. Register: [`EXPERIMENTS.md`](EXPERIMENTS.md).

| status | section |
|---|---|
| — | [Visible Steam UI black-windows on 11.16 — intermittent, dxmt#141-class; silent flow unaffected (2026-08-24)](docs/steam-ui-investigation.md#visible-steam-ui-black-windows-on-1116-intermittent-dxmt141-class-silent-flow-unaffected-2026-08-24) |
| — | [Steam's visible UI is BROKEN since the ~Aug-2026 CEF update — mechanism pinned, fix queued (2026-08-24)](docs/steam-ui-investigation.md#steams-visible-ui-is-broken-since-the-aug-2026-cef-update-mechanism-pinned-fix-queued-2026-08-24) |
| — | [Steam black UI is NOT the Vulkan failure — reboot retest disproves the queued MoltenVK fix (2026-08-24 PM)](docs/steam-ui-investigation.md#steam-black-ui-is-not-the-vulkan-failure-reboot-retest-disproves-the-queued-moltenvk-fix-2026-08-24-pm) |
| — | [⚠ SUPERSEDED same day (see next section): the "11.0 → 11.16 regression" attribution below was disproven by a three-version stock sweep — stock 11.0 is ALSO blank. Kept for the measurements.](docs/steam-ui-investigation.md#superseded-same-day-see-next-section-the-110-1116-regression-attribution-below-was) |
| — | [Steam's black UI is a wine 11.0 → 11.16 REGRESSION, not a CEF/MoltenVK problem (2026-08-24 PM)](docs/steam-ui-investigation.md#steams-black-ui-is-a-wine-110-1116-regression-not-a-cefmoltenvk-problem-2026-08-24-pm) |
| `PARTIAL` | [Embedded Chromium NEVER rendered on stock Wine here — the PK vendor patchset is the enabler (2026-08-24 PM-2)](docs/steam-ui-investigation.md#embedded-chromium-never-rendered-on-stock-wine-here-the-pk-vendor-patchset-is-the-enabler-2026-08-24-pm-2) |
| `PARTIAL` | [Mechanism CONFIRMED by elimination (2026-08-24 evening): cross-process PRESENTATION is the wall; PK wins only via its GPU path](docs/steam-ui-investigation.md#mechanism-confirmed-by-elimination-2026-08-24-evening-cross-process-presentation-is-the-wall-pk-wins-only-via-its-gpu-path) |
| — | [⚠ PARTIAL — see the correction section below: the shim fixes RENDERING but NOT TEXT.](docs/steam-ui-investigation.md#partial-see-the-correction-section-below-the-shim-fixes-rendering-but-not-text) |
| `PARTIAL` | [Steam's visible UI CAN render on stock Wine + DXMT — the webhelper shim (2026-08-24 evening)](docs/steam-ui-investigation.md#steams-visible-ui-can-render-on-stock-wine-dxmt-the-webhelper-shim-2026-08-24-evening) |
| `DISPROVEN` | [The webhelper shim renders everything EXCEPT text — `--in-process-gpu` is what kills glyphs (2026-08-24 late)](docs/steam-ui-investigation.md#the-webhelper-shim-renders-everything-except-text---in-process-gpu-is-what-kills-glyphs-2026-08-24-late) |
| `RETRACTED` | [Taking DXMT out of Steam's path entirely does NOT fix it — the vanilla-wined3d split, measured (2026-08-28)](docs/steam-ui-investigation.md#taking-dxmt-out-of-steams-path-entirely-does-not-fix-it-the-vanilla-wined3d-split-measured-2026-08-28) |
| `DISPROVEN` | [The glyph loss is IN-PROCESS GPU itself, not `--in-process-gpu` — `--single-process` fails identically (2026-08-28)](docs/steam-ui-investigation.md#the-glyph-loss-is-in-process-gpu-itself-not---in-process-gpu---single-process-fails-identically-2026-08-28) |
| `VOID` | [The vanilla-wined3d split is strictly WORSE than DXMT for Steam's CEF — and the trap that nearly voided the test (2026-08-29)](docs/steam-ui-investigation.md#the-vanilla-wined3d-split-is-strictly-worse-than-dxmt-for-steams-cef-and-the-trap-that-nearly-voided-the-test-2026-08-29) |
| `SUPPORTED` | [⚠ The split never gave Steam a WORKING D3D11 — a load is not an implementation (2026-08-29)](docs/steam-ui-investigation.md#the-split-never-gave-steam-a-working-d3d11-a-load-is-not-an-implementation-2026-08-29) |
| `UNREVIEWED` | [The valid Steam-side test at last: DXMT beats vanilla wined3d at EVERY cell (2026-08-29)](docs/steam-ui-investigation.md#the-valid-steam-side-test-at-last-dxmt-beats-vanilla-wined3d-at-every-cell-2026-08-29) |
| — | [There is a THIRD mechanism for Steam's CEF, and we had never read its source (2026-08-29)](docs/steam-ui-investigation.md#there-is-a-third-mechanism-for-steams-cef-and-we-had-never-read-its-source-2026-08-29) |
| `PARTIAL` | [✅ notpop's fork BUILT and TESTED — it does not fix the Steam client, and that restores dxmt#141 (2026-08-29)](docs/steam-ui-investigation.md#notpops-fork-built-and-tested-it-does-not-fix-the-steam-client-and-that-restores-dxmt141-2026-08-29) |
| `SUPPORTED` | [The cross-process root cause, MEASURED: `macdrv_get_cocoa_window` returns NULL for a foreign HWND (2026-08-29)](docs/steam-ui-investigation.md#the-cross-process-root-cause-measured-macdrv_get_cocoa_window-returns-null-for-a-foreign-hwnd-2026-08-29) |
| `SUPPORTED` | [Cross-process, all the way down: wine's own branch is OFFSCREEN, and that is the real wall (2026-08-29)](docs/steam-ui-investigation.md#cross-process-all-the-way-down-wines-own-branch-is-offscreen-and-that-is-the-real-wall-2026-08-29) |
| `SUPPORTED` | [The cross-process compositing already EXISTS — DXMT just can't reach it (2026-08-29)](docs/steam-ui-investigation.md#the-cross-process-compositing-already-exists-dxmt-just-cant-reach-it-2026-08-29) |
| `SUPPORTED` | [🎯 FINAL: the blocker is cross-process CHILD windows, and it is a one-line FIXME in wine (2026-08-29)](docs/steam-ui-investigation.md#final-the-blocker-is-cross-process-child-windows-and-it-is-a-one-line-fixme-in-wine-2026-08-29) |
| — | [Cross-process CHILD windows: implemented, builds, TEST BLOCKED ON A STEAM LOGIN (2026-08-29)](docs/steam-ui-investigation.md#cross-process-child-windows-implemented-builds-test-blocked-on-a-steam-login-2026-08-29) |
| `SUPPORTED` | [✅ IT RENDERS — the cross-process CHILD patch fixes Steam's black client (2026-08-29)](docs/steam-ui-investigation.md#it-renders-the-cross-process-child-patch-fixes-steams-black-client-2026-08-29) |
| `VOID` | [Glyph chase on the new rendering baseline — three hypotheses tested, cause narrowed (2026-08-29)](docs/steam-ui-investigation.md#glyph-chase-on-the-new-rendering-baseline-three-hypotheses-tested-cause-narrowed-2026-08-29) |
| `PARTIAL` | [Geometry mapping lands — and it ELIMINATES occlusion as the glyph cause (2026-08-29)](docs/steam-ui-investigation.md#geometry-mapping-lands-and-it-eliminates-occlusion-as-the-glyph-cause-2026-08-29) |
| `RETRACTED` | [Glyph-atlas texture path ELIMINATED — `scripts/r8test.c` (2026-08-29)](docs/steam-ui-investigation.md#glyph-atlas-texture-path-eliminated-scriptsr8testc-2026-08-29) |
| `RETRACTED` | [Text RASTERISATION eliminated — byte-identical to the build that renders text (2026-08-29)](docs/steam-ui-investigation.md#text-rasterisation-eliminated-byte-identical-to-the-build-that-renders-text-2026-08-29) |
| — | [The glyph defect localised: Chromium has NO working GL at all on this engine (2026-08-29)](docs/steam-ui-investigation.md#the-glyph-defect-localised-chromium-has-no-working-gl-at-all-on-this-engine-2026-08-29) |
| `VOID` | [mikey92's CPU-raster config does NOT reproduce here — and the flag attribution is disproved (2026-08-30)](docs/steam-ui-investigation.md#mikey92s-cpu-raster-config-does-not-reproduce-here-and-the-flag-attribution-is-disproved-2026-08-30) |
| `PARTIAL` | [✅ CPU raster renders Steam WITH TEXT on an 11.0-lineage engine — the glyph story resolves (2026-08-30)](docs/steam-ui-investigation.md#cpu-raster-renders-steam-with-text-on-an-110-lineage-engine-the-glyph-story-resolves-2026-08-30) |
| `RETRACTED` | [No wine-version bisect is warranted — and mikey92's setup relocates the variable to macOS (2026-08-30)](docs/steam-ui-investigation.md#no-wine-version-bisect-is-warranted-and-mikey92s-setup-relocates-the-variable-to-macos-2026-08-30) |
| `RETRACTED` | [⚠ CORRECTION: macOS is NOT the variable — wine-stable 11.0 renders Steam WITH TEXT here (2026-08-30)](docs/steam-ui-investigation.md#correction-macos-is-not-the-variable-wine-stable-110-renders-steam-with-text-here-2026-08-30) |

**Two standing traps that were embedded in this thread stayed here**, because they are general and
you will want them while debugging something else entirely: *screencapture goes silently blind*
and *an unbounded `until` waiter outlived its target*, both below.

## screencapture goes silently blind when the display sleeps/locks (2026-08-24)

Mid-experiment the display slept and later showed the lock screen: `screencapture -l <id>` fails
("could not create image from window"), region captures write nothing, and a full-screen capture
returns an all-black frame — while **CGWindowList keeps working** (winlist still enumerates
windows correctly). Any pixel-based cell that ran in that state is VOID, not negative: two
`--in-process-gpu` pixel cells were discarded this way (their "no window" verdicts survived only
because winlist is display-independent). Before trusting any capture-based verdict, capture the
full screen once and eyeball it — the all-black/lock-screen frame is unmistakable. `caffeinate
-u -t 3` wakes the display, but a locked session stays locked (never enter credentials — park
visual work until the user unlocks).


## An unbounded `until` waiter outlived its target by 6.5 hours (2026-08-29)

`until grep -q <pattern> <file>; do sleep 10; done` was used to wait on a backgrounded probe. The
probe was killed ~15 minutes later; the loop kept polling a file that would never change again and
was still running **6 h 37 m** later, found only because the user noticed it in the task list.

Two lessons, and the second is the one that actually bit:

1. **Bound the wait on the TARGET, not just the condition.** A waiter whose condition can become
   permanently unreachable needs a second exit: check the producer is still alive and break if it
   is not — `until <cond>; do pgrep -f <producer> >/dev/null || break; sleep 10; done` — or cap the
   iterations. Later probes in the same session did this; the first did not.
2. **"Is anything still running?" must include your OWN waiters.** The check run here grepped for
   `steam.exe|wine64|gmake|meson|caffeinate` — the things deliberately *started* — and reported
   "nothing running" while a monitoring loop from the same session was still going. **A waiter is
   exactly as running as the thing it waits for.** Sweep for `until|sleep` loops and background
   task IDs too, and prefer `TaskStop` on the task id over hunting the process.

Cost was negligible (a sleeping shell, no interference with any measurement) — recorded because it
is the same family as the auto-armed background task that blocked a macOS update, per the global
`CLAUDE.md` note, not because this instance did harm.


## End-to-end on 11.16 with the shim armed: it works, with two live defects (2026-08-30)

First full walk of the daily stack after the `nohup` fix, with the shim armed
(`SHIM_ARGS=" --in-process-gpu"`): **Steam UI renders with text · library renders correctly ·
the game boots to `MainMenu reached` with mods loaded** (EasyZoning, FindIt, InfoLoomTwo), Steam
visible and logged in throughout. So the two-wrapper split is no longer *forced* by missing fonts.

Two defects observed live, neither of them font-related:

1. **Store tab flickers heavily while video tiles autoplay.** Library is clean; it is specific to
   the store's video content. "Seems like a cache issue, caught up eventually" — it settles rather
   than staying broken. This is the running cost of `--in-process-gpu`, and it is the first real
   cost that has ever been correctly attributed to that flag (the old "it kills all text" charge
   was the harness, see C4 `DISPROVEN`).
2. **Resolution mismatch on a two-external setup.** The game opened a **3840×2160** window while
   the main display is the 1920×1080 U2424H. That is *not* retina doubling — `RetinaMode` was
   verified unset and the profile correctly selected `home — DELL U2424H (DRS off, native 1:1)`.
   3840×2160 is the **unrotated native resolution of the OTHER display**, the U2720Q, which runs
   2160×3840 portrait. So the game is choosing the wrong display and ignoring its rotation.
   `Settings.coc` had `displayIndex 0`, `width 1920`, `height 1200` — a height matching neither
   panel. Unknown whether this predates today.

   **Recovery, when the window is bigger than the display and the menus are off-screen** — you
   cannot click your way out, because the controls are rendered outside the visible area. CS2 is
   **Unity**, so its standard screen arguments work, and the launcher already forwards `CS2_ARGS`
   to `Cities2.exe` (`launch-cs2-dxmt11.sh:194`):

   ```bash
   CS2_ARGS="-screen-width 1920 -screen-height 1080 -screen-fullscreen 0" bash ~/cs2-patch/launch-cs2-dxmt11.sh
   ```

   Measured 2026-08-30: window came back as **1920x1080 at 0,0**, `MainMenu reached`, dialogs
   centred and clickable. Then set the resolution **in-game** so it persists and the override is no
   longer needed. ⚠ **Do not fix this by editing `Settings.coc`** — partial flips there yield an
   "on but zeroed" profile the game reports as `Custom` and will not restore across a display
   change. The command-line override needs no file edit at all, which is why it is the right tool.
   Quit the game before any such attempt anyway: it rewrites `Settings.coc` on exit and will
   overwrite the edit you just made.

⚠ **A direct `wine Cities2.exe` that bypasses the launcher HANGS** — black window, ~110% CPU, RSS
climbing, no game logs, stalled stderr. Reaching `MainMenu` needs the launcher's preamble, which
sets `SteamAppId`/`SteamGameId`/`SteamOverlayGameId` and runs the display profile. Don't test the
game by calling the exe directly; run the launcher.

## `du` lies about disk on APFS: the two wrappers' 91 GB game installs were CLONES (2026-08-24)

Both wrappers reported a 91 GB `Cities Skylines II` install, so deleting the redundant one in
`CS2dxmt11-pk110.app` looked like a ~91 GB reclaim. **It freed 0 GB** — measured, `df -g` read
222 before and 222 after.

**Why:** APFS `clonefile` copies (Finder duplicate, `cp -c`, `cp -Rc`) get **distinct inodes but
share physical extents**. `du`/`ls` report each clone's *logical* size, so N clones of a 91 GB
tree look like N×91 GB while occupying ~91 GB plus divergence. Checking inodes is **not** enough
to prove two trees are independent — that check passed here and was still wrong.

**How to actually tell before deleting anything large:** trust only the container, not `du` —
`df -g /` (or `diskutil info / | grep "Container Free Space"`) before and after; on a clone the
number does not move. There is no cheap per-file "is this cloned" query, so measure the delta.

**The useful consequence:** restoring a clone is instant and free — `cp -Rc <src> <dst>` re-shares
the extents rather than copying 91 GB. So the pk110 wrapper can be given the game back in seconds
from the daily wrapper's copy if it is ever wanted as a play wrapper again; it does **not** need
a 91 GB Steam re-download. (Deleting `steamapps/common/<game>` **and** its
`appmanifest_<appid>.acf` together is what stops Steam re-downloading — removing the tree while
leaving the manifest makes Steam see "installed, files missing" and fetch the lot again.)

## `SIGTERM` to steam.exe leaves a `.crash` marker too, not just `kill -9` (2026-08-31)

The standing rule says *"never `kill -9` Steam — it leaves a 0-byte `.crash` marker that makes the
next launch exit 1"*. Measured 2026-08-31: a plain **`kill -TERM`** does the same. A whole session's
teardowns used TERM on the strength of that rule and still produced the marker.

**So the rule is really: never signal `steam.exe` at all.** Use `steam.exe -shutdown` and wait for
it; only fall back to `wineserver -k` if that fails. If you did signal it, check and clear:

```bash
rm -f "<prefix>/drive_c/Program Files (x86)/Steam/.crash"
```

`launch-cs2-dxmt11.sh` clears a stale marker on startup, so the daily path self-heals — but a direct
`wine steam.exe` launch does not, which is exactly what the render harness does.

## Same-account Steam sessions SWAP, they don't stack — and the running game doesn't care (2026-08-24)

Context: the two-wrapper split (play on 11.16, shop on 11.0) puts two logged-in Steam clients on
one machine. The question the `CS2 Steam Store.app` shortcut forces: does opening the store kill
a running game?

**Measured mechanics.** Both clients RUN logged-in happily, but the account holds ONE online CM
session. Whichever client connects last takes it; the other logs
`ConnectionDisconnected() not auto reconnecting due to Session Replaced` and drops to its
cached/offline UI (footer shows NO CONNECTION; the library stays browsable). It does NOT
auto-reconnect, so the clients never fight — each swap is one clean handover, triggered only by
a fresh connect (client start, or a manual Go Online).

**The running game survives the steal — measured at the menu AND in live gameplay** (2026-08-24
22:13: session stolen mid-play with James at the controls; 2.5-min soak, game at 250% CPU, the
only new Player.log lines were routine Unity asset GC). Menu-state detail: with CS2 at the menu,
starting the store wrapper's Steam took the session at 21:42:59 — the game-side Steam delivered
`SteamServersDisconnected_t` and the game kept rendering (117% CPU) with ZERO new Player.log
lines over an 8-minute soak. CS2 needs SteamAPI at BOOT (the licence check behind the launcher's
45 s wait); a mid-session CM disconnect is a non-event. The reverse steal is symmetric: the next
game launch logs in and kicks the store back to cached mode (21:48:39, same session).

**Untested edge:** a Paradox Mods download in flight at the moment of a steal (different
auth/CDN — expected unaffected, not measured).

## Prefix-scoped `lsof` attribution has TWO blind spots, and both leave processes running (2026-08-30)

The standing rule — attribute a wine process by open files against the **prefix**, never by command
line — is right, but a teardown built only on it leaves work behind. Found by James noticing wine
was still running after a session I had reported clean.

1. **Processes that hold the wine *share* dir, not the prefix.** A stuck
   `rundll32.exe setupapi,InstallHinfSection … wine.inf` (a prefix update that never finished) had
   `…/SharedSupport/wine/share/wine/wine.inf` open and **no prefix path at all**. A
   `lsof | grep "$WINEPREFIX"` sweep is structurally blind to it. Match on the **wrapper root**
   (`…/CS2dxmt11.app`) to catch both, not the prefix subdirectory.
2. **Other prefixes.** Probing PK 11.0 or wine-stable leaves *their* services running. Tearing down
   the prefix under test says nothing about them — sweep every wrapper you touched this session.

⚠ **`wineserver -k` does not kill orphans.** When the parent wineserver is already gone, `-k` starts
a *fresh* server and kills nothing, reporting success. Twice in one session it left 13 and then 9
processes alive. TERM them by PID; a couple may need KILL. **The `kill -9` prohibition is
specifically about Steam** — a hard-killed `steam.exe` leaves a 0-byte `.crash` marker that makes
the next launch exit 1. Wine service processes carry no such risk, so escalate freely once you have
confirmed by name that no `steam.exe` is in the set, and check both prefixes for `.crash` after.

3. **⚠ The candidate list must NOT be `pgrep -f`.** Published here first as
   `pgrep -f 'wine|Cities2|steam\.exe'` piped into an `lsof` check — which is the **command-line
   attribution this very section forbids**, just moved one step earlier. It reported the machine
   clean while **29 wine processes across six wineserver sessions** were alive, the oldest
   **27 hours**, because their command lines are `C:\windows\system32\explorer.exe /desktop`,
   `services.exe`, `rpcss.exe` — none of which contain "wine", "Cities2" or "steam.exe". The tell
   was a Dock tile James asked about; `System Events` listed a GUI app named `wine` that no `pgrep`
   pattern could find. **Enumerate every PID and let `lsof` decide.** It is slower and it is the
   only version that is correct.

**Sweep that actually works:**

```bash
for p in $(ps -axo pid=); do
  lsof -p "$p" 2>/dev/null | grep -qE '/(CS2dxmt11|CS2dxmt11-pk110|S734M)\.app' \
    && echo "$p  $(ps -o etime= -p $p) $(ps -o command= -p $p | cut -c1-60)"
done
```

Also seen in that sweep: a **`control.exe appwiz.cpl install_mono`** stuck for 9 hours — the Wine
Mono installer blocking silently, which this file already documents as a fresh-prefix trap. It will
sit there forever and no cmdline pattern finds it either.

## Command lines cannot attribute a wine process to its wrapper — use lsof (2026-08-24)

The old rule (scope Steam checks with `pgrep -f "<App>.app.*steam.exe"`) has TWO blind spots,
both hit live in one evening:

1. **A steam.exe re-exec'd by its own updater/watchdog carries a Windows-style argv**
   (`C:\Program Files (x86)\Steam\steam.exe`) — no unix path anywhere, so every .app-path pgrep
   misses it. Found as a *hidden* logged-in Steam that a pgrep sweep called "no steam running";
   left alone it kept re-stealing the account session and respawning webhelpers that looked like
   orphans. An "already running" check that misses it starts a SECOND steam into the same
   prefix; a shutdown loop that misses it declares victory while Steam lives.
2. **steamwebhelper children always carry Windows-style argv AND reparent to launchd** when
   their steam.exe dies mid-cleanup — six of them survived a "Residual: 0" shutdown, invisible
   to `pgrep -f "$APPTAG"`.

**The truthful test is open files:** `lsof -p <pid> 2>/dev/null | grep -q "$WINEPREFIX"`
(~30 ms/pid). Attribute by PREFIX, not by the wine directory — an engine can serve a foreign
prefix (a /tmp/bisect scratch prefix ran the daily wrapper's wine binaries, so wine-dir matching
blamed its webhelpers on the daily wrapper). Both launchers now ship `_owns()` /
`steam_exe_up()` / `webhelper_up()` / `steam_family()` plus a shutdown sweep built on this, and
the `build-engine-1116.sh` / `install-webhelper-shim.sh` preflights use the same loop.

**Bonus trap:** bench/bisect scratch prefixes under /tmp keep their own logged-in steam.exe
alive for hours after the test ends — and steal the account session while at it (see the
session-swap entry above). End them: `WINEPREFIX=/tmp/<scratch> wineserver -k`.

## Retina mode: native 3024×1964 costs ~13% stress-scene GPU — but the game's saved resolution is a ratchet (2026-08-26)

Full campaign: `docs/plans/retina-swapchain-experiment.md` (triple-checked, then executed same
session; rt- rows in the perf results doc). The standing facts:

- **`RetinaMode=y` (+ LogPixels 192) works as designed on the self-built 11.16 engine**: Wine's
  desktop becomes the panel-native 3024×1964, the borderless swapchain follows automatically
  (Unity `Player.log` "Window resolution: 3024x1964", Metal HUD agrees), the compositor ×2
  upscale — the laptop-panel blur — disappears, painted street names go razor sharp, and the
  game UI scales proportionally (normal size). DPI is read from `HKCU\Control Panel\Desktop\
  LogPixels` (primary); per-app `AppDefaults` scoping is deliberately unsupported for RetinaMode
  (upstream comment: DPI/monitor geometry must be prefix-wide) — do not "fix" it into AppDefaults.
- **Measured cost (stress bench, ×3 medians): gpuMs.average 32.31 → 36.42 = +12.7%** for 4× the
  pixels — the scene is CPU/sim-bound, so GPU time responds sub-linearly. On the GPU-bound daily
  city expect the *absolute* delta (~+4 ms GPU) to matter more: ~25 → ~30 ms class, i.e. 40 FPS →
  mid-30s. Accidental middle point: 1920×1200 renders at 33.52 gpuMs (+3.7%).
- **TRAP 1 — `Benchmark.coc` `screenResolution` (→ results.jsonl `resolution`) is NOT the
  swapchain.** It is Unity's `Screen.currentResolution` = the *display-mode* view. Under retina,
  winemac's mode list doubles, the game's saved resolution can suddenly match a mode, and winemac
  *emulates* the mode change for borderless windows — so the field reports the saved value
  (1920×1200 here) while the game demonstrably renders 3024×1964. Arbiter for what actually
  rendered = `Player.log` "Window resolution" + the HUD, never this field.
- **TRAP 2 — the saved resolution cannot be cleared from disk; the game re-derives and re-persists
  it every run.** With a stale external-era 1920×1200 saved: run 1 under retina boots native, but
  the game re-applies 1920×1200 (validation of the on-disk value against its mode list evidently
  rejects 3024×1964), then at exit writes 1920×1200 into BOTH `Settings.coc` (`resolution` key —
  which it also transiently drops and re-adds) AND Unity's Screenmanager registry values, flipping
  `Resolution Use Native` 1 → 0. Consequence: the NEXT boot creates the window at 1920×1200 (soft
  upscale blit). Setting both layers to 3024×1964 with the game closed survives exactly one boot
  (that boot renders native) and is overwritten again on exit — measured across four launches.
  **Stable retina daily use therefore needs a pre-boot assert (`Screenmanager Resolution Use
  Native…=1`) in the launcher, or the in-game dropdown setting the game's own runtime value to
  3024×1964 (untested — the dropdown may not offer it if the mode list filters it).**
- Outcome 2026-08-26: **full revert, nothing adopted** (decision matrix row 4 — stable adoption
  requires a launcher change outside the checked plan's blast radius). Machine byte-verified back
  to the measured baseline state. The revert recipe lives in the plan §1.

**Addendum (same night — ADOPTED via the in-game dropdown; trap 2 refined).** Under retina the
in-game Screen Resolution dropdown lists the full doubled mode set (3024×1964 at 120/60/59/50/48/
47 Hz, 3024×1890, 2704×…, …). James selected 3024×1964×120 live; on exit the game persisted the
**complete tuple — width + height + `refreshRate` object — into `Settings.coc`** and wrote
Screenmanager 3024×1964 with `Use Native=1`. That refines trap 2: the file-edit rejection was
almost certainly the **missing `refreshRate`** (the stale external-era object carried only
width/height; a hand edit of those two fields alone fails the game's validation and falls back) —
not a mode-list filter. Consequences: (a) the ratchet ratchets *whichever way the last in-game
selection points* — after a UI selection of native it is self-maintaining and **no launcher assert
is needed** *(superseded 2026-08-27: the display-profile helper now asserts `Use Native=1` every boot regardless — docs/plans/launcher-display-profiles.md)*; (b) a future from-disk resolution change must write the full tuple including
`refreshRate`, or use the dropdown. Live-city cost of native-at-100% measured far above the
sim-bound bench's +13%: GPU 25.4 → 45.9 ms (40 → 22 FPS) — the bench extrapolation understated a
GPU-bound scene, as flagged. Final adopted config: retina native swapchain + DRS Constant 0.5 +
ContrastAdaptiveSharpen (= morning's render cost, native presentation).

**Second addendum (2026-08-27 — display profiles shipped; DRS disk-enable proven live).** The
launcher now runs `cs2-display-profile.sh` pre-boot (main-display-keyed: mobile = native + DRS
0.5 CAS · home/external = DRS off, native 1:1; `CS2_PROFILE=off|home|mobile`, `DRY=1`;
fail-open). Measured while shipping: (a) disk-flipping the DRS `enabled` flag **to true** does
take effect — a minScale-0.25 discriminator probe moved gpuMs.average 36.5→32.64 and 1%-low
22.5→32.6, far beyond repeat noise (the settings series had only proven the disable direction);
(b) ⚠ DRS-0.5's saving is **invisible on the sim-bound bench scene** at native swapchain (36.5 vs
native median 36.42 — pixels are cheap there); judge DRS by a scale-extreme probe or on the
GPU-bound live city, never by a single 0.5-vs-native bench pair; (c) the Metal HUD resolution
line shows the **drawable**, never DRS's internal render target — it is not a DRS arbiter.

**Third addendum (2026-08-27 — T10 first dock: RetinaMode is GLOBAL, so it joined the profile).**
winemac's RetinaMode doubles the coordinate space of EVERY display in the prefix, not just
retina-backed ones — measured: with a 1× DELL U2424H (1920×1080 logical = pixels) as main, the
game's window came up **3840×2160**, supersampled down by the compositor (75.35 gpuMs / 14.5 FPS
stress-scene — rt-home-1; pretty, unplayable). The display-profile helper (v2) therefore aligns
retina per context: **mobile = RetinaMode y + LogPixels 192/192 · home = RetinaMode deleted, CPD
LogPixels deleted, Fonts 96** — the option is read per-process at init, so a pre-boot flip is
exact, and skip-if-already keeps steady-state boots at zero wine calls. Proven live in the home
direction (rt-home-2: window 1920×1080 true 1:1, 36.49 gpuMs, registry state held through the
game's exit rewrite); the mobile direction is the same code path, DRY-verified, live-confirmed on
the next laptop boot. Reporting subtlety worth keeping: the settings-already-set early exit
initially swallowed the retina-ops report — the helper now flushes the DRY would-do list from
`out()` and marks "retina realigned" on that path.

## Mod keybind ⚠ badges arm at boot from FACTORY defaults — rebinds can't clear them (2026-08-27)

The Options mod-row/tab ⚠ is stale cached state, not live config: during boot, each mod's
`AddActions` triggers `InputManager.CheckConflicts` (via the defer-wrapper →
`ProcessActionsUpdate`) **before the per-user .coc overrides settle**, so the mods'
factory-default chords (which collide: FindIt/Traffic Ctrl+R, Traffic/quicksave Ctrl+S,
trio/quick-set, Anarchy/vanilla PgUp/Dn) get flagged into `ProxyBinding`'s cached conflict
state. Two separate surfaces read that cache — patching only the first (2026-08-27 v2) did
NOT clear the badges James sees; screenshots falsified that attribution:
- `SetModConflictNotification` → a per-mod "KeyBindingConflict" notification (menu toasts).
- **`InputBindingField.get_warning`** → per-keybind-row widget warning
  (`(binding.hasConflicts & mask) != 0`); the KEYBINDS-tab ⚠ and mod-row ⚠ aggregate from
  these rows (the mods declare no `SettingsUI*Warning` attributes — rows are the only
  source). This is the badge.
Opening a badged section re-runs `CheckConflicts` against the settled bindings → cache goes
clean → badge clears on mere viewing, re-arms next boot. That's why the 2026-08-25 disk
rebinds fixed real collisions but never the badge. **Lessons: an indicator that clears on
view without input is an acknowledgment/stale-cache pattern — don't debug it as a mirror of
current config; and after neutering one consumer of shared state, re-check WHICH consumer
renders the artifact you're chasing (xref all readers — here `get_hasConflicts` had four).**

Conflict predicate (for future binding work, disassembled 1.6.0f1):
`ProxyBinding.ConflictsWith` = both set + same device + `PathEquals` (+ usage overlap), where
PathEquals includes modifiers UNLESS either action has `modifierOptions==0` (then base-key-only
— `Alt+R` vs `Ctrl+Alt+R` would collide); `CanConflict` exempts whitelisted/linked pairs
(how Anarchy's mimic-vanilla PgUp/Dn shares keys without flagging).

Fix = two tiny IL patches, `patch-modconflict-badge.py` (~/cs2-patch original, repo scripts/
copy): **P1** `SetModConflictNotification` `ldarg.2`→`ldc.i4.0` (0x04→0x16, always the
pop/clear path — kills the notification) and **P2** `InputBindingField.get_warning` prologue
→ `ldc.i4.0; ret` (0x16 0x2A — constant-false widget warning, kills the badges). The cut is
at the WIDGET, not `ProxyBinding.get_hasConflicts`, because the interactive rebind
"key already taken" dialog (`InputRebindingUISystem` → `NeedAskUser`) reads `hasConflicts`
too and must stay live. Methods re-resolved by name via dnfile each run (refuses on
unexpected bytes), lsof game-down guard (run BEFORE dnfile opens the DLL — dnPE's own mmap
otherwise trips it), idempotent, backs up Game.dll. **The dxmt11 launcher auto-ensures both
at every start (step 0b)** — covers game updates; repatch.sh does NOT cover Game.dll.

## IL opcode surgery: branch opcodes have STACK effects — brfalse pops, br doesn't (2026-08-27)

The v1 badge patch flipped `brfalse`→`br` (0x39→0x38): one byte, same length, looks
equivalent — but `brfalse` POPS the condition its `ldarg.2` pushed and `br` does not, so the
method leaves an orphaned stack slot and Mono rejects the whole method at JIT:
`InvalidProgramException: Invalid IL code in ... SetModConflictNotification ... IL_015a`,
thrown on the BOOT path (CheckConflicts → InitializeUI) and again from every mod's
`AddActions` (MoveIt init died). Boot-verify caught it; backup restore was byte-verified by
the patcher's own sig check reading PATCHABLE again. **Rules: (1) when neutering a
conditional, replace the VALUE (`ldarg.X`→`ldc.i4.0/1`) and keep the branch, rather than
changing the branch opcode — it preserves stack shape by construction; (2) emulate stack
effects over every path before writing any opcode change; (3) an IL patch without a
boot-verify is not applied, it is armed.**

Second and third failures, same day (boot-verify rounds 4 + 5): **truncating a method is
the wrong primitive entirely — Mono linearly decodes the ENTIRE body, and dead code is not
exempt from any of it.** Round 4: `ldc.i4.0; ret` over the first two bytes left the old
third byte (a field-token fragment, 0x33) decoding as `bne.un.s` with an out-of-method
target → `InvalidProgramException: IL_0002`, in unreachable code. Round 5's "fix" (nop-pad
the whole tail) failed the SAME linear pass differently: **a `nop` tail falls off the end
of the method** — the decoder needs the last instruction to be a terminator, kept reading,
and hit the next method's tiny header (`IL_0021: beq.s IL_0095` = the neighbor's `2E 72`).
**Rule (4), as finally measured: don't truncate. The safe primitive is VALUE SUBSTITUTION
inside unchanged control flow — replace a load/call sequence with `ldc` + nops of identical
length, leaving every branch, stack shape and the original terminator intact** (v2c: the
11-byte `hasConflicts` load → `ldc.i4.0` + 10 nops; method computes `(0 & mask) != 0` =
false). Boot-verify caught all three same-day failures; none reached a play session.

## Retina turns an ODD Win32 pixel size into a HALF POINT — and a 1px white seam (2026-08-31)

> **Ledger:** `SUPPORTED` — C12. Evidence: `resize-diag` vs `resize-ship`, `resize-measurements.txt`.

Win32 speaks **raw pixels**. Cocoa speaks **points**. `retina_on` makes that a factor of two, so
`cgrect_mac_from_win()` divides — and an **odd** pixel dimension lands on a `.5` point. The
`NSWindow`'s content view is sized in **whole** points, so anything whose geometry Win32 derives
lands exactly **one device pixel** short of the view, and whatever is beneath shows through.

```
root 2401x1500 px -> hosted layer 1200.5 x 750.0 pt   INSIDE a   1201.0 x 750.0 pt view
capture column x=2401 = 255,255,255                   interior = 15,25,36
```

**The tells, and why this hides:**

- **It is not a race, though it looks exactly like one.** It appears during resize because resizing
  is how you reach an odd size — but it is steady state and it will sit there forever.
- **The odd AXIS is the one that shows it.** `2401x1500` → right edge only. `2400x1501` → bottom
  edge only. `2400x1500` → nothing. That is the cheapest falsification test available, and if your
  theory does not predict *which* edge, it is the wrong theory.
- **A screenshot cannot settle it.** One device pixel disappears in any scaled view. Measure the
  outermost column against an interior reference (`scripts/pixel-probe.swift`).
- **You cannot reach the failing sizes by hand or from a DPI-unaware process** — a DPI-unaware
  `GetWindowRect` reports 1209 for a 2417 px window, and `SetWindowPos` scales by exactly 2, so
  every size you can ask for is even. `scripts/win-resize-driver.c` calls
  `SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2)` for this reason.

**Fix pattern:** extend to the view's edge *only where the rect already reaches it* — never round
every rect outward, which makes interior siblings overlap. Set an opaque background on the hosting
layer as well: the mirrored content is still the odd pixel size, so the residual pixel has to be
painted by something.

## `CALayerHost` z-order is INSERTION order — which is not Win32 paint order (2026-08-31)

> **Ledger:** `SUPPORTED` — C13. Evidence: `resize-diag` (repro) vs `resize-fix` / `resize-ship`.

Sublayers stack in the order they were added. Cross-process hosted layers are added when the owning
process receives `WM_MACDRV_CREATE_REMOTE_LAYER`, i.e. **whenever the other process happens to
create a swapchain** — which has nothing to do with the z-order of the windows they mirror.

CEF recreates a swapchain on **every resize**. Steam's client is **two sibling `CefBrowserWindow`
trees** on one root — *not* a parent and a child, which their rectangles invite you to assume:

```
root 0x30124 SDL_app "Steam"
 |- 0x1013E CefBrowserWindow 2398x1215 @1,250   TOP sibling     -> hosts 0x10140
 `- 0x6012A CefBrowserWindow 2400x1500 @0,66    BOTTOM sibling  -> hosts 0x2011E
```

So any resize that recreated the **lower** browser's surface put its full-window layer **on top of**
the content layer, covering the client with a layer nothing was drawing into. Black — and it
**stayed** black, because the next resize recreated it again. `2400x1500 → 2399x1499 → 2400x1500`
reproduced it every time (interior luminance 82 → 1 → 0).

**Two traps worth naming:**

- **Read the ancestry, do not infer it from rectangles.** The fix was going to be "a child must
  paint above its parent" — which would have been built on a coincidence, because these two are
  siblings. `win-resize-driver.exe tree` answered it in one call.
- **"It renders now" is not evidence the ordering is right.** After the fix the blackout stopped,
  which is consistent with the ordering being correct *and* with it being accidentally lucky again.
  Log the resulting stack (`-DDXMT_RSZ_DEBUG`) and read the numbers: `0x2011E → z2`,
  `0x10140 → z5`, independent of creation order.

**Fix pattern:** derive `zPosition` from Win32 paint order — siblings walked bottom-to-top
(`GW_HWNDNEXT` runs top-to-bottom), each window numbered before its own children, so a child sits
above its parent and an upper sibling sits above a lower one's whole subtree.

## `CGRectIsEmpty` cannot tell "no rect supplied" from "the window is really 0×0" (2026-08-31)

> **Ledger:** `SUPPORTED` — C14. Evidence: the Library-navigation trace + the six-navigation sweep.

CEF keeps an inactive browser **in the z-order** and collapses it to **0×0**. Steam does this on
every switch between the store and the library. So a hosted `CALayerHost` legitimately receives an
**empty** frame — and the code treated empty as *"no child rect was supplied"*, which is the
**root-window** case, and stretched the layer to the whole content view:

```
while black:      0x1013E / 0x10140  =  0x0          (top sibling, still hosted, still above)
after going back: 0x1013E / 0x10140  =  2598x1275
```

Z-order then did its job and put that top sibling above the live content — a full-window layer with
nothing drawn in it. **Black, with 0 GPU crashes.**

**Why it took a human two minutes and a scripted suite zero chance:** the suite drove **geometry**
(sizes, parities, churn) and never drove **content**. Navigation is a different axis, and no amount
of resizing reaches it. When a UI bug has more than one input axis, a sweep along one of them is not
coverage — it is one line through the space.

**Three tells that separate this from the z-order blackout** ([[../GOTCHAS.md]] § `CALayerHost`
z-order):

- **A resize does NOT clear it.** That is diagnostic, not incidental: the update path *skipped*
  empty frames, so a layer that became 0×0 kept its last full-size frame and no geometry event
  could dislodge it.
- **Navigating back DOES clear it** — the rect becomes real again and the frame is applied.
- **0 GPU crashes.** Nothing died; the wrong layer is simply on top.

**Fix pattern:** stop asking `CGRectIsEmpty` a question it cannot answer. The caller already passes
`CGRectNull` for "no rect", so test `CGRectIsNull` **first**, then `CGRectIsEmpty`, then the real
case — three branches, not two. A window with no area gets **hidden**, never stretched; and it must
be **un-hidden** when it gets area back. ⚠ Do not run `CGRectNull` through a retina divide on the
way in: `INFINITY/2` survives, but relying on that is a trap for the next reader — branch before
converting.

**Scriptable repro, no clicking:** `wine steam.exe steam://open/games`, then `steam://store`.

## Visibility and geometry are independent state — don't gate one on the other (2026-08-31)

> **Ledger:** `SUPPORTED` — C15. Evidence: the Friends List trace, `/tmp/steam-popup.log`.

Self-inflicted, live for about an hour, and found by a human in ordinary use rather than by any
test. Hiding a zero-area hosted layer was correct; the **un-hide** was written into the same branch
as the frame update:

```objc
else if (host && !CGRectIsEmpty(frame) && !CGRectEqualToRect(host.frame, frame))
{ host.frame = frame; host.hidden = NO; }        /* WRONG */
```

So un-hiding could only happen if the **frame changed**. Steam's Friends List does this:

```
create ctx=1274046919 frame 300.0x650.0
update frame   0.0x0.0                       -> hidden = YES        (window briefly reports 0x0)
update frame 300.0x650.0 (was 300.0x650.0)   -> EQUAL, branch skipped, hidden stays YES forever
```

The frame came back to a value it **already held**, so the guard suppressed the recovery
permanently. Window: fully black, 20,420 B capture, interior luminance 0.

**The rule:** when a branch touches two independent pieces of state, each needs its own test. Write

```objc
if (!CGRectEqualToRect(host.frame, frame)) host.frame = frame;
if (host.hidden) host.hidden = NO;
```

and zero the frame when hiding, so even a single-test version would recover.

**The wider tell:** a "no-op" guard (`!CGRectEqualToRect`) is only a no-op for the state it
compares. Every *other* effect inside that branch silently becomes conditional on it.

## A fix whose code path never runs — check it logs before you credit it (2026-08-31)

> **Ledger:** `SUPPORTED` — C16. Evidence: SURF-UPD=0 / CONTENT=0 across five instrumented sessions.

`macdrv_swapchain_set_bounds()` was written to fix "stale strips of old content, black boxes in a
corner, and sometimes a wholly black content area", shipped, and credited in a commit message and
a patch file. **It has never executed.** Its only caller is `macdrv_client_surface_update()`'s
remote-layer branch, and across five instrumented Steam sessions:

| session | `SURF-UPD` | `CONTENT` | `HOST create` |
|---|---:|---:|---:|
| resize-diag | 0 | 0 | 67 |
| resize-fix | 0 | 0 | 120 |
| resize-final | 0 | 0 | 184 |
| popup runs | 0 | 0 | 101 |

CEF resizes by **destroying and recreating** the swapchain, so a fresh `CAContextSwapChain` is
built at the new size and the in-place resize path is never taken. Whatever improved in that build
came from the two changes beside it.

**The trap:** the fix went in alongside two others that *did* work, the symptom improved, and the
improvement was attributed to all three. A behavioural claim needs the path to be **observed
running** — `git blame` on a symptom is not attribution. Instrument first, credit after.

## `backgroundColor` on a hosted layer paints it before the content arrives (2026-08-31)

> **Ledger:** `SUPPORTED` — C18. Evidence: the parity re-measurement with and without it.

A `CALayerHost` is **visible from the moment it is added**, and the remote `CAContext` has not
presented anything yet. So `backgroundColor` — set to cover a *one device pixel* seam — paints a
**full black rectangle** over the whole layer until the first frame lands. Every newly hosted layer
flashes. Steam's menus are each their own popup window, so mousing across the menu bar hosts a fresh
layer per menu: *"black box lag as i mouse back and forth over the menus."*

**Do not just delete it, though — measure first.** Removing it brings the white seam straight back,
exactly on the odd axis:

| size | bright edges without the background |
|---|---|
| 2400×1500 | 0 |
| 2401×1500 | 1 (right) |
| 2400×1501 | 1 (bottom) |
| 2401×1501 | 2 |

So it is load-bearing and the frame snap alone is **not** sufficient — a claim written into a source
comment before it was checked, and contradicted by the very next measurement.

**Fix: defer it.** Transparent while the layer is empty (the window's own surface shows through,
exactly as before any of this existed), black 120 ms later, when the only thing a background can
still reveal is the seam. Verified: 0 bright edges on all four parities, popups unaffected.

**The general shape:** a property that exists to fix a *steady-state* artifact should not be applied
during the *transient*. Ask when a value needs to be true, not just whether it needs to be true.

## Paradox launcher: mouse hit-testing sits BELOW the visible cursor (2026-08-31, OPEN)

> **Ledger:** `UNREVIEWED` — C19. Reported by James; direction measured, mechanism is a hypothesis,
> ownership untested.

The Paradox launcher renders correctly on the patched stack (EULA, store panels, PLAY — the game
boots from it and reaches `MainMenu`), but **hit-testing is offset vertically**: to activate a
button you must hold the cursor *above* it, so the hand appears several points above the control
that highlights.

**What is measured.** The launcher's top-level window is a `Chrome_WidgetWin_1`, and Win32 models
almost no non-client area on it:

```
window rect : 325,530  2568x1345
client rect : 2558x1340   (client origin on screen 330,530)
CLIENT OFFSET INSIDE WINDOW: dx=5  dy=0
```

`dy=0` — so the obvious "off by the title-bar height in Win32" story is **already ruled out**;
Win32 believes the client starts at the very top of the window. Yet macOS draws a title bar on that
window. If the Cocoa content view therefore begins lower on screen than Win32's client origin, a
cursor at screen *y* is reported to CEF as a client *y* that is too large, CEF highlights a control
below the visible cursor, and you aim high to click. **That direction matches the report**, and it
is as far as the evidence currently goes — the content view's actual screen origin has not been
measured, so the mechanism is a hypothesis, not a finding.

**Probably not ours, and that is testable rather than assumed.** Our changes are confined to hosted
layer frames, z-order, visibility and background; `grep -c macgameport` over the mouse/cursor/event
mapping path returns **0**. The clean A/B is the stock `winemac.so.bak-*` beside the installed one:
if the offset reproduces there, it is pre-existing wine behaviour for this window style. **That A/B
has not been run.**

⚠ Do not "fix" this by nudging a hosted layer frame. The layer is drawn where the window says it
should be; it is the input mapping that disagrees, and moving the visuals to match would put the
rendering wrong in order to make the aim right.

## `assert_cities2.exe_*.dmp` is written on EVERY launch — it is not evidence of a crash (2026-08-31)

> **Ledger:** `SUPPORTED` — C20. Evidence: six dumps, one per run, including known-good boots.

Steam's crash handler drops an `assert_cities2.exe_<timestamp>.dmp` into
`<prefix>/drive_c/Program Files (x86)/Steam/dumps/` on **every** CS2 launch under wine. Measured
2026-08-31 — six dumps, and the runs at **03:58** and **05:16** are boot-verifies that reached
`MainMenu` cleanly:

```
assert_cities2.exe_20260831002938_1.dmp
assert_cities2.exe_20260831003411_1.dmp
assert_cities2.exe_20260831023845_1.dmp
assert_cities2.exe_20260831035813_1.dmp   <- boot-verify, MainMenu reached
assert_cities2.exe_20260831051605_1.dmp   <- boot-verify, MainMenu reached
assert_cities2.exe_20260831053917_1.dmp   <- MainMenu reached 05:40:07
```

The assertion is Mono's, and it is harmless:
`mono/eglib/gpath.c:115: assertion 'filename != NULL' failed`.

**Related and more misleading: the Paradox launcher's "An error occurred — The game appears to have
crashed or terminated unexpectedly (exit code null)".** It reports this after a run that reached
`MainMenu` and shut down writing its normal Unity memory-stats tail. `exit code null` is the
launcher failing to *read* an exit code from a process under wine, not the game failing. Do not
debug a crash on the strength of that dialog — check `Logs/SceneFlow.log` for `MainMenu reached`
first, and judge by timestamp.

**Note the shortcut does not use the launcher at all.** `launch-cs2-dxmt11.sh` runs `Cities2.exe`
**directly** (its own header says so: *"patches → Steam up + logged in → licence sync → Cities2.exe
DIRECTLY → graceful shutdown"*), so the Paradox launcher only appears on the Steam **PLAY** path.
It also shuts Steam down when the game exits.

## The Paradox launcher's PLAY is broken under wine — and it is not a crash (2026-08-31)

> **Ledger:** `SUPPORTED` — C21/C22. Evidence: `launcher-2026-08-31.log`, `launcher-settings.json`.

Three separate launcher problems, none of them the game and none of them ours. All three announce
themselves misleadingly.

**1. PLAY does nothing but show "the game appears to have crashed (exit code null)".**
The launcher never started it. Its own log says:

```
error [LaunchGameHandler]: Launching game failed VError: Failed to start a game executable:
    Launching game failed: spawn Cities2.exe ENOENT          (x4 today)
```

`launcher-settings.json` has `exePath: "../Cities2.exe"`, and Steam invokes the launcher with
`--gameDir ...\Cities Skylines II\Launcher`. `Cities2.exe` lives in the game **root**, not in
`Launcher\` — and what actually reaches `spawn` is the bare name, so it resolves against a cwd that
does not contain it. **The dialog's advice (verify files, disable mods, install VC++/.NET) is all
wrong** — nothing was ever launched.

**2. "A launcher update has failed. Check your internet connection."** The internet is fine
(`api.paradoxplaza.com` 200, Steam 200, measured). The real error:

```
error [main]: Failed to get free port for cpatch:
    VError: Finding free port failed: connect EADDRNOTAVAIL 127.0.0.1:11000
error [LauncherUpdateHandler]: ... VError: cpatch took too long to connect     (x11 today)
```

It is **loopback TCP to a helper process** (`cpatch.exe`), not the network. Cosmetic — the launcher
runs fine un-updated.

**3. The RESUME tooltip shows your city and population without a Paradox sign-in.** Expected, not a
leak: `gameDataPath` is `%USERPROFILE%/AppData/LocalLow/Colossal Order/Cities Skylines II` and the
launcher reads the local save metadata off disk. (The `12/31/1969` date beside it is Unix epoch 0 —
a wine file-timestamp quirk.)

**The practical answer: use the shortcut.** `launch-cs2-dxmt11.sh` runs `Cities2.exe` **directly**
and never involves the launcher — measured the same night: `MainMenu reached`, 6 mods, 0 exceptions.

## Win32's client rect ignores the macOS title bar — so the cursor aims high (2026-08-31, OPEN)

> **Ledger:** `PARTIAL` — C19. Offset measured; ownership (ours vs stock wine) still untested.

On the Paradox launcher window, hit-testing sits **below** the visible pointer: you must hold the
cursor above a control to activate it. Measured, using the hosted-layer trace for the content view
size and the driver for the Win32 rects:

| | width | height |
|---|---|---|
| Cocoa **window** | 1279 pt | 674 pt |
| Cocoa **content view** (from the trace) | 1279 pt | **642 pt** |
| ⇒ macOS title bar | — | **32 pt** |
| Win32 **client** rect | 2558 px = 1279 pt | 1339 px = **669.5 pt** |

**Widths match exactly. Win32 believes the client is ~27.5 points taller than the view that actually
displays it** — the title bar it is not accounting for. A cursor is therefore mapped ~28 points too
far down the page, so the control that highlights sits below the pointer. That magnitude matches the
report ("several points").

**Probably not ours** — our edits cover hosted layer frames, z-order, visibility and background;
`grep -c macgameport` over the mouse/cursor/event path is **0**, and this window's layer takes the
`CGRectNull` branch (trace: `frame=inf,inf`) so it simply fills the content view, correctly. The A/B
against the stock `winemac.so.bak-*` would settle it and **has not been run**.

## A WS_CAPTION style is not a caption — frameless apps get a doubled title bar (2026-08-31)

> **Ledger:** `PARTIAL` — C23. Decoration fixed and verified; the geometry mismatch behind the
> cursor offset is **not** fixed.

The frameless-but-resizable pattern (Electron/CEF, and the Paradox launcher) keeps
`WS_CAPTION|WS_THICKFRAME` so Windows still gives it resize borders and snap, then handles
`WM_NCCALCSIZE` to take the caption area back for the client and draws its own title bar inside it.

`get_cocoa_window_features()` decides on the **style bits**, so such a window gets a real macOS
title bar on top of the one it draws itself — two sets of window buttons. Its only escape hatch
compares `rects.window` with `rects.visible`; it never consults `rects.client`, which is exactly
the record of what `WM_NCCALCSIZE` did.

**How to tell two lookalike windows apart** — measured, and note that style bits alone cannot:

| | Steam (`SDL_app`) | Paradox launcher (`Chrome_WidgetWin_1`) |
|---|---|---|
| `WS_CAPTION` | yes | yes |
| shaped / layered | no / no | no / no |
| client vs window | `2346x1500` == window, **dx=0 dy=0** | `2560x1341` vs `2570x1346`, **dx=5 dy=0** |
| macOS title bar | none (escapes via `EqualRect`) | **added** |

The launcher reserves 5px of frame left/right/bottom and **zero on top**. That is unambiguous: a
resize border, no caption.

**The change:** after computing the features, suppress `title_bar` (and its buttons) when
`rects.client.top == rects.window.top`. Left/right/bottom frame untouched. Verified — the launcher
now renders with no macOS title bar and its own controls in place.

⚠ **REVERTED 2026-08-31 — see the section below. It removes the doubled chrome but moves the
error rather than removing it, and it makes two winemac functions disagree about the same
question.** Kept here because the diagnosis is correct and the fix is one function short.

⚠ **This does NOT fix the cursor offset, and do not let the visual improvement suggest otherwise.**
The mismatch that causes it is content-view vs Win32-*client*:

```
before:  content view 642.0 pt   vs client 669.5 pt   -> 27.5 pt apart
after :  content view 643.0 pt   vs client 670.5 pt   -> 27.5 pt apart   UNCHANGED
```

The Cocoa window merely **shrank** by the caption height instead of the content growing into it, so
something further down still sizes the window frame as though a caption existed. That is the next
thing to find. Revert: `winemac.so.bak-pretitlebar-*`, and `window.c.pre-titlebar` in the wine tree.

## The cursor offset: TWO functions decide whether a window has a title bar (2026-08-31, OPEN)

> **Ledger:** `SUPPORTED` (mechanism) — C24. The fix is not written; the change that got halfway
> was reverted.

Chased to the bottom. The offset is **not** a global pointer-mapping error — wine's `GetCursorPos`
agrees with macOS `CGEvent` to within truncation:

```
macOS 891.7,641.2 pt = 1783.4,1282.4 px | wine 1783,1282 px | dx -0.4  dy -0.4 px
```

It is **window-relative**. `ScreenToClient` subtracts a window origin that is not where the window
actually is:

```
Win32 says the window is at : 228,346 px = 114,173 pt
Cocoa draws it at           : 232,402 px = 116,201 pt      -> 56 px = 28 pt apart
```

So the client *y* handed to the app is 56 px too large and every control hit-tests 28 points below
the pointer.

**Why the two disagree — this is the actual bug.** Two functions answer "does this window have a
title bar", from different inputs, and nothing reconciles them:

| caller | function | input |
|---|---|---|
| `macdrv_GetWindowStyleMasks` (win32u asks how much **non-client** space the window rect reserves) | `get_window_features_for_style()` | **style bits only** |
| window creation / style change (the **actual Cocoa decoration**) | `get_cocoa_window_features()` | style bits **+ `data->rects`** |

For a frameless-but-resizable window they can differ, and the window rect then describes a frame
the NSWindow does not have.

**Why patching only the second one is not enough — measured, not argued.** Suppressing the Cocoa
title bar there left `GetWindowStyleMasks` still reporting caption masks, so win32u kept reserving
caption space and the NSWindow simply moved **down** by that amount:

| | Cocoa window | Win32 window | content view vs Win32 client |
|---|---|---|---|
| before | 116,169 pt | 114,173 pt (agree) | 642.0 vs 669.5 → **27.5 pt** |
| after | 116,201 pt | 114,173 pt (**28 pt apart**) | 643.0 vs 670.5 → **27.5 pt** |

Same error, different mechanism. **Reverted** — a half-fix that leaves two functions contradicting
each other is worse than the original, because the next reader sees no title bar and has no reason
to suspect the window rect still contains one.

**A real fix has to make both answers come from the same place**, which means `GetWindowStyleMasks`
needs the same client-rect evidence — and it is called *while* win32u is computing those rects, so
the ordering has to be worked out first. That is upstream wine work, unrelated to DXMT.

## The Paradox launcher's PLAY: `ENOENT` is not a missing file (2026-08-31, OPEN)

> **Ledger:** `SUPPORTED` — C25. Evidence: the launcher log across two attempts, one with an
> absolute `exePath`.

`spawn Cities2.exe ENOENT` reads like a path bug. It is not, and chasing the path is a dead end —
tested, so nobody has to repeat it.

Setting `exePath` in `Launcher/launcher-settings.json` from `../Cities2.exe` to a full absolute path
**did take effect** — the launcher logged the resolved path — and the spawn failed identically:

```
info  [LaunchExecutable]: Starting game: C:\...\Cities Skylines II\Cities2.exe
error [LaunchGameHandler]: Launching game failed: spawn Cities2.exe ENOENT
```

Node formats the ENOENT message with the **basename**, which is what makes it look like a bare-name
lookup. It isn't.

**What is established:** the file exists; the launcher resolves the correct absolute path; and plain
wine launches that exact executable fine — that is what `launch-cs2-dxmt11.sh` does, boot-verified
to `MainMenu` repeatedly the same night. So the failure is in the launcher's own (Electron/libuv)
spawn under wine, not in the path, the file, or the game.

**The edit was reverted** — it changed no outcome, and an unnecessary modification to a
Steam-managed file only confuses the next reader (Steam would revert it on validation anyway).

**Not worth chasing further unless someone wants Steam-launching specifically.** The shortcut is
unaffected, and the Steam overlay — the main thing Steam-launching would buy — is deliberately
disabled anyway because it crashes the game under wine (§12 above).

## A "hold until the next event for the same key" cache leaks when the key never fires again (2026-09-02)

**Root cause.** The per-child deferred release (2026-08-31) parked one retired surface per child
HWND and drained it on that child's *next* release. A destroyed child — every closed popup menu,
every closed Friends List — never releases again, so its slot was held forever: CAMetalLayer,
drawables, a window-server `CAContext` and an orphan NSView per popup ever opened. Found by a code
review, not by a symptom; it would have shown up as memory growth over a long session.

**Prevention.** Any "keep until the next event for the same key" design needs a second exit: the
key's *death*. Here that is two guards — a release whose owner is already gone is released
immediately (`NtUserIsWindow`), and every release sweeps the table for dead keys — measured as
`dxmt-life ... dead-child slot(s)` traces. The general shape: if an entry's lifetime is tied to a
future event, list every reason that event might never come and give each one a drain path.

## A hand-maintained patch file drifts from the binary it claims to describe (2026-09-02)

**Root cause.** `scripts/winemac-crossprocess-remote-layer.patch` grew as prose — six dated addenda
with hunks like `@@ before "..." @@` — while the real code lived in the build tree. `patch` could not
apply it, and wine bug 60263 linked it as "a working version of both halves". The DXMT half was a
real diff but cut before its `_ReleaseMetalView` hunk existed, so it described an over-release path
the installed binary did not have. Neither drift was visible from the docs, which cited the files.

**Prevention.** A patch file is generated, never edited: `diff -ruN` (or `git diff`) from the tree,
then **dry-run applied to a fresh base and byte-compared against the working tree** before it is
committed. Narrative goes in a `.md` beside it. `docs/winemac-crossprocess-remote-layer-history.md`
is where the addenda now live; the two patch headers carry the regeneration date.

## The resize driver prints CRLF — `title=Steam$` never matches its output (2026-09-02)

`win-resize-driver.exe` writes through the Windows CRT, so every line ends `\r\n`. A `grep
"title=Steam$"` over its `list` output matches nothing, and a `grep -v` meant to *exclude* the main
window excludes nothing — one verification script closed the main Steam window along with the
popups that way. Pipe the driver through `tr -d '\r'` first. `winlist` (Swift) is LF and unaffected.

## A process-impersonation fixture must be proven detectable before the test that needs it (2026-09-03)

**Root cause.** The busy-prefix test for `scripts/boot-verify.sh` needs a process whose command
line matches `wineserver` and which holds a prefix file open. The planned fixture — `cp /bin/sleep
/tmp/wineserver-fake; exec -a wineserver /tmp/wineserver-fake 300` — produced nothing: the copied
platform binary never appeared in `ps` on macOS 26, and the fallback `exec -a wineserver /bin/bash
-c 'sleep 300'` lost its name because bash tail-execs a lone simple command, so `ps` showed
`sleep 300`. In both cases `pgrep -f wineserver` matched nothing. Had the test then run the script
"to see it refuse", it would have measured a free prefix and **launched the game inside a tool
call** — the negative test's failure mode is the positive action.

**Prevention.** Two rules. (1) A symlink carries the name: `ln -s /bin/sleep /tmp/wineserver;
/tmp/wineserver 300 3<"$PREFIX/system.reg" &` shows as `/tmp/wineserver 300` and inherits the open
fd — the fixture as executed for T2. (2) Before invoking the script under test, prove the fixture
is detectable with the **same predicate the script uses** (`pgrep -f` + `lsof -p … | grep -q
"$PREFIX"`), and do not invoke it otherwise. A refusal test whose fixture is absent is not a red
test; it is the thing the test exists to prevent.

## SceneFlow.log is written live — "flushed on graceful exit" was a wrong-path artifact (2026-09-03)

**Root cause.** On 2026-09-02 the ad-hoc boot harness watched `SceneFlow.log` in the LocalLow root
while the game writes it under `Logs/`. The file it watched never changed during the run, a
complete log was found after the exit, and that became the recorded fact "flushed on graceful
exit, not written live". It was then encoded — as an *instrument fact* — into the boot-verify
plan, the umbrella issue and memory, and the plan's T3 expectation (a SIGTERM'd run leaves the
previous run's log in place → VOID) was derived from it.

**Measured.** `boot-verify.sh --hwnd 1 --dwell 60` (run `20260902-191631`): the new log's first
line appeared 6 s after the game pid; at the SIGTERM the copy held 67 lines, the last written
11 s earlier, and the file's mtime was that line's time. The log is written line by line; only
`GameManager destroyed` is exit-only. A killed run therefore judges **FAIL + GRACEFUL: no** (fresh,
truncated), and VOID is reachable only when nothing was written this run — the launcher dying
before the game starts, or a kill inside the first few seconds.

**Prevention.** A fact about *when a file is written* is measured by watching the file at its real
path with timestamps, never inferred from what a script that looked elsewhere failed to see. And
when an instrument is fixed — here, the path — re-measure every fact that was recorded while it
was broken; the plan's own "facts it encodes" list is the checklist. The judge was designed with a
"fresh but truncated → FAIL" branch anyway, which is why the wrong belief cost nothing but the
expectation in one test row.

## `assert()` bakes `__LINE__` into the object — a comment-only edit is not byte-identical (2026-09-03)

**Root cause.** The upstream-form plan gates its comment/tag passes on rebuilding a
**byte-identical** `winemac.so`, on the project's own 2026-08-31 precedent that a pure style pass
produces an identical binary. Removing 32 comment lines from `window.c` changed the module hash.
The pass was innocent: macOS `assert(x)` expands to `__assert_rtn(__func__, __FILE__, __LINE__, …)`,
so the line number is an **immediate in the object**. `window.c` carries one assert, which moved
from line 1328 to 1296, and `impl_from_client_surface()` inlines at five call sites — so
`window.o` differed in exactly **five bytes, every one `0x30 → 0x10`** (`1328 & 0xff = 0x30`,
`1296 & 0xff = 0x10`).

**Measured four ways**, because "it's only comments" is an argument, not evidence: a
comment-stripped source comparison is identical for all five files; the five differing bytes are
the line-number immediate and nothing else; recompiling both revisions with `-DNDEBUG` (assert
compiled out, every other flag identical) yields a **byte-identical** `window.o`; and
`cocoa_window.o` / `macdrv_main.o`, which contain no `assert`, are byte-identical across the same
pass.

**Prevention.** Byte-identity is the right gate but it is not universal — it holds only for
translation units with no `__LINE__`-bearing macro (`assert`, and anything else expanding to
`__FILE__`/`__LINE__`). State the gate as **"byte-identical, or byte-identical under `-DNDEBUG`
for a file containing `assert()`"**, and pair it with a comment-stripped source comparison, which
is the check that actually proves no code moved. Find the exposure before the pass:
`grep -nE '(^|[^_[:alnum:]])assert[[:space:]]*\(' <files>`.

## Restoring a file to test it destroys the edit you were testing (2026-09-03)

**Root cause.** Verifying the assert finding above meant compiling the *pre-pass* source and
diffing the object. For `window.c` the post-pass copy was saved first and restored after. For
`cocoa_window.m` and `macdrv_main.c` the same restore ran inside a loop with **no save**, silently
overwriting a completed pass on both — roughly fifteen minutes of work, unrecoverable, because the
edits had not been committed and the only other copies were the pre-pass snapshots.

**Prevention.** Two rules, either of which would have prevented it. (1) **Commit before you
measure.** Work that exists only in a working tree is one `cp` from gone; a branch commit costs
nothing and is the durable store. (2) **A restore-for-measurement is a save/restore pair, and the
save is written first** — if a loop restores N files it must snapshot all N before the first
restore, not after. The recovery lever that did survive was the build output: `.o` files compiled
from the destroyed sources were still on disk, so the redo could be byte-compared against them and
proved functionally identical to the lost work. Keep intermediate build artifacts until the source
they came from is committed.

## An aborted churn keeps churning, and the next probe measures during it (2026-09-03)

**Root cause.** `scripts/shimmer-probe.sh churn` launches the resize driver in the background — 240
alternations at 60 ms, about **14 seconds** of continuous resizing — then checks that the window
actually changed size before it scores anything (guard 2, which exists so a churn that never took
cannot be reported as "no gaps"). The abort path printed its message and `exit 1`'d **without
killing the driver**. The churn therefore kept running, and the next probe in the same session
sampled during it.

**What that looked like.** In the C29 re-run for the core/glue split, run 2 aborted and the
**static control** — the run whose entire job is to show what a quiescent window measures — came
back with an interior-luminance **minimum of 0** and one near-black frame scored as a GAP. That is
what a real regression looks like.

⚠ **The evidence is the before/after, not the distinct-frame count.** The first write-up of this
entry claimed a control showing 39 distinct frames of 40 could not be a control, comparing against
C17's "1 distinct frame". That reasoning is **wrong and was corrected the same day**: re-running the
control after the fix gave **40 distinct frames** and a clean result (min luminance 79, 0 gaps),
because Steam's page animates on its own — the distinct count is high either way and discriminates
nothing. What actually establishes the contamination is three things together: the abort path
demonstrably does not kill the driver (read the code), the arithmetic overlaps (a 14 s churn against
a ~4 s wait plus 40 captures), and the same control on the same window goes from min 0 / 1 gap to
min 79 / 0 gaps once the driver is killed. **Minimum interior luminance is the discriminator here;
frame diversity is not.**

**Two fixes, both in the probe.** (1) Kill the driver on the abort path. (2) Stop sampling for the
size change at a fixed instant: it read at t=1.00 s and t=1.09 s, but wine needs about a second to
start, so both samples could land *before the first resize* and abort a run that was about to be
valid — which is what triggered the abort here. It now polls up to 6 s for the change. The battery
also waits 20 s between runs so a control is taken on a settled window.

**The general shape.** A guard that aborts must undo what it started, or it converts "this run is
void" into "the next run is wrong". Any probe that backgrounds a stimulus needs the stimulus killed
on every exit path, not just the successful one — and a control that does not look like a control
should be disbelieved before it is reported.

## A generator with a relative range drifts the day the branch grows — pin by commit, gate by invariant (2026-09-03)

**What happened.** The three published winemac patches are generated from a nested git history
whose shape was `stock → aquadran → cherry-pick(core) → glue`, and the generator encoded that shape
as *positions*: glue was `main~1..main`, "always the last commit on main". The design-gaps build
(C32) then landed D1 and D2 on `main` only. Nothing failed. The combined patch grew to include them,
the "glue" patch silently became the D1 scoping fix's diff, and the committed **core** patch —
the one destined for wine bug 60263 as the stock-applicable reference — quietly lacked both fixes
that the installed module carried. The published reference disagreed with the running binary for
about fourteen hours, and it was found only because `--check` was run by hand while preparing the
attachment. The core header also said *"the five files this touches"* over a four-file diff — the
count had been typed, not measured, and is exactly the comment-accuracy defect issue #6 exists for.

**Three fixes.** (1) Glue is pinned by its commit **subject**, and the generator refuses to run
unless `main`'s tip *is* that commit — so the failure mode is loud the moment anything lands on
`main` after glue, with the remedy in the message (cherry-pick onto `core`, rebuild `main`, prove
the tree unchanged). (2) `--check` now exercises the split's structural invariants with
`git apply` instead of only `cmp`-ing files: core applies to pristine stock; aquadran + core equals
glue's parent byte for byte; glue's parent + glue equals `main`. (3) `--check` is wired into
`check-experiments.py`, so it runs at every `button up` instead of when someone remembers. The
file count in the header is now computed from the diff.

**The general shape.** "The latest commit" is an assumption about history shape that nothing
enforces; a generator that reads it will produce a plausible wrong artifact rather than an error.
State the invariant, check it mechanically, and make the check part of a gate that already runs —
a `--check` that exists but is not wired in is a gate that was not run.

## A probe that averages the perimeter cannot see a black side — score bands, keep the frames (2026-09-03)

**What happened.** The live-drag probe scored each frame as `min(mean luminance over the whole
perimeter, interior luminance)` and reported min 76 / 0 gaps for a sixty-frame human drag. James,
at the mouse, saw black boxes on the open edge. Re-scoring the same frames per outer band: the right
tenth of the window was **93% pure black** in the worst frame and **19 of 60** frames had the right
band at least 20% black (C35, issue #7). The interior was lit the whole time, and a mean over four edges
diluted one fully black side to a rounding error. The number was true and the conclusion drawn from
it was false.

**Two rules.** (1) A score is a compression; before calling a run clean, look at the worst frame by
a metric that can *localise* — `scripts/darkboxes.swift` now reports each band, and both resize
probes print an EXPOSED-EDGE line. (2) **Keep the frames.** C28's eighty were discarded after
scoring, so there is no earlier live-drag baseline and the regression question needed a fresh A/B.

⚠ **And the first version of this entry said 56 of 60.** The summary awk read the analyser's
block-width field as the bottom band, so any frame with a dark block 20 px wide counted, and the
analyser itself had top and bottom swapped. It surfaced as a churn summary reading *"worst band
2400%"* — a number that cannot exist — and was fixed by checking the field mapping against one
frame I had actually looked at. The same rule as for plan folds: never publish a count you have
not eyeballed.

**The general shape.** A human watching the screen is a sensor the harness does not have. When they
report something the numbers deny, assume the numbers are wrong first, and go and look at the
pictures — the frames were sitting in the evidence store the whole time.


## Two scripts sharing `OUT_DIR` — the callee wipes the caller's run directory (2026-09-03)

**What happened.** `stage1-tests.sh` was written to hold a run directory in `OUT_DIR` and call
`shimmer-probe.sh` for each churn. The probe's line 29 is
`out="${OUT_DIR:-/tmp/shimmer-$mode}"; rm -rf "$out"; mkdir -p "$out"` — so on every churn it
**deleted the caller's run directory**, took it over, and wrote its own frames there. The caller's
probe log vanished (a `grep: … No such file` that scrolled past), its frame copy found nothing in
`/tmp/shimmer-churn`, and the scorer therefore read **frames left in `/tmp` by a run half an hour
earlier**. Four churns across two different modules returned byte-identical band counts — `R 8/40
(worst 86%) B 8/40 (worst 94%)`, four times — which is exactly what an untouched stale directory
looks like, and reads exactly like "the change had no effect."

**Why it is worth a heading.** `OUT_DIR`, `OUT`, `TMPDIR`, `LOG` and `DEBUG` are the names every
script in a repo reaches for, and an exported one is inherited by everything downstream. The failure
is silent in both directions: the callee is doing precisely what it documents, and the caller has no
way to notice its own directory was replaced.

**Three rules.**
1. **A script that consumes an env var owns that name.** A runner that calls it must not use the
   same name for its own state — `stage1-tests.sh` now uses `STAGE1_OUT` and passes the callee its
   own `OUT_DIR="$OUT/<label>"` per invocation, which also stops two churns overwriting each other.
2. **`rm -rf $VAR` on a caller-supplied path is a contract**; say so in the callee's header, because
   the caller cannot see line 29.
3. **Count the artifacts before scoring them.** The runner now refuses with `VOID` when the probe
   wrote no frames, instead of scoring whatever it finds. Identical numbers across runs that should
   differ is the tell — treat a repeat as a harness failure until proven otherwise.

> **Ledger:** the four voided cells are not in `EXPERIMENTS.md`; the A/B was re-run after the fix.

## A module built off the wrong branch renders black — and a black window scores as a clean pass (2026-09-03)

**What happened.** The nested winemac repo keeps two branches on purpose: `core`, the
stock-applicable subset that goes upstream, and `main` = aquadran + core + the DXMT glue commit,
which is what actually runs here. A session that had just committed stage 1 to `core` left the tree
checked out there, and the next three diagnostic modules were built from it. Each one **installed
and loaded without complaint**. Steam came up, its GPU process died six times with `c0000409`
(Chromium's `CHECK`/`IMMEDIATE_CRASH` code), no remote layer was ever posted, and the window
rendered pure black.

Then the second failure landed on top of the first. With no hosted layer anywhere, every outer band
scores 100 % black and every diagnostic colour scores **0** — which the attribution table prints as
`GREEN 0 | MAGENTA 0 | BLUE 0 | BLACK 35/40`. `Rgreen → 0` is *exactly* the pass condition the test
was written to look for. A run that measured nothing at all was one glance away from being recorded
as stage 1 working.

Two sessions went into attributing the crash to the diagnostic colours — first to the one hunk that
runs in the GPU process, then, when removing it changed nothing, to the other two — before anyone
compared the module against the one that had been measuring correctly all day. `core` builds
**502560 B**, `main` builds **508544 B**, and a clean `main` rebuild is **byte-identical** to the
installed module. The colours were never implicated.

**Why it is worth a heading.** Every layer of this is silent in the direction that hides it. The
loader does not care that a DLL is missing a vendor feature. The crash is in a *child* process and
is counted by a log line nobody reads unless they are already suspicious. And the measurement does
not fail — it succeeds, with the numbers a working fix would produce.

**Four rules.**
1. **A branch that is not what you run is a loaded gun.** `scripts/build-winemac.sh` now refuses
   unless the nested repo is on `main` and clean, and refuses again if the built module carries no
   `dxmt_client_surface` (5 hits on `main`/`aquadran`, 0 on `core`).
   **The same confusion also produces false claims about the code, not just bad builds.** Within
   the hour it nearly landed a "correction" to the #7 plan: `:781` was read on `core`'s history,
   where it is `host.hidden = YES`, and written off as a bad cite. On `main-old` — the branch the
   plan actually describes — line 781 is `deferred.backgroundColor = CGColorGetConstantColor(
   kCGColorBlack)`, exactly the deferred create-path background the cite claims. **Resolve a
   `file:line` against the branch the document was written against**, and say which branch that
   was; in a repo with a deliberate core/main split, a bare line number is ambiguous.
2. **Establish that the instrument registers, before reading what it says.** The three guards added
   to `stage1-tests.sh` — interior luminance 0, the static control showing gaps, zero placement
   traces — each catch this at a different layer, and any one of them would have caught it on the
   first run.
3. **An absence is not a result.** "No green" and "nothing rendered" are the same reading. Any test
   whose pass condition is *the absence of a signal* needs a positive control in the same frame;
   here the interior is it — a real store page has lit pixels in the middle whatever the edges do.
4. **Read a command's own exit status, not the pipe's.** `python3 patch.py | sed` reported `sed`'s
   status, so a `FAIL: 0 matches (want 1)` scrolled past and an unpatched module was saved under
   the patched module's name — twice, in the middle of diagnosing this. Same family as
   `<cmd> | tail` announcing a failing suite as exit 0.

> **Ledger:** the second void run is indexed as **exp_aa3654** (`stage1-t2a-diagfix2-…`), and the
> generated `capture` column reads **`black`** for it without anyone saying so — that column is the
> cheapest existing tell for this whole failure, and it sits beside every run. The first void run
> predates the per-run cell label and shares the old `stage1` cell. **No conclusion rests on
> either.** C38's A/B is unaffected: those four rounds ran the `main`-built module
> (`2a251a4b2510fb84`), with lit interiors and a clean static control in every session.

## A mutant that never applied reports as a mutant result (2026-09-03)

**What happened.** `hosting-layer-tests.sh --mutants` has three mutants. M1's anchor string —
`if (remote_layer_children_has(data, hwnd)) update_remote_layer_frames(data);` — exists on **no
branch**: not `main`, not `main-old`, not `main-raw`. D1 was rewritten to reposition only the moved
child rather than every layer on the root, and the mutant was never updated, so it still names the
full-pass version it replaced. It has been stale since the script was committed at `cab54e6`,
meaning **M1 has never once been applied**.

The patch threw an `AssertionError` and `mutate` returned non-zero. That should have ended the row.
It did not, because the caller was written as two statements on two lines:

```sh
mutate M1 "…"
build_install && cell m1 && run_t1 m1     # ← runs regardless
```

So the battery built the clean module, installed it, ran the test against it, and printed
`T1 verdict: GREEN` — for a mutant whose *pass condition is red*. A false negative, rendered
identically to a real result.

**The tell was in its own output, one line above the verdict:** `module 2a251a4b2510` — the
baseline hash. Nothing compared them.

**Why it is worth a heading.** This is the blind spot inside the project's own mutant rule. The rule
says *every mutant is applied to real source, built, observed red, then restored — "argued red" is
not red*. It closes the gap between reasoning and running. It does **not** close the gap between
running and **running the thing you think you are running**, and that gap fails silently in the
direction that looks like success: a mutant that does nothing produces the unmutated behaviour,
which for a mutant whose expected result is *red* reads as a test that merely failed to fire.

**Three rules.**
1. **Chain a mutant's row to its patch**, never merely follow it. `mutate X && build_install &&
   cell && run` — a non-zero patch must abort the row, not precede it.
2. **Prove the binary changed.** `build_install` now refuses a module byte-identical to the clean
   one. This catches the other half, which no exit status can see: a patch that applies cleanly and
   changes nothing. Record the clean hash before the first mutant and compare every build to it.
3. **A mutant's anchor is code that rots.** It names an exact source line in a file under active
   development, and nothing recompiles it. When a mechanism is rewritten, its mutants are part of
   the rewrite — grep the anchors, do not assume. The strong version: the mutant's *expected result*
   should differ from the unmutated build's, so a run where they match is itself the alarm.

> **Ledger:** nothing rests on it — no claim in `EXPERIMENTS.md` cites "M1 red", and C32 never
> asserted it; the only reference is the #7 plan's T5 row, which is a criterion being run for the
> first time. Caught 2026-09-03 while running that criterion, and only because the traceback
> happened to be read.

## An audit that reports the MATCHES must not name the non-matches by eye (2026-09-04)

**What happened.** The as-built rule ships with an audit: `grep -ril 'as-built' docs/plans/` — files
with no header are the smell. On a `button up` sweep that produced a finding, an issue, and a
confident table:

> `grep -ril 'as-built' docs/plans/` on `button up` 2026-09-03: 11 plan docs, **9 carry a header,
> 2 do not** … `launcher-display-profiles.md`, `retina-swapchain-experiment.md`

Every part of that is false. **All 11 carried a header**, and both named files had carried one since
the commit that shipped their work — `866f4fd` (2026-08-27) and `54431bf` (2026-08-26). Neither had
been touched in between. The issue sat open overnight before anyone opened either file.

**The mechanism.** `grep -l` returns the set that **has** the property. The audit wants the
**complement**, and the complement was never computed — two plausible candidates were picked by
inspection (both old, both shipped, neither recently touched) and written up as findings. A guess
in the shape of a measurement reads exactly like a measurement once it is in a table with a count
beside it, and the count made it worse: "9 of 11" sounds derived even when nothing derived it.

**Why it is worth a heading.** This is the *inverse* of the usual `grep -L` trap already recorded
here (macOS BSD `grep -L` inverting its exit status). That one produces a wrong answer from a
correct instinct — reaching for the right flag and being betrayed by the platform. This one skips
the instrument entirely and reports intuition in its voice, which no amount of getting `grep -L`
right would have caught. The issue body even contained a warning against reconstructing as-built
headers from memory, sitting directly beneath a premise reconstructed from memory.

**Three rules.**
1. **Compute the complement, never eyeball it.** The one-liner is not longer than the guess:
   `for f in docs/plans/*.md; do grep -qil 'as-built' "$f" || echo "$f"; done`. Anything reported as
   *absent* must come out of a command whose output IS the absences.
2. **A count is a measurement or it is not in the report.** "9 of 11" must be two numbers something
   printed. If you cannot say which command produced a figure, delete the figure.
3. **Naming files raises the bar, it does not lower it.** A vague "some plans may lack headers" is a
   prompt to go and look. A table with two filenames is a finding, and a finding about a specific
   file requires opening that file — the repo's first engineering rule, which explicitly covers a
   claim inherited from a summary or a previous session.

> **Ledger:** no experiment or conclusion rested on it — the damage was one wrong public issue,
> [#8](https://github.com/macgameport/cities-skylines-2-macos/issues/8), open for ~17 hours and
> closed as invalid with the correction in it.

## A signal verified at the declaration is not a signal — measure the value on the path that runs (2026-09-04)

**What happened.** Stage 2 of the growing-edge fix (issue #7) was armed on AppKit's live-resize
signal: `windowDidResize:` really does post `WINDOW_FRAME_CHANGED` with `in_resize =
[self inLiveResize]`, and `windowDidEndLiveResize:` really does post `WINDOW_RESIZE_ENDED`. The
plan said so with line cites, a `check it` pass confirmed the wiring, the build compiled, T10
proved the guard never leaked into a churn — and a real drag fired **zero** stretches. Counted
afterwards across every trace ever captured: `in_resize 1` **0**, `in_resize 0` **8838**,
`WINDOW_RESIZE_ENDED` **0**. The drags never went through AppKit. Steam's SDL window hit-tests its
own border, `DefWindowProc` turns the press into `SC_SIZE`, and win32u's `sys_command_size_move`
issues one `SetWindowPos` per mouse move — wine sets the Cocoa frame programmatically each step, so
`inLiveResize` is NO for the whole drag. The same traces had said so all along:
`macdrv_SysCommand … f002` on every right-edge drag.

**Three things this cost, and the rule for each.**

1. **Every check verified the declaration.** Reading the code, citing the line, confirming the
   field is on the event — all true, all irrelevant. The only thing that could falsify "this
   signal fires here" is the *value* on the *path this app takes*, and nothing measured it until a
   human dragged. **When a fix is gated on a signal, the first test is a count of that signal on a
   recorded run of the real path, before anything is built on it.** Here it would have been one
   grep of a trace that already existed.
2. **The path was inferred from the platform, not read from the app.** "A drag is a macOS live
   resize" is true for a titled AppKit window and false for a frameless app that does its own
   hit-testing — and which one this window is was never asked. **Name the path by its trace**
   (`SysCommand f002` = win32u's loop; `in_resize 1` = AppKit's) rather than by what the platform
   would do to a generic window.
3. **The pass condition was the absence of a signal.** `stage-2 stretches fired: 0` on a
   programmatic churn was reported as containment (T10 green). It was also exactly what a dead
   signal produces. **A test whose pass condition is silence needs a positive control in the same
   session** — here, a drag through the real path showing stretches > 0. That control now exists
   (`win-resize-driver.exe sizedrag` runs win32u's loop with nobody at the mouse), and the row
   that proves the signal arms the stretch is the mutant that silences it (`signal-mutants.py
   --off`) observed red.

**The signal that does exist**, for the record: win32u's loop brackets itself with
`set_capture_window(hwnd, GUI_INMOVESIZE)` … `(0, GUI_INMOVESIZE)`; the server publishes it per
thread (`NtUserGetGUIThreadInfo` → `GUI_INMOVESIZE` / `hwndMoveSize`, a shared-memory read), and
hands the driver both ends as `macdrv_SetCapture(root, GUI_INMOVESIZE, previous)`. Measured
2026-09-04: set on 150 of 150 polls during a synthetic drag, trace bracket `SysCommand f002` →
`SetCapture 0x30122 flags 0x2` … `SetCapture 0x0 flags 0x2 previous 0x30122`. Ledger C46, C47.

**Two smaller traps found on the way.** A top-edge drag on a window flush with the menu bar cannot
grow it: the loop clamps the cursor to the work area, so the loop runs (`GUI_INMOVESIZE` on 100 of
100 polls) and the height never changes — both human runs lost their top-edge segment that way,
and the drag recipe now moves the window down first. And the colour patcher that built every
ledger-cited diagnostic module lived in `/tmp` as a "throwaway"; it was gone when stage 2 needed
rebuilding and had to be recovered from a session transcript. A build input that produced evidence
is not throwaway — it is `scripts/diag-colours-patch.py` now.
