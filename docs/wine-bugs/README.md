# Wine bug reports

Three Wine defects account for **11 of the 17** patches this project needs. Fixing them upstream
retires those patches for every macOS user, not just this machine.

| ID | Summary | Retires | Status |
|---|---|---|---|
| ~~R1~~ | ~~`GetLastError` returns garbage after file APIs~~ | — | **[60220](https://bugs.winehq.org/show_bug.cgi?id=60220) — CLOSED INVALID. Disproven.** |
| [R2](R2-createfile-handle-zero.md) | `CreateFile` returns handle `0` for a valid file | 2 | **not filed — needs the same verification R1 failed** |
| [R3](R3-bcrypt-verifysignature.md) | `BCryptVerifySignature` fails on valid ECDSA | 1 | **not filed** |

## ⚠️ R1 was filed and disproven — read this before filing anything else

Bug [60220](https://bugs.winehq.org/show_bug.cgi?id=60220) was filed 2026-08-22 claiming
`GetLastError` returns garbage after file APIs, and **closed INVALID the same day** because a
focused native probe (`../../scripts/errtest.c`) disproved it:

| failure path | expected | wine-11.15 | wine-10.0 Sikarugir |
|---|---|---|---|
| `CreateFile` missing file | 2 | ✅ | ✅ |
| `CreateFile` under missing dir | 3 | ✅ | ✅ |
| `DeleteFile` missing | 2 | ✅ | ✅ |
| `FindFirstFile` missing dir | 3 | ✅ | ✅ |
| **after `FindNextFile` exhausted** | **18** | **✅** | **✅** |
| `RemoveDirectory` non-empty | 145 | ✅ | ✅ |
| `CreateFile` already held | 32 | ✅ | ✅ |
| `DeleteFile` open handle | 32 | ✅ | ✅ |
| `RemoveDirectory` missing | 2 | ✅ | ✅ |

**9/9 correct on both.** The Win32 layer is fine.

The *symptom* is real — `IOException: "Success"` is measured, repeatedly, in the game. But the
cause is not the raw Win32 error code. Remaining candidates, not yet separated:

1. **Unity's forked Mono** (`mono-2.0-bdwgc.dll`) mangling the error in its P/Invoke layer. That
   points at wine-mono/`mscoree`, or at Unity — possibly not a Wine bug at all.
2. **Concurrency.** The failure was observed under the game's heavily concurrent IO;
   `errtest.c` is single-threaded and passes consistently, so it cannot reproduce a race.

**The lesson, which cost a wrong public bug report:** the patches prove *something* is broken —
they were derived from real, repeated failures. They do **not** prove *where*. Reproduce at the
layer you intend to blame, on the version you intend to file against, before filing.

**Environment for all three**

R3 is the highest-leverage of the three: it is the only one whose workaround has a licensing
problem, so fixing it upstream removes the need for a patch that cannot be published.

File at **https://bugs.winehq.org** (product *Wine*). Each report below is written to be pasted
directly. Please update the table with bug numbers once filed.

> ⚠️ **Test against current Wine, not the wrapper's Wine.** Bug 60220 was filed against **10.0**,
> which is what the D3DMetal wrapper ships — but Wine development is at **11.16**, and WineHQ triage
> expects reproduction on a current release. The reproducers need no graphics, so a stock Wine build
> is enough to retest; do that *before* filing the remaining two. A retest on 11.15 was attempted
> 2026-08-22 and was **inconclusive** — the standalone Gcenx build would not launch any executable
> in a scratch prefix, so nothing can be concluded from it either way.

**Environment for all three**
- Wine 10.0 (Sikarugir build, Kegworks/WineskinNavy wrapper)
- macOS 26, Apple M3 Max (arm64, running x86_64 under Rosetta 2)
- Affected app: Cities: Skylines II 1.6.0f1 (Unity 2022, Mono runtime)
