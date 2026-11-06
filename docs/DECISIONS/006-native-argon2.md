# Decision 006 — native Argon2id with a pure-Dart fallback

**Date:** 2026-11-06
**Status:** accepted
**Supersedes:** the implicit choice of the pure-Dart `cryptography` Argon2id
implementation in `lib/vault.dart`.

## Context

The vault envelope is fixed at Argon2id, 64 MiB, t=3, p=4. The first
implementation used `package:cryptography`'s pure-Dart Argon2id. On the
release-check machine (2 cores, 3.8 GiB RAM, debug/JIT test mode) one
derivation took roughly **110 seconds**. Seven derivations in one test file
ended in a native test-device segmentation fault, so the full suite could not
be trusted even though the parameters were correct.

`dargon2_flutter` was already a direct dependency and its Linux bundle already
contains the reference `libargon2.so`, but the vault never used it. The system
also provides `libargon2.so.1`.

## Decision

1. Introduce `lib/kdf.dart` as the single Argon2id entry point.
2. Prefer the reference C library: the bundle's `lib/libargon2.so` first, then
   the platform `libargon2.so.1` / `argon2.dll` / macOS dylib.
3. Fall back to the pure-Dart `cryptography` implementation only when no
   native library can be loaded. The algorithm and parameters are identical;
   this is a performance path, not a security relaxation.
4. Keep the fixed production parameters at 64 MiB / t=3 / p=4 / 32-byte tag.
5. Add `test/kdf_production_test.dart`: fixed-parameter assertion, native vs
   independent pure-Dart agreement at 1 MiB, and one real 64 MiB vault
   round-trip with a 60 s performance guard.
6. Let envelope/format tests use `VaultCipher.debugKdfOverride`, installed
   through an `assert`-guarded setter so release builds compile it out.

## Consequences

- Measured native cost: **344 ms** for one 64 MiB / t=3 / p=4 derivation
  (2026-11-06, Ubuntu 24.04, 2 cores). The debug pure-Dart fallback remains
  ~110 s and must not be accepted for a release.
- Tests are fast and stable; `vault_test` dropped from ~14 minutes/segfault to
  ~10 seconds.
- The release must ship `libargon2.so` (the existing `dargon2_flutter` plugin
  provides it) or rely on a documented system package. The release checklist
  and `.deb` dependencies include `libsecret-1-0` and `liblzma5`; the bundled
  `libargon2.so` is part of the application directory.
- A native-library crash is a test failure, not a reason to lower parameters.
