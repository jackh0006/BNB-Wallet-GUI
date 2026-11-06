# Implementation Log

Chronological, evidence-bound record. Do not rewrite history here; append new
entries and mark superseded claims.

## 2026-11-06 — release/1.0.10 candidate

**Code commit:** `e474b8956a68febf44ef780c7decf898e9050018`
**Final candidate HEAD:** `142929315b7df572ffae93cbc5ab1a2ec2395724`
**PR:** <https://github.com/jackh0006/BNB-Wallet-GUI/pull/10>

### Cryptography and transaction fixes

- Wired the reference native Argon2id library into `lib/kdf.dart`, with an
  explicit pure-Dart fallback. Measured 344 ms for 64 MiB / t=3 / p=4.
- Added `test/kdf_production_test.dart`: fixed parameters, native vs pure-Dart
  agreement at 1 MiB, one real 64 MiB round-trip under a 60 s guard.
- Envelope/format tests use `VaultCipher.debugKdfOverride` (assert-guarded,
  compiled out of release).
- Fixed `SendIntent.decodeErc20Transfer` to require exact 4+32+32-byte
  calldata; added a trailing-byte regression test.

### Test stability

- Navigation fixture is offline and awaits real storage I/O through
  `runAsync`; HomePage no longer starts real RPC timeouts.
- Storage teardown flushes encrypted-log appends and retries `ENOTEMPTY`.
- Full suite: 47 files / 299 declarations, 47/47 passed locally in 577 s.
- Hosted CI: full suite passes in both push and PR runs.

### Evidence and CI

- Added `release/manifest.json`, `docs/testing/test-inventory.json`,
  `docs/GENERATED_STATUS.md`, generated README status block,
  `scripts/release-gate.py`, `scripts/record_check.py`, `scripts/test_inventory.py`,
  `scripts/release_manifest.py`, and `scripts/generate_docs.py`.
- Added workflows: `dependency-review`, `docs-sync`, `release-build`
  (provenance + SBOM attestations), `reproducibility`, `scheduled-security`.
- Branch protection now also requires `generated-files` and `review`.

### Android incident

- Recorded the historical `scripts/release.keystore` exposure in
  `docs/security/INCIDENT_2026-11-KEYSTORE.md`.
- Added `scripts/verify-android-signer.sh` and
  `release/android-signer-denylist.txt`.
- `scripts/build-apk.sh` requires owner approval, an approved signer, and a
  populated denylist; Android remains blocked.

### Reproducibility investigation

- Two worktrees at different paths differed in `bnb_wallet_gui`,
  `libapp.so`, and three plugin `.so` files.
- `strings` showed `libapp.so` embeds
  `file:///<path>/.dart_tool/flutter_build/dart_plugin_registrant.dart`, and
  plugins embed `<path>/linux/flutter/ephemeral`.
- `readelf -n` confirmed different linker build IDs.
- Rebuilding twice in the same path was identical except one stale
  `native_assets.json`.
- Two clean builds at the same fixed path `/tmp/bnb-repro-final` produced
  identical files and, with `SOURCE_DATE_EPOCH=0` and `gzip -n`, identical
  archives: `134e6b064dcc22b57a23136031b3224b6594af2f9efeb2ad388dfc3b2e6c86d4`.
- Constraint documented: different absolute build paths are not guaranteed to
  match; independent-machine proof is still required.

### Artifact

- Built unsigned `bnb-wallet-1.0.10-amd64.deb` from the final docs state.
- SHA-256: `734ccd3bbf0754db6c67f8b00d484d6c0751001883cd18a9112a33fa680cf088`.
- `dpkg-deb -x` + `ldd` resolve all libraries; no secret-bearing filenames.
- Not signed, not installed, not published.

### Continuation — durable records and reproducibility fix

- Added `IMPLEMENTATION_STATUS.md`, `docs/IMPLEMENTATION_LOG.md`,
  `docs/SECURITY_SCORECARD.md`, `docs/SECURITY_RISK_REGISTER.md`,
  `docs/TEST_RESULTS.md`, `docs/RELEASE_PROCESS.md`,
  `docs/RELEASE_VERIFICATION.md`, `docs/COMPATIBILITY.md`,
  `docs/BACKUP_AND_RECOVERY.md`, `docs/INCIDENT_RESPONSE.md`,
  `docs/CRYPTOGRAPHY.md`, `docs/TRANSACTION_SECURITY.md`,
  `docs/SUPPLY_CHAIN_SECURITY.md`, and `docs/SECURITY_AUDIT.md`.
- Added `docs/evidence/2026-11-06/` with environment, CI checks, suite summary,
  reproducibility log, same-path diff, and package hash.
- Reworked `scripts/reproducibility-check.sh` to use a fixed absolute build
  path, `SOURCE_DATE_EPOCH=0`, and `gzip -n`.
- Reproducibility result: PASS at `/tmp/bnb-repro-final`, archive
  `388f94bf…`; different absolute paths still differ.
- Provisional self-assessed score: **73/100**, with release blockers listed.
- Added the three-pass self-audit (`docs/SELF_AUDIT_2026-11-06.md`) and an
  independent-review guide (`docs/INDEPENDENT_REVIEW_GUIDE.md`).

## Superseded claims

- “Reproducibility FAILED” (earlier 2026-11-06 entry) is superseded by the
  fixed-path pass above. Different-path builds still differ; the earlier
  failure was real and is retained as investigation history.
