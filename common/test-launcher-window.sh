#!/bin/bash
# test-launcher-window.sh -- compiles common/launcher-window.swift (14unch3r's window) and asks its text modes
# about fixture apps made in a scratch folder: which apps are rows, their order and states (--list, --folders),
# the row selected when the window opens (--default), whether a start asks first (--second), what Steam's
# package cache says the account owns (--owned) and the offers made of it (--list --games), and a start
# (--start); the icon's pixels (--icon-at), the grid's layout, text, accessibility and colours (--grid) and what
# keys, clicks and VoiceOver do to it (--act), both on the real views with no window; the SVG (--svg) and the
# Desktop alias (--alias). Every one of those modes returns before any window is made, and the window itself is
# never started here: the program is only ever run with a mode. No game, no Steam, no Wine, no real Steam file, and
# nothing of the preferences domain local.1launcher.window. The only apps started are this test's own fixture
# apps under /tmp (LSUIElement, a shim that appends its process number to a file and sleeps 30 s); they are
# stopped, and taken out of LaunchServices' list, at exit. The packageinfo.vdf files are written here from fixed
# bytes (python3 -I). Plans: docs/plans/launcher-window.md, W1 W2 W3 W7 W9; docs/plans/launcher-window-look.md,
# W13 to W17.
#   bash common/test-launcher-window.sh     exit 0 = every case passed; exit 2 = not a pass: swiftc is missing,
#                                           a mutant did not apply, or open cannot start an app here (over ssh)
#   MUTANT=1 ...    the role test dropped; must exit 1
#   MUTANT=2 ...    a text app id accepted; must exit 1
#   MUTANT=3 ...    a boolean app id accepted; must exit 1
#   MUTANT=4 ...    the title taken from the file name first; must exit 1
#   MUTANT=5 ...    rows ordered by path, not by title; must exit 1
#   MUTANT=6 ...    no size limit on Info.plist; must exit 1
#   MUTANT=7 ...    rows told apart by the path as given, not the resolved one; must exit 1
#   MUTANT=8 ...    a refused kill read as alive; must exit 1
#   MUTANT=9 ...    the manifest test dropped; must exit 1
#   MUTANT=10 ...   absent wins over busy; must exit 1
#   MUTANT=11 ...   a lock target +7 read as 7; must exit 1
#   MUTANT=12 ...   a Steam app read as busy; must exit 1
#   MUTANT=13 ...   the last app id ignored; must exit 1
#   MUTANT=14 ...   a row with the busy row's prefix asked; must exit 1
#   MUTANT=15 ...   the Steam app not asked; must exit 1
#   MUTANT=16 ...   the second busy title given; must exit 1
#   MUTANT=17 ...   open -n always; must exit 1
#   MUTANT=18 ...   open -n never; must exit 1
#   MUTANT=19 ...   exit 0 on a failed open; must exit 1
#   MUTANT=20 ...   the path passed through a shell; must exit 1
#   MUTANT=21 ...   the appids name test dropped; must exit 1
#   MUTANT=22 ...   ids under depotids counted; must exit 1
#   MUTANT=23 ...   a file not read cleanly answered not-owned; must exit 1
#   MUTANT=24 ...   the 8-byte token always read; must exit 1
#   MUTANT=25 ...   no size limit on packageinfo.vdf; must exit 1
#   MUTANT=26 ...   only the first file read; must exit 1
#   MUTANT=27 ...   an offer for a game that has an app; must exit 1
#   MUTANT=28 ...   a guide address not on https://github.com/ accepted; must exit 1
#   MUTANT=29 ...   no time limit on the child that reads the files; must exit 1
#   MUTANT=30 ...   the files read in the list's own process, not a child's; must exit 1
#   MUTANT=31 ...   the mark not stroked in the icon; must exit 1
#   MUTANT=32 ...   the arc ended at 302 degrees, not 238; must exit 1
#   MUTANT=33 ...   the small form's stroke at 0.05; must exit 1
#   MUTANT=34 ...   5 to a row; must exit 1
#   MUTANT=35 ...   the group gap dropped; must exit 1
#   MUTANT=36 ...   the least width dropped; must exit 1
#   MUTANT=37 ...   the button role dropped; must exit 1
#   MUTANT=38 ...   an offer's label without the guide words; must exit 1
#   MUTANT=39 ...   offers not starting a row; must exit 1
#   MUTANT=40 ...   the offers block given the games' left edge; must exit 1
#   MUTANT=41 ...   the first tile selected whatever the last id; must exit 1
#   MUTANT=42 ...   the title allowed 3 lines; must exit 1
#   MUTANT=43 ...   the file name cut at its tail; must exit 1
#   MUTANT=44 ...   an absent game not dim; must exit 1
#   MUTANT=45 ...   the tile's help left as the tooltip; must exit 1
#   MUTANT=46 ...   acceptsFirstMouse true; must exit 1
#   MUTANT=47 ...   the pill the accent colour; must exit 1
#   MUTANT=48 ...   the outline dropped; must exit 1
#   MUTANT=49 ...   the second line at alpha 0.5; must exit 1
#   MUTANT=50 ...   the mark at alpha 0.4; must exit 1
#   MUTANT=51 ...   a start on the press; must exit 1
#   MUTANT=52 ...   the release not compared with the armed tile; must exit 1
#   MUTANT=53 ...   a second click counted; must exit 1
#   MUTANT=54 ...   a reload not disarming; must exit 1
#   MUTANT=55 ...   down moving one tile on; must exit 1
#   MUTANT=56 ...   right wrapping to the first; must exit 1
#   MUTANT=57 ...   Escape dropped; must exit 1
#   MUTANT=58 ...   Space dropped; must exit 1
#   MUTANT=59 ...   Space taken under a sheet; must exit 1
#   MUTANT=60 ...   the press action starting nothing; must exit 1
#   MUTANT=61 ...   blocked not asked; must exit 1
#   MUTANT=62 ...   focus never answered; must exit 1
#   MUTANT=63 ...   a reload selecting the default; must exit 1
#   MUTANT=64 ...   the selection not scrolled into view; must exit 1
#   MUTANT=65 ...   the 1's top at 0.70, not 0.76; must exit 1
#   MUTANT=66 ...   a second line break written at the end; must exit 1
#   MUTANT=67 ...   an existing path overwritten; must exit 1
#   MUTANT=68 ...   a symlink to the app read as have; must exit 1
#   MUTANT=69 ...   an alias to another app read as have; must exit 1
#   MUTANT=70 ...   exit 0 on a failed write; must exit 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/launcher-window.swift"
LAUNCHER="$HERE/../cities-skylines-2/launchers/launch-cs2-dxmt11.sh"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -f "$SRC" ] || { echo "REFUSED: $SRC not found"; exit 2; }
[ -f "$LAUNCHER" ] || { echo "REFUSED: $LAUNCHER not found (W2 copies its acquire_lock)"; exit 2; }
xcrun -f swiftc >/dev/null 2>&1 || { echo "REFUSED: swiftc is missing (install the Xcode Command Line Tools); nothing was tested"; exit 2; }
T="$(mktemp -d /tmp/launcher-window-test.XXXX)"
KEEP=""      # background processes of this test, stopped at exit
STARTED=""   # files the fixture apps append their process numbers to
APPS=""      # fixture apps given to open, by their resolved paths: taken out of LaunchServices' list at exit
cleanup() {
  local f p
  for p in $KEEP; do kill "$p" 2>/dev/null; done
  for f in $STARTED; do [ -f "$f" ] && for p in $(cat "$f"); do kill "$p" 2>/dev/null; done; done
  rm -rf "$T"
  # Unregistered while its bundle was still there, the fixture started last was back in LaunchServices' list
  # within the second, in 4 runs of 4. Deleted first, then unregistered by the path LaunchServices keeps (under
  # /private/tmp), none was left in 6 runs of 6 (2026-11-10).
  if [ -x "$LSREGISTER" ]; then
    printf '%s\n' "$APPS" | while IFS= read -r a; do [ -n "$a" ] && "$LSREGISTER" -u "$a" > /dev/null 2>&1; done
  fi
}
trap cleanup EXIT
cp "$SRC" "$T/w.swift"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
drop() {   # <fixed text>: delete the one source line that holds it
  [ "$(grep -cF -- "$1" "$T/w.swift")" = 1 ] || mutated
  grep -vF -- "$1" "$T/w.swift" > "$T/w.new" && mv "$T/w.new" "$T/w.swift"
}
swap() {   # <fixed text> <new line>: replace the one source line that holds the text, keeping its indent
  [ "$(grep -cF -- "$1" "$T/w.swift")" = 1 ] || mutated
  OLD="$1" NEW="$2" awk 'index($0, ENVIRON["OLD"]) { match($0, /^ */); print substr($0, 1, RLENGTH) ENVIRON["NEW"]; next } { print }' \
    "$T/w.swift" > "$T/w.new" && mv "$T/w.new" "$T/w.swift"
  [ "$(grep -cF -- "$2" "$T/w.swift")" -ge 1 ] || mutated
}
case "${MUTANT:-0}" in
  0) ;;
  1) drop 'guard roleText == "game" || roleText == "steam" else { return nil }' ;;
  2) swap 'guard let n = v as? NSNumber else { return nil }' 'guard let n = (v as? NSNumber) ?? (v as? String).flatMap({ Int($0) }).map({ NSNumber(value: $0) }) else { return nil }' ;;
  3) drop 'if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }' ;;
  4) swap 'let raw = text(d["CFBundleDisplayName"]) ?? text(d["CFBundleName"]) ?? base' 'let raw = base' ;;
  5) drop 'if c != .orderedSame { return c == .orderedAscending }' ;;
  6) swap 'readPlainFile(path + "/Contents/Info.plist", limit: 1_048_576)' 'guard let data = readPlainFile(path + "/Contents/Info.plist", limit: 1 << 40) else { return nil }' ;;
  7) swap 'let key = realPath(path) ?? path' 'let key = path' ;;
  8) swap 'return kill(pid, 0) == 0' 'return kill(pid, 0) == 0 || errno == EPERM' ;;
  9) swap 'return fm.fileExists(atPath: marker) ? .ready : .absent' 'return .ready' ;;
  10) swap 'if r.role == .game, lockHeldByLiveProcess(p) { return .busy }' 'if r.role == .game, fm.fileExists(atPath: marker), lockHeldByLiveProcess(p) { return .busy }' ;;
  11) drop 'guard !t.isEmpty, t.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else { return false }' ;;
  12) swap 'if r.role == .game, lockHeldByLiveProcess(p) { return .busy }' 'if lockHeldByLiveProcess(p) { return .busy }' ;;
  13) drop 'if let id = last, let r = rows.filter' ;;
  14) swap '!samePrefix($0.prefix, chosen.prefix) }' 'let busy = rows.filter { $0.role == .game && $0.state == .busy }' ;;
  15) swap 'guard chosen.role == .game || chosen.role == .steam else { return nil }' 'guard chosen.role == .game else { return nil }' ;;
  16) swap 'return busy.first' 'return busy.last' ;;
  17) swap 'func openArguments(_ target: String, new: Bool) -> [String] { new ? ["-n", target] : [target] }' 'func openArguments(_ target: String, new: Bool) -> [String] { ["-n", target] }' ;;
  18) swap 'func openArguments(_ target: String, new: Bool) -> [String] { new ? ["-n", target] : [target] }' 'func openArguments(_ target: String, new: Bool) -> [String] { [target] }' ;;
  19) swap 'if p.terminationReason == .exit && p.terminationStatus == 0 { return nil }' 'return nil' ;;
  20) swap 'p.arguments = openArguments(target, new: new)' 'p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", "/usr/bin/open " + openArguments(target, new: new).joined(separator: " ")]' ;;
  21) swap 'appids: depth == 1 && name.elementsEqual("appids".utf8), ids: &ids)' 'guard children(depth: depth + 1, appids: depth == 1, ids: &ids) else { return false }' ;;
  22) swap 'appids: depth == 1 && name.elementsEqual("appids".utf8), ids: &ids)' 'guard children(depth: depth + 1, appids: depth == 1 && (name.elementsEqual("appids".utf8) || name.elementsEqual("depotids".utf8)), ids: &ids) else { return false }' ;;
  23) swap 'return clean ? "not-owned" : "unknown"' 'return "not-owned"' ;;
  24) swap 'if token { guard r.skip(8) else { return nil } }' 'guard r.skip(8) else { return nil }' ;;
  25) swap 'readPlainFile(file, limit: 16_777_216)' 'guard let data = readPlainFile(file, limit: 1 << 40), let ids = ownedIDs(data) else { continue }' ;;
  26) swap 'for file in files {' 'for file in files.prefix(1) {' ;;
  27) drop 'guard !have.contains(g.id) else { continue }' ;;
  28) drop 'guard g.address.hasPrefix("https://github.com/") else { continue }' ;;
  29) swap 'let deadline = Date().addingTimeInterval(limit)' 'let deadline = Date.distantFuture' ;;
  30) swap 'guard let out = runChild(helper, ["--owned", String(id)] + files, limit: 5) else { return "unknown" }' 'let out = ownership(of: id, in: files)' ;;
  31) drop 'markPath(in: small ? smallBox : iconBox, stroke:' ;;
  32) swap 'static let to = 238.0' 'static let to = 302.0' ;;
  33) swap 'static let smallStroke = 0.085' 'static let smallStroke = 0.05' ;;
  34) swap 'static let perRow = 4' 'static let perRow = 5' ;;
  35) swap 'if i > 0 { x += r.role == .steam' 'if i > 0 { x += Look.gap }' ;;
  36) swap 'let width = max(widest + 2 * Look.margin, Look.least)' 'let width = widest + 2 * Look.margin' ;;
  37) drop 'setAccessibilityRole(.button)' ;;
  38) swap 'opens the set-up guide in your browser' 'if r.role == .offer { return "\(r.title), not set up on this Mac" }' ;;
  39) swap 'for (bi, group) in [apps, offers].enumerated() {' 'for (bi, group) in [apps + offers].enumerated() {' ;;
  40) swap 'let blockW = block.map { $0.w }.max() ?? 0' 'let blockW = blocks[0].map { $0.w }.max() ?? 0' ;;
  41) swap 'let pick = tiles.firstIndex { $0.row.key == keep }' 'let pick: Int? = tiles.isEmpty ? nil : 0' ;;
  42) swap 'static let titleLines = 2' 'static let titleLines = 3' ;;
  43) swap 'cut((r.path as NSString).lastPathComponent, Look.titleFont, .middle)]' 'cut((r.path as NSString).lastPathComponent, Look.titleFont, .end)]' ;;
  44) swap 'func dim(_ r: Row) -> Bool { r.role == .offer || r.state == .absent }' 'func dim(_ r: Row) -> Bool { r.role == .offer || (r.state == .absent && r.role == .steam) }' ;;
  45) drop 'override func accessibilityHelp() -> String? { nil }' ;;
  46) swap 'override func acceptsFirstMouse(for e: NSEvent?) -> Bool { false }' 'override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }' ;;
  47) swap 'static let pill = NSColor(srgbRed' 'static let pill = NSColor.controlAccentColor' ;;
  48) swap 'static let outlineWidth: CGFloat = 1.5' 'static let outlineWidth: CGFloat = 0' ;;
  49) swap 'static let secondAlpha: CGFloat = 0.88' 'static let secondAlpha: CGFloat = 0.5' ;;
  50) swap 'static let markAlpha: CGFloat = 0.075' 'static let markAlpha: CGFloat = 0.4' ;;
  51) swap 'static let startOnPress = false' 'static let startOnPress = true' ;;
  52) swap 'guard unblocked(), clicks == 1, let i = tile(at: p), tiles[i].row.key == armed else { return nil }' 'guard unblocked(), clicks == 1, let i = tile(at: p) else { return nil }' ;;
  53) swap 'guard unblocked(), clicks == 1, let i = tile(at: p), tiles[i].row.key == armed else { return nil }' 'guard unblocked(), let i = tile(at: p), tiles[i].row.key == armed else { return nil }' ;;
  54) drop 'armed = nil   // a reload disarms' ;;
  55) swap 'let next = tiles.indices.filter { tiles[$0].cell.0 == from.cell.0 + d }' 'let next = [min(i + d, tiles.count - 1)].filter { $0 >= 0 }' ;;
  56) swap 'select(max(0, min(i + (code == 124 ? 1 : -1), tiles.count - 1)))' 'select((i + (code == 124 ? 1 : -1) + tiles.count) % tiles.count)' ;;
  57) drop 'case 53: return sheetUp ? .endSheet : .quit' ;;
  58) drop 'case 49: return sheetUp ? .pass : .start' ;;
  59) swap 'case 49: return sheetUp ? .pass : .start' 'case 49: return .start' ;;
  60) drop 'onStart(t.row)   // the press action starts the tile' ;;
  61) swap 'func unblocked() -> Bool { !blocked() }' 'func unblocked() -> Bool { true }' ;;
  62) drop 'override func isAccessibilityFocused() -> Bool { selected }' ;;
  63) swap 'let keep = chosen?.key' 'let keep: String? = nil' ;;
  64) swap 'offset = scrollOffset(for: tiles[i].frame, from: before, shown: shown)' 'offset = before' ;;
  65) swap 'static let one: [(Double, Double)]' 'static let one: [(Double, Double)] = [(0.30, 0.605), (0.455, 0.70), (0.455, 0.08)]' ;;
  66) swap '</svg>' '</svg>\n' ;;
  67) swap 'guard rest.count == 3, state == "none" else { print(state); exit(0) }' 'guard rest.count == 3 else { print(state); exit(0) }' ;;
  68) swap 'guard (st.st_mode & S_IFMT) == S_IFREG else { return "other" }' 'guard (st.st_mode & S_IFMT) != S_IFDIR else { return "other" }' ;;
  69) swap 'return a == b ? "have" : "other"' 'return "have"' ;;
  70) swap 'if let why = makeAlias(app, path) { print("failed\t\(why)"); exit(1) }' 'if let why = makeAlias(app, path) { print("failed\t\(why)"); exit(0) }' ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac
