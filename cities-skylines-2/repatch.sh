#!/bin/bash
# Re-apply the Cities: Skylines II binary patches (idempotent).
#   bash repatch.sh                  the default wrapper's game folder, or CS2_GAME_DIR
#   bash repatch.sh dxmt11           the same
#   bash repatch.sh <game folder>    that folder
# Each patch pattern-matches and REFUSES to write if the code moved (a game update), rather than
# corrupting the binary. Every one writes a .bak on first run.
# There is one stack, Wine 11 + DXMT. It needs ten of the sixteen patch scripts. The other six tolerate a
# file-error defect that Wine 10 had and that some Wine 11 builds bring back: CS2_ERRNO_PATCHES, below.
# patch_fshandle is among the ten: handle-0 is a separate defect that Wine 11 does not fix.
# Wine 11 also verifies the game's UI middleware licence correctly (root cause R3, docs/wine-bugs/), which
# Wine 10 did not. Nothing here touches that check, and nothing ever shipped here did.
set -e
HERE="$(cd "$(dirname "$0")/patches" && pwd)"
DXMT_GAME="${CS2_GAME_DIR:-$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II}"
ERRNO_PATCHES=0
case "${1:-dxmt11}" in
  dxmt11|DXMT11|wine11) GAME="$DXMT_GAME" ;;
  free|FREE|d3dmetal|wine10)
    echo "The Wine 10 + D3DMetal stack was retired on 2026-11-09. Its last version is commit fefc1e0."
    exit 2 ;;
  *) GAME="$1"
     echo "  ten patches (the Wine 11 set). An engine with the errno defect, Wine 10 included, needs CS2_ERRNO_PATCHES=1" ;;
esac

# CS2_ERRNO_PATCHES=1 — also apply the six errno-tolerance mscorlib patches.
# They are off by default because wine-11.0
# fixed the Mono P/Invoke garbage-errno defect (docs/wine-bugs/FINDING-wine11-fixes-it.md). Not
# every wine-11.x BUILD is clean, though: WineForge's 11.16 reintroduces it, which breaks in-game
# mod downloads (docs/wine-bugs/FINDING-wine11.16-tradeoff.md). If you are on an engine that needs
# them, force them back on without changing target:
#     CS2_ERRNO_PATCHES=1 bash repatch.sh dxmt11
# Verify which you need by running the probe in scripts/ — see docs/wine-bugs/README.md.
# ⚠ To go BACK to the wine-11 set afterwards it is not enough to re-run without the flag: the
#   patches are already written into mscorlib.dll. Restore the pristine backup first:
#     cp "<game>/Cities2_Data/Managed/mscorlib.dll.bak" "<game>/Cities2_Data/Managed/mscorlib.dll"
#     bash repatch.sh dxmt11
# ⚠ The patch scripts take no --check/--dry flag: running one ALWAYS applies it. To inspect state
#   without mutating, diff the DLL against its .bak.
if [ -n "${CS2_ERRNO_PATCHES:-}" ]; then
  ERRNO_PATCHES="$CS2_ERRNO_PATCHES"
  echo "  (CS2_ERRNO_PATCHES=$ERRNO_PATCHES)"
fi
[ -f "$GAME/Cities2.exe" ] || { echo "ERROR: no Cities2.exe under: $GAME"; exit 1; }
echo "Target game dir: $GAME"

# Every patch script is run, counted, and named if it fails. One failure does not stop the others: the bytes each
# writes do not depend on the rest (measured on copies of the game's files, in reverse order too), and stopping at
# the first left a game update that moved one pattern with every later fix unapplied. The ORDER still matters for
# one backup: patch_colossal_io refreshes Colossal.IO.dll.bak from the live file, so it runs before patch_longfile.
EXPECTED=10
if [ "$ERRNO_PATCHES" = 1 ]; then EXPECTED=16; fi
RAN_OK=0
FAILED=""
run() {   # <patch script> <its arguments>
  local p="$1"; shift
  if python3 "$HERE/$p" "$@"; then RAN_OK=$((RAN_OK + 1)); else FAILED="$FAILED $p"; fi
}
# Find the Wine user's folder in the prefix: a Porting Kit wrapper's is Wineskin, others use the Mac's user name.
PREFIX_ROOT="${GAME%%/drive_c/*}"
WUSER=""
for u in Wineskin "$USER" crossover; do
  [ -d "$PREFIX_ROOT/drive_c/users/$u" ] && WUSER="$u" && break
done

echo "== Re-applying the Cities: Skylines II patches =="
run patch_cohtml.py "$GAME"
run patch_colossal_io.py "$GAME"
run patch_longfile.py "$GAME"
run patch_asset_database.py "$GAME"

