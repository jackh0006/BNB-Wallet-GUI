# Independent Review Guide

This guide is for an external reviewer. It is not a claim that a review has
occurred. The project is self-assessed; an independent audit is still absent.

## Scope

- Linux amd64 Flutter/Dart wallet for BNB Smart Chain.
- Vault encryption and recovery.
- Native/pure-Dart Argon2id backend.
- Transaction construction, review, signing, broadcast.
- Cold-wallet envelopes and independent byte verification.
- Network/TLS/Tor behavior.
- Release tooling, reproducibility, and supply chain.

Out of scope unless separately agreed: Android APK signing (blocked), hardware
wallets (not implemented), a professional multisig deployment, and real-money
transactions.

## Evidence to start from

| Evidence | Location |
|---|---|
| Manifest / toolchain / hashes | `release/manifest.json` |
| Scorecard | `docs/SECURITY_SCORECARD.md` |
| Threat model | `docs/THREAT_MODEL.md` |
| Risk register | `docs/SECURITY_RISK_REGISTER.md` |
| Self-audit | `docs/SELF_AUDIT_2026-11-06.md` |
| Test results | `docs/TEST_RESULTS.md` |
| Implementation log | `docs/IMPLEMENTATION_LOG.md` |
| Cryptographic spec | `docs/CRYPTO.md` |
| Transaction security | `docs/TRANSACTION_SECURITY.md` |
| Supply chain | `docs/SUPPLY_CHAIN_SECURITY.md` |
| Release verification | `docs/RELEASE_VERIFICATION.md` |
| Incident record | `docs/security/INCIDENT_2026-11-KEYSTORE.md` |

## Commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
(cd verification && npm ci && node verify.cjs)
python3 scripts/dependency-audit.py
python3 scripts/license-check.py
python3 scripts/sbom.py --out docs/SBOM.json
python3 scripts/test_inventory.py --check
python3 scripts/release_manifest.py --check
python3 scripts/generate_docs.py --check
python3 scripts/release-gate.py
```

`package-smoke` and the full suite are also run on GitHub Actions; the exact
run IDs are in `docs/TEST_RESULTS.md`.

## High-value review targets

1. `lib/vault.dart` — envelope layout, AAD, nonce/salt generation, v1 path.
2. `lib/kdf.dart` — native loading, fallback equivalence, parameter integrity.
3. `lib/send_intent.dart` — exact calldata and field binding.
4. `lib/cold_tx_codec.dart` — canonical RLP, low-s, bounds, re-encode check.
5. `lib/cold_wallet_protocol.dart` / `cold_wallet_service.dart` — replay,
   expiry, substitution, broadcast.
6. `lib/storage.dart` / `lib/posix_fs.dart` — atomic writes, symlinks,
   rollback, locking.
7. `lib/net/privacy_client.dart` — TLS validation order, pins, SOCKS/Tor.
8. `lib/rpc_service.dart` — chain-ID checks, timeouts, broadcast ambiguity.
9. `.github/workflows/*` and `scripts/*` — permissions, pins, release gate.

## Questions the reviewer should answer

- Can a modified vault, backup, or cold envelope cause code execution, a crash,
  or a false success?
- Can a malicious RPC cause a wrong-chain or wrong-field signature?
- Can the reviewed transaction change between review and signing?
- Can a failed backup/migration destroy a known-good vault?
- Can an artifact be published without the exact commit, signature, and gate?
- Is the reproducibility claim limited to the documented fixed-path case?
- Are any security claims unsupported by code or tests?

## Access and disclosure

Report privately to `jackh109867@gmail.com`. Do not request seeds, private
keys, or vault passwords. Use synthetic wallets and test funds only.
