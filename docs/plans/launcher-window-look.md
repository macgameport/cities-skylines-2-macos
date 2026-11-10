# 14unch3r: desktop icons over a dark background, and the mark

> **Status:** Written 2026-11-10, not yet checked.
> Tracking: issue #22. A follow-on to `docs/plans/launcher-window.md` ("the parent"), whose step numbers,
> test numbers and decisions this plan continues: B8 to B12, W13 to W19, D12 to D21. File and line
> references are as of `f1afa88`. A path is relative to the repository root. Every number marked
> "measured" was measured on the Studio on 2026-11-10 (macOS 27.2) with throwaway programs under `/tmp`
> that drew offscreen and exited; none of them is in the repository.

## 0. What James asked for (2026-11-10)

| # | His words | What this plan does with it |
|---|---|---|
| K1 | "Can we change the orientation and font sizes to make them look more like desktop icons in the popup window. maybe add a cool background with the 14 logo" | The table becomes a grid of tiles: a 64-point icon with the name centred under it (2.1 to 2.4) |
| K2 | "Like maybe a one and a backwards for that creates an upward arrow inside a circle", with a pen sketch | The mark of 2.5 |
| K3 | Of three mockups: "very cool, third iteration looks awesome" | The third is the look: the mark large, faint, white and centred behind the tiles |
| K4 | The app icon becomes the mark, white on the graphite rounded square | 2.6; it replaces the drawn "14" (parent 2.6, D8) |
| K5 | "let's go ahead and place that on the deskop with the install script (we can ask if the user wants a desktop shortcut during isntall)" | `setup.sh` offers one alias on the Desktop (2.9) |
| K6 | "can we also add the logo to the github page" | The root `README.md` shows the mark, from one generated SVG (2.8) |

Already built in `f1afa88` and kept: one click starts a row, Return and Enter start the selection, no
button (parent as-built deviation 8).

## 1. What is true today (read or measured)

- The window is an `NSTableView` in a scroll view: `ItemCell` (`common/launcher-window.swift:572-606`),
  `Launcher` (`:609-866`), `reload()` (`:725-749`), `fit()` (`:754-769`), 420 points wide (`:563`).
- `startChosen` (`:771-779`) refuses while `starting` or while a sheet is up (`:772`), and takes a click
  only when `clickedRow == selectedRow` (`:773`). The key monitor (`:671-683`) maps Return, Enter and
  Escape. `ask` (`:781-796`), `launch` (`:798-813`) and `failed` (`:815-823`) are attached alerts.
- `secondLine()` (`:157-166`) gives a row's state in words; `defaultRow` (`:210-213`) picks the row
  selected at open; `drawIcon` (`:489-508`) draws "14" into a bitmap of exactly 1024 by 1024 pixels.
- Every text mode returns before any window object is made (`:520-555`), and the tests run only those
  (`common/test-launcher-window.sh:1-11`). `common/test-make-launcher-app.sh:127-133` checks the icon's
  1024 pixels and the builder's fallback.
- **A view tree works with no window, no `NSApplication` and no run loop** (measured). A command-line
  program built `NSView` subclasses, read their frames, read `accessibilityRole()` (`AXButton`),
  `accessibilityLabel()` and `accessibilityChildren()` (3 of 3), got `true` and the side effect from
  `accessibilityPerformPress()`, made a key event with `NSEvent.keyEvent(with:...)` and passed it to
  `keyDown(with:)` (selection moved twice), drew with `cacheDisplay(in:to:)`, and exited with `NSApp`
  still nil. `NSView.hitTest` on a flipped view with no superview gave the wrong answer, so hit testing
  here is the grid's own function over the tile frames (2.7). `acceptsFirstMouse(for:)` is false by default.
- **The title bar is 32 points** on macOS 27 (measured from `NSWindow.frameRect(forContentRect:styleMask:)`,
  with no window made). It was 28 on older systems, so no test names a height that includes it.