if [ "$ERRNO_PATCHES" = 1 ]; then
# Paradox Mods download I/O fix (IOERR_101 "IOError - Success").
# ROOT CAUSE (2026-07-07, monohost probe): Unity-Mono Directory.Delete(path, recursive:true)
# is broken under Wine — after the FindNextFile end-of-dir, Wine leaves GetLastError garbage
# and CoreFX's FileSystem.RemoveDirectoryRecursive throws BEFORE removing the dir. Every failing
# download op (PrepareFolderForPatching/CleanupTempFileStorage/CleanupAndLogResult/LocalStorage.Delete)
# is a recursive delete; none are Move/Copy. patch_dirdel NOPs that one spurious throw so execution
# reaches the real removal (which works). Proven via scripts/filetest_net.cs [5][6][7] under Unity mono.
run patch_dirdel.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
# patch_dirhandle: the ACTUAL download blocker (2026-07-07). PrepareFolderForPatching → ClearFolderAndKeepPatchFile
# → Directory.GetDirectories on the not-yet-created .downloading\<id>; Wine leaves a GARBAGE (non-deterministic)
# GetLastError on the failed open, so CoreFX's ContinueOnDirectoryError can't recognise not-found and THROWS
# "IOException: Success" instead of enumerating empty. Fix forces the graceful empty-enumeration path.
run patch_dirhandle.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
# patch_delfile: File.Delete graceful on Wine garbage-errno (was aborting downloads before the content .zip).
run patch_delfile.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
run patch_delrec.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
run patch_dirrec_nx.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
run patch_delchild.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
else
  echo "  (the six errno-tolerance patches are off; CS2_ERRNO_PATCHES=1 applies them)"
fi
# patch_fshandle: Wine returns file handle 0 for a VALID open file; .NET's SafeFileHandle derives
# from SafeHandleZeroOrMinusOneIsInvalid, so IsInvalid is true and mscorlib's FileStream.Init throws
# "ArgumentException: Invalid handle" -> the every-boot "Failed to read settings file with GUID ..."
# dialog, settings falling back to defaults, and mod conflict alerts. patch_longfile already NOPs
# Colossal.IO's own throw in LongFile.GetFileHandle, but mscorlib validates the handle AGAIN.
# Scoped to FileStream deliberately (NOT SafeHandleZeroOrMinusOneIsInvalid.get_IsInvalid, which has
# 6 subclasses incl. registry/wait/buffer handles). Verified 2026-08-22: 6 errors -> 0, boot clean.
run patch_fshandle.py "$GAME/Cities2_Data/Managed/mscorlib.dll"
# patch_mkparent: in-process Directory.CreateDirectory before CreateFileStream writes (kills the DirectoryNotFound
# cascade so nested mod-download writes land). PDX.SDK.dll (relocated method body).
run patch_mkparent.py "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# patch_lockbypass: PdxSdk AsyncReaderWriterLock fails "UNKNOWN" under Wine threading (SemaphoreSlim.WaitAsync throws),
# blocking the content .zip download. Force AcquireLockResult.GetError to return null so the caller proceeds past the
# lock-failure check. (PDX.SDK.dll.)
run patch_lockbypass.py "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
run patch_longdelete.py "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# patch_createfile: PdxSdk LongPathFileExists/DirectoryExists test existence by OPENING the file
# (CreateFile/OPEN_EXISTING + SafeHandle.IsInvalid) instead of querying attrs (GetFileAttributesW/FindFirstFile),
# which under Wine concurrency return garbage "exists" for a missing file -> PathExists false-positive ->
# CheckIntegrity reads the not-yet-downloaded .zip -> abort before download. Opening is reliable; querying is not.
# BEATS the false-positive; content downloads. (Supersedes patch_attrsguard, which missed.) See change-ledger.txt.
run patch_createfile.py "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
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
run patch_lockleak.py "$GAME/Cities2_Data/Managed/PDX.SDK.dll"
# NOTE: patch_pdxsdk_io.py is DELIBERATELY NOT run — it force-returns Success=true, which MASKS the
# failure (the dir is never actually deleted) and BREAKS BOOT on empty mod-state (NRE in PdxSdk.Initialize,
# GOTCHAS #18b). patch_dirdel is the correct layer. Do not re-add patch_pdxsdk_io.

# JetBrains Toolbox stub (stops the modding-tools DirectoryNotFoundException)
TB="$PREFIX_ROOT/drive_c/users/${WUSER:-crossover}/AppData/Local/JetBrains/Toolbox"
mkdir -p "$TB"; printf '{}' > "$TB/.settings.json"
echo "JetBrains Toolbox stub: written"
echo "== Done. Patched: $GAME (wine user: ${WUSER:-crossover}) =="
# "finished without error", not "applied": two of the scripts cannot tell an applied patch from a moved pattern.
echo "$RAN_OK of $EXPECTED patch scripts finished without error"
if [ -n "$FAILED" ]; then echo "FAILED:$FAILED"; exit 1; fi
if [ "$RAN_OK" != "$EXPECTED" ]; then echo "FAILED: $RAN_OK patch scripts ran where $EXPECTED were expected"; exit 1; fi
