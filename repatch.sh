#!/bin/bash
# Re-apply all Cities: Skylines II macOS/Wine binary patches (idempotent).
# Usage: bash repatch.sh [<game-dir>]   or   CS2_GAME_DIR=<dir> bash repatch.sh
# Each patch pattern-matches and REFUSES to write if the IL moved (game update),
# rather than corrupting the binary. Every one writes a .bak on first run.
# Usage: bash ~/cs2-patch/repatch.sh
set -e
HERE="$(cd "$(dirname "$0")/patches" && pwd)"
# Game dir may be passed as $1 (e.g. the free Kegworks/Sikarugir wrapper prefix).
# Default remains the CrossOver "Steam" bottle.
CX_GAME="${CS2_GAME_DIR:-$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II}"
FREE_GAME="${CS2_GAME_DIR:-$HOME/Applications/CS2.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II}"
DXMT_GAME="${CS2_GAME_DIR:-$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II}"
GAME="${1:-$CX_GAME}"
# wine-11.0 fixes the Mono P/Invoke garbage-errno defect that wine-10.0 has (measured 2026-08-22 —
# docs/wine-bugs/FINDING-wine11-fixes-it.md), so the dxmt11 target SKIPS the 6 errno-tolerance
# mscorlib patches, and (below) the Gameface licence bypass: 10 patches instead of 17.
# patch_fshandle STAYS — handle-0 is a separate defect that Wine 11 does NOT fix.
# COHTML_LICENSE=0 on wine 11: MEASURED 2026-08-22 — with cohtml.WindowsDesktop.dll restored to
# PRISTINE (bypass removed), the game reached MainMenu and loaded a city with ZERO "Invalid License
# key used!" errors. wine-11.0's BCryptVerifySignature verifies the Gameface ECDSA signature
# correctly, so root cause R3 is FIXED UPSTREAM and the withheld bypass is unnecessary on this
# target. **Every patch the wine 11 path needs is published in this repo.** Wine 10 still needs it.
ERRNO_PATCHES=1
COHTML_LICENSE=1
case "$GAME" in
  free|FREE)             GAME="$FREE_GAME" ;;
  dxmt11|DXMT11|wine11)  GAME="$DXMT_GAME"; ERRNO_PATCHES=0; COHTML_LICENSE=0 ;;
esac
[ -f "$GAME/Cities2.exe" ] || { echo "ERROR: no Cities2.exe under: $GAME"; exit 1; }
echo "Target game dir: $GAME"
# Derive the wine user dir from the prefix (CrossOver bottle = 'crossover', Kegworks wrapper = 'js').
PREFIX_ROOT="${GAME%%/drive_c/*}"
WUSER=""
for u in crossover js "$USER"; do
  [ -d "$PREFIX_ROOT/drive_c/users/$u" ] && WUSER="$u" && break
done

echo "== Re-applying CS2 macOS/CrossOver patches =="
python3 "$HERE/patch_cohtml.py"        "$GAME"
python3 "$HERE/patch_colossal_io.py"   "$GAME"
python3 "$HERE/patch_longfile.py"      "$GAME"
python3 "$HERE/patch_asset_database.py" "$GAME"
# ── cohtml Gameface licence bypass — NOT in this repository, and NOT needed on wine 11 ─────────
# CS2's Coherent Gameface middleware validates its own embedded licence key via Windows CNG
# (BCryptImportKeyPair -> BCryptHashData -> BCryptVerifySignature). On **wine 10** that final call
# fails on a valid signature (root cause R3), cohtml aborts with "Invalid License key used!", and
# the game crashes before the menu — so that stack needs a bypass, which is deliberately NOT
# published here: a ready-to-run signature-check bypass for commercial middleware reads as
# circumvention regardless of intent.
#
# ✅ **On wine 11 none of that applies.** Measured 2026-08-22 with the DLL restored to pristine:
# MainMenu reached, city loaded, zero licence errors. wine-11.0 verifies the signature correctly.
# So the `dxmt11` target below needs no bypass, and every patch it *does* need is in this repo.
# THE CORRECT FIX WAS ALWAYS IN WINE — see docs/wine-bugs/R3-*.md.
if [ "$COHTML_LICENSE" = 1 ]; then
  echo "  !! wine 10 target: this stack needs the unpublished cohtml licence bypass (see above)."
  echo "     Expect 'Invalid License key used!' and no main menu. Use the wine 11 target instead."
fi
# ───────────────────────────────────────────────────────────────────────────────────────────────

