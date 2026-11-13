#!/bin/bash
# test-launcher-parity.sh -- the two launchers are kept the same where they are meant to be, and this file is
# the table of the differences kept on purpose. It reads launch-cs2-dxmt11.sh, launch-relaunched.sh and the
# licence-wait probes as text; the only code it runs is licence_wait from the launch-feedback block, with sleep
# stubbed, to get the line a probe must find. No game, no Steam, no Wine. It fails when:
#   1. the launch-feedback blocks differ by a byte;
#   2. the update-check blocks, with setting names, app ids, titles and folders made equal, differ in a line
#      that is not in the list below, or a line in the list no longer differs (then take it out);
#   3. a number sent to step (by a step call outside the block, or through licence_wait) is outside 0 to STEPS,
#      one of 1 to STEPS is unused, or 0 is used outside acquire_lock;
#   4. a licence_wait call line is not the recorded one, indent included;
#   5. a launcher's note calls are not the recorded list (a start-up milestone must not go back to a pop-up unseen);
#   6. a step or note text is not one plain "…" literal, holds " or \, or a step text is longer than 62
#      characters as written (the window's label; the widths with the numbers filled in are seen live);
#   7. a die does not begin by printing ERROR: and call _alert, osascript is called outside the block anywhere
#      but in the update question, the cloud warning does not go through _alert, or a second note or step is
#      defined outside the block;
#   8. a probe's test for the `Licence wait:` line does not find the line the block prints.
# The lock functions are compared in common/test-launch-lock.sh.
#   bash common/test-launcher-parity.sh            exit 0 = every rule holds; exit 2 = a file is missing
#   MUTANT=1 ...    one byte changed in one copy of the launch-feedback block; must exit 1
#   MUTANT=2 ...    a new differing line in one update-check block; must exit 1
#   MUTANT=3 ...    a listed difference made equal; must exit 1
#   MUTANT=4 ...    a step numbered past STEPS; must exit 1
#   MUTANT=5 ...    a step number left unused; must exit 1
#   MUTANT=6 ...    a licence wait call line changed (another default); must exit 1
#   MUTANT=7 ...    a start-up milestone put back to note; must exit 1
#   MUTANT=8 ...    a quote added to a step text; must exit 1
#   MUTANT=9 ...    a probe's pattern changed; must exit 1
#   MUTANT=10 ...   the licence wait made unconditional (every warm start would wait); must exit 1
#   MUTANT=11 ...   a die that prints no ERROR:; must exit 1
#   MUTANT=12 ...   a die with its own osascript line; must exit 1
#   MUTANT=13 ...   a second note defined outside the block; must exit 1
#   MUTANT=14 ...   step 0 used outside acquire_lock; must exit 1
#   MUTANT=15 ...   a step text of 63 characters; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/launcher-parity-test.XXXX)"
trap 'rm -rf "$T"' EXIT
CS2="$T/launch-cs2-dxmt11.sh"; SM="$T/launch-relaunched.sh"
CS2PROBE="$T/cs2-licence-wait-probe.sh"; SMPROBE="$T/sm-licence-wait-probe.sh"
take() {   # <path in the repo> <copy>
  [ -f "$HERE/$1" ] || { echo "REFUSED: $1 not found under $HERE"; exit 2; }
  cp "$HERE/$1" "$2"
}
take cities-skylines-2/launchers/launch-cs2-dxmt11.sh "$CS2"
take surviving-mars-relaunched/launch-relaunched.sh "$SM"
take cities-skylines-2/scripts/licence-wait-probe.sh "$CS2PROBE"
take surviving-mars-relaunched/tools/licence-wait-probe.sh "$SMPROBE"
PROBES=("$CS2PROBE" "$SMPROBE")
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
mutate() {   # <file> <sed expression> <fixed text that proves it applied>
  sed -i '' "$2" "$1"; grep -qF -- "$3" "$1" || mutated
}
X63="$(printf 'x%.0s' $(seq 1 62))…"   # a step text of 63 characters
case "${MUTANT:-0}" in
  0) ;;
  1) mutate "$SM" 's/^  echo "\[\$1\/\$STEPS\] \$2"$/  echo "[$1\/$STEPS]  $2"/' '  echo "[$1/$STEPS]  $2"' ;;
  2) mutate "$CS2" 's/^apply_game_update() {$/apply_game_update() {   # changed in one launcher only/' 'changed in one launcher only' ;;
  3) mutate "$SM" 's/^  msg="Steam has a game update waiting (build \$UPD_FROM -> \$UPD_TO)\."$/  msg="Steam has a game update waiting (build $UPD_FROM -> $UPD_TO). Mods follow the newest game version, so the installed build can break them."/' 'so the installed build can break them."' ;;
  4) mutate "$SM" 's/^step 5 "Starting /step 6 "Starting /' 'step 6 "Starting ' ;;
  5) mutate "$CS2" 's/^step 1 "Checking the Mac fixes /step 2 "Checking the Mac fixes /' 'step 2 "Checking the Mac fixes ' ;;
  6) mutate "$CS2" 's/^  licence_wait 3 "\${CS2_LICENCE_WAIT:-}" 15$/  licence_wait 3 "${CS2_LICENCE_WAIT:-}" 30/' '  licence_wait 3 "${CS2_LICENCE_WAIT:-}" 30' ;;
  7) mutate "$CS2" 's/^  step 2 "Steam is already running…"$/  note "Steam is already running…"/' '  note "Steam is already running…"' ;;
  8) mutate "$SM" 's/^  step 1 "Starting Steam and signing in…"$/  step 1 "Starting \\"Steam\\" and signing in…"/' '  step 1 "Starting \"Steam\" and signing in…"' ;;
  9) mutate "$SMPROBE" 's/"^Licence wait: \$2 s/"^Licence Wait: $2 s/' '"^Licence Wait: $2 s' ;;
  10) awk '$0 == "if [ \"$STARTED_STEAM\" = 1 ]; then" { skip = 1; next }
           skip == 1 && /^  licence_wait / { sub(/^  /, ""); print; skip = 2; next }
           skip == 2 { if ($0 == "fi") skip = 0; next }
           { print }' "$CS2" > "$CS2.new" && mv "$CS2.new" "$CS2"
      grep -q '^licence_wait 3 ' "$CS2" && ! grep -q 'STARTED_STEAM" = 1 \]; then' "$CS2" || mutated ;;
  11) sed -i '' 's/^  echo "ERROR: \$1"$/  echo "$1"/' "$SM"; grep -q '^  echo "ERROR: \$1"$' "$SM" && mutated ;;
  12) mutate "$CS2" 's/^    _alert "\$1"$/    osascript -e "display alert \\"Cities: Skylines II\\" message \\"$1\\" as critical" >\/dev\/null 2>\&1/' '    osascript -e "display alert \"Cities: Skylines II\" message \"$1\" as critical" >/dev/null 2>&1' ;;
  13) printf '%s\n' 'note() { echo "$1"; }' >> "$SM"; grep -q '^note() { echo "\$1"; }$' "$SM" || mutated ;;
  14) mutate "$CS2" 's/^step 4 "Checking for a game update…"$/step 0 "Checking for a game update…"/' 'step 0 "Checking for a game update…"' ;;
  15) mutate "$SM" "s/^step 4 \"Checking for a game update…\"\$/step 4 \"$X63\"/" "step 4 \"$X63\"" ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