- **Text at 112 points wide** (measured, system font). 12 points semibold: "Cities: Skylines II" 1 line,
  "Surviving Mars: Relaunched" 2 lines of 15, a title with its file name 3 lines. 10.5 points regular, 13
  per line: "In use: starting, running or closing" 2, "Game files not found. See its set-up guide." 2,
  "Steam for Windows, run under Wine" 2, "Windows Steam not found. Build this app again." 3, "Not set up
  on this Mac. Opens the set-up guide." 3, "Windows Steam not found" 2, "Not set up. Opens its guide." 2.
- **Contrast** (measured, WCAG ratio, white text). On `controlAccentColor` in dark mode: 4.02 for blue,
  and 3.18, 2.57, 1.58, 2.43, 3.20 for red, orange, yellow, green and pink. On
  `selectedContentBackgroundColor`: 6.27 for blue (`#0059D1`), but 4.07, 2.44 and 3.86 for orange, yellow
  and green. So neither system colour holds 4.5 for every accent a user can pick. On the background of
  2.3, sampled at every pixel of windows 444 by 188 up to 580 by 600: without the mark, white 8.20 and
  white at alpha 0.88 6.83 at worst; with the mark behind, white 6.80, white at alpha 0.88 5.72, white at
  alpha 0.75 4.68 at worst. The pill `#0059D1` against that background is 1.03 to 1.24: it differs by
  hue, not by lightness.
- **A bookmark alias** (measured in `/tmp`): `URL.bookmarkData(options: .suitableForBookmarkFile)` and
  `URL.writeBookmarkData(_:to:)` wrote an 880-byte file that `file` calls "MacOS Alias file", whose
  `isAliasFile` is true and `isSymbolicLink` false, and that `URL(resolvingAliasFileAt:)` resolved to the
  app. After the app was moved to another folder it resolved to the new place. After the app was deleted
  the resolve threw. A plain file resolves to itself, a symlink reads `isAliasFile` true and
  `isSymbolicLink` true, and a target that does not exist cannot be bookmarked. No AppleEvent is sent.
- No script in the repository writes to `~/Desktop` (`git grep -i desktop` finds Wine's virtual desktop
  only). `setup.sh` asks one question, at a terminal only (`[ -t 0 ]`,
  `cities-skylines-2/scripts/setup.sh:136-138`); `--check` stops at `:135`; the window is built at
  `:217-225` and named in the closing lines at `:237`.
- The repository holds no image outside `cities-skylines-2/docs/images/`, whose audit
  (`scripts/check-experiments.py:28-29`) covers that folder only. The root `docs/` holds `plans/` only.
- **The mark as SVG** (measured): the path of 2.8, written by hand from `markPath`'s numbers, passed
  `xmllint --noout`, and drawn through `NSImage` had ink and body at the same eleven points as the bitmap.

## 2. Design

### 2.1 The grid

Tiles replace rows. The rows, their order, their states and their titles are the parent's, unchanged.

| Constant | Points |
|---|---|
| Tile | 120 wide, 146 high |
| Icon | 64 by 64, its top 6 below the tile's top, centred |
| Title | starts 9 below the icon; at most 112 wide and 2 lines (30) |
| Second line | starts 4 below the title; at most 112 wide and 2 lines (26) |
| Side margin 24, gap between tiles in a row 8, gap between rows 8 |  |
| Group gap, before the first Steam tile when a game is to its left in the same row | 28 |
| Above the first row 4, below the last row 22 |  |
| Narrowest grid | 444 |

- **Order and wrap.** Games, then Steam apps, laid left to right, 4 to a row. The first Steam tile is set
  apart by the group gap. When it starts a row there is nothing to its left and no gap is added: its second
  line says what it is.
- **Offers** (parent 2.5) start a row of their own below the others, 4 to a row, under a label "You also
  own": 11 points semibold, white at alpha 0.88, 16 high, 8 below the row above it and 4 above its tiles.
  The label stays because a tile with a generic icon and no app behind it needs its reason said. An offer's
  icon is drawn at half strength; its text is at full strength, so the contrast of 2.4 holds.
- **Width** is the widest row plus both margins, and at least 444. A row is its tiles, the gaps between
  them, and 20 more when it holds the group gap. Rows share one left edge, and that block is centred.
- **Height** is 4, the rows and the gaps between them, the offers block when there is one (8 + 16 + 4 and
  its rows), and 22. The window's content is that plus the title bar. Past 600 points the grid scrolls
  inside a scroll view that draws no background; the background does not move.