P="$T/launcher-window"
if ! xcrun swiftc -O -o "$P" "$T/w.swift" > "$T/swiftc.out" 2>&1; then
  [ "${MUTANT:-0}" = 0 ] || { echo "REFUSED: mutant ${MUTANT} does not compile"; sed 's/^/    /' "$T/swiftc.out"; exit 2; }
  echo "FAIL  the window does not compile:"; sed 's/^/    /' "$T/swiftc.out"; exit 1
fi
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
TAB="$(printf '\t')"

# --- fixtures: an Info.plist from its keys, apps as the builders write them, fake Wine prefixes
plist() {   # <app> <dict body>: an XML Info.plist
  mkdir -p "$1/Contents"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict>%s</dict></plist>\n' "$2" > "$1/Contents/Info.plist"
}
k() { printf '<key>%s</key>%s' "$1" "$2"; }
s() { printf '<string>%s</string>' "$1"; }
n() { printf '<integer>%s</integer>' "$1"; }
game() {    # <app> <title> <app id> [<prefix>]
  plist "$1" "$(k L1Role "$(s game)")$(k L1SteamAppID "$(n "$3")")$(k CFBundleName "$(s "$2")")${4:+$(k L1Prefix "$(s "$4")")}"
}
steamapp() {   # <app> <title> [<prefix>]
  plist "$1" "$(k L1Role "$(s steam)")$(k CFBundleName "$(s "$2")")${3:+$(k L1Prefix "$(s "$3")")}"
}
prefix() {  # <name>: makes a fake Wine prefix and prints its path
  mkdir -p "$T/px/$1/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps"
  printf '%s' "$T/px/$1/Contents/SharedSupport/prefix"
}
manifest() { : > "$1/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_$2.acf"; }
steamexe() { : > "$1/drive_c/Program Files (x86)/Steam/steam.exe"; }
list() { "$P" --list "$@" 2>&1; }
state() { "$P" --list "$1" 2>&1 | cut -f3; }
line() { printf '%s\t%s\t%s\t%s\t%s' "$@"; }