if [ "$ERRNO_PATCHES" = 1 ]; then
# Paradox Mods download I/O fix (IOERR_101 "IOError - Success").
# ROOT CAUSE (2026-07-07, monohost probe): Unity-Mono Directory.Delete(path, recursive:true)
# is broken under Wine — after the FindNextFile end-of-dir, Wine leaves GetLastError garbage
# and CoreFX's FileSystem.RemoveDirectoryRecursive throws BEFORE removing the dir. Every failing
# download op (PrepareFolderForPatching/CleanupTempFileStorage/CleanupAndLogResult/LocalStorage.Delete)
# is a recursive delete; none are Move/Copy. patch_dirdel NOPs that one spurious throw so execution
# reaches the real removal (which works). Proven via scripts/filetest_net.cs [5][6][7] under Unity mono.
python3 "$HERE/patch_dirdel.py" "$GAME/Cities2_Data/Managed/mscorlib.dll"
# patch_dirhandle: the ACTUAL download blocker (2026-07-07). PrepareFolderForPatching → ClearFolderAndKeepPatchFile
# → Directory.GetDirectories on the not-yet-created .downloading\<id>; Wine leaves a GARBAGE (non-deterministic)
# GetLastError on the failed open, so CoreFX's ContinueOnDirectoryError can't recognise not-found and THROWS
# "IOException: Success" instead of enumerating empty. Fix forces the graceful empty-enumeration path.
python3 "$HERE/patch_dirhandle.py" "$GAME/Cities2_Data/Managed/mscorlib.dll"
# patch_delfile: File.Delete graceful on Wine garbage-errno (was aborting downloads before the content .zip).
python3 "$HERE/patch_delfile.py"  "$GAME/Cities2_Data/Managed/mscorlib.dll"
python3 "$HERE/patch_delrec.py"   "$GAME/Cities2_Data/Managed/mscorlib.dll"
python3 "$HERE/patch_dirrec_nx.py" "$GAME/Cities2_Data/Managed/mscorlib.dll"
python3 "$HERE/patch_delchild.py" "$GAME/Cities2_Data/Managed/mscorlib.dll"
else
  echo "  (errno-tolerance six skipped: Wine 11 target)"
fi
# patch_fshandle: Wine returns file handle 0 for a VALID open file; .NET's SafeFileHandle derives
# from SafeHandleZeroOrMinusOneIsInvalid, so IsInvalid is true and mscorlib's FileStream.Init throws
# "ArgumentException: Invalid handle" -> the every-boot "Failed to read settings file with GUID ..."
# dialog, settings falling back to defaults, and mod conflict alerts. patch_longfile already NOPs
# Colossal.IO's own throw in LongFile.GetFileHandle, but mscorlib validates the handle AGAIN.
# Scoped to FileStream deliberately (NOT SafeHandleZeroOrMinusOneIsInvalid.get_IsInvalid, which has
# 6 subclasses incl. registry/wait/buffer handles). Verified 2026-08-22: 6 errors -> 0, boot clean.
python3 "$HERE/patch_fshandle.py" "$GAME/Cities2_Data/Managed/mscorlib.dll"
# patch_mkparent: in-process Directory.CreateDirectory before CreateFileStream writes (kills the DirectoryNotFound
# cascade so nested mod-download writes land). PDX.SDK.dll (relocated method body).
python3 "$HERE/patch_mkparent.py" "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# patch_lockbypass: PdxSdk AsyncReaderWriterLock fails "UNKNOWN" under Wine threading (SemaphoreSlim.WaitAsync throws),
# blocking the content .zip download. Force AcquireLockResult.GetError to return null so the caller proceeds past the
# lock-failure check. (PDX.SDK.dll.)
python3 "$HERE/patch_lockbypass.py" "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
python3 "$HERE/patch_longdelete.py" "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# patch_createfile: PdxSdk LongPathFileExists/DirectoryExists test existence by OPENING the file
# (CreateFile/OPEN_EXISTING + SafeHandle.IsInvalid) instead of querying attrs (GetFileAttributesW/FindFirstFile),
# which under Wine concurrency return garbage "exists" for a missing file -> PathExists false-positive ->
# CheckIntegrity reads the not-yet-downloaded .zip -> abort before download. Opening is reliable; querying is not.
# BEATS the false-positive; content downloads. (Supersedes patch_attrsguard, which missed.) See change-ledger.txt.
python3 "$HERE/patch_createfile.py" "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# patch_lockleak: the content .zip WRITE blocker. CORRECTS the old "reader->writer upgrade deadlock" theory —
# <CreateFileStream>d__25 acquires reader XOR writer (IL 0x6c-0x87 is an if/else on FileAccess), so there is no
# upgrade and no self-deadlock. The real defect: the method has TWO catch clauses and NO finally, and the
# catch handler at IL 0x1a6 never disposes the lock acquired at 0x78/0x82 (the FileNotFound path at 0x120 does).
# So any Wine garbage-errno throw from CreateDirectory (0x16f) / CreateFileStream (0x192) LEAKS the per-path lock;
# every later op on that path then waits on it and GetLockToken's timeout CTS cancels the wait -> WaitAsync THROWS
# (exactly the observed AcquireWriterLockInner -> WaitUntilCountOrTimeoutAsync -> SetException stack).
# Fix injects a null-guarded Dispose into the catch handler, in-place over the redundant inner Log call
# (30 bytes in / 30 out -> no relocation, no offset or EH-clause shifts). Locking semantics stay INTACT, which is
# why this is safe where the 4 global neuters were not.
# Do NOT add patch_locksem/writenowait/readerinit/readerskip — all 4 chased the phantom upgrade-deadlock and were
# reverted (they break SDK init / the fetch / boot asset-DB caching respectively).
python3 "$HERE/patch_lockleak.py" "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# NOTE: patch_pdxsdk_io.py is DELIBERATELY NOT run — it force-returns Success=true, which MASKS the
# failure (the dir is never actually deleted) and BREAKS BOOT on empty mod-state (NRE in PdxSdk.Initialize,
# GOTCHAS #18b). patch_dirdel is the correct layer. Do not re-add patch_pdxsdk_io.

# JetBrains Toolbox stub (stops the modding-tools DirectoryNotFoundException)
TB="$PREFIX_ROOT/drive_c/users/${WUSER:-crossover}/AppData/Local/JetBrains/Toolbox"
mkdir -p "$TB"; printf '{}' > "$TB/.settings.json"
echo "JetBrains Toolbox stub: written"
echo "== Done. Patched: $GAME (wine user: ${WUSER:-crossover}) =="
