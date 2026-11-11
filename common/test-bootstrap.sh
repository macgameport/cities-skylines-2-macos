#!/bin/bash
# test-bootstrap.sh -- the root install.sh (docs/plans/simple-install.md, 2.4 and NT4), with HOME and TMPDIR
# at scratch folders and a stub curl that serves fixture archives. The fixture's game installer records its
# arguments and what L1_FETCHED_REF it was given. One fixture is cut with git archive from a scratch
# repository, so that it carries its commit in its header as GitHub's archives do. No network.
#   bash common/test-bootstrap.sh            exit 0 = every case passed
#   MUTANT=1 ...  the temporary folder kept; must exit 1
#   MUTANT=2 ...  the installer's exit code dropped; must exit 1
#   MUTANT=3 ...  a ref with .. fetched; must exit 1
#   MUTANT=4 ...  the checkout's case decided by $0; must exit 1
#   MUTANT=5 ...  L1_FETCHED_REF not set; must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
REAL="$REPO/install.sh"
T="$(mktemp -d /tmp/bootstrap-test.XXXX)"
trap 'rm -rf "$T"' EXIT
S="$T/install.sh"; cp "$REAL" "$S"
mutate() {  # <sed expression> <grep that proves it applied>
  sed -i '' "$1" "$S"; grep -q -- "$2" "$S" || { echo "REFUSED: mutant did not apply"; exit 2; }
}
case "${MUTANT:-0}" in
  1) mutate "s#^  trap 'rm -rf \"\$L1_TMP\"' EXIT\$#  :#" '^  :$' ;;
  2) mutate 's#^  bash "\$top/\$game/scripts/install.sh" "\$@"$#  bash "$top/$game/scripts/install.sh" "$@"; true#' 'install.sh" "\$@"; true$' ;;
  3) mutate 's#-\*|/\*|\*\.\.\*|\*//\*)#-*|/*|*//*)#' '^    -\*|/\*|\*//\*)' ;;
  4) mutate 's#^  self="\${BASH_SOURCE\[0\]:-}"$#  self="$0"#' '^  self="\$0"$' ;;
  5) mutate 's#^  export L1_FETCHED_REF="\$ref"$#  :#' '^  :$' ;;
esac

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- fixtures
F="$T/fix"; mkdir -p "$F"
REC='#!/bin/bash
echo "INSTALLER args=$* ref=${L1_FETCHED_REF:-} from=$(basename "$(cd "$(dirname "$0")/../.." && pwd)")" >> "$CALLS"
exit "${STUB_INSTALL_EXIT:-0}"'
G="$T/gitrepo"; mkdir -p "$G/cities-skylines-2/scripts" "$G/other-game"
printf '%s\n' "$REC" > "$G/cities-skylines-2/scripts/install.sh"; : > "$G/other-game/README.md"
( cd "$G" && git init -q . && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -q -m fixture \
  && git archive --format=tar.gz --prefix=1launcher-release/ HEAD > "$F/good.tar.gz" )
