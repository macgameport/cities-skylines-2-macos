#!/bin/bash
# mac-inventory.sh -- what this Mac holds of the project, before anything is moved or updated on it.
# Read-only: it changes nothing, starts no Wine, Steam, game or Intel program, and reads no file's contents
# beyond a launcher path and a build number. The output is meant to be pasted somewhere else, so it names no
# account, user or computer: the home folder prints as ~, and an identity prints as "project", "personal" or
# "none". Run it from a checkout, or straight from the remote without touching one:
#   bash common/mac-inventory.sh
#   git fetch origin && git show origin/main:common/mac-inventory.sh | bash
#
# It looks into folders it did not create, so it trusts none of them. A git checkout's own settings can name
# programs for git to run (a credential helper, a filter, a file-system monitor, a hook), and a remote address
# is no proof of whose checkout it is. So:
#   - which folders are checkouts of the project is read from each one's settings FILE, never by running git
#     inside it;
#   - git is run inside a checkout only when that file holds nothing but the plain keys in PLAIN_KEYS below,
#     any file it includes is a .gitconfig file directly in the home folder, and the checkout does not hand
#     its settings to another folder (a commondir file). Anything else is listed by name and not examined
#     further;
#   - even then git is pinned to that one .git folder, so it cannot go looking for another repository further
#     up whose settings were never read, and it runs with monitors and hooks off, no pager, without touching
#     the index, and without looking into repositories nested inside the checkout;
#   - no credential helper is ever run: the script reports which settings file would supply the push
#     credentials, not what they are.
# What git may still start is a program named in YOUR OWN settings (a large-file filter, say), as it would in
# any folder of yours.
set -u
PROJECT_LOGIN="iosoceans"          # the project's public commit identity
t() { sed "s#$HOME#~#g"; }
kind() { case "$1" in "") echo none ;; "$PROJECT_LOGIN") echo project ;; *) echo personal ;; esac; }
sec() { echo; echo "== $1"; }
in_documents() { case "$1" in "$HOME/Documents"/*) echo "YES (apps cannot run scripts there)" ;; *) echo no ;; esac; }
PLAIN_KEYS='^(core\.(repositoryformatversion|filemode|bare|logallrefupdates|ignorecase|precomposeunicode|symlinks)|remote\.[^.]+\.(url|fetch|pushurl)|branch\..+\.(remote|merge|rebase)|user\.(name|email)|pull\.(rebase|ff)|push\.(default|autosetupremote)|include\.path)$'
own() { git config --no-includes -f "$1/.git/config" "${@:2}" 2>/dev/null; }     # reads that one file; runs nothing in the checkout
safe() { LC_ALL=C tr -cd 'A-Za-z0-9._ #/,[]-'; }  # text taken from a checkout's settings, before it is printed
not_plain() {   # <checkout>: prints what in its own settings is outside the plain set, or nothing
  [ -e "$1/.git/commondir" ] && printf 'a-commondir-file '
  own "$1" --name-only --list >/dev/null || printf 'a-settings-file-git-cannot-read '
  own "$1" --name-only --list | grep -v -i -E "$PLAIN_KEYS" | sed 's/^\([^.]*\)\..*\.\([^.]*\)$/\1.\2/' | sort -u | tr '\n' ' ' | safe
  own "$1" --get-all include.path | while IFS= read -r inc; do
    case "$inc" in "~/.gitconfig"*|"$HOME/.gitconfig"*) inc="${inc#\~/}"; inc="${inc#$HOME/}"
                     case "$inc" in */*) printf 'an-include-below-the-home-folder ' ;; esac ;;
                   *) printf 'an-include-outside-the-home-folder ' ;; esac
  done
}
G() { git --no-pager --no-optional-locks -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"; }
Gd() { G --git-dir="$d/.git" --work-tree="$d" "$@"; }     # git in checkout $d: that .git folder and no other

sec "this Mac"
echo "macOS $(sw_vers -productVersion 2>/dev/null) · Apple Silicon: $([ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] && echo yes || echo no)"
echo "Rosetta files present: $([ -d /Library/Apple/usr/share/rosetta ] && echo yes || echo no) (not started: this script runs no Intel program)"
echo "python3: $(command -v python3 2>/dev/null | t) $(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null) · /usr/bin/python3: $(/usr/bin/python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "does not run")"
echo "Wine, Steam or game processes running: $(pgrep -fl -i '[w]ine|[s]team' | wc -l | tr -d ' ')"
echo "free disk: $(df -h "$HOME" | awk 'NR==2{print $4}')"

sec "checkouts of the project"
found=0
for g in "$HOME"/*/.git "$HOME"/*/*/.git "$HOME"/*/*/*/.git; do
  [ -f "$g/config" ] || continue
  d="${g%/.git}"
  urls="$(own "$d" --get-regexp '^remote\..*\.url$')"
  case "$urls" in *macgameport/*|*sm-patch.git*) ;; *) continue ;; esac
  found=$((found + 1))
  echo "$d" | t
  echo "$urls" | while read -r key url; do
    name="$(printf '%s' "${key#remote.}" | safe)"; name="${name%.url}"
    case "$url" in
      *macgameport/1launcher*) w="GitHub, current name" ;;
      *macgameport/cities-skylines-2-macos*) w="GitHub, old name (redirects)" ;;
      *macgameport/surviving-mars-relaunched-macos*) w="GitHub, the separate Surviving Mars repo" ;;
      *sm-patch.git*) w="a private git server" ;;
      *) w="other" ;;
    esac
    echo "    remote $name: $w"
  done
  echo "    under ~/Documents: $(in_documents "$d") · layout: $([ -d "$d/cities-skylines-2" ] && echo "one folder per game" || echo "before the restructure") · Surviving Mars folder: $([ -d "$d/surviving-mars-relaunched" ] && echo yes || echo no)"
  echo "    untracked or ignored at old places: $(for f in MODS-GUIDE.md logs .env CLAUDE.local.md .claude; do [ -e "$d/$f" ] && printf '%s ' "$f"; done; ls "$d"/scripts/*.exe >/dev/null 2>&1 && printf 'scripts/*.exe(%s) ' "$(ls "$d"/scripts/*.exe | wc -l | tr -d ' ')"; echo)"
  odd="$(not_plain "$d")"
  if [ -n "$odd" ]; then
    echo "    NOT EXAMINED FURTHER: its own git settings hold more than the plain set: $odd"
    continue
  fi
  if ! Gd rev-parse --git-dir >/dev/null 2>&1; then
    echo "    NOT EXAMINED FURTHER: git does not take its .git folder for a repository"
    continue
  fi
  echo "    HEAD $(Gd rev-parse --short HEAD 2>/dev/null) on $(Gd rev-parse --abbrev-ref HEAD 2>/dev/null) · $(Gd status -sb --ignore-submodules=all 2>/dev/null | head -1 | safe) · $(Gd status --porcelain --ignore-submodules=all 2>/dev/null | wc -l | tr -d ' ') changed or untracked · $(Gd status --porcelain --ignored --ignore-submodules=all 2>/dev/null | grep -c '^!!') ignored"
  an="$(Gd var GIT_AUTHOR_IDENT 2>/dev/null | sed 's/ <.*//')"
  # which settings file would supply the push credentials for GitHub here: a read of settings, no helper is run
  # git reads these in order, and an empty one clears the list so far: what is left is what a push would use
  src="$(Gd config --show-origin --get-regexp '^credential\.(.*\.)?helper$' 2>/dev/null | awk -F'\t' '
    { n = index($2, " "); key = n ? substr($2, 1, n - 1) : $2; val = n ? substr($2, n + 1) : ""
      if (key != "credential.helper" && key != "credential.https://github.com.helper") next
      if (val == "") { out = ""; next }
      o = $1; sub(/^file:/, "", o); if (index(out, o " ") == 0) out = out o " " }
    END { printf "%s", out }' | t)"
  [ -n "$src" ] || src="no settings file "
  echo "    commits as: $(kind "$an") · the GitHub credential helper is named in: $src· repo-local identity include: $([ -n "$(own "$d" --get-all include.path)" ] && echo yes || echo no)"
done
[ "$found" = 0 ] && echo "none found three levels under ~"

sec "identity by folder (the two dotfiles)"
git config --global --get-regexp '^includeif' 2>/dev/null | awk '{print "git includeIf: " $1}' | t
# only the folder patterns themselves: never the rest of a line of the shell profile
echo "gh wrapper patterns: $(grep -o '"\$HOME/github/[A-Za-z0-9_-]*/"\*' "$HOME/.zshrc" 2>/dev/null | sort -u | tr '\n' ' ')"
echo "gh in an interactive shell is: $(zsh -ic 'whence -w gh' </dev/null 2>/dev/null | tail -1)"

sec "apps and wrappers in ~/Applications"
for a in "Cities Skylines II" "CS2 Steam Store" "Surviving Mars Relaunched"; do
  s="$HOME/Applications/$a.app/Contents/MacOS/launch"
  if [ -f "$s" ]; then r="$(sed -n 's/^SCRIPT="\(.*\)"$/\1/p' "$s" | head -1 | t)"
    echo "$a.app: $([ -n "$r" ] && echo "runs $r" || echo "present (it names no launcher script)")$(grep -q 'pull --ff-only' "$s" && echo " · pulls a remote at each launch")"
  else echo "$a.app: absent"; fi
done
for w in CS2dxmt11 CS2dxmt11-pk110 S734M SurvivingMars CS2 CS2child-test; do
  p="$HOME/Applications/$w.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps"
  [ -d "$HOME/Applications/$w.app" ] || continue
  echo "$w.app: Cities: Skylines II $([ -f "$p/common/Cities Skylines II/Cities2.exe" ] && echo "installed, build $(grep -m1 '"buildid"' "$p/appmanifest_949230.acf" 2>/dev/null | tr -dc 0-9)" || echo "not installed") · Surviving Mars $([ -f "$p/common/Project Spark/Mars.exe" ] && echo "installed, build $(grep -m1 '"buildid"' "$p/appmanifest_3215050.acf" 2>/dev/null | tr -dc 0-9)" || echo "not installed")"
done

sec "the Cities: Skylines II install folder"
I="$HOME/cs2-patch"
if [ -e "$I" ]; then
  echo "~/cs2-patch: $([ -L "$I" ] && echo "a symlink" || echo "a folder"), $(ls -A "$I" | wc -l | tr -d ' ') entries · launcher dated $(stat -f '%Sm' -t '%Y-%m-%d' "$I/launch-cs2-dxmt11.sh" 2>/dev/null || echo "absent")"
  echo "    patch scripts: $(ls "$I"/patches/*.py 2>/dev/null | wc -l | tr -d ' ') · library folder patches/_vendor: $([ -d "$I/patches/_vendor" ] && echo yes || echo no) · old Python environment revenv: $([ -d "$I/revenv" ] && echo yes || echo no)"
  B="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2_Data/Managed"
  echo "    mod badge patch: file $([ -f "$I/patch-modconflict-badge.py" ] && echo installed || echo absent) · marker $([ -f "$I/patches/.mod-badges-on" ] && echo yes || echo no) · times it has run here: $(ls "$B"/Game.dll.bak-modconflict-* 2>/dev/null | wc -l | tr -d ' ')"
  echo "    retired fallback launcher still there: $([ -f "$I/launch-cs2.sh" ] && echo yes || echo no) · a folder old-patchers: $([ -d "$I/old-patchers" ] && echo "yes, $(ls "$I/old-patchers" | wc -l | tr -d ' ') files, a file named patch_cohtml_license.py: $([ -f "$I/old-patchers/patch_cohtml_license.py" ] && echo PRESENT || echo absent)" || echo no)"
  echo "    git repos inside it: $(for g in "$I"/*/.git "$I"/*/*/.git "$I"/*/*/*/.git "$I"/*/*/*/*/.git "$I"/*/*/*/*/*/.git; do [ -e "$g" ] && echo x; done | wc -l | tr -d ' ')"
else echo "~/cs2-patch: absent"; fi

sec "Surviving Mars: old home and new places"
S="$HOME/sm-patch"
if [ -d "$S" ]; then
  echo "~/sm-patch: present · $(for d in runs backup engine scratch; do [ -d "$S/$d" ] && printf '%s(%s entries) ' "$d" "$(ls -A "$S/$d" | wc -l | tr -d ' ')"; done)· helper programs: $(ls "$S"/tools/*.exe 2>/dev/null | wc -l | tr -d ' ')"
else echo "~/sm-patch: absent"; fi
for d in "$HOME/Library/Application Support/1launcher" "$HOME/Library/Developer/1launcher"; do
  echo "$(echo "$d" | t): $([ -d "$d" ] && (cd "$d" && find . -maxdepth 2 -mindepth 1 -type d | sed 's#^\./##' | tr '\n' ' ') || echo absent)"
done

sec "other things that name the old places"
echo "scheduled tasks: $(grep -l 'github/cs2\|sm-patch\|cs2-patch' "$HOME"/.claude/scheduled-tasks/*/SKILL.md 2>/dev/null | sed 's#.*/scheduled-tasks/##; s#/SKILL.md##' | tr '\n' ' ')"
echo "launch agents: $(grep -l 'github/cs2\|sm-patch\|cs2-patch' "$HOME"/Library/LaunchAgents/*.plist 2>/dev/null | wc -l | tr -d ' ')"
echo "Claude project folders for old paths: $(ls -d "$HOME"/.claude/projects/*github-cs2 "$HOME"/.claude/projects/*sm-patch 2>/dev/null | wc -l | tr -d ' ')"
