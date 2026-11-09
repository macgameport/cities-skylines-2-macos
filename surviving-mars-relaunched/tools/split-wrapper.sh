#!/bin/bash
# split-wrapper.sh -- give Surviving Mars its own wrapper (docs/plans/one-wrapper-per-game.md, phases A0-A4b).
#
#   A0  refuse unless: no Wine process holds the donor (S734M) or the store wrapper, no launcher lock, the
#       store's game folder is real and its manifest reads StateFlags 4, the donor's copy is the expected
#       symlink, the last exit upload for the game was ok, and if Steam synced after it, every save still
#       matches Steam's last-synced copy; then back up both manifests, the saves and the donor's
#       userdata/<acct>/3215050 into $SM_STATE/backup/ (SM_STATE as in launch-relaunched.sh).
#   A1  cp -Rc the donor to the new wrapper (APFS clone); drop its copied lock and .crash marker.
#   A2  strip Cities: Skylines II from the clone (tree + manifest + shader cache + userdata, together).
#   A3  tools/make-engine.sh --install the clone (D3DMetal 3.0 in place, the 2.1 Wine kept as a BAK).
#   A4  unlink the clone's symlink, mv the store's game folder into its place, move the store's manifest
#       aside to $SM_STATE/runs/; A4b unlink the donor's (now dangling) symlink and move its manifest aside too, or
#       its Steam re-downloads the game (cs2 GOTCHAS: a manifest over a missing folder).
#
# Never deletes through a symlink: links go with unlink, and rm -r refuses a link and anything outside
# the wrapper it is meant for (an `rm -rf link/` deletes the target's contents -- measured 2026-11-07).
# SPLIT_DONOR / SPLIT_STORE / SPLIT_CLONE / SPLIT_RUNS / SPLIT_BACKUP / SPLIT_LAUNCHER override the paths
# and SPLIT_SKIP_ENGINE=1 skips A3, for tools/test-split-wrapper.sh.
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SM_STATE="${SM_STATE:-$HOME/Library/Application Support/1launcher/surviving-mars-relaunched}"
DONOR="${SPLIT_DONOR:-$HOME/Applications/S734M.app}"
STORE="${SPLIT_STORE:-$HOME/Applications/CS2dxmt11-pk110.app}"
CLONE="${SPLIT_CLONE:-$HOME/Applications/SurvivingMars.app}"
RUNS="${SPLIT_RUNS:-$SM_STATE/runs}"
BACKUP="${SPLIT_BACKUP:-$SM_STATE/backup/one-wrapper-$(date +%Y%m%d-%H%M%S)}"
LAUNCHER="${SPLIT_LAUNCHER:-$HERE/launch-relaunched.sh}"
APPID=3215050
STEAMREL="drive_c/Program Files (x86)/Steam"
GAMEDIR="steamapps/common/Project Spark"
pfx() { echo "${1%/}/Contents/SharedSupport/prefix"; }
DS="$(pfx "$DONOR")/$STEAMREL"; SS="$(pfx "$STORE")/$STEAMREL"; CS="$(pfx "$CLONE")/$STEAMREL"
DM="$DS/steamapps/appmanifest_$APPID.acf"; SM="$SS/steamapps/appmanifest_$APPID.acf"

