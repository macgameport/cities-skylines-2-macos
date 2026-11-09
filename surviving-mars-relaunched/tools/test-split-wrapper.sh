#!/bin/bash
# test-split-wrapper.sh -- tools/split-wrapper.sh on throwaway donor and store wrappers with the real layout
# (small files, no Wine, no Steam; A3's engine step skipped, tools/test-make-engine-install.sh covers it).
# The clean run must leave: the game folder moved into the clone, Cities: Skylines II stripped from the
# clone and untouched in the donor, both SM manifests moved to runs/, backups written. Each A0 refusal must
# exit 1 and change nothing. A sign-in pull after the last exit upload passes while every save matches
# Steam's remotecache.vdf, and refuses once one does not.
#   bash tools/test-split-wrapper.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-split-wrapper.sh   the clone's link removed with `rm -rf link/`; must exit 1
#   MUTANT=2 bash tools/test-split-wrapper.sh   the save check passes every save; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$HERE/tools/split-wrapper.sh"
T="$(mktemp -d /tmp/split-test.XXXX)"
FIX=""
cleanup() { [ -n "$FIX" ] && kill "$FIX" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
case "${MUTANT:-0}" in
  1) sed 's|^unlink_in "\$CLONE" "\$L"$|rm -rf "$L/"|' "$SCRIPT" > "$T/split-wrapper.sh"
     grep -q '^rm -rf "\$L/"$' "$T/split-wrapper.sh" || { echo "REFUSED: mutant did not apply"; exit 2; }
     SCRIPT="$T/split-wrapper.sh" ;;
  2) sed 's|^  u=$(unsynced "\$RC" "\$SAVES")$|  u=""|' "$SCRIPT" > "$T/split-wrapper.sh"
     grep -q '^  u=""$' "$T/split-wrapper.sh" || { echo "REFUSED: mutant did not apply"; exit 2; }
     SCRIPT="$T/split-wrapper.sh" ;;
esac
ST="drive_c/Program Files (x86)/Steam"

fixture() {   # <dir>: build donor + store wrappers under <dir>; echo nothing
  local d="$1" dp sp
  dp="$d/Donor.app/Contents/SharedSupport/prefix"; sp="$d/Store.app/Contents/SharedSupport/prefix"
  mkdir -p "$sp/$ST/steamapps/common/Project Spark" "$sp/$ST/logs"
  echo game > "$sp/$ST/steamapps/common/Project Spark/Mars.exe"
  printf '"AppState"\n{\n\t"StateFlags"\t\t"4"\n\t"buildid"\t\t"25579348"\n\t"AutoUpdateBehavior"\t\t"0"\n}\n' > "$sp/$ST/steamapps/appmanifest_3215050.acf"
  mkdir -p "$dp/$ST/steamapps/common/Cities Skylines II" "$dp/$ST/steamapps/shadercache/949230" \
           "$dp/$ST/userdata/111/3215050" "$dp/$ST/userdata/111/949230" "$dp/$ST/logs" \
           "$dp/drive_c/users/Wineskin/Saved Games/Surviving Mars Relaunched/111"
  echo cs2 > "$dp/$ST/steamapps/common/Cities Skylines II/Cities2.exe"
  ln -s "$sp/$ST/steamapps/common/Project Spark" "$dp/$ST/steamapps/common/Project Spark"
  printf '"AppState"\n{\n\t"StateFlags"\t\t"4"\n\t"buildid"\t\t"25579348"\n\t"AutoUpdateBehavior"\t\t"1"\n}\n' > "$dp/$ST/steamapps/appmanifest_3215050.acf"
  echo x > "$dp/$ST/steamapps/appmanifest_949230.acf"; echo x > "$dp/$ST/steamapps/appmanifest_228980.acf"
  echo x > "$dp/$ST/steamapps/shadercache/949230/c"; echo x > "$dp/$ST/userdata/111/949230/c"
  printf '"3215050"\n{\n\t"ChangeNumber"\t\t"34"\n\t"Surviving Mars Relaunched/111/Archibald.savegame.sav"\n\t{\n\t\t"root"\t\t"9"\n\t\t"sha"\t\t"%s"\n\t}\n}\n' \
    "$(printf 'save\n' | shasum -a 1 | cut -c1-40)" > "$dp/$ST/userdata/111/3215050/remotecache.vdf"
  echo save > "$dp/drive_c/users/Wineskin/Saved Games/Surviving Mars Relaunched/111/Archibald.savegame.sav"
  printf '[2026-11-07 17:50:01] [AppID 3215050] Starting sync (up,AC Exit,)\r\n[2026-11-07 17:50:07] [AppID 3215050] Upload complete, result OK\r\n' > "$dp/$ST/logs/cloud_log.txt"
  touch "$dp/$ST/.crash"
}
run() {   # <dir>: run the script against <dir>'s fixture; echo its exit code
  SPLIT_DONOR="$1/Donor.app" SPLIT_STORE="$1/Store.app" SPLIT_CLONE="$1/Game.app" SPLIT_RUNS="$1/runs" \
  SPLIT_BACKUP="$1/backup" SPLIT_LAUNCHER="$HERE/launch-relaunched.sh" SPLIT_SKIP_ENGINE=1 \
    bash "$SCRIPT" > "$1.out" 2>&1
  echo $?
}
snap() { (cd "$1" && find . | sort | shasum | cut -c1-12); }
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
yes_no() { if eval "$1"; then echo yes; else echo no; fi; }

