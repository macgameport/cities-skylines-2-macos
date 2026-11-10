# Mac game ports — Windows games on Apple Silicon, one folder per game

Field notes, patches and launchers for running Windows games on Apple Silicon Macs under Wine. Each
game has its own folder, with its own README, install guide and findings.

**You need your own copy of each game on Steam.** Nothing here contains game files. The scripts work
on the copy that Steam installs on your Mac, and each game still starts through your own signed-in
Steam, which checks that you own it.

This is an independent community project. It is not affiliated with, endorsed by or supported by
Paradox Interactive, Colossal Order, Valve, Apple or CodeWeavers, and their names and trademarks
belong to them. If something here breaks, ask in [Discussions](https://github.com/macgameport/1launcher/discussions)
or [open an issue](https://github.com/macgameport/1launcher/issues) in this repository rather than contacting a
publisher's support team: they cannot help with it. See also the [security policy](SECURITY.md) and the
[code of conduct](CODE_OF_CONDUCT.md).

| Game | Folder | Stack | Status |
|---|---|---|---|
| **Cities: Skylines II** | [`cities-skylines-2/`](cities-skylines-2/README.md) | Wine 11 + DXMT, free, no CrossOver | Playable; details in its README |
| **Surviving Mars: Relaunched** | [`surviving-mars-relaunched/`](surviving-mars-relaunched/README.md) | Wine 10 + D3DMetal 3.0, taken from a local CrossOver 26 install | Plays on its maintainer's Macs; integration glue, not a product |

Everything that used to sit at the top level of this repository is now in `cities-skylines-2/`.

## Cities: Skylines II — quick start

Own the game on Steam, on an Apple Silicon Mac? Roughly 20 minutes:

```bash
git clone https://github.com/macgameport/1launcher.git
cd 1launcher/cities-skylines-2
bash scripts/setup.sh
```

`setup.sh` checks your prerequisites, applies the patches, and builds a double-clickable app with
the game's own icon, and **14unch3r**, one small window that lists every game set up on your Mac and
starts the one you choose. Each game's own app stays in Applications, so Spotlight finds it too. You need a Wine wrapper with Steam and the game inside it first:
**[INSTALL.md](cities-skylines-2/INSTALL.md) walks through all of it**. The stack, the numbers and the
story are in the game's [README](cities-skylines-2/README.md).

Cloned this before the folders moved? `git pull`, then run setup the way you always have:
`bash scripts/setup.sh` from the top of the clone still works.

## Compatibility

Apple Silicon Macs only. Both games run Intel (x86-64) Wine under Rosetta 2, so Rosetta must be installed.

| | Cities: Skylines II | Surviving Mars: Relaunched |
|---|---|---|
| **Tested** | macOS 26 on an M3 Max and macOS 27.0.1 on an M5 Max: played and benchmarked. macOS 27.2 on an M3 Max: boots to the main menu. One user report from an M4 Pro on macOS 27.0 | macOS 27.2, on an M3 Max and an M5 Max |
| **Untested** | macOS 14 and 15. DXMT's own minimum is macOS 14, but the DXMT library inside the Porting Kit engine that the install guide uses is built for macOS 26, and macOS does not load a library built for a newer release. Treat macOS 26 as the floor until someone reports otherwise | macOS 14.6 to 26. The Sikarugir wrapper's stated minimum is 14.6 and D3DMetal 3.0 is built for 14.0, but nobody has run this there |
| **Not supported** | Intel Macs; macOS 13 and earlier; macOS 28 and later | Intel Macs; macOS before 14.6; macOS 28 and later |

Two things to know about macOS 27:

- **It is the last release this can run on as built.** Apple has said macOS 27 is the final release
  with general Rosetta support ([Apple's notice of 1 September 2026](https://developer.apple.com/news/?id=w5ngl9k2)).
  Do not move a Mac you play on to macOS 28. The plan for a route without Rosetta is
  [issue #16](https://github.com/macgameport/1launcher/issues/16).
- **A macOS update can remove Rosetta.** The upgrade to 27.0.1 and the update to 27.2 both did on the
  test Macs. If a launcher says Rosetta is missing, run
  `softwareupdate --install-rosetta --agree-to-license` in Terminal and start the game again.

Where the component minimums come from: [DXMT](https://github.com/3Shain/dxmt/wiki/Device-System-Runtime-Specifications)
and [Sikarugir](https://github.com/Sikarugir-App/Sikarugir), read 2026-11-09; the build targets were read
from the installed libraries with `otool -l` the same day.

## Layout

| Path | What |
|---|---|
| [`cities-skylines-2/`](cities-skylines-2/) | everything for Cities: Skylines II |
| [`surviving-mars-relaunched/`](surviving-mars-relaunched/) | everything for Surviving Mars: Relaunched |
| `common/` | what every game shares: 14unch3r, the window that lists the games, its builder and its table of games; checks and tests |
| `docs/plans/` | plans for the repository as a whole |
| `scripts/` | compatibility only: old paths that existing clones and outside links still use |

## Licence

MIT, see [LICENSE](LICENSE). This licence covers the scripts, notes and documentation in this repository ONLY. One exception inside the tree: the seven `.patch` files against Wine in `cities-skylines-2/scripts/` are offered under LGPL-2.1-or-later, the licence of the Wine files they modify. Two of those are other people's work, kept with their authorship: `wineandaqua-dxmt.patch` (Paweł Kołodziejski) and `wine-6cfa941-win32u-visible-rect.patch` (a Wine commit). The four patches against DXMT follow DXMT's MIT licence. `cities-skylines-2/patches/_vendor/` holds two MIT-licensed Python libraries, dnfile and pefile, unmodified and with their own licence files. It does not, and cannot, grant any rights in Cities: Skylines II, Surviving Mars: Relaunched, their binaries, Coherent Gameface, the Paradox SDK, Wine, DXMT, D3DMetal, CrossOver or any other third-party software referenced here. Nothing from Apple or CodeWeavers is in this repository, and a Wine engine built with their D3DMetal may not be redistributed. Those remain the property of their respective owners under their own terms.
