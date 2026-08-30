# Committed image audit

> **Every image tracked under `docs/images/` must have a row here, and its hash must match.**
> `scripts/check-experiments.py` enforces both at `button up` — a new image with no row, or an
> image replaced since its audit, fails the check. This exists because the repo is public and Steam
> client windows carry the persona name twice plus the avatar.
>
> **To add an image:** open it, look at it, add a row saying what is visible, and record
> `shasum -a 256 <file> | cut -c1-12`. Do not add a row you have not earned by looking.

| file | sha256[:12] | audited | what is actually visible | verdict |
|---|---|---|---|---|
| `cs2-on-macos.png` | `34d1ca5992e5` | 2026-08-30 | In-game view + Metal HUD (FPS/GPU/DXMT build). macOS menu bar shows app menus, status icons and `Sun Aug 23 19:04`. City name "Grand Village", street name, no account chrome. | **clean** — no persona name, no avatar, no Steam ID, no `/Users/` path |
| `steam-crossprocess-child-renders.png` | `536209e8acfd` | 2026-08-30 | Steam storefront rendering with **zero glyphs** — nav items are bare chevrons, search box empty, no labels anywhere. No avatar drawn. | **clean, but only incidentally** — see the warning below |
| `cs2-paradox-mods.jpg` | `21ae9a83c5a9` | 2026-08-30 | Paradox Mods **Library** tab: 5 installed mods with their public author handles (River-mochi, krzychu124, algernon, yenyang), "253.22 GB Free disk space", active playset name, Metal HUD. The `ME` tab is **not** open, so no Paradox account name is shown. | **clean of identifiers** — but see the note below |
| `steam-crossprocess-geometry-mapped.png` | `b1527e3bddc5` | 2026-08-30 | Steam storefront, again **zero glyphs**. Window chrome present; the **avatar is visible** top-right (monkey). No persona name text. | **clean** — avatar is fine by James (2026-08-30); no name rendered |

## ⚠ The two Steam captures are clean *because of the bug being chased*

Steam renders no text on this engine, so there is no persona name to leak. **That protection
disappears the moment the glyph problem is fixed** — which is the whole point of the investigation.
A capture of the identical window, taken after text works, carries the persona name **twice** (top
right, and as a nav item).

So: do not read "our committed Steam captures have always been fine" as precedent. It is an artifact
with an expiry date, and the expiry is *success*.

## The durable fix, in order of preference

1. **Rename the Steam persona to something generic before any further capture work.** The persona
   name is a **label** — freely editable, nothing resolves by it — which is this project's own
   [keys-are-opaque](../../CLAUDE.md) doctrine applied to itself. This is the only option that makes
   a capture safe *whether or not text renders*, needs no per-image discipline, and is reversible in
   one click. Renaming back afterwards costs nothing.
2. **Keep captures in the evidence store by default.** `~/cs2-patch/evidence/` is outside the repo
   for exactly this reason. Committing a window capture should be a deliberate act with a row here,
   not the default.
3. **Do not mask or blur.** A mask you got wrong is worse than no mask, because it looks safe. There
   is also nothing to mask today — the names are not rendered, so a redaction box would be
   decoration over an already-clean image while implying the rest was checked by the same means.

## ⚠ One judgment call, flagged rather than decided

`cs2-paradox-mods.jpg` contains no account name and no personal identifier — but it does show
**which five mods are installed**. `.gitignore` excludes `MODS-GUIDE.md` on the stated grounds that
*"the public repo documents the port, not the playstyle"*, so this screenshot lightly overlaps the
thing that entry protects.

It is a much weaker disclosure than the guide itself (five mod names, no configuration, no
commentary), and the image earns its place in the README by showing the mod pipeline working. **Left
as-is pending James's call** — the options are keep it, crop to the header row, or swap in a capture
with the library empty.