die()   { echo "REFUSED: $1"; exit 1; }                  # before anything is written
abort() { echo "ABORTED: $1"; echo "State is partial: see the plan's section 4 (rollback)."; exit 3; }
step()  { echo; echo "== $1"; }
acf()   { sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$2" 2>/dev/null | head -n 1; }
phys()  { echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"; }   # resolves parents, not the last part
inside() { case "$(phys "$2")" in "$(cd "$1" && pwd -P)"/*) ;; *) abort "$2 is outside $1" ;; esac; }
rmtree() {   # <wrapper> <path>: rm -rf a real directory inside <wrapper>; never a symlink
  [ -e "$2" ] || [ -L "$2" ] || return 0
  inside "$1" "$2"; [ ! -L "$2" ] || abort "refusing rm -r on a symlink: $2"
  rm -rf "$2"
}
unlink_in() {   # <wrapper> <path>: remove a symlink inside <wrapper>
  inside "$1" "$2"; [ -L "$2" ] || abort "expected a symlink: $2"
  unlink "$2"
}
held_by() {   # <prefix>: pids of Wine/Steam processes with files open in it
  local p; for p in $(pgrep -f -i 'wine|steam|\.exe' 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    lsof -p "$p" 2>/dev/null | grep -qF "$1/" && echo "$p"
  done
  return 0
}

# <remotecache.vdf>: "<path>\t<sha1>" per file Steam last synced (path relative to the Saved Games root)
rc_entries() { awk '{ sub(/\r$/, "") } /^\t"[^"]+"$/ { p = substr($0, 3, length($0) - 3) }
                    /^\t\t"sha"\t/ { s = $0; gsub(/.*"sha"[[:space:]]*"|"$/, "", s); print p "\t" s }' "$1"; }
unsynced() {   # <remotecache.vdf> <saves dir>: each save that differs from Steam's last-synced copy or has none
  local root e; root=$(dirname "$2"); e=$(rc_entries "$1")
  [ -z "$e" ] || echo "$e" | while IFS="$(printf '\t')" read -r p s; do
    [ -f "$root/$p" ] && [ "$(shasum -a 1 < "$root/$p" | cut -c1-40)" = "$s" ] || echo "$p"
  done
  (cd "$root" && find "$(basename "$2")" -type f ! -name steam_autocloud.vdf) | while IFS= read -r p; do
    echo "$e" | cut -f1 | grep -qxF "$p" || echo "$p"
  done
}

step "A0 preconditions"
[ "$(phys "$CLONE")" != "$(phys "$DONOR")" ] && [ "$(phys "$CLONE")" != "$(phys "$STORE")" ] \
  || die "the new wrapper path equals a source wrapper"
[ ! -e "$CLONE" ] || die "$CLONE already exists"
for w in "$DONOR" "$STORE"; do
  [ -d "$(pfx "$w")" ] || die "no prefix in $w"
  h=$(held_by "$(pfx "$w")"); [ -z "$h" ] || die "Wine/Steam processes hold $(basename "$w") (pids: $(echo $h)); quit them first"
  [ ! -L "$(pfx "$w")/.launcher.lock" ] || die "$(basename "$w") has a launcher lock (pid $(readlink "$(pfx "$w")/.launcher.lock")); a launch is running"
done
[ -d "$SS/$GAMEDIR" ] && [ ! -L "$SS/$GAMEDIR" ] && [ -f "$SS/$GAMEDIR/Mars.exe" ] || die "the store wrapper has no real game folder at $GAMEDIR"
[ "$(acf StateFlags "$SM")" = 4 ] || die "the store's appmanifest_$APPID.acf is not StateFlags 4 (mid-update?)"
[ -L "$DS/$GAMEDIR" ] && [ "$(readlink "$DS/$GAMEDIR")" = "$SS/$GAMEDIR" ] || die "the donor's $GAMEDIR is not the expected symlink to the store"
[ -f "$DM" ] || die "the donor has no appmanifest_$APPID.acf"
ACCT=$(cd "$DS/userdata" && for a in *; do [ -d "$a/$APPID" ] && echo "$a"; done | head -n 1)
[ -n "$ACCT" ] || die "no userdata/<acct>/$APPID in the donor"
SAVES=$(find "$(pfx "$DONOR")/drive_c/users" -maxdepth 3 -type d -name 'Surviving Mars Relaunched' -path '*Saved Games*' | head -n 1)
[ -n "$SAVES" ] || die "no Saved Games/Surviving Mars Relaunched in the donor"
CLOG="$DS/logs/cloud_log.txt"
eval "$(sed -n '/^cloud_outcome() {/,/^}/p' "$LAUNCHER")"
[ "$(type -t cloud_outcome)" = function ] || die "cloud_outcome not found in $LAUNCHER"
n=$(grep -n "\[AppID $APPID\] Starting sync (up,AC Exit" "$CLOG" 2>/dev/null | tail -1 | cut -d: -f1)
[ -n "$n" ] || die "no exit upload for $APPID in the donor's cloud_log.txt"
SteamAppId=$APPID; v=$(tail -n +"$n" "$CLOG" | cloud_outcome)
[ "$v" = ok ] || die "the last exit upload was '$v', not ok: play and exit once so the cloud holds the latest saves"
# A sync after the exit upload is usually Steam's sign-in pull with no game run after it (MacBook,
# 2026-11-07: a cs2 boot-verify signed S734M's Steam in, and it pulled change 34 for the still-registered
# game). A run whose exit upload was skipped (another Steam signed in) leaves the same kind of log, so the
# log cannot tell them apart; the saves can. Steam's remotecache.vdf records the SHA-1 of every file as it
# last synced it: a save that differs, or has no entry, is not in the cloud.
later=$(tail -n +"$((n + 1))" "$CLOG" | grep -c "\[AppID $APPID\] Starting sync" || true)
SYNCED=""
if [ "$later" != 0 ]; then
  RC="$DS/userdata/$ACCT/$APPID/remotecache.vdf"
  [ -f "$RC" ] || die "Steam synced after the last exit upload and there is no remotecache.vdf to check the saves against; play and exit once more"
  u=$(unsynced "$RC" "$SAVES")
  [ -z "$u" ] || die "Steam synced after the last exit upload and these saves are not in the cloud: $(echo "$u" | sed 's|.*/||' | paste -sd, -); play and exit once more"
  SYNCED=", $later later sync(s) and every save matches Steam's last-synced copy"
fi
BUILDID=$(acf buildid "$SM")
echo "  ok: nothing running, store build $BUILDID, last upload ok$SYNCED, account dir $ACCT"

step "A0 backups -> ${BACKUP#$HERE/}"
mkdir -p "$BACKUP"; chmod 700 "$BACKUP"
cp -p "$SM" "$BACKUP/appmanifest_$APPID.acf.store"
cp -p "$DM" "$BACKUP/appmanifest_$APPID.acf.s734m"
tar -czf "$BACKUP/saved-games.tgz" -C "$(dirname "$SAVES")" "$(basename "$SAVES")"
cp -pR "$DS/userdata/$ACCT/$APPID" "$BACKUP/userdata-$APPID"
echo "$BUILDID" > "$BACKUP/buildid"
echo "  $(ls "$BACKUP" | wc -l | tr -d ' ') items"

step "A1 clone $(basename "$DONOR") -> $(basename "$CLONE")"
cp -Rc "$DONOR" "$CLONE" || abort "clone failed"
[ "$(stat -f %d "$DONOR")" = "$(stat -f %d "$CLONE")" ] || abort "the clone is on another volume (cp -c made a full copy)"
inside "$CLONE" "$(pfx "$CLONE")/.launcher.lock"; rm -f "$(pfx "$CLONE")/.launcher.lock"
inside "$CLONE" "$CS/.crash"; rm -f "$CS/.crash"

step "A2 strip Cities: Skylines II from the clone"
rmtree "$CLONE" "$CS/steamapps/common/Cities Skylines II"
inside "$CLONE" "$CS/steamapps/appmanifest_949230.acf"; rm -f "$CS/steamapps/appmanifest_949230.acf"
rmtree "$CLONE" "$CS/steamapps/shadercache/949230"
rmtree "$CLONE" "$CS/userdata/$ACCT/949230"
[ -L "$CS/$GAMEDIR" ] || abort "the clone's $GAMEDIR is not a symlink"

step "A3 D3DMetal 3.0 into the clone's Wine"
if [ "${SPLIT_SKIP_ENGINE:-0}" = 1 ]; then echo "  skipped (SPLIT_SKIP_ENGINE=1)"
else bash "$HERE/tools/make-engine.sh" --install "$CLONE" || abort "make-engine.sh --install failed"; fi

step "A4 move the game folder into the clone"
L="$CS/$GAMEDIR"
[ "$(readlink "$L")" = "$SS/$GAMEDIR" ] || abort "the clone's link does not point at the store's folder"
unlink_in "$CLONE" "$L"
mv "$SS/$GAMEDIR" "$L" || abort "mv of the game folder failed"
[ -f "$L/Mars.exe" ] && [ ! -L "$L" ] && [ ! -e "$SS/$GAMEDIR" ] || abort "after the move the clone has no Mars.exe, or the store still has the folder"
mkdir -p "$RUNS"
mv -n "$SM" "$RUNS/appmanifest_$APPID.acf.store"; [ ! -e "$SM" ] || abort "the store's manifest did not move (runs/ already holds one?)"

step "A4b drop the donor's registration"
unlink_in "$DONOR" "$DS/$GAMEDIR"
mv -n "$DM" "$RUNS/appmanifest_$APPID.acf.s734m"; [ ! -e "$DM" ] || abort "the donor's manifest did not move (runs/ already holds one?)"

step "done"
CMF="$CS/steamapps/appmanifest_$APPID.acf"
echo "  $(basename "$CLONE"): Mars.exe present, manifest StateFlags $(acf StateFlags "$CMF"), buildid $(acf buildid "$CMF") (store had $BUILDID), AutoUpdateBehavior $(acf AutoUpdateBehavior "$CMF")"
echo "  $(basename "$STORE"): game folder and manifest gone (manifest in runs/)"
echo "  $(basename "$DONOR"): link and manifest gone (manifest in runs/); Cities: Skylines II untouched"
echo "  next: plan A4 step 6 / T1-T2 (start the new wrapper's Steam once, read StateFlags)"