| Tiles | Grid size | Tile origins, x from the left and y from the top of the grid |
|---|---|---|
| none | 444 by 172 | the two lines of the empty state, centred |
| 1 game | 444 by 172 | 162, 4 |
| 2 games and Steam | 444 by 172 | 24, 152 and 300; all 4. This is the mockup |
| 3 games and Steam | 572 by 172 | 24, 152, 280 and 428 |
| 4 games and Steam | 552 by 326 | row 2: Steam at 24, 158 |
| 5 games and Steam | 552 by 326 | row 2: 24 and 172, at 158 |
| 8 tiles | 552 by 326 | two full rows, or 572 wide when a row holds the group gap |
| 2 games, Steam, 1 offer | 444 by 346 | label at y 158; the offer at 24, 178 |

### 2.2 Window chrome

`styleMask` is `[.titled, .closable, .fullSizeContentView]`, with `titlebarAppearsTransparent = true` and
`titleVisibility = .hidden`. The background runs under the title bar; the grid starts below it, so no tile
is under the close button and the bar still drags the window. `window.title` stays "14unch3r" and the
accessibility title stays "14unch3r game launcher". `fit()` keeps the top edge and the horizontal middle
when the size changes, as when the offers arrive.

### 2.3 Appearance and background

The window is dark whatever the system is set to: `NSApp.appearance = NSAppearance(named: .darkAqua)`, set
once before the window is made, so the alerts and the menu follow. This replaces the parent's sentence
"Every colour is a system colour, so light and dark follow the system": the colours below are fixed, and
only the alerts' own colours are the system's.

One background view fills the content, title bar included, and draws in this order:

1. a vertical gradient, `NSColor(white: 0.24)` at the top to `NSColor(white: 0.09)` at the bottom;
2. a radial glow, `NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.75, alpha: 0.22)` fading to clear,
   centred at 0.15 of the width on the top edge, radius 0.7 of the width;
3. the mark of 2.5, stroked in white at alpha 0.075.

### 2.4 Text, selection and hover

- **Title:** 12 points semibold, white, centred, word-wrapped, at most 2 lines, the second cut with an
  ellipsis. Under it a shadow: black at alpha 0.75, blur 3, offset 1 down. No shadow on the selected tile.
- **Second line:** 10.5 points regular, white at alpha 0.88, the same shadow, at most 2 lines. It is
  `secondLine()` except for the two sentences that measured 3 lines: a Steam app that is `absent` shows
  "Windows Steam not found", and an offer shows "Not set up. Opens its guide." The full sentence stays in
  the VoiceOver label and is the tile's tooltip, with the full title.
- **Selection:** a plate behind the icon, the icon's rectangle grown by 7 at the sides and 6 above and
  below, corner radius 10, filled white at alpha 0.16 and outlined 1.5 points in white at alpha 0.75; and
  a pill behind the title, the title's rectangle grown by 5 and 1, radius 4, filled `#0059D1` in sRGB.
  The pill is a fixed colour, not the accent (section 1). The outline is not in the mockup: it is what
  shows the selection by lightness (4.68 to 1 at worst), where the pill alone is 1.03 to 1.24.
- **Hover:** the same plate, filled white at alpha 0.08 with no outline, and the pointing-hand cursor over
  a tile. It is an extra cue: a click starts a game, so the tile under the pointer says it is live.
- **Measured ratios the build must keep:** title on the pill 6.27; title on the background 6.80 at worst
  with the mark behind and 8.20 without; second line and label 5.72 and 6.83. All are above 4.5.
- The empty state keeps its two strings (`:623-624`), "No games are set up on this Mac yet." at 13 points
  in white and the README address at 11 points in white at alpha 0.88, still selectable, centred in a
  grid of 444 by 172 with the mark behind. The address measured 350 points wide.
- Nothing animates.

### 2.5 The mark

One function, `markPath(in:)`, is the only place its numbers live. In a square box, x to the right and y
up, both from 0 to 1:

| Part | Geometry |
|---|---|
| Ring | an arc centred 0.5, 0.5, radius 0.42, counter-clockwise from -58 to 238 degrees: open at the bottom |
| The 1 | 0.30, 0.605 to 0.455, 0.76 to 0.455, 0.08 |
| The mirrored 4 | 0.545, 0.08 to 0.545, 0.76 to 0.715, 0.585 to 0.545, 0.545 |
| Stroke | 0.05 of the box, round caps, round joins, no fill |

**In the window** the box is a square whose side is 0.75 of the content's width, rounded: 333 at 444 wide.
It is centred horizontally, and its bottom edge is 0.08 of its side below the window's bottom edge, so the
two stems run out of the window as in the mockup. It grows with the width and is cropped by the height: a
one-row window shows its middle band, a taller one more of the ring.

### 2.6 The app icon

`drawIcon` keeps its contract: a bitmap of exactly 1024 by 1024 pixels, the rounded square 824 wide,
centred, corner radius 185, the gradient from `NSColor(white: 0.32)` to `NSColor(white: 0.13)`. The "14" and its
font go. In their place `markPath(in:)` is stroked in opaque white in the square inset by 92 on every
side: a box of 640 at 192, 192, stroke 32. The drawing moves into `iconBitmap()`, which `--icon` writes and
`--icon-at` samples. The builder's packing (`common/make-launcher-app.sh:82-93`) does not change.

### 2.7 Interaction and VoiceOver

A `GridView` holds one `TileView` per row and is the window's only key view and first responder.

- **Click.** Mouse-down on a tile selects and arms it. Mouse-up on the armed tile starts it; mouse-up
  anywhere else starts nothing. A press between tiles, in a margin or on the label does nothing. A tile's
  hit area is its 120 by 146 frame, found by the grid's own function over the tile frames. Neither view
  overrides `acceptsFirstMouse`, so the first click into an inactive window only activates it.
- **Keys.** Left and Right move one tile through the whole order, across rows, and stop at both ends.
  Up and Down move to the tile in the next row in that direction whose centre is nearest in x, the offers
  rows included, and stay put when there is no such row. Return, Enter and Space start the selection.
  Escape quits, or answers "Don't Start" in the question, as today. The monitor of `:671-683` gains Space
  and passes everything else on; the arrows are the grid's `keyDown`.
- **A start** still goes through `startChosen`, which keeps `:772` (nothing while `starting` or while a
  sheet is up), the reload, the question of `ask` for a busy target and `launch`. Its test of
  `clickedRow` (`:773`) goes: the armed-tile rule replaces it. `chosen` reads the grid's selection.
- **The selection at open** is `defaultRow`'s choice, and a reload keeps it on the same app, as `:726` and
  `:738-745` do today.
- **VoiceOver.** Each tile is one element with the button role and today's label: the title, or "<title>,
  <second line>" with `secondLine()`'s full sentence, or for an offer "<title>, not set up on this Mac,
  opens the set-up guide in your browser" (`:602-603`). Its press action starts it. Icons and texts are
  drawn, so they are not elements. The grid is a group labelled "Games", with the help "Click a game, or
  press Return, to start it." The label "You also own" is not an element: an offer's label says it.
- **Full keyboard access.** The grid is the only stop, so Tab has nowhere to go and the arrows do the
  moving. Nothing is added for it beyond Space.

### 2.8 The mark on the repository's page

- `launcher-window --svg <out.svg>` writes the icon form from the same numbers, every number with two
  decimals, in a fixed order of attributes, ending in one line break:
  `viewBox="100 100 824 824"`, `role="img"`, `aria-label="14unch3r"`; a vertical gradient `#525252` to
  `#212121`; a `rect` at 100, 100, 824 by 824, `rx` 185; and one `path`, white, `stroke-width` 32.00, round
  caps and joins, no fill, whose data for today's numbers is
  `M654.44 739.96A268.80 268.80 0 1 0 369.56 739.96M384.00 444.80L483.20 345.60L483.20 780.80M540.80 780.80L540.80 345.60L649.60 457.60L540.80 483.20`
  (x = 192 + 640 x, y = 832 - 640 y). No text, no image, no script, no link.
