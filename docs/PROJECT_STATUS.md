# PROJECT_STATUS.md — Current Project State

**Last Updated**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`
**Current Milestone**: M3 — Local Encrypted Storage
**Previous Milestone**: M2 — Linux Application Foundation (COMPLETE)

---

## Completed Tasks (with Evidence)

| Task | Status | Evidence Location |
|------|--------|-------------------|
| **M0-01**: AGENTS.md | ✅ DONE | `AGENTS.md` |
| **M0-02**: BASELINE.md | ✅ DONE | `docs/project/BASELINE.md` |
| **M0-03**: PROJECT_MASTER_PLAN.md | ✅ DONE | `docs/PROJECT_MASTER_PLAN.md` |
| **M0-05**: THREAT_MODEL.md (updated) | ✅ DONE | `docs/THREAT_MODEL.md` |
| **M1-01**: Cold EIP-1559 codec | ✅ DONE | `lib/cold_tx_codec.dart`, `test/cold_tx_codec_test.dart` (4/4) |
| **M1-02**: Cold protocol envelopes | ✅ DONE | `lib/cold_wallet_protocol.dart`, `test/cold_wallet_protocol_test.dart` (15/15) |
| **M1-03**: Cold wallet service | ✅ DONE | `lib/cold_wallet_service.dart`, `test/cold_wallet_service_test.dart` (15/15) |
| **M1-04**: Strict response verification | ✅ DONE | `lib/wallet_core.dart::verifyColdSignatureDetailed` |
| **M1-05**: Independent ethers.js verification | ✅ DONE | `verification/verify.cjs` (ethers 6.13.2) |
| **M1-06**: TLS SPKI pinning (standard first) | ✅ DONE | `lib/net/privacy_client.dart`, `test/tls_pinning_test.dart` (6/6) |
| **M1-07**: Fixed v3 cert SPKI index bug | ✅ DONE | Was hashing extensions (idx 7), now public key (idx 6) |
| **M1-08**: Memory hardening (FFI) | ✅ DONE | `lib/memory_protection.dart`, `test/memory_protection_test.dart` (2/2) |
| **M1-09**: Release hygiene (keystore, env-only) | ✅ DONE | `scripts/build-apk.sh`, `.gitignore`, `scripts/secret-scan.sh` |
| **M1-10**: Cold account-index signing | ✅ DONE | `ColdWalletService.signRequest` derives matching index |
| **M1-11**: Test stability fixes | ✅ DONE | Keyring timeout, dialog `isExpanded=true` |
| **M1-12**: Security documentation updates | ✅ DONE | `SECURITY_AUDIT.md`, `COLD_WALLET.md`, `TESTING.md`, etc. |
| **M2-01**: Verify `flutter build linux --release` | ✅ DONE | Built `build/linux/x64/release/bundle/bnb_wallet_gui` |
| **M2-02**: Linux desktop integration (launcher, icon) | ✅ DONE | `.desktop` file in .deb, icon in assets |
| **M2-03**: Run `scripts/build-deb.sh` end-to-end | ✅ DONE | Produced `bnb-wallet-1.0.7-amd64.deb` |
| **M2-04**: Install .deb on clean Ubuntu VM | ⚠️ NOT TESTED | Clean VM not available |
| **M2-05**: Verify .deb contents (no secrets, perms) | ✅ DONE | `dpkg -c` — no secrets, correct perms |
| **M2-06**: SHA-256 + GPG signature on .deb | ✅ DONE | `.sha256` + `.asc` (verified good) |
| **M2-07**: Document build reproducibility | ⚠️ NOT TESTED | Toolchain not pinned |

---

## Tested Tasks (Automated Tests Passing)

| Suite | Count | Result | Notes |
|-------|-------|--------|-------|
| **Non-KDF full suite** | 209 | ✅ PASS | `flutter test --exclude-tags kdf --concurrency=2` |
| **cold_tx_codec_test** | 4 | ✅ PASS | Canonical EIP-1559 codec |
| **cold_wallet_protocol_test** | 15 | ✅ PASS | Envelopes, checksums, expiry, substitutions |
| **cold_wallet_service_test** | 15 | ✅ PASS | Persistence, replay, broadcast, verification |
| **cold_wallet_test** | 8 | ✅ PASS | Existing cold wallet tests |
| **tls_pinning_test** | 6 | ✅ PASS | Standard validation + pin, CONNECT refused |
| **memory_protection_test** | 2 | ✅ PASS | Kernel state: dumpable=0, core limit=0 |
| **privacy_dialogs_test** | 2 | ✅ PASS | Proxy/Tor dialogs |
| **widget_test** | 3 | ✅ PASS | App launch, home tab |
| **verification/verify.cjs** | 1 script | ✅ PASS | 8 field substitutions rejected |
| **secret-scan.sh** | 1 scan | ✅ PASS | No tracked keystores/PKs/passwords |
| **flutter analyze** | — | ✅ NO ERRORS | 1 unused_element warning |

---

## Incomplete Tasks (Current Milestone M3)

| Task ID | Description | Status | Blockers |
|---------|-------------|--------|----------|
| **M3-01** | Vault creation UI (path selection, password) | ✅ DONE (existing) | M2 |
| **M3-02** | Vault path management (move, rename, switch) | ✅ DONE (backend) | M2 |
| **M3-03** | Password change (re-encrypt with new salt) | ✅ DONE (backend) | M2 |
| **M3-04** | Encrypted backup (export/import) | ✅ DONE (backend - security hardened) | M2 |
| **M3-05** | Vault integrity verification | ✅ DONE (part of export/import) | M2 |
| **M3-06** | Storage usage display | ⏳ PENDING | M2 |
| **M3-07** | Secure deletion workflow (crypto-erase + overwrite) | ✅ DONE (existing) | M2 |
| **M3-08** | Multiple vault support | ⏳ PENDING | M2 |

---

## Blocked Tasks

| Task ID | Description | Blocker | Resolution Path |
|---------|-------------|---------|-----------------|
| **BLK-01** | KDF tests OOM on 2-core 4GB | Memory exhaustion | Run individually with 8-15 min timeouts; documented |
| **BLK-02** | Two-device physical cold-wallet test | No second device | File/paste/QR tested in code; mark NOT TESTED |
| **BLK-03** | Local Anvil integration test | `anvil` not installed | Install Foundry or use CI runner |
| **BLK-04** | Hardware wallet compatibility | No physical devices | Architecture first; test when devices available |
| **BLK-05** | Linux QR camera scanning | Camera plugin not integrated | Add `camera` plugin; implement scanner |
| **BLK-06** | Old release keystore in Git history | **COMPROMISED** — cannot rewrite public history | Rotate key operationally; new keystore outside repo |
| **BLK-07** | `mlockall` best-effort failure | Low RLIMIT_MEMLOCK | Test asserts dumpable=0, core=0 only |
| **BLK-08** | HTTP CONNECT with pins refused | Not enforced, only refused | Document as limitation; future: pin CONNECT |

---

## Latest Successful Build

| Metric | Value |
|--------|-------|
| **Flutter Version** | 3.47.6 (stable) |
| **Dart Version** | 3.13.5 |
| **Last Clean Build** | 2026-11-03 — `flutter build linux --release` ✅ |
| **Last .deb Build** | 2026-11-03 — `bnb-wallet-1.0.7-amd64.deb` (9.5 MB) |
| **Package Verify** | `dpkg -c` — no secrets, correct perms ✅ |
| **Checksum** | `c668ebdfdcb948fadcc4e0f722e323a17e357e37934033353d886296cda1158f` |
| **GPG Signature** | Verified (EDDSA key CC819EF5E109A1518E840379D8C0CEC84BCCE06B) |
| **Last Test Run** | 2026-11-03 (non-KDF: 209 pass) |
| **Analyzer** | No errors |
| **Secret Scan** | Clean |

---

## Latest Test Results (2026-11-03)

```
flutter test --exclude-tags kdf --concurrency=2
→ 209 tests passed (0 failed, 0 skipped)
Exit code: 0