# --- W1: which apps are rows, their titles and order; the folders
F="$T/w1"
game "$F/one/Game.app" Cities 949230
check "a game app is listed with its id, title and path" "$(list "$F/one")" "$(line game 949230 unknown Cities "$F/one/Game.app")"
nolist() { check "not listed: $1" "$(list "$2")" ""; }
plist "$F/norole/X.app" "$(k L1SteamAppID "$(n 949230)")$(k CFBundleName "$(s X)")"
nolist "no L1Role" "$F/norole"
plist "$F/otherrole/X.app" "$(k L1Role "$(s wrapper)")$(k L1SteamAppID "$(n 949230)")$(k CFBundleName "$(s X)")"
nolist "another role" "$F/otherrole"
plist "$F/noid/X.app" "$(k L1Role "$(s game)")$(k CFBundleName "$(s X)")"
nolist "a game with no id" "$F/noid"
for v in 0 -5 2147483648; do
  plist "$F/id$v/X.app" "$(k L1Role "$(s game)")$(k L1SteamAppID "$(n "$v")")"
  nolist "an id of $v" "$F/id$v"
done
plist "$F/idtext/X.app" "$(k L1Role "$(s game)")$(k L1SteamAppID "$(s 949230)")"
nolist "an id that is text" "$F/idtext"
plist "$F/idtrue/X.app" "$(k L1Role "$(s game)")$(k L1SteamAppID '<true/>')"
nolist "an id that is <true/>" "$F/idtrue"
plist "$F/idreal/X.app" "$(k L1Role "$(s game)")$(k L1SteamAppID '<real>949230</real>')"
nolist "an id that is a real" "$F/idreal"
mkdir -p "$F/broken/X.app/Contents"
printf '<?xml version="1.0"?><plist version="1.0"><dict><key>L1Role</key><string>game</string>' > "$F/broken/X.app/Contents/Info.plist"
nolist "a plist that does not parse" "$F/broken"
# a valid game plist padded inside a string to exactly 1,048,576 bytes, and one byte past it
pad() {   # <folder> <total bytes>
  local keys have
  keys="$(k L1Role "$(s game)")$(k L1SteamAppID "$(n 949230)")$(k CFBundleName "$(s Big)")"
  plist "$1/X.app" "$keys$(k Pad "$(s "")")"
  have=$(wc -c < "$1/X.app/Contents/Info.plist" | tr -d ' ')
  plist "$1/X.app" "$keys$(k Pad "$(s "$(head -c $(($2 - have)) /dev/zero | tr '\0' x)")")"
}
pad "$F/max" 1048576
check "a plist of exactly 1,048,576 bytes is listed" "$(wc -c < "$F/max/X.app/Contents/Info.plist" | tr -d ' ') $(list "$F/max" | cut -f4)" "1048576 Big"
pad "$F/over" 1048577
check "a plist of 1,048,577 bytes, otherwise a valid game plist, is not listed" "$(wc -c < "$F/over/X.app/Contents/Info.plist" | tr -d ' ') $(list "$F/over")" "1048577 "
mkdir -p "$F/sym"; ln -s "$F/one/Game.app" "$F/sym/Link.app"
nolist "a symlink named *.app" "$F/sym"
mkdir -p "$F/notdir"; : > "$F/notdir/File.app"
nolist "a plain file named *.app" "$F/notdir"
game "$F/upper/Up.APP" Up 949230
check ".APP is listed" "$(list "$F/upper")" "$(line game 949230 unknown Up "$F/upper/Up.APP")"
game "$F/binary/Bin.app" Binary 949230
plutil -convert binary1 "$F/binary/Bin.app/Contents/Info.plist"
check "a binary plist is listed" "$(head -c 6 "$F/binary/Bin.app/Contents/Info.plist") $(list "$F/binary" | cut -f4)" "bplist Binary"
plist "$F/t1/File Name.app" "$(k L1Role "$(s game)")$(k L1SteamAppID "$(n 1)")$(k CFBundleDisplayName "$(s Shown)")$(k CFBundleName "$(s Bundle)")"
check "the title is the display name first" "$(list "$F/t1" | cut -f4)" "Shown"
plist "$F/t2/File Name.app" "$(k L1Role "$(s game)")$(k L1SteamAppID "$(n 1)")$(k CFBundleDisplayName "$(s "")")$(k CFBundleName "$(s Bundle)")"
check "then the bundle name (an empty display name counts as none)" "$(list "$F/t2" | cut -f4)" "Bundle"
plist "$F/t3/File Name.app" "$(k L1Role "$(s game)")$(k L1SteamAppID "$(n 1)")"
check "then the file name without .app" "$(list "$F/t3" | cut -f4)" "File Name"
game "$F/t4/X.app" "$(printf 'One\tTwo\nThree')" 1
check "a tab or a line break in a title becomes a space" "$(list "$F/t4" | cut -f4)" "One Two Three"
game "$F/twin/x2.app" Twin 1; game "$F/twin/x1.app" Twin 2; game "$F/twin/y.app" twin 3; game "$F/twin/z.app" Other 4
check "apps with one title, in any case, each show their file name" "$(list "$F/twin" | cut -f4 | tr '\n' '|')" "Other|Twin (x1.app)|Twin (x2.app)|twin (y.app)|"
game "$F/order/z1.app" Bravo 1; game "$F/order/a1.app" charlie 2; game "$F/order/m1.app" alpha 3
steamapp "$F/order/b2.app" "Steam B"; steamapp "$F/order/a2.app" "steam a"
check "order: games then Steam apps, each by title without case, not by path" \
  "$(list "$F/order" | cut -f1,4 | tr '\t\n' ':|')" "game:alpha|game:Bravo|game:charlie|steam:steam a|steam:Steam B|"
