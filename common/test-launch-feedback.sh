#!/bin/bash
# test-launch-feedback.sh -- what each launcher tells the player, and how: step, note, licence_wait, _alert
# and die. From each launcher it takes the `QUIET=` line, the launch-feedback-config lines, the launch-feedback
# block and die, and runs them in a fresh bash under `set -u`, driven by the settings the app's shim passes
# (CS2_QUIET and CS2_PANEL, SM_QUIET and SM_PANEL). A recording osascript and a recording sleep come first on
# PATH, so nothing is shown and nothing waits. osacompile, which compiles and shows nothing, checks that the
# AppleScript each call would run is valid. No game, no Steam, no Wine.
#   bash common/test-launch-feedback.sh            exit 0 = every case passed; exit 2 = a launcher or a piece is missing
#   MUTANT=1 ...   step ignores PANEL (the window and a notification for the same milestone); must exit 1
#   MUTANT=2 ...   note is silenced by PANEL (a warning nobody sees); must exit 1
#   MUTANT=3 ...   the PANEL= line is deleted (under set -u the app's launch dies at its first step); must exit 1
#   MUTANT=4 ...   the Cities: Skylines II launcher reads SM_PANEL; must exit 1
#   MUTANT=5 ...   the notification's text is pasted into the AppleScript source again; must exit 1
#   MUTANT=6 ...   licence_wait ignores the setting; must exit 1
#   MUTANT=7 ...   licence_wait drops the remainder below 15 s; must exit 1
#   MUTANT=8 ...   licence_wait takes the setting as it is, with no validation; must exit 1
#   MUTANT=9 ...   the alert's text is pasted into the AppleScript source again; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/launch-feedback-test.XXXX)"
trap 'rm -rf "$T"' EXIT
# launcher | the prefix of its settings | the title its pop-ups carry
GAMES=("cities-skylines-2/launchers/launch-cs2-dxmt11.sh|CS2|Cities: Skylines II"
       "surviving-mars-relaunched/launch-relaunched.sh|SM|Surviving Mars: Relaunched")
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
mutate() {   # <file> <sed expression> <fixed text that proves it applied>
  sed -i '' "$2" "$1"; grep -qF -- "$3" "$1" || mutated
}
n=0
for g in "${GAMES[@]}"; do
  n=$((n + 1)); f="${g%%|*}"
  [ -f "$HERE/$f" ] || { echo "REFUSED: $f not found under $HERE"; exit 2; }
  L="$T/launcher.$n.sh"; cp "$HERE/$f" "$L"
  case "${MUTANT:-0}" in
    0) ;;
    1) mutate "$L" 's/^  \[ "\$QUIET" = 1 \] && \[ "\$PANEL" != 1 \] && _notify "\$2"$/  [ "$QUIET" = 1 ] \&\& _notify "$2"/' '  [ "$QUIET" = 1 ] && _notify "$2"' ;;
    2) mutate "$L" 's/^  \[ "\$QUIET" = 1 \] && _notify "\$1"$/  [ "$QUIET" = 1 ] \&\& [ "$PANEL" != 1 ] \&\& _notify "$1"/' '  [ "$QUIET" = 1 ] && [ "$PANEL" != 1 ] && _notify "$1"' ;;
    3) sed -i '' '/^PANEL=/d' "$L"; grep -q '^PANEL=' "$L" && mutated ;;
    4) [ "$n" = 1 ] && mutate "$L" 's/^PANEL="\${CS2_PANEL:-0}"$/PANEL="${SM_PANEL:-0}"/' 'PANEL="${SM_PANEL:-0}"' ;;
    5) mutate "$L" 's/^_notify() { .*/_notify() { osascript -e "display notification \\"$1\\" with title \\"$TITLE\\"" >\/dev\/null 2>\&1; }/' '_notify() { osascript -e "display notification \"$1\" with title \"$TITLE\"" >/dev/null 2>&1; }' ;;
    6) mutate "$L" 's/\*) w=\$((10#\$2)) ;; esac$/*) w=$3 ;; esac/' "''|*[!0-9]*|????*) w=\$3 ;; *) w=\$3 ;; esac" ;;
    7) mutate "$L" 's/else sleep "\$w"; w=0; fi$/else w=0; fi/' 'sleep 15; w=$((w - 15)); else w=0; fi' ;;
    8) mutate "$L" 's/^  case "\$2" in .*) w=\$((10#\$2)) ;; esac$/  w=${2:-$3}/' '  w=${2:-$3}' ;;
    9) mutate "$L" 's/^  else osascript .* as critical. .*; fi$/  else osascript -e "display alert \\"$TITLE\\" message \\"$1\\" as critical" >\/dev\/null 2>\&1; fi/' '  else osascript -e "display alert \"$TITLE\" message \"$1\" as critical" >/dev/null 2>&1; fi' ;;
    *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
  esac
  {
    grep '^QUIET=' "$L"
    sed -n '/^# >>> launch-feedback-config/,/^# <<< launch-feedback-config/p' "$L"
    sed -n '/^# >>> launch-feedback (/,/^# <<< launch-feedback$/p' "$L"
    sed -n '/^die() {/,/^}/p' "$L"
  } > "$T/pieces.$n.sh"
  [ "$(grep -c '^QUIET=' "$T/pieces.$n.sh")" = 1 ] && grep -q '^# <<< launch-feedback-config' "$T/pieces.$n.sh" \
    && grep -q '^# <<< launch-feedback$' "$T/pieces.$n.sh" && grep -q '^die() {' "$T/pieces.$n.sh" \
    || { echo "REFUSED: could not find the QUIET= line, the config, the block and die in $f"; exit 2; }
