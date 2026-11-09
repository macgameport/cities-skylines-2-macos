#!/bin/bash
# test-cloud-outcome.sh -- fixtures for cloud_outcome in launch-relaunched.sh, which reads Steam's
# logs/cloud_log.txt after the game exits. Fixture lines are copied from real cloud logs (the 2026-11-01
# conflict on the Studio; an upload by another app, retagged where the case needs this game's AppID).
# Account identifiers, save names, file hashes and batch IDs in the lines are replaced (<id>, <account>,
# <user>, <batch>, <file>, "Colony One"): cloud_outcome never reads them.
#   bash tools/test-cloud-outcome.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-cloud-outcome.sh   naive "any upload OK" test swapped in; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SteamAppId=3215050
eval "$(sed -n '/^cloud_outcome() {/,/^}/p' "$HERE/launch-relaunched.sh")"
[ "$(type -t cloud_outcome)" = function ] || { echo "REFUSED: cloud_outcome not found in the launcher"; exit 2; }
if [ "${MUTANT:-0}" = 1 ]; then
  cloud_outcome() { grep -q 'Upload complete, result OK' && echo ok || echo none; }
fi

CONFLICT='[2026-11-01 15:57:57] [AppID 3215050] Starting sync (up,AC Exit,)
[2026-11-01 15:57:57] [AppID 3215050] Running AutoCloud on exit. Looking for new and updated files
[2026-11-01 15:57:57] [AppID 3215050]     Persisting file C:\users\<user>\Saved Games\Surviving Mars Relaunched\<id>\Colony One.savegame.sav to the cloud
[2026-11-01 15:57:57] [AppID 3215050] AutoCloud complete
[2026-11-01 15:57:57] [AppID 3215050] Attempting to sync from local change number '"'0'"' to global change number '"'3'"' (full)
[2026-11-01 15:57:57] [AppID 3215050] Surviving Mars Relaunched/<id>/account.dat already marked as conflicting. Local/Remote SHA: 6862 / 684f
[2026-11-01 15:57:57] [AppID 3215050] Sync conflict for file Surviving Mars Relaunched/<id>/account.dat.bak
[2026-11-01 15:57:57] [AppID 3215050] Sync conflict for file Surviving Mars Relaunched/<id>/account.dat
[2026-11-01 15:57:57] [AppID 3215050] Upload failed due to conflicts in build list'
UPLOAD='[2026-08-22 11:18:17] [AppID 949230] Starting sync (up,AC Exit,)
[2026-08-22 11:18:17] [AppID 949230] Need to upload file <file>
[2026-08-22 11:18:18] [AppID 949230] Upload batch initiated, ID: <batch>, ChangeNumber: 2, App Build ID: 23700737
[2026-08-22 11:18:19] [AppID 949230] Upload OK for file <file>
[2026-08-22 11:18:19] [AppID 949230] Upload complete, result OK'
OURS=${UPLOAD//949230/3215050}
STARTED=$(printf '%s\n' "$OURS" | sed -n '1,3p')
OFFLINE="[2026-08-22 11:44:15] [AppID 3215050] Failed sync for 'up,AC Exit,' [login=false][offlineMode=false]"
INIT='[2026-11-01 15:22:31] [AppID 3215050] Starting sync (init,)
[2026-11-01 15:22:32] [AppID 3215050] AutoCloud checking local state for user <account>'
# MacBook 2026-11-01 01:32: Steam's -shutdown landed mid-upload (the save path shortened to <id>).
CANCELLED='[2026-11-01 01:32:21] [AppID 3215050] Upload batch initiated, ID: <batch>, ChangeNumber: 3, App Build ID: 0
[2026-11-01 01:32:31] [AppID 3215050] Upload OK for file Surviving Mars Relaunched/<id>/account.dat
[2026-11-01 01:32:44] [AppID 3215050] Upload Timeout for file Surviving Mars Relaunched/<id>/Colony Two.savegame.sav
[2026-11-01 01:32:44] [AppID 3215050] Failed to send CompleteAppUploadBatch notification (No Connection / OK)
[2026-11-01 01:32:44] [AppID 3215050] Job Canceled
[2026-11-01 01:32:44] [AppID 3215050] Failed to send BSignalAppExitSyncDone'
# MacBook 2026-11-01 01:09: the store wrapper had replaced this Steam's session mid-game.
DISABLED="[2026-11-01 01:09:53] [AppID 3215050] Starting sync (AC Exit,Sync Disabled,)
[2026-11-01 01:09:53] [AppID 3215050] Running AutoCloud on exit. Looking for new and updated files
[2026-11-01 01:09:53] [AppID 3215050] AutoCloud complete
[2026-11-01 01:09:53] [AppID 3215050] Failed sync for 'AC Exit,Sync Disabled,' [login=false][offlineMode=false]"

fails=0
check() {   # <name> <expected> <log text>
  local got; got=$(printf '%s\n' "$3" | cloud_outcome)
  if [ "$got" = "$2" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$got', want '$2')"; fails=$((fails + 1)); fi
}
check "conflict names the files"            "conflict account.dat.bak, account.dat" "$CONFLICT"
check "CRLF log (as Steam writes it)"       "conflict account.dat.bak, account.dat" "$(printf '%s\n' "$CONFLICT" | sed $'s/$/\r/')"
check "this game's upload completes"        ok        "$OURS"
check "another app's upload is ignored"     none      "$UPLOAD"
check "upload begun, not finished"          uploading "$STARTED"
check "a bare Failed sync line"             failed    "$OFFLINE"
check "upload cancelled by -shutdown"       failed    "$CANCELLED"
check "Steam offline at exit (replaced)"    offline   "$DISABLED"
check "launch-time sync only"               none      "$INIT"
check "a conflict, then a clean upload"     ok        "$CONFLICT
$OURS"

echo "$fails failure(s)"
[ "$fails" = 0 ]