case "$F" in
  /tmp/*) check "one app reached through /tmp and /private/tmp is one row, kept as first reached" \
            "$(list "$F/one" "/private$F/one")" "$(line game 949230 unknown Cities "$F/one/Game.app")" ;;
  *) check "the scratch folder is under /tmp" "$F" "/tmp/..." ;;
esac
check "a folder given twice is read once" "$(list "$F/one" "$F/one/" | wc -l | tr -d ' ')" 1
pre=$(prefix w1)
manifest "$pre" 1
game "$F/rel/X.app" Rel 1 "drive_c/../Contents/SharedSupport/prefix"
check "a relative L1Prefix counts as none: unknown" "$(state "$F/rel")" unknown
mkdir -p "$T/px/w1/Contents/SharedSupport/prefix-old"
game "$F/old/X.app" Old 1 "$T/px/w1/Contents/SharedSupport/prefix-old"
check "an L1Prefix not ending in the prefix segment counts as none: unknown" "$(state "$F/old")" unknown
game "$F/slash/X.app" Slash 1 "$pre/"
check "an L1Prefix with a trailing slash counts as none: unknown" "$(state "$F/slash")" unknown
check "--folders, run bare with HOME set: that folder's Applications and nothing else" \
  "$(HOME="$T/home" "$P" --folders 2>&1)" "$T/home/Applications"

# --- W2: states. Paths: <prefix>/.launcher.lock, the game's appmanifest_<id>.acf, the Steam app's steam.exe
S="$T/w2"
sleep 300 & LIVE=$!; disown; KEEP="$KEEP $LIVE"
withlock() {   # <name> <lock target>: a game with a manifest whose lock is a symlink to the target
  local p
  p=$(prefix "w2-$1")
  manifest "$p" 949230
  ln -s "$2" "$p/.launcher.lock"
  game "$S/$1/G.app" G 949230 "$p"
}
withlock live "$LIVE"
check "busy: a lock naming a live process of this user" "$(state "$S/live")" busy
/bin/bash -c 'exit 0' & dead=$!; wait "$dead"
withlock dead "$dead"
check "ready: a lock naming a dead number" "$(state "$S/dead")" ready
withlock one 1
check "ready: a lock naming process 1" "$(state "$S/one")" ready
withlock zero 0
check "ready: a lock naming 0 (kill(0, 0) would ask about this program's own group)" "$(state "$S/zero")" ready
withlock plus "+$LIVE"
check "ready: a lock naming +<a live number> (+7 style: not digits only)" "$(state "$S/plus")" ready
withlock text abc
check "ready: a lock naming text" "$(state "$S/text")" ready
other=$(ps -A -o pid=,uid= | awk -v me="$(id -u)" '$2 != me && $1 > 1 { print $1; exit }')
if [ -n "$other" ] && ! kill -0 "$other" 2>/dev/null; then
  withlock other "$other"
  check "ready: a lock naming another user's live process (kill refused)" "$(state "$S/other")" ready
else
  echo "REFUSED: found no live process of another user to name in a lock"; exit 2
fi
pf=$(prefix w2-file); manifest "$pf" 949230; echo "$LIVE" > "$pf/.launcher.lock"; game "$S/file/G.app" G 949230 "$pf"
check "ready: a lock that is a plain file naming a live process" "$(state "$S/file")" ready
# the launchers' own acquire_lock, copied out as common/test-launch-lock.sh copies it
fn() {
  awk -v f="$1" 'index($0, f "() {") == 1 { print; if ($0 ~ /; }[[:space:]]*$/) exit; p = 1; next }
                 p { print; if ($0 ~ /^}/) exit }' "$2"
}
{
  echo 'LOCK="$1"'
  echo 'note() { :; }; step() { :; }; die() { echo "DIE $1"; exit 1; }; game_running() { return 1; }'
  for f in lock_holder acquire_lock release_lock; do
    fn "$f" "$LAUNCHER" | grep -q . || { echo "REFUSED: $f not found in $LAUNCHER" >&2; exit 2; }
    fn "$f" "$LAUNCHER"
  done
} > "$T/fns.sh" || exit 2
printf '. "$1" "$2"\nacquire_lock "$3" || { echo BUSY; exit 1; }\ntrap release_lock EXIT\necho GOT; sleep "$4"\n' > "$T/launcher.sh"
pa=$(prefix w2-acq); manifest "$pa" 949230; game "$S/acq/G.app" G 949230 "$pa"
/bin/bash "$T/launcher.sh" "$T/fns.sh" "$pa/.launcher.lock" 1 2 > "$T/acq.out" & acq=$!; KEEP="$KEEP $acq"
for _ in $(seq 1 25); do [ -L "$pa/.launcher.lock" ] && break; sleep 0.2; done
check "busy: a lock taken by the launchers' own acquire_lock" "$(state "$S/acq")" busy
wait "$acq"
check "ready once that launcher has exited and released it" "$(cat "$T/acq.out") $(state "$S/acq")" "GOT ready"
pb=$(prefix w2-absent); game "$S/absent/G.app" G 949230 "$pb"
check "absent: a prefix without the manifest" "$(state "$S/absent")" absent
manifest "$pb" 949230
check "ready: the same prefix with the manifest" "$(state "$S/absent")" ready
manifest "$pb" 3215050; rm "$pb/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_949230.acf"
check "absent: a manifest of another game only" "$(state "$S/absent")" absent
game "$S/none/G.app" G 949230
check "unknown: no prefix" "$(state "$S/none")" unknown
pn=$(prefix w2-busyabsent); ln -s "$LIVE" "$pn/.launcher.lock"; game "$S/busyabsent/G.app" G 949230 "$pn"
check "busy: a busy row without a manifest" "$(state "$S/busyabsent")" busy
psm=$(prefix w2-steam); steamapp "$S/steam/S.app" S734M "$psm"
check "a Steam app is absent without steam.exe" "$(list "$S/steam")" "$(line steam - absent S734M "$S/steam/S.app")"
steamexe "$psm"
check "a Steam app is ready with steam.exe" "$(state "$S/steam")" ready
ln -s "$LIVE" "$psm/.launcher.lock"
check "a Steam app is never busy, even with a live lock in its prefix" "$(state "$S/steam")" ready

# --- W3: the row selected when the window opens; whether a start asks first
D="$T/w3"
pa=$(prefix w3-alpha); manifest "$pa" 100; pb=$(prefix w3-beta)
game "$D/one/a.app" Alpha 100 "$pa"; game "$D/one/b.app" Beta 200 "$pb"; steamapp "$D/one/s.app" S734M
check "--default: the last game when listed, even absent" "$(state "$D/one" | tr '\n' ' ')$("$P" --default 200 "$D/one")" "ready absent unknown $D/one/b.app"
ln -s "$LIVE" "$pb/.launcher.lock"
check "--default: the last game when listed, even busy" "$("$P" --default 200 "$D/one" "$D/one")" "$D/one/b.app"
check "--default: the first game when the last is not listed" "$("$P" --default 999 "$D/one")" "$D/one/a.app"
check "--default: the first game when none is recorded" "$("$P" --default - "$D/one")" "$D/one/a.app"
check "--default: a last id that is not a number counts as none" "$("$P" --default 200x "$D/one")" "$D/one/a.app"
game "$D/two/b1.app" Beta 200; game "$D/two/b0.app" Zeta 200; game "$D/two/a.app" Alpha 100
check "--default: with two apps for the last id, the first by path" "$("$P" --default 200 "$D/two")" "$D/two/b0.app"
steamapp "$D/steam/s.app" S734M; steamapp "$D/steam/t.app" "Another Steam"
check "--default: the first Steam app when there is no game" "$("$P" --default 200 "$D/steam")" "$D/steam/t.app"
mkdir -p "$D/empty"
check "--default: nothing with no row" "$("$P" --default 200 "$D/empty"; echo "rc=$?")" "rc=0"
Q="$T/w3q"
p1=$(prefix q-mars); p2=$(prefix q-cities); p3=$(prefix q-steam); p4=$(prefix q-anno)
for f in quiet busy two; do
  game "$Q/$f/mars.app" Mars 3215050 "$p1"; game "$Q/$f/mars copy.app" "Mars copy" 3215050 "$p1"
  game "$Q/$f/cities.app" Cities 949230 "$p2"; steamapp "$Q/$f/s734m.app" S734M "$p3"
done
game "$Q/two/anno.app" Anno 1 "$p4"
check "--second: go when nothing is busy" "$("$P" --second "$Q/quiet/cities.app" "$Q/quiet")" go
ln -s "$LIVE" "$p1/.launcher.lock"; ln -s "$LIVE" "$p4/.launcher.lock"
check "--second: go for the busy row itself" "$("$P" --second "$Q/busy/mars.app" "$Q/busy")" go
check "--second: go for another app with the busy row's prefix" "$("$P" --second "$Q/busy/mars copy.app" "$Q/busy")" go
check "--second: ask, naming the busy game, for a game with another prefix" "$("$P" --second "$Q/busy/cities.app" "$Q/busy")" "ask${TAB}Mars"
check "--second: ask for the Steam app" "$("$P" --second "$Q/busy/s734m.app" "$Q/busy")" "ask${TAB}Mars"
check "--second: with two busy games, the first by title" "$("$P" --second "$Q/two/cities.app" "$Q/two")" "ask${TAB}Anno"
check "--second: the path may be spelled another way" "$("$P" --second "/private$Q/busy/cities.app/" "$Q/busy")" "ask${TAB}Mars"
check "--second: go for a path that is no row" "$("$P" --second "$Q/busy/nothing.app" "$Q/busy")" go
check "--second: go for a folder that is no row" "$("$P" --second "$Q/busy" "$Q/busy")" go

# --- usage: anything else exits 2 before any window
usage() { local name="$1"; shift; "$P" "$@" > "$T/usage.out" 2>&1; check "usage: $name exits 2" "$?" 2; }
usage "--list" --list
usage "--list --games" --list --games
usage "--default <id> and no folder" --default 1
usage "--second <app> and no folder" --second "$Q/busy/mars.app"
usage "--start" --start
usage "--start <app> now" --start "$Q/busy/mars.app" now
usage "--folders <folder>" --folders "$T"
usage "--bogus <folder>" --bogus "$T"
usage "--games <tsv> --list <folder> (a mode after --games)" --games "$T/games.tsv" --list "$T"

# --- W7: --owned, and offers. Every packageinfo.vdf here is written by this test from fixed bytes, in the
# layout of plan section 1; none is read, copied or cut from Steam's own.
V="$T/w7"
mkdir -p "$V/fuzz"
cat > "$T/vdf.py" <<'EOF'
import os, random, struct, sys
out = sys.argv[1]
def node(t, name, v=None):
    head = bytes([t]) + name.encode() + b"\0"
    if t == 0: return head + b"".join(v) + b"\x08"
    if t == 1: return head + v.encode() + b"\0"
    if t == 2: return head + struct.pack("<I", v)
    if t == 7: return head + struct.pack("<Q", v)
    return head + v
def ids(*vals): return [node(2, str(i), v) for i, v in enumerate(vals)]
def package(pid, children, token=True):
    head = struct.pack("<I", pid) + bytes(range(20)) + struct.pack("<I", 7)
    if token: head += struct.pack("<Q", 0x1122334455667788)
    return head + node(0, str(pid), children) + b"\x08"
def vdf(packages, magic=0x06565528, end=True, tail=b""):
    return struct.pack("<II", magic, 1) + b"".join(packages) + (struct.pack("<I", 0xFFFFFFFF) if end else b"") + tail
def write(name, data):
    with open(os.path.join(out, name), "wb") as f: f.write(data)
def owning(token=True, extra=()):
    return [package(1001, [node(2, "packageid", 1001), node(1, "billingtype", "10"), *extra,
                           node(0, "appids", ids(949230, 1111, 2222)), node(0, "depotids", ids(949231)),
                           node(0, "extended", [node(1, "k", "v"), node(7, "big", 1 << 40)])], token),
            package(1002, [node(0, "appids", ids(3215050))], token)]
good = vdf(owning())
write("own28.vdf", good)
write("own27.vdf", vdf(owning(False), magic=0x06565527))
write("depot.vdf", vdf([package(5, [node(0, "appids", ids(4444)), node(0, "depotids", ids(949230))])]))
write("deep.vdf", vdf([package(5, [node(0, "appids", ids(4444)), node(0, "extended", [node(0, "appids", ids(949230))])])]))
write("nopkg.vdf", vdf([]))
write("trunc.vdf", good[: len(good) // 2])
rng = random.Random(1103)
write("noise.vdf", bytes(rng.randrange(256) for _ in range(4096)))
write("magic.vdf", vdf(owning(), magic=0x06565529))
write("magic2.vdf", vdf(owning(), magic=0x07565528))
write("type3.vdf", vdf([package(5, [node(0, "appids", ids(949230)), node(3, "f", b"\0\0\0\0")])]))
def chain(levels):   # nested nodes under a root, the deepest at depth 1 + levels
    n = node(0, "d%d" % (levels + 1), [])
    for d in range(levels, 1, -1): n = node(0, "d%d" % d, [n])
    return n
write("nest8.vdf", vdf([package(5, [node(0, "appids", ids(949230)), chain(7)])]))
write("nest9.vdf", vdf([package(5, [node(0, "appids", ids(949230)), chain(8)])]))
write("noend.vdf", vdf(owning(), end=False))
write("trail.vdf", vdf(owning(), tail=b"\0"))
def padded(total):
    small = len(vdf(owning(extra=[node(1, "pad", "")])))
    return vdf(owning(extra=[node(1, "pad", "x" * (total - small))]))
write("max.vdf", padded(16777216))
write("big.vdf", padded(16777217))
fuzz = random.Random(20261110)
for i in range(200):
    b = bytearray(good)
    at = fuzz.randrange(len(b))
    b[at] = (b[at] + 1 + fuzz.randrange(255)) % 256
    write("fuzz/%03d.vdf" % i, bytes(b))
EOF
python3 -I "$T/vdf.py" "$V" || { echo "REFUSED: the fixture files could not be written"; exit 2; }
owned() { "$P" --owned "$@" 2>&1; }
check "--owned: an id under a root's appids, 0x28 header: owned" "$(owned 949230 "$V/own28.vdf")" owned
check "--owned: the same in the 0x27 header, with no token: owned" "$(owned 949230 "$V/own27.vdf")" owned
check "--owned: an id of the second package: owned" "$(owned 3215050 "$V/own28.vdf")" owned
check "--owned: an id in no package: not-owned" "$(owned 730 "$V/own28.vdf")" not-owned
check "--owned: the number only under depotids: not-owned" "$(owned 949230 "$V/depot.vdf")" not-owned
check "--owned: only under an appids one level deeper: not-owned" "$(owned 949230 "$V/deep.vdf")" not-owned
check "--owned: a valid file with no package: not-owned" "$(owned 949230 "$V/nopkg.vdf")" not-owned
for f in "trunc:a truncated file" "noise:a fixed block of noise" "magic:another magic (low byte 0x29)" \
         "magic2:another magic (0x07565528)" "type3:a node of type 3" "nest9:a nesting of 9" \
         "noend:no end mark" "trail:a byte after the end mark"; do
  check "--owned: unknown for ${f#*:}" "$(owned 949230 "$V/${f%%:*}.vdf")" unknown
done
check "--owned: a nesting of 8 is read" "$(owned 949230 "$V/nest8.vdf")" owned
check "--owned: a file of exactly 16,777,216 bytes is read" "$(wc -c < "$V/max.vdf" | tr -d ' ') $(owned 949230 "$V/max.vdf")" "16777216 owned"
check "--owned: an owning file padded inside a string to 16,777,217 bytes: unknown" "$(wc -c < "$V/big.vdf" | tr -d ' ') $(owned 949230 "$V/big.vdf")" "16777217 unknown"
ln -s "$V/own28.vdf" "$V/link.vdf"
check "--owned: a symlink to a valid file: unknown" "$(owned 949230 "$V/link.vdf")" unknown
check "--owned: no file: unknown" "$(owned 949230 "$V/absent.vdf")" unknown
check "--owned: one bad file and one owning: owned" "$(owned 949230 "$V/trunc.vdf" "$V/own28.vdf")" owned
check "--owned: one bad file and one clean without the id: not-owned" "$(owned 949230 "$V/trunc.vdf" "$V/depot.vdf")" not-owned
odd=0; seen=""
for f in "$V"/fuzz/*.vdf; do
  out="$("$P" --owned 949230 "$f" 2>&1)"; rc=$?
  case "$out $rc" in "owned 0"|"not-owned 0"|"unknown 0") seen="$seen $out" ;; *) odd=$((odd + 1)); echo "      $f: '$out' exit $rc" ;; esac
done
check "--owned: 200 single-byte changes to a valid file, fixed seed: each answer one word, exit 0" "$odd $(ls "$V"/fuzz | wc -l | tr -d ' ')" "0 200"
echo "      (the 200: $(printf '%s\n' $seen | sort | uniq -c | tr -s ' ' | tr '\n' ',' | sed 's/,$//'))"
usage "--owned <id> and no file" --owned 949230
usage "--owned <id that is no number> <file>" --owned 94x "$V/own28.vdf"
# offers: a table of five games; the account owns four of them by the Steam app's packageinfo.vdf
printf '# app id\tfolder\ttitle\tguide\n949230\tcs2\tCities: Skylines II\thttps://github.com/example/1launcher/blob/main/cs2.md\n3215050\tsmr\tSurviving Mars: Relaunched\thttps://github.com/example/1launcher/blob/main/smr.md\n1111\tf\tA File Game\tfile:///etc/hosts\n2222\th\tAn Http Game\thttp://github.com/example/h\n4444\tn\tNot Owned\thttps://github.com/example/n\n' > "$T/games.tsv"
O="$T/w7o"
pso=$(prefix w7-steam); pmo=$(prefix w7-mars); pbad=$(prefix w7-bad)
mkdir -p "$pso/drive_c/Program Files (x86)/Steam/appcache" "$pbad/drive_c/Program Files (x86)/Steam/appcache"
cp "$V/own28.vdf" "$pso/drive_c/Program Files (x86)/Steam/appcache/packageinfo.vdf"
cp "$V/trunc.vdf" "$pbad/drive_c/Program Files (x86)/Steam/appcache/packageinfo.vdf"
steamapp "$O/main/s.app" S734M "$pso"; game "$O/main/mars.app" Mars 3215050 "$pmo"
steamapp "$O/bad/s.app" S734M "$pbad"; game "$O/bad/mars.app" Mars 3215050 "$pmo"
steamapp "$O/noprefix/s.app" S734M
OFFER="$(line offer 949230 owned "Cities: Skylines II" https://github.com/example/1launcher/blob/main/cs2.md)"
check "offers: an owned ported game with no app is an offer line, after the Steam apps; nothing else is offered" \
  "$(list --games "$T/games.tsv" "$O/main")" \
  "$(line game 3215050 absent Mars "$O/main/mars.app")
$(line steam - absent S734M "$O/main/s.app")
$OFFER"
check "offers: none without --games" "$(list "$O/main" | cut -f1 | tr '\n' ' ')" "game steam "
check "offers: none when the only file is not read cleanly (unknown)" "$(list --games "$T/games.tsv" "$O/bad" | cut -f1 | tr '\n' ' ')" "game steam "
check "offers: none when no row has a prefix" "$(list --games "$T/games.tsv" "$O/noprefix" | cut -f1 | tr '\n' ' ')" "steam "
printf '#!/bin/bash\nsleep 8\necho owned\n' > "$T/slow.sh"
printf '#!/bin/bash\nexit 1\n' > "$T/fails.sh"
printf '#!/bin/bash\necho owned\nexit 1\n' > "$T/saysfails.sh"
printf '#!/bin/bash\necho owned\nkill -SEGV $$\n' > "$T/crashes.sh"
chmod +x "$T/slow.sh" "$T/fails.sh" "$T/saysfails.sh" "$T/crashes.sh"
t0=$(date +%s)
out="$(L1_OWNED_HELPER="$T/slow.sh" "$P" --list --games "$T/games.tsv" "$O/main" 2>&1)"
t1=$(date +%s)
check "offers: a helper that sleeps 8 s: the rows within 7 s, and no offer" \
  "$([ $((t1 - t0)) -lt 7 ] && echo in-time || echo "after $((t1 - t0)) s") $(printf '%s\n' "$out" | cut -f1 | tr '\n' ' ')" "in-time game steam "
check "offers: a helper that exits 1 without a word: no offer" \
  "$(L1_OWNED_HELPER="$T/fails.sh" "$P" --list --games "$T/games.tsv" "$O/main" 2>&1 | cut -f1 | tr '\n' ' ')" "game steam "
check "offers: a helper that says owned and exits 1: no offer" \
  "$(L1_OWNED_HELPER="$T/saysfails.sh" "$P" --list --games "$T/games.tsv" "$O/main" 2>&1 | cut -f1 | tr '\n' ' ')" "game steam "
check "offers: a helper that says owned and crashes: no offer" \
  "$(L1_OWNED_HELPER="$T/crashes.sh" "$P" --list --games "$T/games.tsv" "$O/main" 2>&1 | cut -f1 | tr '\n' ' ')" "game steam "
check "offers: L1_OWNED_HELPER naming no program: no offer" \
  "$(L1_OWNED_HELPER="$T/none.sh" "$P" --list --games "$T/games.tsv" "$O/main" 2>&1 | cut -f1 | tr '\n' ' ')" "game steam "

# --- W13: the icon carries the mark, and a small form for 16 and 32 pixels (docs/plans/launcher-window-look.md)
check "--icon-at: ink on the ring, the stems and both flags; body in the opening, between the stems and beside them; clear outside" \
  "$("$P" --icon-at 512,242 243,511 780,511 483,575 540,575 433,395 650,458 512,780 512,575 672,575 64,959 | tr '\n' ' ')" "ink ink ink ink ink ink ink body body body clear "
check "--icon-at small: ink at 512,192, which is body in the full form" "$("$P" --icon-at small 512,192):$("$P" --icon-at 512,192)" "ink:body"

# --- W14: --grid. A tile line: tile, row, column, x, y, role, selected, dim, AX role, label, help, title lines,
# the title as shown, the second line as shown.
grid() { "$P" --grid "$@" 2>&1; }
gsize() { grid "$@" | awk -F'\t' '$1 == "size" { printf "%s by %s", $2, $3 }'; }
origins() { grid "$@" | awk -F'\t' '$1 == "tile" { printf "%s,%s ", $4, $5 }'; }
field() {   # <column> <grid arguments...>: that column of every tile line, one per line
  local c="$1"; shift
  grid "$@" | awk -F'\t' -v c="$c" '$1 == "tile" { print $c }'
}
mkgames() {   # <folder> <games> <Steam apps>
  local i
  for ((i = 1; i <= $2; i++)); do game "$1/g$(printf %02d $i).app" "Game $(printf %02d $i)" $((500 + i)); done
  for ((i = 1; i <= $3; i++)); do steamapp "$1/s$i.app" "Steam $i"; done
}
Gd="$T/w14"; mkdir -p "$Gd/none"
check "grid: an empty folder is 444 by 172, both strings, no tile" "$(gsize - "$Gd/none")|$(grid - "$Gd/none" | grep -c '^tile')|$(grid - "$Gd/none" | grep '^empty')" \
  "444 by 172|0|empty${TAB}No games are set up on this Mac yet.${TAB}https://github.com/macgameport/1launcher/blob/main/README.md"
mkgames "$Gd/1-0" 1 0; mkgames "$Gd/2-1" 2 1; mkgames "$Gd/3-1" 3 1; mkgames "$Gd/4-1" 4 1; mkgames "$Gd/5-1" 5 1; mkgames "$Gd/8-0" 8 0
mkgames "$Gd/7-1" 7 1; mkgames "$Gd/17-0" 17 0
check "grid: 1 game" "$(gsize - "$Gd/1-0") $(origins - "$Gd/1-0")" "444 by 172 162,4 "
check "grid: 2 games and Steam" "$(gsize - "$Gd/2-1") $(origins - "$Gd/2-1")" "444 by 172 24,4 152,4 300,4 "
check "grid: 3 games and Steam" "$(gsize - "$Gd/3-1") $(origins - "$Gd/3-1")" "572 by 172 24,4 152,4 280,4 428,4 "
check "grid: 4 games and Steam" "$(gsize - "$Gd/4-1") $(origins - "$Gd/4-1")" "552 by 326 24,4 152,4 280,4 408,4 24,158 "
check "grid: 5 games and Steam" "$(gsize - "$Gd/5-1") $(origins - "$Gd/5-1")" "552 by 326 24,4 152,4 280,4 408,4 24,158 172,158 "
check "grid: 8 games, two full rows" "$(gsize - "$Gd/8-0")" "552 by 326"
check "grid: 7 games and Steam, the group gap in row 2" "$(gsize - "$Gd/7-1")" "572 by 326"
check "grid: 17 games are 552 by 788, shown 600 high, the last tile at 24,620" \
  "$(gsize - "$Gd/17-0")|$(grid - "$Gd/17-0" | grep '^window')|$(origins - "$Gd/17-0" | awk '{ print $NF }')" "552 by 788|window${TAB}552${TAB}600|24,620"
check "grid: the mark: side, left edge and depth below, at 444 and at 552" \
  "$(grid - "$Gd/2-1" | grep '^mark')|$(grid - "$Gd/4-1" | grep '^mark')" "mark${TAB}333${TAB}55.5${TAB}27|mark${TAB}414${TAB}69${TAB}33"
check "grid: every tile is AXButton with no help; the group is AXGroup Games with its help; the first click activates" \
  "$(field 9 - "$Gd/5-1" | sort -u)|$(field 11 - "$Gd/5-1" | sort -u)|$(grid - "$Gd/5-1" | grep '^group')|$(grid - "$Gd/5-1" | grep '^first-click')" \
  "AXButton|-|group${TAB}AXGroup${TAB}Games${TAB}Click a game, or press Return, to start it.|first-click${TAB}activates"
check "grid: the selected tile is the last game when listed, else the first game" \
  "$(grid 503 "$Gd/5-1" | awk -F'\t' '$7 == "selected" { print $13 }')|$(grid 999 "$Gd/5-1" | awk -F'\t' '$7 == "selected" { print $13 }')" "Game 03|Game 01"
game "$O/two/mars.app" Mars 3215050 "$pmo"; game "$O/two/other.app" Other 777 "$pmo"; steamapp "$O/two/s.app" S734M "$pso"
check "grid: 2 games, Steam, 1 offer: the offer and its label at the offers block's left edge" \
  "$(gsize --games "$T/games.tsv" - "$O/two") $(origins --games "$T/games.tsv" - "$O/two")|$(grid --games "$T/games.tsv" - "$O/two" | grep '^label')" \
  "444 by 346 24,4 152,4 300,4 162,178 |label${TAB}162${TAB}158${TAB}You also own"
check "grid: the offer's label ends with the guide words; it shows the short line and is dim" \
  "$(grid --games "$T/games.tsv" - "$O/two" | awk -F'\t' '$6 == "offer" { print $10 "|" $14 "|" $8 }')" \
  "Cities: Skylines II, not set up on this Mac, opens the set-up guide in your browser|Not set up. Opens its guide.|dim"
check "grid: an absent Steam app shows the short line and is dim; its label holds the full sentence" \
  "$(grid - "$O/two" | awk -F'\t' '$6 == "steam" { print $10 "|" $14 "|" $8 }')" "S734M, Windows Steam not found. Build this app again.|Windows Steam not found|dim"
pga=$(prefix w14-absent); pgr=$(prefix w14-ready); manifest "$pgr" 949230
game "$Gd/inst/absent.app" "Not Here" 3215050 "$pga"; game "$Gd/inst/ready.app" "Here" 949230 "$pgr"
check "grid: a game not installed in Steam shows so and is dim; an installed one is not" \
  "$(grid - "$Gd/inst" | awk -F'\t' '$1 == "tile" { printf "%s|%s|%s|%s ", $13, $14, $8, $10 }')" \
  "Here|-|-|Here Not Here|Not installed in Steam|dim|Not Here, Not installed in Steam. See its set-up guide. "
game "$Gd/same/Surviving Mars Relaunched.app" "Surviving Mars: Relaunched" 3215050
game "$Gd/same/Surviving Mars Relaunched copy.app" "Surviving Mars: Relaunched" 3215051
check "grid: two apps with one title: 2 lines each, line 1 the title, and the two shown titles differ" \
  "$(field 12 - "$Gd/same" | tr '\n' ' ')|$(field 13 - "$Gd/same" | sed 's/ | .*//' | sort -u | wc -l | tr -d ' ')|$(field 13 - "$Gd/same" | sort -u | wc -l | tr -d ' ')" "2 2 |1|2"