- The output is committed as `docs/images/14unch3r.svg`, a new folder beside `docs/plans/`. W16 compares
  it byte for byte with fresh output, so the file cannot drift from the icon.
- `README.md` gains, above its first heading:
  `<p align="center"><img src="docs/images/14unch3r.svg" width="128" height="128" alt="14unch3r: a 1 and a mirrored 4 that form an upward arrow in a circle"></p>`
- One file, not `<picture>` with two: the white mark sits on its own graphite square (white on its
  lightest grey is 7.8 to 1 by the same formula), so it reads on GitHub's light and dark pages alike, and
  there is one file to keep equal to the program.
- Outside this plan, by James in GitHub's settings if he wants them: the organisation's avatar and the
  repository's social preview. `--icon` gives a PNG to upload.

### 2.9 A shortcut on the Desktop

- **Kind:** an alias file, written by the window program. Not a symlink: it breaks when the app
  moves, where the alias followed it (section 1). Not Finder through `osascript`:
  that brings an Automation question for whatever runs setup.
- **Mode:** `launcher-window --alias <app> <alias path> [make]`. It prints one word and exits 0:
  `have` when the path is an alias file, not a symlink, that resolves (no interface, no mounting) to the
  same resolved path as the app; `other` when anything else is at the path, a dangling symlink included;
  `none` when nothing is. With `make` and `none` it writes the alias and prints `made`; with `make` and
  `have` or `other` it writes nothing and prints that word. A write that fails prints `failed`, a tab and
  the system's sentence, and exits 1.
- **Never replaced.** An existing path is never written, removed or renamed. On James's Macs the Desktop
  is in iCloud, where a quick delete and rewrite leaves a stale " 2" copy, and where an alias made on one
  Mac appears on the other: there it reads `have` when it resolves to that Mac's app, and `other` when it
  does not, and either way setup adds nothing. No other file on the Desktop is read or touched.
- **Name:** `~/Desktop/14unch3r`, with `$HOME` as setup has it. When the Desktop folder is missing,
  nothing is made.
- **In `setup.sh`,** after the window was built (`WINDOW_BUILT=1`, `:221`) and before the closing lines,
  with the program at `$HOME/Applications/14unch3r.app/Contents/MacOS/launcher-window`:

| State | At a terminal, no flag | `--desktop` | `--yes`, or not at a terminal |
|---|---|---|---|
| `none` | asks `Put a 14unch3r shortcut on the Desktop? [y/N] `; `y` or `Y` makes it, anything else does not | makes it, no question | no question, nothing made |
| `have` | no question | no question | no question |
| `other` | no question | nothing made | nothing made |

- `--yes` does not answer this question with a yes: it means "do not stop", not "write to my Desktop".
  `--desktop` is the yes. `--check` exits at `:135`, before any of this, with or without `--desktop`.
- Nothing is remembered. A later run that finds `none` asks again.
- **One closing line** under `Play:`, by outcome: `Desktop:   14unch3r shortcut added`; `Desktop:   the
  14unch3r shortcut is already there`; `Desktop:   something else named 14unch3r is there; it was left as
  it is`; `Desktop:   no shortcut. To add one:  bash scripts/setup.sh --desktop`; or, on `failed`,
  `Desktop:   the shortcut could not be made` and the sentence. None counts as a problem. When the window
  was not built there is no line.
- Not measured, and owed to live step L3: whether macOS asks the terminal for access to the Desktop
  folder when the mode first looks there, and whether that comes before the question above.

## 3. Phases

Built in this order on a branch in a scratch worktree, as the parent was. A step is done when its tests
exit 0, every mutant of those rows has been seen red and restored, and every suite that passed before
still passes.

| Step | What | Files |
|---|---|---|
| B8 | `markPath`, `iconBitmap()`, the icon carrying the mark, `--icon-at` | `common/launcher-window.swift`, `common/test-launcher-window.sh` |
| B9 | The grid: layout, `GridView`, `TileView`, the background, the chrome, dark appearance, keys, clicks, VoiceOver, `--grid` and `--act`; `ItemCell` and the table go | the same two |
| B10 | `--svg`, the committed SVG, the README line | the same two, `docs/images/14unch3r.svg`, `README.md` |
| B11 | `--alias`; `setup.sh`'s `--desktop`, question and closing line | the same two, `cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/test-setup.sh` |
| B12 | Documents: the pointer lines of section 8; the mode list in the source header (`:7-18`) and `usage()` (`:468-481`); `CLAUDE.md` (the Desktop alias as a place outside the repo, with its reason; `docs/images/`); `cities-skylines-2/INSTALL.md` (the question, `--desktop`, and the alias under Uninstall); the as-built header here | those |

