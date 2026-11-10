#!/bin/bash
# test-mac-inventory.sh -- mac-inventory.sh looks into folders it did not create, so it must start no program
# that a checkout names. This builds a throwaway home folder of booby-trapped checkouts, each with a remote
# address that looks like the project's, runs the script with HOME pointed at it, and fails if a planted
# program ran, if a trapped checkout was examined, or if the one honest checkout was not. Then it runs plain
# git in every trapped checkout and requires each trap to fire, so that no case passes for want of a live trap.
#   bash common/test-mac-inventory.sh            exit 0 = every case passed
#   MUTANT=1 bash common/test-mac-inventory.sh   every key counts as plain; must exit 1
#   MUTANT=2 ...                                 an include may name any file; must exit 1
#   MUTANT=3 ...                                 a commondir file is not noticed; must exit 1
#   MUTANT=4 ...                                 git status looks into nested repositories; must exit 1
#   MUTANT=5 ...                                 a credential helper is asked for the push identity; must exit 1
# No game, no Steam, no Wine, no Intel program. Everything it writes is under one folder in /tmp.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$HERE/common/mac-inventory.sh"
[ -f "$SCRIPT" ] || { echo "REFUSED: $SCRIPT not found"; exit 2; }
T="$(mktemp -d /tmp/mac-inventory-test.XXXX)"
trap 'rm -rf "$T"' EXIT
unset GIT_ASKPASS SSH_ASKPASS GIT_DIR GIT_WORK_TREE GIT_CONFIG_PARAMETERS
export GIT_TERMINAL_PROMPT=0
H="$T/home"; E="$T/elsewhere"; mkdir -p "$H/github" "$H/.gitconfig-dir" "$E"; : > "$H/.zshrc"

# the planted program: it records its label, and passes a file through when it is run as a filter
printf '#!/bin/bash\necho "$1" >> "%s/fired"\n[ "${2:-}" = filter ] && cat\nexit 0\n' "$T" > "$T/trap.sh"; chmod +x "$T/trap.sh"
TRAP="$T/trap.sh"
# git starts an askpass program without a shell, so it has to be one file with no arguments
for w in own elsewhere; do printf '#!/bin/bash\n%s %s-askpass\n' "$TRAP" "$w" > "$T/ask-$w.sh"; chmod +x "$T/ask-$w.sh"; done
g() { HOME="$H" git "$@"; }

# the home folder's own settings: a personal identity, and the project's in its own file. Each clears the
# helper list first, as the real ones do, so no helper of this Mac is ever reached from here.
printf '[user]\n\tname = somebody\n\temail = somebody@example.invalid\n[credential "https://github.com"]\n\thelper =\n\thelper = !%s home-helper-personal\n' "$TRAP" > "$H/.gitconfig"
printf '[user]\n\tname = iosoceans\n\temail = project@example.invalid\n[credential "https://github.com"]\n\thelper =\n\thelper = !%s home-helper-project\n' "$TRAP" > "$H/.gitconfig-cs2"
# settings a checkout might pull in from a place of its own choosing
printf '[core]\n\tfsmonitor = %s elsewhere-fsmonitor\n\taskPass = %s\n[filter "trap"]\n\tclean = %s elsewhere-filter filter\n[credential]\n\thelper = !%s elsewhere-helper\n' "$TRAP" "$T/ask-elsewhere.sh" "$TRAP" "$TRAP" > "$E/evil.cfg"

mk() {   # <name>: a checkout with one commit, a filter attribute, a changed file and the project's address
  d="$H/github/$1"
  g init -q "$d" 2>/dev/null
  printf '* filter=trap\n' > "$d/.gitattributes"; echo one > "$d/file.txt"
  g -C "$d" add -A && g -C "$d" commit -q -m one
  g -C "$d" remote add origin https://github.com/macgameport/1launcher.git
  echo two >> "$d/file.txt"
}
set_own() { g config -f "$H/github/$1/.git/config" "$2" "$3"; }

mk plain;             set_own plain include.path "~/.gitconfig-cs2"
mkdir -p "$H/github/plain/.git/hooks"
for h in fsmonitor-watchman post-index-change pre-commit post-checkout; do
  printf '#!/bin/bash\n%s plain-hook-%s\n' "$TRAP" "$h" > "$H/github/plain/.git/hooks/$h"; chmod +x "$H/github/plain/.git/hooks/$h"