game "$Gd/long/long.app" "Surviving Mars: Relaunched Deluxe Edition of the Red Planet" 77
endsdots() {   # <shown title>: whether its second line ends in an ellipsis (a function: bash 3.2 ends $( at a case pattern's paren)
  case "$1" in
    *" | "*…) echo ellipsis ;;
    *) echo none ;;
  esac
}
check "grid: a title that wraps to three lines shows 2, the second ending in an ellipsis" \
  "$(field 12 - "$Gd/long")|$(endsdots "$(field 13 - "$Gd/long")")" "2|ellipsis"
paint() { grid --games "$T/games.tsv" - "$O/two" | awk -F'\t' -v k="$1" '$1 == "paint" && $2 == k { $1 = ""; $2 = ""; sub(/^  /, ""); print }'; }
atleast() { awk -v v="$1" -v m="$2" 'BEGIN { exit !(v != "-" && v + 0 >= m) }' && echo ok || echo "$1"; }
check "grid: paint: the pill is #0059D1 at 6.27; title, second line and label at least 4.5" \
  "$(paint pill)|$(atleast "$(paint title)" 4.5)|$(atleast "$(paint second)" 4.5)|$(atleast "$(paint label)" 4.5)" "#0059D1 6.27|ok|ok|ok"
check "grid: paint: the outline at least 4.5 on the background and 3 on the plate" \
  "$(atleast "$(paint outline | cut -d' ' -f1)" 4.5)|$(atleast "$(paint outline | cut -d' ' -f2)" 3)" "ok|ok"

