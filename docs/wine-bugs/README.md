# Wine bug reports

Three Wine defects account for **11 of the 17** patches this project needs. Fixing them upstream
retires those patches for every macOS user, not just this machine.

| ID | Summary | Retires | Status |
|---|---|---|---|
| [R1](R1-getlasterror-garbage.md) | `GetLastError` returns garbage after file APIs | 8 | **not filed** |
| [R2](R2-createfile-handle-zero.md) | `CreateFile` returns handle `0` for a valid file | 2 | **not filed** |
| [R3](R3-bcrypt-verifysignature.md) | `BCryptVerifySignature` fails on valid ECDSA | 1 | **not filed** |

R3 is the highest-leverage of the three: it is the only one whose workaround has a licensing
problem, so fixing it upstream removes the need for a patch that cannot be published.

File at **https://bugs.winehq.org** (product *Wine*). Each report below is written to be pasted
directly. Please update the table with bug numbers once filed.

**Environment for all three**
- Wine 10.0 (Sikarugir build, Kegworks/WineskinNavy wrapper)
- macOS 26, Apple M3 Max (arm64, running x86_64 under Rosetta 2)
- Affected app: Cities: Skylines II 1.6.0f1 (Unity 2022, Mono runtime)