COMMIT="$(git -C "$G" rev-parse HEAD)"
mkdir -p "$F/plain/1launcher-x/cities-skylines-2/scripts"; printf '%s\n' "$REC" > "$F/plain/1launcher-x/cities-skylines-2/scripts/install.sh"
( cd "$F/plain" && tar -czf "$F/plain.tar.gz" 1launcher-x )
mkdir -p "$F/two/a/cities-skylines-2/scripts" "$F/two/b"; printf '%s\n' "$REC" > "$F/two/a/cities-skylines-2/scripts/install.sh"
( cd "$F/two" && tar -czf "$F/two.tar.gz" a b )
mkdir -p "$F/link"; ln -s "$F/plain/1launcher-x" "$F/link/1launcher-x"; ( cd "$F/link" && tar -czf "$F/link.tar.gz" 1launcher-x )
echo "not an archive" > "$F/broken.tar.gz"
mkdir -p "$T/bin"
cat > "$T/bin/curl" << 'C'
#!/bin/bash
echo "CURL $*" >> "$CALLS"
[ -n "${STUB_CURL_EXIT:-}" ] && exit "$STUB_CURL_EXIT"
out=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cp "$FIX" "$out"
C
printf '#!/bin/bash\nif [ "$1" = -u ] && [ -n "${STUB_ROOT:-}" ]; then echo 0; else exec /usr/bin/id "$@"; fi\n' > "$T/bin/id"
chmod +x "$T/bin"/*
export CALLS="$T/calls"
TM="$T/tmp"; mkdir -p "$TM" "$T/empty" "$T/home"
left() { ls -A "$TM" | wc -l | tr -d ' '; }
calls() { grep -c -- "$1" "$CALLS"; }
URL='https://github.com/macgameport/1launcher/archive'
# the pasted form: bash -c "<the script's text>" [name [arguments]], from folder $1
pasted() {   # <folder> <fixture> [name and arguments]: output in $T/out; echoes the exit code
  local d="$1" fix="$2"; shift 2; : > "$CALLS"
  ( cd "$d" && env HOME="$T/home" TMPDIR="$TM" PATH="$T/bin:$PATH" FIX="$fix" /bin/bash -c "$(cat "$S")" "$@" > "$T/out" 2>&1 < /dev/null; echo $? )
}
asfile() {   # <script path> <fixture> [arguments]
  local f="$1" fix="$2"; shift 2; : > "$CALLS"
  ( cd "$T/empty" && env HOME="$T/home" TMPDIR="$TM" PATH="$T/bin:$PATH" FIX="$fix" bash "$f" "$@" > "$T/out" 2>&1 < /dev/null; echo $? )
}
said() { grep -c -- "$1" "$T/out"; }

check "the file's last line is the call of main" "$(tail -n 1 "$REAL")" 'main "$@"'

# --- the pasted form always fetches
rc="$(pasted "$T/empty" "$F/good.tar.gz")"
check "pasted, from an empty folder: fetches the release branch, runs its installer, exit 0" \
  "$rc:$(grep -c "^CURL --proto =https --tlsv1.2 -fsSL --retry 2 -o .* $URL/release.tar.gz\$" "$CALLS"):$(grep -c '^INSTALLER args= ref=release from=1launcher-release$' "$CALLS")" "0:1:1"
check "  ...says the commit it fetched" "$(said "^1launcher at commit $COMMIT\$")" 1
check "  ...and leaves no temporary folder" "$(left)" 0
rc="$(STUB_INSTALL_EXIT=7 pasted "$T/empty" "$F/good.tar.gz")"
check "the installer's exit code is this script's" "$rc:$(left)" "7:0"
rc="$(pasted "$T/empty" "$F/good.tar.gz" 1launcher-install cities-skylines-2 simple-install --check --yes)"
check "pasted with a name and arguments: the ref fetched, the options passed on" \
  "$rc:$(calls " $URL/simple-install.tar.gz\$"):$(grep -c '^INSTALLER args=--check --yes ref=simple-install ' "$CALLS")" "0:1:1"
rc="$(pasted "$T/empty" "$F/plain.tar.gz")"
check "an archive with no commit in its header: says so, and goes on" "$rc:$(said '^1launcher: commit not read$'):$(calls '^INSTALLER')" "0:1:1"
CO="$T/checkout"; mkdir -p "$CO/cities-skylines-2/scripts"; cp "$S" "$CO/install.sh"
printf '#!/bin/bash\necho "LOCAL args=$*" >> "$CALLS"\n' > "$CO/cities-skylines-2/scripts/install.sh"
rc="$(pasted "$CO" "$F/good.tar.gz")"
check "pasted from inside a checkout: still fetches, the local installer is not run" "$rc:$(calls '^CURL'):$(calls '^LOCAL'):$(calls '^INSTALLER')" "0:1:0:1"
rc="$(pasted "$CO" "$F/good.tar.gz" install.sh)"
check "  ...even with install.sh as its name word" "$rc:$(calls '^CURL'):$(calls '^LOCAL')" "0:1:0"

# --- as a file in a checkout: nothing fetched
rc="$(asfile "$CO/install.sh" "$F/good.tar.gz")"
check "as a file beside a game folder: curl not called, the checkout's installer run" "$rc:$(calls '^CURL'):$(grep -c '^LOCAL args=$' "$CALLS"):$(said 'Using this checkout')" "0:0:1:1"
rc="$(asfile "$CO/install.sh" "$F/good.tar.gz" cities-skylines-2 some-ref --check)"
check "  ...a ref is ignored there, options passed on" "$rc:$(calls '^CURL'):$(grep -c '^LOCAL args=--check$' "$CALLS")" "0:0:1"
rc="$(asfile "$CO/install.sh" "$F/good.tar.gz" --check)"
check "  ...options alone: the default game, --check passed on" "$rc:$(grep -c '^LOCAL args=--check$' "$CALLS")" "0:1"
rc="$(asfile "$S" "$F/good.tar.gz")"
check "as a file with no game folder beside it: fetches" "$rc:$(calls '^CURL'):$(calls '^INSTALLER')" "0:1:1"

# --- refused with nothing fetched
bad() { check "$1: exit 2, nothing fetched" "$2:$(calls '^CURL')" "2:0"; }
bad "a ref with a space" "$(pasted "$T/empty" "$F/good.tar.gz" x cities-skylines-2 'a b')"
bad "a ref with ;" "$(pasted "$T/empty" "$F/good.tar.gz" x cities-skylines-2 'a;b')"
bad "a ref with .." "$(pasted "$T/empty" "$F/good.tar.gz" x cities-skylines-2 '../../other/repo/archive/main')"
bad "a ref with //" "$(pasted "$T/empty" "$F/good.tar.gz" x cities-skylines-2 'a//b')"
bad "a ref starting /" "$(pasted "$T/empty" "$F/good.tar.gz" x cities-skylines-2 '/etc')"
bad "a game named ../x" "$(pasted "$T/empty" "$F/good.tar.gz" x '../x')"
bad "a game with a capital" "$(pasted "$T/empty" "$F/good.tar.gz" x 'Cities')"
bad "a third leading word" "$(pasted "$T/empty" "$F/good.tar.gz" x cities-skylines-2 release extra)"
rc="$(STUB_ROOT=1 pasted "$T/empty" "$F/good.tar.gz")"
check "run as root: exit 1, nothing fetched" "$rc:$(calls '^CURL')" "1:0"

# --- failures: exit 1 with a line, no folder left, no installer run
failed() { check "$1: exit 1, no installer run, no folder left" "$2:$(calls '^INSTALLER'):$(left)" "1:0:0"; }
failed "the fetch fails" "$(STUB_CURL_EXIT=6 pasted "$T/empty" "$F/good.tar.gz")"; check "  ...says to check the network" "$(said 'Check the network')" 1
failed "GitHub has no such ref" "$(STUB_CURL_EXIT=22 pasted "$T/empty" "$F/good.tar.gz")"; check "  ...points at the guide" "$(said 'blob/main/cities-skylines-2/INSTALL.md')" 1
failed "what came is not an archive" "$(pasted "$T/empty" "$F/broken.tar.gz")"
failed "an archive with two top folders" "$(pasted "$T/empty" "$F/two.tar.gz")"
failed "an archive whose top entry is a link" "$(pasted "$T/empty" "$F/link.tar.gz")"
failed "a game without an installer" "$(pasted "$T/empty" "$F/good.tar.gz" x other-game)"
check "  ...names the games that have one" "$(said '^  cities-skylines-2$')" 1

echo "$fails failure(s)"
[ "$fails" = 0 ]