done

mkdir -p "$T/bin"
printf '#!/bin/bash\n{ echo "CALL $#"; printf "%%s\\n" "$@"; } >> "$OSA_CALLS"\n' > "$T/bin/osascript"
printf '#!/bin/bash\necho "$1" >> "$SLEEP_CALLS"\n' > "$T/bin/sleep"
chmod +x "$T/bin/osascript" "$T/bin/sleep"
printf 'set -u\n. "$1"\neval "$2"\n' > "$T/harness.sh"
drive() {   # <pieces> <shell text> [NAME=value ...]: the text runs after the pieces; output in $T/out, calls in $T/osa and $T/sleeps
  local pc="$1" code="$2"; shift 2
  : > "$T/osa"; : > "$T/sleeps"
  env -u CS2_QUIET -u CS2_PANEL -u SM_QUIET -u SM_PANEL "$@" PATH="$T/bin:$PATH" OSA_CALLS="$T/osa" SLEEP_CALLS="$T/sleeps" \
    /bin/bash "$T/harness.sh" "$pc" "$code" > "$T/out" 2> "$T/err" < /dev/null
}
posts() { grep -c '^CALL ' "$T/osa"; }
out() { tr '\n' '|' < "$T/out"; }
sources() { awk 'p { print; p = 0 } $0 == "-e" { p = 1 }' "$T/osa"; }   # the AppleScript lines of the recorded calls
compiles() { sources > "$T/src.applescript"; osacompile -o "$T/src.scpt" "$T/src.applescript" > "$T/osacompile.out" 2>&1 && echo yes || echo "no: $(head -1 "$T/osacompile.out")"; }
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
STEP='step 2 "two…"; echo "rc:$?"'; NOTE='note "a warning"; echo "rc:$?"'
TXT='He said "no" and C:\temp\x'

