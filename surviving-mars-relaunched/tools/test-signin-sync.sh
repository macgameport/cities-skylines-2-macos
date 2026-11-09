#!/bin/bash
# test-signin-sync.sh -- fixtures for launch-relaunched.sh's pull-before-play: signin_outcome, which reads
# Steam's logs/cloud_log.txt after sign-in. Log lines are copied from the MacBook's probes of 2026-11-02
# and the Studio's 2026-11-01 conflict (save paths shortened to <id>; save names, the storage host and
# batch IDs replaced: signin_outcome never reads them). The registration cases went with
# the registration code when the game got its own wrapper (docs/plans/one-wrapper-per-game.md).
#   bash tools/test-signin-sync.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-signin-sync.sh   naive versions swapped in; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
L="$HERE/launch-relaunched.sh"
SteamAppId=3215050
eval "$(sed -n '/^signin_outcome() {/,/^}/p' "$L")"
for f in signin_outcome; do
  [ "$(type -t $f)" = function ] || { echo "REFUSED: $f not found in the launcher"; exit 2; }
done
if [ "${MUTANT:-0}" = 1 ]; then
  signin_outcome() { grep -q 'Eval complete' && echo current || echo none; }
fi

IN_SYNC="[2026-11-02 15:13:45] [AppID 3215050] Starting sync (eval,)
[2026-11-02 15:13:45] [AppID 3215050] Need to sync from local change number '5' to global change number '6' (full), but not attempting now
[2026-11-02 15:13:45] [AppID 3215050] File is in sync Surviving Mars Relaunched/<id>/account.dat
[2026-11-02 15:13:45] [AppID 3215050] Eval complete"
PULLING="[2026-11-02 15:17:25] [AppID 3215050] Starting sync (eval,)
[2026-11-02 15:17:25] [AppID 3215050] Need to sync from local change number '5' to global change number '6' (full), but not attempting now
[2026-11-02 15:17:25] [AppID 3215050] Need to download file Surviving Mars Relaunched/<id>/Colony One.savegame.sav
[2026-11-02 15:17:25] [AppID 3215050] Eval complete
[2026-11-02 15:17:25] [AppID 3215050] Starting sync (down,)
[2026-11-02 15:17:25] [AppID 3215050] HTTP download for file 'Surviving Mars Relaunched/<id>/Colony One.savegame.sav' from host '<host>', path /x"
PULLED="$PULLING
[2026-11-02 15:17:28] [AppID 3215050] Download OK for file Surviving Mars Relaunched/<id>/Colony One.savegame.sav
[2026-11-02 15:17:28] [AppID 3215050] Download complete, result OK
[2026-11-02 15:17:28] [AppID 3215050] Successfully synced to ChangeNumber 6"
# 2026-11-02 15:04, a pending upload: pull first, then push
PUSHING="[2026-11-02 15:04:19] [AppID 3215050] Starting sync (eval,)
[2026-11-02 15:04:19] [AppID 3215050] Need to download file Surviving Mars Relaunched/<id>/account.dat
[2026-11-02 15:04:19] [AppID 3215050] Need to upload file Surviving Mars Relaunched/<id>/Colony Two.savegame.sav
[2026-11-02 15:04:19] [AppID 3215050] Eval complete
[2026-11-02 15:04:19] [AppID 3215050] Starting sync (up,)
[2026-11-02 15:04:57] [AppID 3215050] Download complete, result OK
[2026-11-02 15:04:57] [AppID 3215050] Successfully synced to ChangeNumber 4
[2026-11-02 15:04:57] [AppID 3215050] Upload batch initiated, ID: <batch>, ChangeNumber: 5, App Build ID: 0"
PUSHED="$PUSHING
[2026-11-02 15:05:02] [AppID 3215050] Upload OK for file Surviving Mars Relaunched/<id>/Colony Two.savegame.sav
[2026-11-02 15:05:02] [AppID 3215050] Upload complete, result OK"
CONFLICT="[2026-11-01 15:57:57] [AppID 3215050] Surviving Mars Relaunched/<id>/account.dat already marked as conflicting. Local/Remote SHA: 6862 / 684f
[2026-11-01 15:57:57] [AppID 3215050] Sync conflict for file Surviving Mars Relaunched/<id>/account.dat.bak
[2026-11-01 15:57:57] [AppID 3215050] Sync conflict for file Surviving Mars Relaunched/<id>/account.dat
[2026-11-01 15:57:57] [AppID 3215050] Upload failed due to conflicts in build list"
# A download-side conflict: the shape Steam logged for AppID 7 on 2026-07-04, retagged to this game.
DOWN_CONFLICT="[2026-07-04 23:53:03] [AppID 3215050] Starting sync (down,)
[2026-07-04 23:53:04] [AppID 3215050] Attempting to sync from local change number '0' to global change number '1' (full)
[2026-07-04 23:53:04] [AppID 3215050] Surviving Mars Relaunched/<id>/account.dat has local changes but mismatch - creating a conflict. Local/Remote SHA: f2b1 / 73ae
[2026-07-04 23:53:04] [AppID 3215050] Sync conflict for file Surviving Mars Relaunched/<id>/account.dat
[2026-07-04 23:53:04] [AppID 3215050] Download failed due to conflicts in build list"
EVAL_PENDING=$(printf '%s\n' "$PULLING" | sed -n '1,4p')
# A conflict recorded by an earlier sync, logged on its own (first line of the Studio's conflict).
MARKED=$(printf '%s\n' "$CONFLICT" | sed -n '1p')
# A reused Steam, read just as the last game's exit upload begins (2026-11-02 15:06:12 shape).
EXIT_STARTING="$PULLED
[2026-11-02 15:06:12] [AppID 3215050] Starting sync (up,AC Exit,)"
crlf() { printf '%s\n' "$1" | sed $'s/$/\r/'; }
OTHER_APP="[2026-11-01 01:43:15] [AppID 949230] Currently already synced to global change number '5', should be nothing to download
[2026-11-01 01:43:15] [AppID 949230] Eval complete"
ALREADY=${OTHER_APP//949230/3215050}
FAILED="[2026-11-01 01:09:53] [AppID 3215050] Failed sync for 'eval,' [login=false][offlineMode=false]"

fails=0
check() {   # <name> <expected> <got>
  if [ "$3" = "$2" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$3', want '$2')"; fails=$((fails + 1)); fi
}
so() { printf '%s\n' "$1" | signin_outcome; }
check "sign-in: files already in sync"         current "$(so "$IN_SYNC")"
check "sign-in: already at the cloud's change" current "$(so "$ALREADY")"
check "sign-in: download under way"            busy    "$(so "$PULLING")"
check "sign-in: eval done, download pending"   busy    "$(so "$EVAL_PENDING")"
check "sign-in: download-side conflict"        "conflict account.dat" "$(so "$DOWN_CONFLICT")"
check "sign-in: conflict marked earlier"       conflict "$(so "$MARKED")"
check "reused Steam: exit upload starting"     busy    "$(so "$EXIT_STARTING")"
check "sign-in: CRLF log, conflict names clean" "conflict account.dat.bak, account.dat" "$(crlf "$CONFLICT" | signin_outcome)"
check "sign-in: CRLF log, download finished"   current "$(crlf "$PULLED" | signin_outcome)"
check "sign-in: download finished"             current "$(so "$PULLED")"
check "sign-in: pulled, push under way"        busy    "$(so "$PUSHING")"
check "sign-in: pulled and pushed"             current "$(so "$PUSHED")"
check "sign-in: conflict names the files"      "conflict account.dat.bak, account.dat" "$(so "$CONFLICT")"
check "sign-in: conflict outlasts a later sync" "conflict account.dat.bak, account.dat" "$(so "$CONFLICT
$PULLED")"
check "sign-in: failed"                        failed  "$(so "$FAILED")"
check "sign-in: another app only (unregistered)" none  "$(so "$OTHER_APP")"
check "sign-in: nothing logged"                none    "$(so "")"

echo "$fails failure(s)"
[ "$fails" = 0 ]