# --- W15: --act. A step's line: the step, what it did, then focus and offset.
act() { "$P" --act "$@" 2>&1 | awk -F'\t' '{ o = ""; for (i = 2; i <= NF && $i != "focus"; i++) o = o (o == "" ? "" : " ") $i; print o }' | paste -sd'|' -; }
focus() { "$P" --act "$@" 2>&1 | awk -F'\t' '{ for (i = 1; i < NF; i++) if ($i == "focus") print $(i + 1) }' | paste -sd' ' -; }
offset() { "$P" --act "$@" 2>&1 | awk -F'\t' '{ print $NF }' | paste -sd' ' -; }
check "act: right moves on and stays at the last tile; left stays at the first" "$(act right,right,right,right,left,left,left,left - "$Gd/3-1")" \
  "selected Game 02|selected Game 03|selected Steam 1|selected Steam 1|selected Game 03|selected Game 02|selected Game 01|selected Game 01"
check "act: right goes from the end of row 1 to the start of row 2" "$(act right,right,right,right - "$Gd/5-1")" "selected Game 02|selected Game 03|selected Game 04|selected Game 05"
check "act: down goes to the nearest tile of the next row, Steam and not the fifth game, and stays on the last row; up the reverse" \
  "$(act right,right,right,down,down,up,up - "$Gd/5-1")" \
  "selected Game 02|selected Game 03|selected Game 04|selected Steam 1|selected Steam 1|selected Game 02|selected Game 02"
