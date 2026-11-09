# Security policy

## Reporting a problem

Report it privately. Open this repository's **Security** tab and choose **Report a vulnerability**, or go
straight to [the private report form](https://github.com/macgameport/1launcher/security/advisories/new).
Only the maintainers see what you send. Please do not open a public issue or discussion for something that
could put other players at risk.

Reports are read by one maintainer in spare time, so a reply can take a week or more.

## What counts

The scripts here run on your Mac with your own permissions. They edit files inside your own copy of a game
and start Wine and Steam. A report is in scope when something in this repository could:

- run code you did not choose to run, or fetch code from somewhere it does not say it does;
- write, move or delete files outside the folders the install guide names;
- expose your Steam account, your saves or personal information, for example by writing them into a log
  that people are asked to share;
- leave a game install damaged in a way its backups do not undo.

## What does not

Problems in the games themselves, or in Steam, Wine, DXMT, D3DMetal, Porting Kit or macOS, belong with
their own projects and vendors. A game that will not start is an ordinary bug: use
[Issues](https://github.com/macgameport/1launcher/issues) or
[Discussions](https://github.com/macgameport/1launcher/discussions).

## Supported versions

The `main` branch, and the newest tagged release once there is one.