kept() { grep -v '^#' | LC_ALL=C sort; }   # a recorded list: its lines without the reasons, sorted
block() { sed -n '/^# >>> launch-feedback (/,/^# <<< launch-feedback$/p' "$1"; }   # not the config: its markers begin with the same words
outside() { awk '/^# >>> launch-feedback \(/ { b = 1 } !b { print } /^# <<< launch-feedback$/ { b = 0 }' "$1"; }
# one line per step or note call outside the block and outside comment lines:
#   <step|note> TAB <line number> TAB <the step's number, ? if it is not written out, - for a note> TAB <ok|bad> TAB <text>
# ok = the text is one plain "…" literal holding no " and no \; bad = it is not, and <text> is what was found.
calls() {
  awk '
    function emit(kw,    re, rest, num, ok, lit) {
      re = "(^[ \t]*|&&[ \t]+|[|][|][ \t]+|;[ \t]+|then[ \t]+|else[ \t]+|do[ \t]+|[)][ \t]+)" kw "[ \t]+"
      if (!match($0, re)) return
      rest = substr($0, RSTART + RLENGTH); num = "-"
      if (kw == "step") {
        if (match(rest, /^[0-9]+ /)) { num = substr(rest, 1, RLENGTH - 1); rest = substr(rest, RLENGTH + 1) } else num = "?"
      }
      if (match(rest, /^"[^"\\]*"/) && substr(rest, RLENGTH + 1) ~ /^[ \t]*($|;|#|[|][|]|&&)/) { ok = "ok"; lit = substr(rest, 2, RLENGTH - 2) }
      else { ok = "bad"; lit = rest }
      print kw "\t" NR "\t" num "\t" ok "\t" lit
    }
    /^# >>> launch-feedback \(/ { b = 1 }
    !b && $0 !~ /^[ \t]*#/ { emit("step"); emit("note") }
    /^# <<< launch-feedback$/ { b = 0 }' "$1"
}
chars() { printf '%s' "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }
list() { tr '\n' ' ' | sed 's/ $//'; }

# --- 1. launch-feedback: one text in two files
block "$CS2" > "$T/fb.cs2"; block "$SM" > "$T/fb.sm"
check "1. both launchers hold a launch-feedback block" "$([ -s "$T/fb.cs2" ] && [ -s "$T/fb.sm" ] && echo yes)" yes
check "1. the two copies are the same, byte for byte" "$(cmp -s "$T/fb.cs2" "$T/fb.sm" && echo same || echo differ)" same

# --- 2. update-check: the differences kept on purpose, each with its reason. Lines as `diff` prints them
#        (< Cities: Skylines II, > Surviving Mars) once the names are made equal.
uc() { sed -n '/^# >>> update-check/,/^# <<< update-check/p' "$1" | sed -E 's/CS2_|SM_/X_/g; s/949230|3215050/APPID/g; s/Cities: Skylines II|Surviving Mars: Relaunched/TITLE/g; s/cs2-patch|sm-patch/DIR/g'; }
uc "$CS2" > "$T/uc.cs2"; uc "$SM" > "$T/uc.sm"
check "2. both launchers hold an update-check block" "$([ -s "$T/uc.cs2" ] && [ -s "$T/uc.sm" ] && echo yes)" yes
diff "$T/uc.cs2" "$T/uc.sm" | grep '^[<>]' | LC_ALL=C sort > "$T/uc.got"
kept > "$T/uc.kept" <<'KEPT'
# each launcher's opening marker names its own test
< # >>> update-check — scripts/test-update-check.sh sources everything between these markers
> # >>> update-check — tools/test-update-check.sh sources everything between these markers
# the comment on the validate line. Cities: Skylines II records that its patched DLLs count as mismatches and
# what one update cost (ledger 2026-10-10); Surviving Mars patches no game file
<   # Forwarded to the running Steam. It validates the installed build first — our patched DLLs
<   # count as mismatches, which is expected — then runs the real update. 1.6.0f1 -> 1.6.2f1 was
<   # 5.1 GB and ~6.5 min (ledger 2026-10-10). No `timeout` wrapper: macOS has none, and
<   # `timeout … wine` exits 127 having done nothing.
>   # Forwarded to the running Steam, which validates the installed build and then runs the update.
>   # No `timeout` wrapper: macOS has none, and `timeout … wine` exits 127 having done nothing.
# Surviving Mars can run Steam on another engine than the game's (SM_STEAM_ENGINE), so it reaches Steam through STEAM_WINE
<   "$WINE" "$STEAM" "steam://validate/APPID" >/dev/null 2>&1 & disown
>   "$STEAM_WINE" "$STEAM" "steam://validate/APPID" >/dev/null 2>&1 & disown
# Cities: Skylines II says why an update matters there: mods follow the newest game build
<   msg="Steam has a game update waiting (build $UPD_FROM -> $UPD_TO). Mods follow the newest game version, so the installed build can break them."
>   msg="Steam has a game update waiting (build $UPD_FROM -> $UPD_TO)."
# the question's wording: "takes several minutes" was measured there (6.5 min), "can take" was not
<         btn=$(osascript -e "button returned of (display dialog \"$msg Updating takes several minutes.\" buttons {\"Play anyway\", \"Update first\"} default button \"Update first\" with title \"TITLE\" giving up after $UPDATE_ASK_SECS)" 2>/dev/null)
>         btn=$(osascript -e "button returned of (display dialog \"$msg Updating can take several minutes.\" buttons {\"Play anyway\", \"Update first\"} default button \"Update first\" with title \"TITLE\" giving up after $UPDATE_ASK_SECS)" 2>/dev/null)
# only Cities: Skylines II patches game files, so only it applies them again after an update
<   ensure_patches || note "WARNING: some fixes did not apply to the new game build — see INSTALL.md 'After a game update'."
KEPT
check "2. the list of kept differences holds 15 lines" "$(wc -l < "$T/uc.kept" | tr -d ' ')" 15
check "2. the update-check blocks differ in no line outside the list" "$(LC_ALL=C comm -23 "$T/uc.got" "$T/uc.kept")" ""
check "2. every line in the list still differs" "$(LC_ALL=C comm -13 "$T/uc.got" "$T/uc.kept")" ""

# --- 3. to 7. per launcher. What is recorded for each:
#   the licence_wait call line, with its indent (two spaces: inside the `if` that skips the wait when Steam
#   was already running, and inside the branch that started Steam), and the measurement behind its default:
#     15 (Cities: Skylines II): 6 of 6 boots at 0 s on the Studio and 5 of 5 at 15 s on the MacBook, 2026-11-10
#         (cities-skylines-2/scripts/licence-wait-probe.sh; docs/plans/launch-experience.md, 3.6). It was 45, a
#         margin with no run count (cities-skylines-2/GOTCHAS.md, section 11).
#     15 (Surviving Mars): 10 of 10 clean runs on the Studio, 2026-11-08 (surviving-mars-relaunched/tools/licence-wait-probe.sh).
#   the note calls: everything that stays a pop-up while the progress window is up, each with what it is.
WAIT_CS2='  licence_wait 3 "${CS2_LICENCE_WAIT:-}" 15'
WAIT_SM='  licence_wait 2 "${SM_LICENCE_WAIT:-}" 15'
kept > "$T/notes.cs2" <<'KEPT'
# the compat note: this macOS release is outside what has been run, said once per release
This Mac runs macOS $_osv, which this has not been tested on. See the README's Compatibility section.
# a patch failed (the text is asserted by scripts/test-launcher-notes.sh and quoted in the install guide)
Some patches could not be applied. Update and run setup: INSTALL.md, After a game update.
# the update that was declined, or that nobody was there to answer
WARNING: game update waiting (build $UPD_FROM -> $UPD_TO) — launching the installed build. CS2_UPDATE=apply takes it.
# a patch failed on the build an update just brought
WARNING: some fixes did not apply to the new game build — see INSTALL.md 'After a game update'.
# the closing line: the only sign that Steam is down on this Mac, for a player with two
Cities: Skylines II closed.
KEPT
kept > "$T/notes.sm" <<'KEPT'
# the two cloud warnings at sign-in: the game starts, with this Mac's saves
Steam Cloud could not sync at sign-in (Steam's logs/cloud_log.txt says why); playing with this Mac's saves.
Steam Cloud: no sign-in sync logged; playing with this Mac's saves.
# the update that was declined, or that nobody was there to answer
WARNING: game update waiting (build $UPD_FROM -> $UPD_TO) — launching the installed build. SM_UPDATE=apply takes it.
# the click helper is missing: it is part of the install
The click helper (tools/frame-fix.exe) is missing, so this install is damaged: open the installer again. If clicks miss meanwhile, press Option+Return twice.
# the closing line: the only sign that Steam is down on this Mac, for a player with two
Surviving Mars: Relaunched closed.
KEPT
for g in "CS2|$CS2|$WAIT_CS2|$T/notes.cs2" "SM|$SM|$WAIT_SM|$T/notes.sm"; do
  r="${g#*|}"; L="${r%%|*}"; r="${r#*|}"; WAIT="${r%%|*}"; NOTES="${r#*|}"; tag="${L##*/}"
  calls "$L" > "$T/calls"
  n="$(sed -n 's/^STEPS=\([0-9][0-9]*\)$/\1/p' "$L")"

  # 4. the licence wait call
  outside "$L" | grep -v '^[[:space:]]*#' | grep 'licence_wait ' > "$T/wait"
  check "4. $tag calls licence_wait once, on the recorded line" "$(wc -l < "$T/wait" | tr -d ' '):$(cat "$T/wait")" "1:$WAIT"
  wn="$(sed -n 's/^ *licence_wait \([0-9][0-9]*\) .*/\1/p' "$T/wait")"

  # 3. step numbers
  check "3. $tag sets STEPS once" "$(echo "$n" | grep -c '^[0-9][0-9]*$')" 1
  check "3. $tag: every step call outside the block writes its number out" "$(awk -F'\t' '$1 == "step" && $3 == "?"' "$T/calls" | wc -l | tr -d ' ')" 0
  { awk -F'\t' '$1 == "step" { print $3 }' "$T/calls"; echo "$wn"; } | grep -v '^0$' | sort -n | uniq | list > "$T/used"
  check "3. $tag uses every step from 1 to STEPS and none above" "$(cat "$T/used")" "$(seq 1 "${n:-0}" | list)"
  lock="$(awk '/^acquire_lock\(\) \{/ { a = NR } a && !z && /^\}/ { z = NR } END { print a + 0 "-" z + 0 }' "$L")"
  check "3. $tag uses step 0, and only inside acquire_lock" \
    "$(awk -F'\t' -v a="${lock%-*}" -v z="${lock#*-}" '$1 == "step" && $3 == 0 { n++; if ($2 > a && $2 < z) in_lock++ } END { print n + 0 ":" in_lock + 0 }' "$T/calls")" "1:1"

  # 5. what stays a pop-up
  awk -F'\t' '$1 == "note" { print $5 }' "$T/calls" | LC_ALL=C sort > "$T/notes.got"
  check "5. $tag: no note call that is not in the list" "$(LC_ALL=C comm -23 "$T/notes.got" "$NOTES")" ""
  check "5. $tag: every note in the list is still called" "$(LC_ALL=C comm -13 "$T/notes.got" "$NOTES")" ""

  # 6. the texts. The countdown line inside the block is a step text too, and the widest.
  check "6. $tag: every step and note text is one plain literal with no \" and no \\" "$(awk -F'\t' '$4 == "bad" { print $1 " at line " $2 ": " $5 }' "$T/calls")" ""
  cd_text="$(block "$L" | sed -n 's/^    step "\$1" "\([^"\\]*\)"$/\1/p')"
  check "6. $tag: the countdown text in the block is one plain literal" "$(printf '%s\n' "$cd_text" | grep -c .)" 1
  long=""
  while IFS= read -r t; do [ "$(chars "$t")" -le 62 ] || long="$long[$(chars "$t"): $t]"; done <<EOF
$(awk -F'\t' '$1 == "step" && $4 == "ok" { print $5 }' "$T/calls")
$cd_text
EOF
  check "6. $tag: no step text is longer than 62 characters as written" "$long" ""

  # 7. failures and pop-ups go through the block
  sed -n '/^die() {/,/^}/p' "$L" > "$T/die"
  check "7. $tag: die begins by printing ERROR:, calls _alert, and has no osascript of its own" \
    "$(sed -n 2p "$T/die"):$(grep -c '_alert "\$1"' "$T/die"):$(grep -c osascript "$T/die")" '  echo "ERROR: $1":1:0'
  outside "$L" | grep -v '^[[:space:]]*#' | grep osascript > "$T/osa"
  check "7. $tag calls osascript outside the block once, in the update question" "$(wc -l < "$T/osa" | tr -d ' '):$(grep -c 'button returned of (display dialog ' "$T/osa")" "1:1"
  check "7. $tag defines note and step once each, inside the block" \
    "$(grep -cE '^[[:space:]]*(function[[:space:]]+)?(note|step)[[:space:]]*\(\)' "$L"):$(outside "$L" | grep -cE '^[[:space:]]*(function[[:space:]]+)?(note|step)[[:space:]]*\(\)')" "2:0"
done
check "7. launch-relaunched.sh: the cloud warning after the game goes through _alert" "$(grep -c '^  \[ "\$QUIET" = 1 \] && _alert "\$CLOUD_MSG" warning$' "$SM")" 1

# --- 8. each probe finds the plain line the block prints, and only for the seconds it was run with
( QUIET=0; STEPS=5; PANEL=0; TITLE=x; . "$T/fb.cs2"; sleep() { :; }; licence_wait 3 15 45 ) > "$T/wait15.log" 2>&1
check "8. the block prints one plain line for a wait of 15" "$(grep -c '^Licence wait: 15 s$' "$T/wait15.log")" 1
for p in "${PROBES[@]}"; do
  fn="$(grep '^wait_lines() {' "$p")"
  check "8. ${p##*/}: its wait_lines finds that line for 15 and not for 45" \
    "$( [ -n "$fn" ] && { eval "$fn"; echo "$(wait_lines "$T/wait15.log" 15):$(wait_lines "$T/wait15.log" 45)"; } )" "1:0"
done

echo "$fails failure(s)"
[ "$fails" = 0 ]