check "act: down goes into the offers row, a start there gives its address, and up goes to the nearest tile above" \
  "$(act down,return,up --games "$T/games.tsv" - "$O/two")" "selected Cities: Skylines II|start https://github.com/example/1launcher/blob/main/cs2.md|selected Other"
check "act: return, enter and space start the selection; escape quits" "$(act right,return,enter,space,escape - "$Gd/3-1")" \
  "selected Game 02|start $Gd/3-1/g02.app|start $Gd/3-1/g02.app|start $Gd/3-1/g02.app|quit"
check "act: under a sheet, escape ends it, and space and return pass to it" "$(act sheet:escape,sheet:space,sheet:return - "$Gd/3-1")" "end-sheet|pass|pass"
check "act: press and release on one tile start it, and it is selected after the press" "$(act press:160:40,release:170:100 - "$Gd/3-1")" "selected Game 02|start $Gd/3-1/g02.app"
check "act: press on one tile and release on another, or in a gap: nothing" "$(act press:160:40,release:30:40,press:160:40,release:146:40 - "$Gd/3-1")" "selected Game 02|nothing|selected Game 02|nothing"
check "act: a second click starts nothing" "$(act press:160:40,release2:160:40 - "$Gd/3-1")" "selected Game 02|nothing"
check "act: a reload between press and release starts nothing" "$(act press:160:40,reload,release:160:40 - "$Gd/3-1")" "selected Game 02|selected Game 02|nothing"
check "act: press and release between two tiles, and in the margin: nothing" "$(act press:146:40,release:146:40,press:10:10,release:10:10 - "$Gd/3-1")" "nothing|nothing|nothing|nothing"
check "act: while blocked, a click, return, right and the press action do nothing; unblocked they act" \
  "$(act block,press:160:40,release:160:40,return,right,axpress:1,unblock,right,return - "$Gd/3-1")" \
  "selected Game 01|nothing|nothing|nothing|nothing|nothing|selected Game 01|selected Game 02|start $Gd/3-1/g02.app"
