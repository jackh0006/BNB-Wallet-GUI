# DECISION-001: Pure Dart Crypto Core (No Rust FFI)

**Date**: 2026-11-03
**Status**: ACCEPTED
**Authors**: jackh0006

## Context

The original wallet spec called for a Rust crypto core bridged via `flutter_rust_bridge` to isolate secrets in a memory-safe language with deterministic signing.

## Decision

**Use pure Dart for all cryptographic operations** (`lib/wallet_core.dart`, `lib/vault.dart`, `lib/cold_tx_codec.dart`, `lib/workers.dart`).

## Rationale

1. **Reviewability**: Entire crypto stack is in Dart — any AGPL deb user can read and audit without Rust toolchain
2. **No FFI attack surface**: No native libraries, no JNI/FFI bugs, no platform-specific binaries in the deb
3. **Reproducible builds**: Standard `flutter build linux` with pinned Dart/Flutter versions
4. **Worker isolates solve UI freeze**: `compute()` moves Argon2id to background isolate — byte-identical output, same security
5. **Maintained dependencies**: `cryptography` (Argon2id, XChaCha20-Poly1305, HKDF), `web3dart`/`wallet` (secp256k1, BIP-32/44, EIP-55) are well-reviewed
6. **Cold codec cross-checked**: `verification/verify.cjs` (ethers.js 6.17.0) independently verifies EIP-1559 serialization

## Trade-offs

| Pro | Con |
|-----|-----|
| Simpler build, smaller attack surface | No hardware-enforced memory isolation |
| Full source review in Dart | GC timing side-channels (mitigated by worker isolates) |
| Cross-platform without native builds | `mlockall` best-effort only |
| Faster iteration | Relies on Dart VM constant-time ops |

## Revisit Conditions

- Third-party audit finds Dart-side crypto deficiency unfixable in Dart
- Hardware wallet integration requires FFI anyway (then isolate FFI to transport only)
- Post-quantum migration needs Rust primitives not yet in Dart ecosystem

## Related

- `docs/ARCHITECTURE.md` (Language decision section)
- `docs/THREAT_MODEL.md` (Compromised OS section)
- `docs/security/SECURITY_CLAIMS.md` (Cryptographic claims)