# --- the clean run
D="$T/clean"; mkdir -p "$D"; fixture "$D"
DS="$D/Donor.app/Contents/SharedSupport/prefix/$ST"; SS="$D/Store.app/Contents/SharedSupport/prefix/$ST"; CS="$D/Game.app/Contents/SharedSupport/prefix/$ST"
check "clean run exits 0" "$(run "$D")" 0
check "clone has the game as a real folder" "$(yes_no "[ -f \"$CS/steamapps/common/Project Spark/Mars.exe\" ] && [ ! -L \"$CS/steamapps/common/Project Spark\" ]")" yes
check "store's game folder is gone" "$(yes_no "[ ! -e \"$SS/steamapps/common/Project Spark\" ]")" yes
check "store's manifest moved to runs/" "$(yes_no "[ ! -e \"$SS/steamapps/appmanifest_3215050.acf\" ] && [ -f \"$D/runs/appmanifest_3215050.acf.store\" ]")" yes
check "donor's link and manifest gone, manifest in runs/" "$(yes_no "[ ! -e \"$DS/steamapps/common/Project Spark\" ] && [ ! -L \"$DS/steamapps/common/Project Spark\" ] && [ -f \"$D/runs/appmanifest_3215050.acf.s734m\" ]")" yes
check "donor keeps Cities: Skylines II and its manifest" "$(yes_no "[ -f \"$DS/steamapps/common/Cities Skylines II/Cities2.exe\" ] && [ -f \"$DS/steamapps/appmanifest_949230.acf\" ]")" yes
check "clone lost CS2 tree, manifest, shader cache, userdata" "$(yes_no "[ ! -e \"$CS/steamapps/common/Cities Skylines II\" ] && [ ! -e \"$CS/steamapps/appmanifest_949230.acf\" ] && [ ! -e \"$CS/steamapps/shadercache/949230\" ] && [ ! -e \"$CS/userdata/111/949230\" ]")" yes
check "clone keeps 228980, its SM manifest, saves, cloud cache" "$(yes_no "[ -f \"$CS/steamapps/appmanifest_228980.acf\" ] && [ -f \"$CS/steamapps/appmanifest_3215050.acf\" ] && [ -f \"$D/Game.app/Contents/SharedSupport/prefix/drive_c/users/Wineskin/Saved Games/Surviving Mars Relaunched/111/Archibald.savegame.sav\" ] && [ -f \"$CS/userdata/111/3215050/remotecache.vdf\" ]")" yes
check "clone has no .crash marker" "$(yes_no "[ ! -e \"$CS/.crash\" ]")" yes
check "backups: 2 manifests, saves, userdata, buildid" "$(ls "$D/backup" | sort | tr '\n' ' ')" "appmanifest_3215050.acf.s734m appmanifest_3215050.acf.store buildid saved-games.tgz userdata-3215050 "

