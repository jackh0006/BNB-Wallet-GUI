# Cryptography

This is a summary and index. The authoritative byte-level specification is
[`docs/CRYPTO.md`](CRYPTO.md); the native-KDF decision is
[`docs/DECISIONS/006-native-argon2.md`](DECISIONS/006-native-argon2.md).

## Primitives

| Purpose | Primitive | Implementation |
|---|---|---|
| Password KDF | Argon2id v1.3, 64 MiB, t=3, p=4, 32-byte tag | Reference C library via `lib/kdf.dart`; pure-Dart `cryptography` fallback |
| Authenticated encryption | XChaCha20-Poly1305 | `package:cryptography` |
| Device key derivation | HKDF-SHA256 | `package:cryptography` |
| Hashing / checksums | SHA-256 | `package:crypto` |
| EVM signatures | secp256k1, low-s, EIP-155/EIP-1559 | `web3dart` / `wallet` |
| Address checksum | EIP-55 | `web3dart` + project validation |
| Mnemonic | BIP-39 | `bip39_mnemonic` |
| HD derivation | BIP-32/BIP-44 `m/44'/60'/0'/0/i` | `bip32_plus` |
| Cold serialization | Canonical EIP-1559 RLP | project code, cross-checked by ethers.js |

## Invariants

- Production Argon2 parameters are fixed; a malformed header is rejected before
  KDF allocation.
- Every AEAD box authenticates the 37-byte header as AAD.
- The password and device wrappers must recover the same DEK in constant time;
  disagreement fails closed.
- Encryption uses OS CSPRNG (`Random.secure`) for salts and nonces.
- No custom cryptographic algorithm is used. The only project serialization
  code is the EIP-1559 codec, because the available RLP helper mishandled byte
  strings.
- Native library loading failure falls back to the same algorithm in pure Dart;
  it never changes parameters.
- Dart garbage-collected memory is not claimed to be securely erased.

## Verification

- `test/kdf_production_test.dart` — fixed parameters, native vs pure-Dart
  agreement, one real 64 MiB round-trip (344 ms native).
- `test/vault_test.dart` — envelope, tamper, wrong password/device, v1
  migration, hostile header.
- `test/fuzz_and_property_test.dart` — parser totality and invariants.
- `verification/verify.cjs` — independent ethers.js parsing/recovery, eight
  substitution cases.
- `docs/SECURITY_AUDIT_2026-11-04.md` — self-audit findings.

## Limitations

- No independent cryptographic audit.
- No hardware-backed key storage.
- A compromised OS or same-UID attacker can read an unlocked process.
- The pure-Dart fallback is ~110 s per derivation and is not acceptable for a
  release; the gate measures the native path.
