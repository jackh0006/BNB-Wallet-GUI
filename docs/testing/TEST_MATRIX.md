# TEST_MATRIX.md — Comprehensive Test Coverage Matrix

**Date**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`

---

## Test Organization

| Category | Tag | Concurrency | Timeout | Purpose |
|----------|-----|-------------|---------|---------|
| **Light Suites** | (none) | 2 | 30s default | Unit, widget, integration (no KDF) |
| **KDF Suites** | `@Tags(['kdf'])` | 1 | 4-15 min | Real 64 MiB Argon2id derivations |

---

## Test Suite Inventory

### Core Cryptography

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `vault_test.dart` | 7 | `kdf` | ✅ PASS* | Vault v2 round-trip, wrong pw/dev, fresh nonce, downgraded params, no oracle, v1 migration |
| `workers_test.dart` | 3 | `kdf` | ✅ PASS* | Worker isolate encrypt/decrypt, wrong device key, pinHashJob format |
| `wallet_core_test.dart` | 12 | (light) | ✅ PASS | Mnemonic, derivation, address, signing, import |

*Individual tests pass with generous timeouts (8-15 min); full KDF suite OOM on 2-core 4GB

### Cold Wallet

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `cold_tx_codec_test.dart` | 4 | (light) | ✅ PASS | Canonical payload, digest, signed tx parsing, field validation |
| `cold_wallet_protocol_test.dart` | 15 | (light) | ✅ PASS | Pairing/request/signature envelopes, checksums, expiry, substitutions |
| `cold_wallet_service_test.dart` | 15 | (light) | ✅ PASS | Persistence, replay, signing, verification, broadcast, burn list |
| `cold_wallet_test.dart` | 8 | (light) | ✅ PASS | Existing cold wallet tests |

### Network & Privacy

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `tls_pinning_test.dart` | 6 | (light) | ✅ PASS | Standard validation + pin, pin cannot bypass CA/hostname, CONNECT refused |
| `privacy_dialogs_test.dart` | 2 | (light) | ✅ PASS | Proxy/Tor dialog options, URL parsing |
| `nodes_test.dart` | 14 | (light) | ✅ PASS | Node book CRUD, enable/disable, reset, test checklist |
| `node_manager_test.dart` | 10 | (light) | ✅ PASS | Pool selection, strict mode, import/export |
| `ua_scrub_test.dart` | 3 | (light) | ✅ PASS | User-Agent scrubbing on all transports |

### Transaction & Fees

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `fee_engine_test.dart` | 18 | (light) | ✅ PASS | Fee math, EIP-1559/legacy, multi-node merge, sanity clamp |
| `fee_parity_test.dart` | 6 | (light) | ✅ PASS | Terminal v1 parity, terminal arithmetic |
| `send_intent_test.dart` | 11 | (light) | ✅ PASS | Send flow validation, rehearsal, signing, broadcast |
| `tx_lifecycle_test.dart` | 8 | (light) | ✅ PASS | Journey stages, pending, receipt, narration |

### Storage & Security

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `encrypted_log_store_test.dart` | 5 | (light) | ✅ PASS | BNBLOG01 envelope, encryption, cap |
| `receipt_store_test.dart` | 10 | (light) | ✅ PASS | BNBRCPT1 envelope, encryption, cap, tamper detection |
| `erase_flow_test.dart` | 4 | (light) | ✅ PASS | Crypto-erasure, overwrite, preference wipe |
| `clipboard_guard_test.dart` | 5 | (light) | ✅ PASS | Secret detection (mnemonic, hex key), auto-clear |
| `drawer_secret_test.dart` | 6 | (light) | ✅ PASS | Device key memoization, fallback, migration |
| `memory_protection_test.dart` | 2 | (light) | ✅ PASS | Kernel state: dumpable=0, core limit=0 |

### UI & Navigation

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `widget_test.dart` | 3 | (light) | ✅ PASS | App launch, home tab, app lock |
| `navigation_flow_test.dart` | 8 | (light) | ✅ PASS | Unlock→send, unlock→wallet, no save dialogs |
| `create_wallet_dialog_test.dart` | 4 | (light) | ✅ PASS | Creation flow, seed entry, backup quiz |
| `backup_quiz_test.dart` | 5 | (light) | ✅ PASS | 3-word verification, creation + settings |
| `journey_map_test.dart` | 4 | (light) | ✅ PASS | 5-stop map, states, detail |
| `hold_to_confirm_test.dart` | 3 | (light) | ✅ PASS | Hold gesture, cancellation |

### Token & Assets

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `token_sources_test.dart` | 7 | (light) | ✅ PASS | Official sources, user links, CI checker |
| `watch_only_test.dart` | 4 | (light) | ✅ PASS | Watch-only import, send refusal, persistence |

### Logging & Misc

| Test File | Tests | Tag | Status | Coverage |
|-----------|-------|-----|--------|----------|
| `log_presenter_test.dart` | 6 | (light) | ✅ PASS | Simple/Expert modes, category/level mapping |
| `log_canary_test.dart` | 3 | (light) | ✅ PASS | Log canary integrity |
| `story_test.dart` | 5 | (light) | ✅ PASS | Narration, debounce, budget, cascade cut |
| `privacy_config_test.dart` | 4 | (light) | ✅ PASS | Proxy/Tor config persistence |
| `receipt_image_test.dart` | 3 | (light) | ✅ PASS | PNG rendering |

---

## Independent Verification (Non-Flutter)

| Test | Command | Status | Coverage |
|------|---------|--------|----------|
| **Cold-signature ethers.js** | `cd verification && npm ci && node verify.cjs` | ✅ PASS | Payload, digest, fields, r/s/yParity, hash, recovered signer, 8 substitutions |
| **Secret scan** | `bash scripts/secret-scan.sh` | ✅ PASS | No tracked keystores, PEM PKs, old password, inline Android pw, hardcoded keys |
| **Static analysis** | `flutter analyze --no-pub` | ✅ PASS | No errors (1 unused_element warning) |
| **SBOM freshness** | `python3 scripts/sbom.py --out docs/SBOM.json && git diff --exit-code` | ⏳ PENDING | SBOM committed and current |

---

## Test Execution Commands

```bash
# Full sequential-aware suite (as in CI)
bash scripts/test-suite.sh