# --- A0 refusals: each on a fresh fixture, each must change nothing
refuse() {  # <name> <setup command, run in the fixture dir with $DS/$SS set> <expected message part>
  local D="$T/r$RANDOM" before rc
  mkdir -p "$D"; fixture "$D"
  DS="$D/Donor.app/Contents/SharedSupport/prefix/$ST"; SS="$D/Store.app/Contents/SharedSupport/prefix/$ST"
  eval "$2"
  before=$(snap "$D"); rc=$(run "$D")
  check "refused: $1" "$rc:$(grep -c "REFUSED: .*$3" "$D.out")" "1:1"
  [ -n "$FIX" ] && { kill "$FIX" 2>/dev/null; wait "$FIX" 2>/dev/null; FIX=""; }
  check "  ...nothing changed" "$(snap "$D" | sed 's/^/x/')" "$(echo "$before" | sed 's/^/x/')"
}
refuse "target exists" 'mkdir -p "$D/Game.app"' "already exists"
refuse "launcher lock in the donor" 'ln -s 99999 "$D/Donor.app/Contents/SharedSupport/prefix/.launcher.lock"' "launcher lock"
refuse "store mid-update" 'sed -i "" "s/\"4\"/\"6\"/" "$SS/steamapps/appmanifest_3215050.acf"' "StateFlags 4"
refuse "last upload was a conflict" 'printf "[2026-11-07 17:50:01] [AppID 3215050] Starting sync (up,AC Exit,)\r\n[2026-11-07 17:50:02] [AppID 3215050] Sync conflict for file x/account.dat\r\n[2026-11-07 17:50:02] [AppID 3215050] Upload failed due to conflicts in build list\r\n" > "$DS/logs/cloud_log.txt"' "not ok"
# a sign-in pull after the exit upload, as the MacBook's S734M had (2026-11-07); SV is the fixture's save dir
PULL='printf "[2026-11-07 20:38:44] [AppID 3215050] Starting sync (eval,)\r\n[2026-11-07 20:38:44] [AppID 3215050] Starting sync (down,)\r\n[2026-11-07 20:38:50] [AppID 3215050] Download complete, result OK\r\n[2026-11-07 20:38:50] [AppID 3215050] Successfully synced to ChangeNumber 34\r\n" >> "$DS/logs/cloud_log.txt"'
SV='$D/Donor.app/Contents/SharedSupport/prefix/drive_c/users/Wineskin/Saved Games/Surviving Mars Relaunched/111'
refuse "a later sync, then a save changed" "$PULL; echo more >> \"$SV/Archibald.savegame.sav\"" "not in the cloud: Archibald.savegame.sav"
refuse "a later sync, then a new save" "$PULL; echo new > \"$SV/New.savegame.sav\"" "not in the cloud: New.savegame.sav"
refuse "a later sync, no remotecache.vdf" "$PULL; rm \"\$DS/userdata/111/3215050/remotecache.vdf\"" "no remotecache.vdf"
refuse "a Wine process holds the donor" '( exec -a wine-fixture-hold tail -f "$DS/logs/cloud_log.txt" ) >/dev/null 2>&1 & FIX=$!; sleep 1' "processes hold"
refuse "donor link points elsewhere" 'rm "$DS/steamapps/common/Project Spark"; ln -s /nonexistent "$DS/steamapps/common/Project Spark"' "expected symlink"

# --- a later sign-in pull with every save as Steam last synced it: the split goes ahead
D="$T/pulled"; mkdir -p "$D"; fixture "$D"
DS="$D/Donor.app/Contents/SharedSupport/prefix/$ST"; eval "$PULL"
check "a later sync, saves as synced: clean run exits 0" "$(run "$D")" 0
check "  ...and it says the saves were checked" "$(grep -c 'every save matches' "$D.out")" 1
check "  ...and the clone has the game" "$(yes_no "[ -f \"$D/Game.app/Contents/SharedSupport/prefix/$ST/steamapps/common/Project Spark/Mars.exe\" ]")" yes

echo "$fails failure(s)"
[ "$fails" = 0 ]
