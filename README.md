# Mac game ports — Windows games on Apple Silicon, one folder per game

Field notes, patches and launchers for running Windows games on Apple Silicon Macs under Wine. Each
game has its own folder, with its own README, install guide and findings.

| Game | Folder | Stack | Status |
|---|---|---|---|
| **Cities: Skylines II** | [`cities-skylines-2/`](cities-skylines-2/README.md) | Wine 11 + DXMT, free, no CrossOver | Playable; details in its README |

Everything that used to sit at the top level of this repository is now in `cities-skylines-2/`.

## Cities: Skylines II — quick start

Own the game on Steam, on an Apple Silicon Mac? Roughly 20 minutes:

```bash
git clone https://github.com/macgameport/1launcher.git
cd 1launcher/cities-skylines-2
bash scripts/setup.sh
```

`setup.sh` checks your prerequisites, applies the patches, and builds a double-clickable app with
the game's own icon. You need a Wine wrapper with Steam and the game inside it first:
**[INSTALL.md](cities-skylines-2/INSTALL.md) walks through all of it**. The stack, the numbers and the
story are in the game's [README](cities-skylines-2/README.md).

Cloned this before the folders moved? `git pull`, then run setup the way you always have:
`bash scripts/setup.sh` from the top of the clone still works.

## Layout

| Path | What |
|---|---|
| [`cities-skylines-2/`](cities-skylines-2/) | everything for Cities: Skylines II |
| `common/` | checks shared by every game |
| `docs/plans/` | plans for the repository as a whole |
| `scripts/` | compatibility only: old paths that existing clones and outside links still use |

## Licence

MIT, see [LICENSE](LICENSE). This licence covers the scripts, notes and documentation in this repository ONLY. It does not, and cannot, grant any rights in Cities: Skylines II, its binaries, Coherent Gameface, the Paradox SDK, Wine, DXMT, D3DMetal or any other third-party software referenced here. Those remain the property of their respective owners under their own terms.