## 4. Test plan

The parent's conventions hold: fixtures in a scratch folder, no game, no Steam, no Wine, the window never
started, an exit 2 is not a pass, each mutant one changed line in a copy of the source. The new modes
build the real `GridView` and `TileView` with no window and read their answers from those views.

- `--grid [--games <tsv>] <last app id or -> <folder>...` prints, tab-separated: `size`, width, height;
  `mark`, x, y, side, for that width; `group`, the role and the label; `label`, x, y and the text, when
  there are offers; per tile `tile`, row, column, x, y, the role, `selected` or `-`, the accessibility
  role, the accessibility label, the lines of its title, the second line as shown; `empty` and each
  string when there is no tile; `first-click`, `activates` or `starts`.
- `--act <step,...> [--games <tsv>] <last app id or -> <folder>...` applies steps to the same views and
  prints one line per step: the step, then `selected` and the title, or `start` and the path, or `quit`,
  or `nothing`. Steps: `left right up down return enter space escape` as key events to the handlers the
  window uses; `press:x,y` and `release:x,y` in grid points; `axpress:<n>` on tile n. A start prints and
  starts nothing.
- `--icon-at <x,y>...` prints `ink`, `body` or `clear` per pixel of `iconBitmap()`, x and y from the top
  left: white, the grey square, or outside it.

| # | Step | Test | Cases | Mutants, each seen red |
|---|---|---|---|---|
| W13 | B8 | `common/test-launcher-window.sh`: `--icon-at` | `ink` at 512,242 (ring top), 243,511 and 780,511 (ring sides), 483,575 and 540,575 (the stems), 433,395 (the 1's flag); `body` at 512,780 (the ring's opening), 512,575 (between the stems), 672,575; `clear` at 64,959. The "14" icon measured `body` at five of those ink points and `ink` at 512,575 and 672,575, so the case tells the two apart. `test-make-launcher-app.sh:127-133` still passes unchanged: 1024 by 1024 | the mark not stroked in the icon; the arc ended at 302 degrees, not 238 |
| W14 | B9 | same file: `--grid` | Each row of 2.1's table by size and origins, with fixture apps. The mark is 333 wide at 444 and 414 at 552. Every tile has `AXButton` and the label of 2.7; the group is `AXGroup`, "Games". An offer is on its own row under the label, its accessibility label ends "opens the set-up guide in your browser", and it shows "Not set up. Opens its guide." An `absent` Steam app shows "Windows Steam not found" and its label holds the full sentence. Two apps with one title: 2 title lines. The selected tile is the last game when listed, else the first game. An empty folder: `size 444 172`, both strings, no tile. `first-click activates` | 5 to a row; the group gap dropped; the least width dropped; the button role dropped; an offer's label without the guide words; offers not starting a row; the first tile selected whatever the last id; the title allowed 3 lines |
| W15 | B9 | same file: `--act` | `right` moves on, stays at the last tile; `left` stays at the first; `right` goes from the end of row 1 to the start of row 2. `down` goes to the nearest tile of the next row, into the offers row too, and stays on the last row; `up` the reverse. `return`, `enter` and `space` print `start` and the selected path; on an offer, its address. `escape` prints `quit`. `press` and `release` on one tile: `start`, and the tile is selected after the press. `press` on one tile and `release` on another, or in a gap: `nothing`. `press` and `release` at 146,40, between two tiles, and at 10,10: `nothing`. `axpress:2` starts tile 2 | a start on the press; the release not compared with the armed tile; `down` moving one tile on; `right` wrapping to the first; Escape dropped; Space dropped; the press action starting nothing; `acceptsFirstMouse` true |
| W16 | B10 | same file: `--svg` | The output passes `xmllint --noout`, equals `docs/images/14unch3r.svg` by `cmp`, holds the path data of 2.8, and holds none of `<text`, `<image`, `<script`, `href`. `README.md` names that file once | the 1's top at 0.70, not 0.76; a second line break written at the end |
| W17 | B11 | same file: `--alias`, in a scratch folder with a fixture app | `none` for an empty path; `make` prints `made`, and the file is an alias by `file`, then reads `have`; `make` again prints `have` and the file's bytes and inode are unchanged. `other`, and untouched under `make`: a plain file, a folder, a symlink to the app, a dangling symlink, an alias to another fixture app. After the app is moved within the scratch folder the alias still reads `have` for the new path. A target that does not exist: `failed`, exit 1, nothing written. A folder that does not exist: `failed`, exit 1 | an existing path overwritten; a symlink to the app read as `have`; an alias to another app read as `have`; exit 0 on a failed write |
| W18 | B11 | `cities-skylines-2/scripts/test-setup.sh`: the builder stub (`:52-57`) also writes a recording `launcher-window` into the scratch `HOME`'s `14unch3r.app`, which answers `--alias` with `$STUB_ALIAS` (default `none`), records each call, and prints `made` under `make` | With the pty helper (`:157-161`, which types Return; a second form types a given answer) typing `y`: the question is asked once, `make` is recorded once, the `added` line. Typing Return, and typing `n`: asked, no `make`, the `no shortcut` line. `--yes` at a terminal: not asked, no `make`, the `no shortcut` line. `--desktop` with no terminal: not asked, `make` once. No terminal and no flag: not asked, no `make`, the `no shortcut` line. `STUB_ALIAS=have`: not asked, no `make`, the `already there` line, with and without `--desktop`. `STUB_ALIAS=other`: not asked, no `make`, the `left as it is` line, even with `--desktop`. `--check --desktop`: no call at all and nothing written. The window stub exiting 1: no call, no `Desktop:` line. Every case exits 0 with `=== setup complete ===` | Return counted as yes; `--yes` counted as yes; asked without a terminal; `make` passed when the state is `other`; asked when the state is `have`; the alias step run when the window was not built |
| W19 | B9 | `common/test-launcher-builders.sh`, unchanged | The builders' apps still come out of `--list` as before: the grid changed no row | none new |