done
mk helper;            set_own helper credential.helper "!$TRAP own-helper"
mk filter;            set_own filter filter.trap.clean "$TRAP own-filter filter"
mk fsmonitor;         set_own fsmonitor core.fsmonitor "$TRAP own-fsmonitor"
mk askpass;           set_own askpass core.askPass "$T/ask-own.sh"
mk uppercase;         printf '[CORE]\n\tFSMONITOR = %s own-uppercase\n' "$TRAP" >> "$H/github/uppercase/.git/config"
mk include-elsewhere; set_own include-elsewhere include.path "$E/evil.cfg"
mk include-climbs;    set_own include-climbs include.path "~/.gitconfig-dir/../../elsewhere/evil.cfg"
mk includeif;         set_own includeif "includeIf.gitdir:/.path" "$E/evil.cfg"
mk worktreeconfig;    set_own worktreeconfig extensions.worktreeConfig true
printf '[core]\n\tfsmonitor = %s own-worktreeconfig\n' "$TRAP" > "$H/github/worktreeconfig/.git/config.worktree"
# its settings live in another folder: the file inside the checkout is a plain decoy
mk commondir; d="$H/github/commondir"
mv "$d/.git" "$E/common"; mkdir "$d/.git"
cp "$E/common/HEAD" "$E/common/index" "$E/common/config" "$d/.git/"; echo "$E/common" > "$d/.git/commondir"
g config -f "$E/common/config" filter.trap.clean "$TRAP commondir-filter filter"
# a second repository inside the checkout, with settings of its own that the outer file says nothing about
mk nested; d="$H/github/nested"
g init -q "$d/sub" 2>/dev/null; printf '* filter=trap\n' > "$d/sub/.gitattributes"; echo one > "$d/sub/file.txt"
g -C "$d/sub" add -A && g -C "$d/sub" commit -q -m one
g -C "$d" add sub 2>/dev/null && g -C "$d" commit -q -m sub
g config -f "$d/sub/.git/config" filter.trap.clean "$TRAP nested-filter filter"; echo two >> "$d/sub/file.txt"
TRAPPED="helper filter fsmonitor askpass uppercase include-elsewhere include-climbs includeif worktreeconfig commondir"

# the script under test, or a mutant of it
RUN="$T/inventory.sh"; cp "$SCRIPT" "$RUN"
case "${MUTANT:-0}" in
  0) ;;
  1) sed -i '' "s/^PLAIN_KEYS=.*/PLAIN_KEYS='.*'/" "$RUN" ;;
  2) sed -i '' "s/printf 'an-include-[a-z-]* '/:/" "$RUN" ;;
  3) sed -i '' '/commondir" ] && printf/d' "$RUN" ;;
  4) sed -i '' 's/ --ignore-submodules=all//g' "$RUN" ;;
  5) awk '{print} /^  src="\$\(G -C "\$d" config --show-origin/ { ins = 1 } ins && /\| t\)"$/ { print "  printf \"protocol=https\\nhost=github.com\\n\\n\" | G -C \"$d\" credential fill >/dev/null 2>&1"; ins = 0 }' "$SCRIPT" > "$RUN" ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac
if [ "${MUTANT:-0}" != 0 ]; then
  cmp -s "$SCRIPT" "$RUN" && { echo "REFUSED: mutant ${MUTANT} changed nothing"; exit 2; }
  /bin/bash -n "$RUN" || { echo "REFUSED: mutant ${MUTANT} does not parse"; exit 2; }
fi

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
block() { awk -v h="~/github/$1" '$0 == h { p = 1; next } p && /^[^ ]/ { exit } p' "$T/out"; }
has() { block "$1" | grep -q -e "$2" && echo yes || echo no; }

HOME="$H" /bin/bash "$RUN" < /dev/null > "$T/out" 2> "$T/err"
check "the script exits 0" "$?" 0
check "it writes nothing to stderr" "$(wc -c < "$T/err" | tr -d ' ')" 0
check "no planted program ran: $(sort -u "$T/fired" 2>/dev/null | tr '\n' ' ')" "$([ -s "$T/fired" ] && echo ran || echo none)" none
check "the output names no absolute home path" "$(grep -c -F "$T" "$T/out")" 0
check "it lists all 12 checkouts" "$(grep -c '^~/github/' "$T/out")" 12
check "plain: examined" "$(has plain '^    HEAD [0-9a-f]\{7,\} on ')" yes
check "plain: its one changed file is counted" "$(has plain ' · 1 changed or untracked · ')" yes
check "plain: commits as the project" "$(has plain 'commits as: project · ')" yes
check "plain: the helper is the project file's alone" "$(has plain 'named in: ~/.gitconfig-cs2 · ')" yes
check "nested: examined, its inner repository left alone" "$(has nested '^    HEAD [0-9a-f]\{7,\} on ')" yes
for c in $TRAPPED; do
  check "$c: not examined" "$(has "$c" 'NOT EXAMINED FURTHER')$(has "$c" '^    HEAD ')" yesno
done
check "helper: the reason names the key" "$(has helper 'plain set: credential.helper $')" yes
check "includeif: the reason prints no path" "$(has includeif 'plain set: includeif.path $')" yes
check "include-elsewhere: the reason" "$(has include-elsewhere 'an-include-outside-the-home-folder')" yes
check "include-climbs: the reason" "$(has include-climbs 'an-include-below-the-home-folder')" yes
check "commondir: the reason" "$(has commondir 'a-commondir-file')" yes

# every trap is live: plain git, run the ordinary way in each checkout, starts the planted program
mv "$T/fired" "$T/fired-by-script" 2>/dev/null; : > "$T/fired"
for c in plain $TRAPPED nested; do
  ( cd "$H/github/$c" && g status --porcelain; printf 'protocol=https\nhost=github.com\n\n' | g credential fill ) > /dev/null 2>&1 < /dev/null
done
for label in home-helper-project home-helper-personal own-helper own-filter own-fsmonitor own-askpass own-uppercase \
             elsewhere-fsmonitor elsewhere-filter elsewhere-askpass elsewhere-helper own-worktreeconfig commondir-filter nested-filter; do
  check "control: plain git does start $label" "$(grep -c -x "$label" "$T/fired" | sed 's/^[1-9][0-9]*$/fires/')" fires
done

echo "$fails failure(s)"
[ "$fails" = 0 ]