flutter test --tags kdf --concurrency=1
→ Resource exhaustion (OOM) after ~2.5 hours on 2-core 4GB
→ Individual tests pass with generous timeouts (8-15 min)
→ Documented in BASELINE.md and SECURITY_AUDIT.md

cd verification && npm ci && node verify.cjs
→ PASS: payload, digest, fields, r/s/yParity, hash, recovered signer
→ 8 substitution cases rejected (recipient, value, chain, nonce, gas, fees, calldata)

bash scripts/secret-scan.sh
→ PASS: No tracked keystores, PEM private keys, old password, inline Android passwords, hardcoded 32-byte keys
```

---

## Outstanding Security Concerns

| ID | Concern | Severity | Mitigation |
|----|---------|----------|------------|
| **SEC-01** | Old release keystore compromised | CRITICAL | Must rotate; new keystore outside repo; users reinstall |
| **SEC-02** | No third-party audit | HIGH | Internal self-audit only (SECURITY_AUDIT.md); state clearly |
| **SEC-03** | No two-device cold test | MEDIUM | Code tested; mark NOT TESTED in claims |
| **SEC-04** | No Anvil integration test | MEDIUM | Fake RPC used; mark NOT TESTED |
| **SEC-05** | Hardware wallet unverified | MEDIUM | Matrix NOT TESTED; no false claims |
| **SEC-06** | KDF resource exhaustion on weak HW | MEDIUM | Documented; tests pass individually; not a security flaw |
| **SEC-07** | `mlockall` may fail silently | LOW | Test asserts kernel state only; best-effort documented |
| **SEC-08** | HTTP CONNECT pins refused not enforced | LOW | Documented limitation; no silent downgrade |

---

## Next Exact Actions

1. **Implement vault backup/restore UI** — Add "Export vault" and "Import vault" options in wallet management
2. **Implement password change UI** — Add "Change vault password" option
3. **Implement vault info display** — Show vault path, size, custom/default status
4. **Implement vault path management UI** — Add "Move vault" and "Reset path" options in wallet management
5. **Run full test suite** after each UI component

---

## Documentation Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| `AGENTS.md` | ✅ CURRENT | 2026-11-03 |
| `BASELINE.md` | ✅ CURRENT | 2026-11-03 |
| `PROJECT_MASTER_PLAN.md` | ✅ CURRENT | 2026-11-03 |
| `PROJECT_STATUS.md` | ✅ CURRENT | 2026-11-03 |
| `SECURITY_AUDIT.md` | ✅ CURRENT | 2026-11-03 |
| `docs/COLD_WALLET.md` | ✅ CURRENT | 2026-11-03 |
| `docs/TESTING.md` | ✅ CURRENT | 2026-11-03 |
| `docs/THREAT_MODEL.md` | ✅ CURRENT | 2026-11-03 |
| `docs/CRYPTO.md` | ✅ CURRENT | 2026-11-03 |
| `docs/SECURITY.md` | ✅ CURRENT | 2026-11-03 |
| `docs/SPEC-COMPLIANCE.md` | ✅ CURRENT | 2026-11-03 |
| `docs/ARCHITECTURE.md` | ✅ CURRENT | 2026-11-03 |
| `docs/CHANGELOG.md` | ✅ CURRENT | 2026-11-03 |
| `README.md` | ✅ CURRENT | 2026-11-03 |
| **Security docs (new)** | 🔄 IN PROGRESS | See below |
| **Testing docs (new)** | 🔄 IN PROGRESS | See below |
| **Hardware/Network docs (new)** | 🔄 IN PROGRESS | See below |

---

## New Documentation In Progress (M0 deliverables)

| File | Status | Target |
|------|--------|--------|
| `docs/security/SECURITY_CLAIMS.md` | ✅ DONE | 2026-11-03 |
| `docs/security/NETWORK_PRIVACY_MODEL.md` | ✅ DONE | 2026-11-03 |
| `docs/security/STORAGE_SECURITY.md` | ✅ DONE | 2026-11-03 |
| `docs/security/RELEASE_SECURITY.md` | ✅ DONE | 2026-11-03 |
| `docs/testing/TEST_MATRIX.md` | ✅ DONE | 2026-11-03 |
| `docs/hardware/COMPATIBILITY_MATRIX.md` | ✅ DONE | 2026-11-03 |
| `docs/network/NETWORK_GUIDE.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/001-pure-dart-crypto.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/002-cold-wallet-protocol.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/003-tls-pinning-standard-first.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/004-memory-hardening-ffi.md` | ✅ DONE | 2026-11-03 |

---

*Update this file at every milestone completion. Record actual outputs, not expectations.*