# Manual phases:
flutter test --exclude-tags kdf --concurrency=2    # 209 tests, ~1.5 min
flutter test --tags kdf --concurrency=1            # 10 tests, ~10+ min (sequential)

# Individual KDF tests (with generous timeouts):
flutter test test/vault_test.dart --plain-name "VaultCipher v2 envelope round-trips" --timeout 8m
flutter test test/vault_test.dart --plain-name "VaultCipher v2 envelope rejects a wrong password" --timeout 8m
flutter test test/vault_test.dart --plain-name "VaultCipher v2 envelope rejects a wrong device secret" --timeout 8m
flutter test test/vault_test.dart --plain-name "VaultCipher v2 envelope unknown plaintexts differ" --timeout 8m
flutter test test/vault_test.dart --plain-name "VaultCipher v2 envelope rejects downgraded Argon2id" --timeout 8m
flutter test test/vault_test.dart --plain-name "VaultCipher v2 envelope does not leak which wrapper failed" --timeout 8m
flutter test test/vault_test.dart --plain-name "VaultCipher v1 migration legacy blobs stay readable" --timeout 8m
flutter test test/workers_test.dart --plain-name "vaultEncryptJob → vaultDecryptJob round-trips" --timeout 8m
flutter test test/workers_test.dart --plain-name "vaultDecryptJob refuses the wrong device key" --timeout 8m
flutter test test/workers_test.dart --plain-name "pinHashJob keeps the exact v1.0.4 record format" --timeout 15m

# Independent verification:
cd verification && npm ci && node verify.cjs

# Security scans:
bash scripts/secret-scan.sh
flutter analyze --no-pub
```

---

## Resource Requirements

| Test Type | RAM | CPU | Time (2-core 4GB) | Notes |
|-----------|-----|-----|-------------------|-------|
| Light suites (209 tests) | ~1 GB | 2 cores | ~90 seconds | Concurrent 2-wide |
| KDF suite (10 tests) | ~3 GB peak | 1 core | ~2.5 hours (OOM) | Sequential; each Argon2id ~1m45s |
| Individual KDF test | ~500 MB | 1 core | 1-3 minutes | With 8-15 min timeout |

---

## Coverage Gaps (Not Tested)

| Area | Gap | Reason |
|------|-----|--------|
| **Two-device cold wallet** | Physical exchange | No second device |
| **Anvil/local chain integration** | Real broadcast test | `anvil` not installed |
| **Hardware wallet** | Ledger/Trezor/SafePal | No physical devices |
| **Linux QR camera** | Camera scanning | Plugin not integrated |
| **Atomic vault write (crash sim)** | Power loss during rename | Manual only |
| **Backup/restore** | Encrypted export/import | Manual only |
| **Android build** | APK creation | Requires external keystore |
| **.deb install** | Clean VM test | VM access needed |
| **Reproducible build** | Two-build comparison | Toolchain not pinned |
| **Network leak (packet capture)** | Wireshark/tcpdump verification | Controlled infra needed |

---

## CI Pipeline (`.github/workflows/verify.yml`)

```yaml
jobs:
  secret-scan:     # scripts/secret-scan.sh
  flutter:         # analyze + test-suite.sh
  cold-signature:  # verification/verify.cjs (ethers.js)
  sources-and-sbom: # check_token_sources.py + sbom.py + git diff SBOM
```

All jobs must pass for merge.

---

## Evidence Collection

| Evidence | Location | Generated By |
|----------|----------|--------------|
| Test logs | `docs/evidence/test-results-<date>.log` | `scripts/test-suite.sh` redirect |
| Build logs | `docs/evidence/build-<date>.log` | `scripts/build-deb.sh` / `build-apk.sh` |
| Secret scan | `docs/evidence/secret-scan-<date>.log` | `scripts/secret-scan.sh` |
| Analyzer | `docs/evidence/analyze-<date>.log` | `flutter analyze --no-pub` |
| Packet captures | `docs/evidence/pcap-<date>.pcapng` | Manual (Wireshark/tcpdump) |
| SBOM | `docs/SBOM.json` | `scripts/sbom.py` |

---

*This matrix is updated at every test run. Green = automated test passes; Yellow = implemented but not auto-tested; Red = not implemented.*