check "act: axpress:2 starts tile 2" "$(act axpress:2 - "$Gd/3-1")" "start $Gd/3-1/g02.app"
check "act: axfocus:3 selects tile 3, and after every move focus names the selected tile" \
  "$(act axfocus:3 - "$Gd/3-1")|$(focus right,axfocus:3,left,left,down - "$Gd/5-1")" "selected Game 03|2 3 2 1 5"
check "act: a reload keeps the selection on the same app" "$(act right,reload - "$Gd/3-1")" "selected Game 02|selected Game 02"
check "act: with 17 games the grid scrolls to the selected tile and back" "$(offset down,down,down,down,up,up,up,up - "$Gd/17-0")" "0 0 34 188 188 188 154 0"

# --- W16: --svg
REPOROOT="$HERE/.."
"$P" --svg "$T/mark.svg"
check "svg: well formed, equal to docs/images/14unch3r.svg, the path of 2.8, and no text, image, script or link" \
  "$(xmllint --noout "$T/mark.svg" > /dev/null 2>&1; echo $?):$(cmp -s "$T/mark.svg" "$REPOROOT/docs/images/14unch3r.svg" && echo same):$(grep -cF 'd="M654.44 739.96A268.80 268.80 0 1 0 369.56 739.96M384.00 444.80L483.20 345.60L483.20 780.80M540.80 780.80L540.80 345.60L649.60 457.60L540.80 483.20"' "$T/mark.svg"):$(grep -c '<text\|<image\|<script\|href' "$T/mark.svg")" "0:same:1:0"
check "svg: README.md names the file once" "$(grep -c 'docs/images/14unch3r.svg' "$REPOROOT/README.md")" 1

# --- W17: --alias
A="$T/w17"; mkdir -p "$A/apps/Fix.app/Contents" "$A/apps/Other.app/Contents" "$A/desk" "$A/moved"
al() { local o; o="$("$P" --alias "$@" 2>&1)"; printf '%s:%s' "$o" $?; }
sig() { stat -f '%i' "$1" 2>/dev/null; shasum < "$1" 2>/dev/null | cut -c1-12; }
check "alias: none for an empty path" "$(al "$A/apps/Fix.app" "$A/desk/14")" "none:0"
check "alias: make prints made" "$(al "$A/apps/Fix.app" "$A/desk/14" make)" "made:0"
check "  ...the file is an alias by file, and reads have" "$(file -b "$A/desk/14" | grep -c -i 'alias'):$(al "$A/apps/Fix.app" "$A/desk/14")" "1:have:0"
before="$(sig "$A/desk/14")"
check "  ...make again prints have, bytes and inode unchanged" "$(al "$A/apps/Fix.app" "$A/desk/14" make)$([ "$(sig "$A/desk/14")" = "$before" ] && echo :same)" "have:0:same"
echo plain > "$A/desk/plain"; mkdir "$A/desk/folder"; ln -s "$A/apps/Fix.app" "$A/desk/link"; ln -s "$A/nowhere" "$A/desk/dangling"
"$P" --alias "$A/apps/Other.app" "$A/desk/toother" make > /dev/null
for x in plain folder link dangling toother; do
  before="$(ls -lTd "$A/desk/$x"; [ -f "$A/desk/$x" ] && sig "$A/desk/$x")"
  check "alias: other, and untouched under make: $x" "$(al "$A/apps/Fix.app" "$A/desk/$x")$(al "$A/apps/Fix.app" "$A/desk/$x" make)$([ "$(ls -lTd "$A/desk/$x"; [ -f "$A/desk/$x" ] && sig "$A/desk/$x")" = "$before" ] && echo same)" "other:0other:0same"
done
mv "$A/apps/Fix.app" "$A/moved/Fix.app"
check "alias: after the app is moved it reads have for the new path" "$(al "$A/moved/Fix.app" "$A/desk/14")" "have:0"
out="$(al "$A/apps/Gone.app" "$A/desk/new" make)"
check "alias: a target that does not exist: failed, exit 1, nothing written" "$(printf '%s' "$out" | cut -f1):${out##*:}:$([ -e "$A/desk/new" ] && echo there)" "failed:1:"
out="$(al "$A/moved/Fix.app" "$A/nofolder/14" make)"
check "alias: a folder that does not exist: failed, exit 1" "$(printf '%s' "$out" | cut -f1):${out##*:}" "failed:1"

# --- W9: --start, around fixture apps; last, since it needs a session that can start apps
W="$T/w9"
fixture() {   # <app> <file it appends to>: an LSUIElement app whose shim appends its process number and sleeps
  mkdir -p "$1/Contents/MacOS"
  plist "$1" "$(k CFBundleExecutable "$(s fix)")$(k CFBundleIdentifier "$(s "local.launcher-window-test.$RANDOM$RANDOM")")$(k CFBundlePackageType "$(s APPL)")$(k LSUIElement '<true/>')"
  printf '#!/bin/bash\necho $$ >> %q\nexec sleep 30\n' "$2" > "$1/Contents/MacOS/fix"
  chmod +x "$1/Contents/MacOS/fix"
  STARTED="$STARTED $2"
  APPS="$APPS
$(cd "$(dirname "$1")" && pwd -P)/${1##*/}"
}
count() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
waitfor() { local i; for i in $(seq 1 50); do [ "$(count "$1")" -ge "$2" ] && return 0; sleep 0.2; done; return 1; }
fixture "$W/FixA.app" "$W/a.pids"
out="$("$P" --start "$W/FixA.app" 2>&1)"; rc=$?
if [ "$out $rc" != "started 0" ] || ! waitfor "$W/a.pids" 1; then
  echo "REFUSED: open could not start a fixture app here (got '$out', exit $rc); W9 needs a logged-in session"; exit 2
fi
check "--start: started, exit 0, and the app's number there within 10 s" "$out $rc $(count "$W/a.pids")" "started 0 1"
first=$(head -1 "$W/a.pids")
check "the fixture is alive before a plain start" "$(kill -0 "$first" 2>/dev/null && echo alive)" alive
out="$("$P" --start "$W/FixA.app" 2>&1)"; rc=$?
sleep 5
check "--start of an app still alive: started, and no second copy" "$out $rc $(count "$W/a.pids")" "started 0 1"
check "the fixture is alive before a start with new" "$(kill -0 "$first" 2>/dev/null && echo alive)" alive
out="$("$P" --start "$W/FixA.app" new 2>&1)"; rc=$?
waitfor "$W/a.pids" 2
check "--start with new: a second copy" "$out $rc $(count "$W/a.pids")" "started 0 2"
mkdir -p "$W/Empty.app/Contents"
plist "$W/Empty.app" "$(k CFBundleExecutable "$(s fix)")$(k CFBundleIdentifier "$(s "local.launcher-window-test.$RANDOM$RANDOM")")$(k CFBundlePackageType "$(s APPL)")$(k LSUIElement '<true/>')"
APPS="$APPS
$(cd "$W" && pwd -P)/Empty.app"
out="$("$P" --start "$W/Empty.app" 2>&1)"; rc=$?
check "--start of a bundle with no executable: failed, a sentence, exit 1" \
  "$(printf '%s' "$out" | cut -f1) $rc $([ -n "$(printf '%s' "$out" | cut -s -f2)" ] && echo said)" "failed 1 said"
fixture "$W/a b;c/FixC.app" "$W/c.pids"
out="$("$P" --start "$W/a b;c/FixC.app" 2>&1)"; rc=$?
waitfor "$W/c.pids" 1
check "--start: the path is one argument (a folder named with a space and a ;)" "$out $rc $(count "$W/c.pids")" "started 0 1"
for f in $STARTED; do [ -f "$f" ] && for p in $(cat "$f"); do kill "$p" 2>/dev/null; done; done

echo "$fails failure(s)"
[ "$fails" = 0 ]
