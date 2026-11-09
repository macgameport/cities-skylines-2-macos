# R3 — `BCryptVerifySignature` fails on a valid ECDSA signature

**Component:** bcrypt
**Severity:** normal · **Platform:** macOS (Apple Silicon, Rosetta 2)
**Priority for this project: highest** — see *Why this one matters* below.

## Summary

`BCryptVerifySignature` reports failure for an ECDSA signature that verifies correctly on Windows.
The surrounding calls appear to succeed; only the final verification result is wrong.

The observed sequence is:

```
BCryptOpenAlgorithmProvider
BCryptImportKeyPair        (public key blob)
BCryptCreateHash / BCryptHashData / BCryptFinishHash
BCryptVerifySignature      -> fails
```

The verifier parses `"R"` and `"S"` components from the key blob, i.e. a raw ECDSA r/s signature
pair rather than a DER-encoded one.

## Observed in

Cities: Skylines II uses **Coherent Gameface** (`cohtml`) for its UI. Gameface validates its own
embedded licence key through the above CNG sequence. Under Wine the verification fails, so Gameface
logs `[UI][ERROR] Invalid License key used!` and the game crashes in `cohtml.Net.Library:Initialize`
before reaching the main menu.

Key evidence that this is a Wine issue and not a licence or file problem:

- The licence key is present, unmodified and **valid** — the same game files verify fine elsewhere.
- Under **CrossOver's** Wine (which implements this path correctly) the same binaries produce **zero**
  "Invalid License key" errors and the game boots normally.
- The DLLs were byte-compared (SHA-1 identical) between the working and failing setups. Only the
  Wine build differs.

## Reproducer

Not yet reduced to a minimal case — help welcome. A standalone reproducer would import a known
ECDSA public key, hash a fixed message, and call `BCryptVerifySignature` with a known-good raw r/s
signature, comparing the result against Windows.

## Why this one matters most

This is the only one of the three whose workaround **cannot responsibly be published**. Working
around it requires patching a signature check in commercial middleware, which reads as
circumvention regardless of the fact that the licence being checked is legitimate and present.

Fixing `BCryptVerifySignature` in Wine removes the need for that patch entirely, and is the only
route that lets the full setup be documented openly.
