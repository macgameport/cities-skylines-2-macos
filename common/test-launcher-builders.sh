#!/bin/bash
# test-launcher-builders.sh -- the three app builders and the 14unch3r window agree (docs/plans/launcher-window.md,
# W8). make-shortcut.sh, surviving-mars-relaunched/make-app.sh and make-steam-shortcut.sh each build their app
# into one scratch folder, around fixture paths and a fixture store wrapper, with a stub xcrun so that no
# progress window is compiled; the window, compiled from common/launcher-window.swift, must then list two games
# and one Steam app, and each game's id and title must equal its line in common/games.tsv. A builder that
# renamed a key, or a table that lost a game, would leave the window blind to an app without any one test of
# its own going red. No game, no Steam, no Wine: the builders are run with fixtures and the window only with
# --list. Kept apart from test-launcher-window.sh, which the plan named, so that its 30 mutants need no builder.
#   bash common/test-launcher-builders.sh            exit 0 = every case passed; exit 2 = swiftc is missing,
#                                                    which is not a pass: nothing was tested
#   MUTANT=1 ...   a game's line is missing from games.tsv; must exit 1
#   MUTANT=2 ...   make-app.sh writes L1Role under another name; must exit 1
set -u
TOP="$(cd "$(dirname "$0")/.." && pwd)"
for f in common/launcher-window.swift common/games.tsv cities-skylines-2/scripts/make-shortcut.sh \
         cities-skylines-2/scripts/make-steam-shortcut.sh surviving-mars-relaunched/make-app.sh; do
  [ -f "$TOP/$f" ] || { echo "REFUSED: $f not found"; exit 2; }
done
xcrun -f swiftc >/dev/null 2>&1 || { echo "REFUSED: swiftc is missing (install the Xcode Command Line Tools); nothing was tested"; exit 2; }
T="$(mktemp -d /tmp/launcher-builders-test.XXXX)"
trap 'rm -rf "$T"' EXIT

# scratch copies laid out as in the repo, so that a mutant edits a copy
mkdir -p "$T/repo/common" "$T/repo/cities-skylines-2/scripts" "$T/repo/surviving-mars-relaunched"
cp "$TOP/common/games.tsv" "$T/repo/common/"
cp "$TOP/cities-skylines-2/scripts/make-shortcut.sh" "$TOP/cities-skylines-2/scripts/make-steam-shortcut.sh" "$T/repo/cities-skylines-2/scripts/"
cp "$TOP/surviving-mars-relaunched/make-app.sh" "$T/repo/surviving-mars-relaunched/"
TSV="$T/repo/common/games.tsv"; SM_MAKE="$T/repo/surviving-mars-relaunched/make-app.sh"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "${MUTANT:-0}" in
  0) ;;
  1) grep -v '^3215050	' "$TSV" > "$TSV.new" && mv "$TSV.new" "$TSV"; grep -q '^3215050	' "$TSV" && mutated ;;
  2) sed -i '' 's|<key>L1Role</key>|<key>L1Rol</key>|' "$SM_MAKE"; grep -q '<key>L1Rol</key>' "$SM_MAKE" || mutated ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# fixtures: a stub xcrun (no progress window is compiled), a fake launcher, and a store wrapper whose wine64
# prints a version and whose steam.exe is an empty file. Each game's path lies in a fixture prefix.
mkdir -p "$T/bin" "$T/home" "$T/cwd" "$T/apps"
printf '#!/bin/bash\nexit 1\n' > "$T/bin/xcrun"; chmod +x "$T/bin/xcrun"
printf '#!/bin/bash\n# >>> launch-feedback (a fake launcher)\nexit 0\n' > "$T/launch.sh"
W="$T/wrappers/Store.app/Contents/SharedSupport"
mkdir -p "$W/wine/bin" "$W/prefix/drive_c/Program Files (x86)/Steam"
printf '#!/bin/bash\necho wine-11.0\n' > "$W/wine/bin/wine64"; chmod +x "$W/wine/bin/wine64"
: > "$W/prefix/drive_c/Program Files (x86)/Steam/steam.exe"
for g in Play Mars; do mkdir -p "$T/wrappers/$g.app/Contents/SharedSupport/prefix/drive_c/game"; done
CS_GAME="$T/wrappers/Play.app/Contents/SharedSupport/prefix/drive_c/game/Cities2.exe"
SM_GAME="$T/wrappers/Mars.app/Contents/SharedSupport/prefix/drive_c/game/Mars.exe"
P="$T/bin:$PATH"

( cd "$T/cwd" && HOME="$T/home" PATH="$P" /bin/bash "$T/repo/cities-skylines-2/scripts/make-shortcut.sh" --dest "$T/apps" \
    --launcher "$T/launch.sh" --game "$CS_GAME" ) > "$T/cs.out" 2>&1; rc1=$?
( cd "$T/cwd" && HOME="$T/home" PATH="$P" SM_APP="$T/apps/Surviving Mars Relaunched.app" SM_SCRIPT="$T/launch.sh" SM_GAME_EXE="$SM_GAME" \
    /bin/bash "$SM_MAKE" ) > "$T/sm.out" 2>&1; rc2=$?
( cd "$T/cwd" && HOME="$T/home" PATH="$P" /bin/bash "$T/repo/cities-skylines-2/scripts/make-steam-shortcut.sh" --dest "$T/apps" \
    --wrapper "$T/wrappers/Store.app" --from "$T/no-such-donor.app" ) > "$T/st.out" 2>&1; rc3=$?
check "the three builders each build their app into one folder" "$rc1:$rc2:$rc3" "0:0:0"

xcrun swiftc -O -o "$T/launcher-window" "$TOP/common/launcher-window.swift" > "$T/compile.out" 2>&1 \
  || { echo "REFUSED: common/launcher-window.swift did not compile"; exit 2; }
"$T/launcher-window" --list "$T/apps" > "$T/list" 2>&1
check "the window lists two games and one Steam app, and nothing else" \
  "$(cut -f1 "$T/list" | sort | uniq -c | awk '{ printf "%s %s;", $2, $1 }')" "game 2;steam 1;"

# every game row matches its line in the table, by id and by title; and every line of the table has its row
rows=0; matched=0
while IFS="	" read -r role id state title path; do
  [ "$role" = game ] || continue
  rows=$((rows + 1))
  awk -F '\t' -v id="$id" -v t="$title" '$1 == id && $3 == t { f = 1 } END { exit !f }' "$TSV" && matched=$((matched + 1))
done < "$T/list"
check "each game's id and title are those of its line in games.tsv" "$matched of $rows" "2 of 2"
lines=0; found=0
while IFS="	" read -r id folder title guide; do
  case "$id" in ''|\#*) continue ;; esac
  lines=$((lines + 1))
  awk -F '\t' -v id="$id" '$1 == "game" && $2 == id { f = 1 } END { exit !f }' "$T/list" && found=$((found + 1))
done < "$TSV"
check "each line of games.tsv has its game in the list" "$found of $lines" "2 of 2"
check "each game's row carries the prefix its game path lies in, so its state is read" \
  "$(awk -F '\t' '$1 == "game" { print $3 }' "$T/list" | sort -u | tr '\n' ' ')" "absent "
check "the Steam app is listed as S734M, its Windows Steam found" "$(awk -F '\t' '$1 == "steam" { print $3 "|" $4 }' "$T/list")" "ready|S734M"

echo "$fails failure(s)"
[ "$fails" = 0 ]