Only a person sees: the look itself, the hover plate and cursor, the alerts in dark, a first click
activating the real window, clicks ignored while a start is under way, the Dock icon, the alias's arrow
and icon in Finder, and the page on GitHub.

## 5. Live steps, each on James's word

Records carry counts and verdict words only. Captures go to the evidence store, not the repository.

- **L1. Merge and build, on the Studio, with no launcher running** (the parent's live step 1 check), then
  `bash common/make-launcher-app.sh`. `--grid - ~/Applications` gives two games and one Steam tile at
  444 by 172.
- **L2. The rehearsal. This replaces parent live step 4**, on the same fixtures: the window opened on a
  scratch folder holding a busy app, one whose shim writes a file, one with no executable, an `absent`
  one, and a table that makes an offer. Captured once, the window's own region, with the system in light
  and again in dark: both must show the same dark window. Captures: the grid with every second line, the
  selected tile, a hovered tile, the offer row, the question, the failed-start alert, the empty window.
  On each, the text measures at least 4.5 to 1 against what is behind it, the mark included, and the
  selection outline at least 3 to 1. "Don't Start" writes no file; "Start Anyway" writes it and the window
  quits; a failed start keeps the window. A press dragged off a tile starts nothing. The first click into
  the window from another app starts nothing. James moves through it with the arrows, Return, Space and
  Escape, once with VoiceOver on, and once with the accent set to yellow. The mark reads at 16 pixels in
  the Dock and in Finder's list view, where the parent asked that of "14".
- **L3. The Desktop.** `bash scripts/setup.sh` at a terminal: the question, `y`, and one `14unch3r` alias
  with the app's icon and arrow, which opens the window. Written down: whether macOS asked for access to
  the Desktop folder, and when. A second run does not ask. James's two game aliases are byte-identical
  before and after, and no name ending " 2" has appeared on the Desktop a minute later.
- **L4. The page.** After the push, the README on github.com shows the mark in the light and the dark
  theme. `python3 common/check-links.py` exits 0.
- **L5. The MacBook.** `git pull`, the build, and `setup.sh`: the alias that iCloud brought reads `have`
  or `other`, which is written down, and no second one is made. Parent live steps 5 to 8 then go on from
  this window; their wording "row" means a tile.

## 6. Exit criteria

- W13 to W18 exit 0 with every mutant seen red and restored; W19 and every suite the parent's section 6
  names still exit 0, as do `test-make-launcher-app.sh` and the parent's W1 to W12.
- `launcher-window.swift` holds no `NSTableView`, no `ItemCell` and no "14" drawn as text.
- L1 to L4 pass on the Studio and L5 on the MacBook.
- The design gate: L2's captures at the measured ratios; every state is words; the keyboard reaches every
  tile; VoiceOver reads each tile's title and state and can start it.
- The as-built header here is written, and the parent has the pointer lines of section 8.

## 7. Rollback

`git revert` of this plan's merge, then `bash common/make-launcher-app.sh` on each Mac: the window is the
table of `f1afa88` again, with the "14" icon. By hand: `~/Desktop/14unch3r` to the Trash, once, on one
Mac, since iCloud removes it from the other. The revert takes `docs/images/14unch3r.svg` and the README
line with it. No launcher code, game file, save or preference is touched by this plan: `lastAppID` is
read and written as before.

## 8. Pointer lines the builder adds to the parent

- In `docs/plans/launcher-window.md` 2.2, under "What it looks like": "Superseded 2026-11-10 by
  `docs/plans/launcher-window-look.md`, sections 2.1 to 2.4 and 2.7: tiles, a dark window, fixed colours."
- In 2.6: "Superseded 2026-11-10 by `docs/plans/launcher-window-look.md`, 2.5 and 2.6: the icon carries the
  mark, and one SVG of it is in `docs/images/`."
- In section 5, live step 4: "Replaced by live step L2 of `docs/plans/launcher-window-look.md`."
- In section 9, at D8: "See D12 and D19 of `docs/plans/launcher-window-look.md`."

## 9. Decisions (James)

| # | Question | Recommendation, or what was decided |
|---|---|---|
| D12 | The icon | **Decided 2026-11-10:** the mark, white on the graphite square. It ends the parent's D8 "until James supplies art" |
| D13 | The look | **Decided 2026-11-10** from the third mockup: tiles, the dark background, the mark centred and faint |
| D14 | Light mode | The window is always dark, alerts included. The parent's "light and dark follow the system" ends |
| D15 | The selection's colour | A fixed blue, `#0059D1`, not the system accent: white on the accent measured 1.58 to 4.02. On a Mac set to another accent the pill stays blue |
| D16 | An outline on the selected icon's plate, which the mockup does not have | Add it. Without it the selection is told by hue alone. **James sees it in L2 and can strike it** |
| D17 | Two second lines shortened on the tile | "Windows Steam not found" and "Not set up. Opens its guide.", so no tile needs a third line. The full sentences stay for VoiceOver and the tooltip |
| D18 | The label "You also own" | Kept, small, above a row of its own |
| D19 | An image file in the repository, which the parent's D8 ruled out | **Decided 2026-11-10** by K6: one SVG, written by the program and compared with it by a test |
| D20 | The Desktop shortcut | Asked at a terminal, default no; `--desktop` says yes; `--yes` does not; never replaced; nothing remembered. **The default and `--yes` are James's to confirm** |
| D21 | A new place outside the repo, which `CLAUDE.md` asks James's word for | `~/Desktop/14unch3r`, one alias, made only on a yes. K5 is that word; B12 writes it into `CLAUDE.md` |

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|

Key paths: `common/launcher-window.swift`, `common/make-launcher-app.sh`, `common/test-launcher-window.sh`,
`common/test-make-launcher-app.sh`, `common/test-launcher-builders.sh`, `cities-skylines-2/scripts/setup.sh`,
`cities-skylines-2/scripts/test-setup.sh`, `README.md`, `docs/plans/launcher-window.md`.