n=0
for g in "${GAMES[@]}"; do
  n=$((n + 1)); f="${g%%|*}"; r="${g#*|}"; P="${r%%|*}"; TITLE="${r#*|}"; B="$T/pieces.$n.sh"; tag="${f##*/}:"

  # --- step and note, as the shim's settings drive them
  drive "$B" "$STEP" "${P}_QUIET=1" "${P}_PANEL=1"; a=$(posts); o=$(out)
  drive "$B" "$NOTE" "${P}_QUIET=1" "${P}_PANEL=1"
  check "$tag quiet with the window up: step posts 0, note posts 1" "$a:$(posts)" "0:1"
  check "$tag   ...the step line reads [n/N] text, the note is plain, both return 0" "$o$(out)" "[2/5] two…|rc:0|a warning|rc:0|"
  check "$tag   ...the note's pop-up carries the text and this game's title, each as one argument" "$(grep -cxF 'a warning' "$T/osa"):$(grep -cxF "$TITLE" "$T/osa")" "1:1"
  drive "$B" "$STEP" "${P}_QUIET=1"; a=$(posts); o=$(out)
  check "$tag   ...and the step's does, when it posts" "$(grep -cxF 'two…' "$T/osa"):$(grep -cxF "$TITLE" "$T/osa")" "1:1"
  drive "$B" "$NOTE" "${P}_QUIET=1"
  check "$tag quiet with no window: step posts 1, note posts 1" "$a:$(posts)" "1:1"
  check "$tag   ...and the log lines are the same as with the window" "$o$(out)" "[2/5] two…|rc:0|a warning|rc:0|"
  drive "$B" "$STEP" "${P}_QUIET=1" "${P}_PANEL=0"
  check "$tag quiet with the window said to be down: step posts 1" "$(posts)" 1
  drive "$B" "$STEP"; a=$(posts); o=$(out)
  drive "$B" "$NOTE"
  check "$tag not quiet: step posts 0, note posts 0, the lines are printed" "$a:$(posts):$o$(out)" "0:0:[2/5] two…|rc:0|a warning|rc:0|"
  drive "$B" "$STEP" "${P}_PANEL=1"; a=$(posts)
  drive "$B" "$NOTE" "${P}_PANEL=1"
  check "$tag not quiet, the window setting given by hand: still nothing posted" "$a:$(posts)" "0:0"

  # --- the text is an argument, never AppleScript source, and the source compiles
  drive "$B" 'note "$TXT"' "${P}_QUIET=1" "TXT=$TXT"
  check "$tag a note holding \" and \\ arrives as one unchanged argument" "$(posts):$(grep -cxF -- "$TXT" "$T/osa"):$(sources | grep -cF 'He said')" "1:1:0"
  check "$tag   ...and the notification's AppleScript compiles" "$(compiles)" yes
  drive "$B" '_alert "$TXT"' "TXT=$TXT"
  check "$tag an alert holding \" and \\ arrives as one unchanged argument, with the title, as critical" "$(posts):$(grep -cxF -- "$TXT" "$T/osa"):$(grep -cxF "$TITLE" "$T/osa"):$(sources | grep -cF 'He said'):$(sources | grep -c ' as critical$')" "1:1:1:0:1"
  check "$tag   ...and the alert's AppleScript compiles" "$(compiles)" yes
  drive "$B" '_alert "$TXT" warning' "TXT=$TXT"
  check "$tag a warning alert: the same, as warning" "$(posts):$(grep -cxF -- "$TXT" "$T/osa"):$(grep -cxF "$TITLE" "$T/osa"):$(sources | grep -cF 'He said'):$(sources | grep -c ' as warning$')" "1:1:1:0:1"
  check "$tag   ...and it compiles" "$(compiles)" yes

  # --- die: ERROR: in the log, one alert when quiet, exit 1
  drive "$B" 'die "$TXT"; echo "not reached"' "${P}_QUIET=1" "${P}_PANEL=1" "TXT=$TXT"; rc=$?
  check "$tag die when quiet: exit 1, the ERROR: line first, one critical alert holding the text unchanged" "$rc:$(head -1 "$T/out"):$(posts):$(grep -cxF -- "$TXT" "$T/osa"):$(sources | grep -c ' as critical$')" "1:ERROR: $TXT:1:1:1"
  drive "$B" 'die "$TXT"; echo "not reached"' "TXT=$TXT"; rc=$?
  check "$tag die when not quiet: exit 1, the ERROR: line first, no alert" "$rc:$(head -1 "$T/out"):$(posts):$(grep -c 'not reached' "$T/out")" "1:ERROR: $TXT:0:0"

  # --- the licence wait: <step> <the setting as given> <default>
  waitcase() {   # <name> <setting> <sleeps wanted> <seconds in the step lines wanted> <seconds in the plain line wanted>
    drive "$B" 'licence_wait 3 "$V" 45; echo "rc:$?"' "V=$2"
    check "$tag licence wait, $1" \
      "sleeps: $(tr '\n' ' ' < "$T/sleeps")| steps: $(sed -n 's/^\[3\/5\] Steam is confirming the game licence, about \([0-9]*\) seconds left…$/\1/p' "$T/out" | tr '\n' ' ')| $(grep '^Licence wait: ' "$T/out" | tr '\n' '|') $(tail -1 "$T/out") stderr: $(wc -c < "$T/err" | tr -d ' ')" \
      "sleeps: $3| steps: $4| Licence wait: $5 s| rc:0 stderr: 0"
  }
  waitcase "nothing set: the default, in three parts" ""      "15 15 15 " "45 30 15 " 45
  waitcase "20: 15 then the remainder"                20      "15 5 "     "20 5 "     20
  waitcase "15: one part"                             15      "15 "       "15 "       15
  waitcase "0: the plain line, no step, no sleep"     0       ""          ""          0
  waitcase "08 is 8, not an octal error"              08      "8 "        "8 "        8
  waitcase "100: three digits are taken"              100     "15 15 15 15 15 15 10 " "100 85 70 55 40 25 10 " 100
  waitcase "abc: the default"                         abc     "15 15 15 " "45 30 15 " 45
  waitcase "-5: the default"                          -5      "15 15 15 " "45 30 15 " 45
  waitcase "9999: the default"                        9999    "15 15 15 " "45 30 15 " 45
  waitcase "99999: the default"                       99999   "15 15 15 " "45 30 15 " 45
  drive "$B" 'licence_wait 3 "" 45' "${P}_QUIET=1"; a=$(posts)
  drive "$B" 'licence_wait 3 "" 45' "${P}_QUIET=1" "${P}_PANEL=1"
  check "$tag licence wait: its countdown lines are steps (3 pop-ups with no window, 0 with it)" "$a:$(posts)" "3:0"
done

echo "$fails failure(s)"
[ "$fails" = 0 ]
