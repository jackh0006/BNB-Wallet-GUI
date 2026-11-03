# AGENTS.md — Persistent Instructions for All OpenCode Sessions

## Product Mission

**BNB Wallet** — A complete, professional, highly secure, privacy-focused, self-custodial, open-source BNB/EVM wallet with:

- Local encrypted storage (vaults)
- Tor and proxy support (HTTP, HTTPS, SOCKS5)
- Hardware wallet and cold wallet support
- Comprehensive BNB Smart Chain / EVM blockchain functionality
- Transparent, encrypted local activity logs
- Beautiful, exceptionally easy user experience (black/dark theme, orange/yellow accent)
- First release: Ubuntu Linux amd64 `.deb`
- Future: Android APK

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          BNB Wallet GUI (Flutter/Dart)                  │
├─────────────────────────────────────────────────────────────────────────┤
│  UI Layer (lib/screens/, lib/widgets/)                                  │
│  ├── Dashboard / Home                                                   │
│  ├── Wallets / Vault Management                                         │
│  ├── Assets / Token Management                                          │
│  ├── Send / Receive / Fee Selection                                     │
│  ├── Transaction History / Explorer                                     │
│  ├── Hardware Wallet / Cold Wallet                                      │
│  ├── Network Settings / Tor / Proxy                                     │
│  ├── Storage / Backup / Password                                        │
│  ├── Activity Center / Security Center                                  │
│  └── Settings                                                           │
├─────────────────────────────────────────────────────────────────────────┤
│  Core Services (lib/)                                                   │
│  ├── app_state.dart         — Central state (ChangeNotifier)            │
│  ├── wallet_core.dart       — Pure crypto/validation (BIP-39/44, EIP-55)│
│  ├── vault.dart             — Encrypted vault (Argon2id + XChaCha20)    │
│  ├── storage.dart           — Preferences + secure storage              │
│  ├── cold_wallet*.dart      — Cold wallet protocol & service            │
│  ├── rpc_service.dart       — RPC engine, node management               │
│  ├── fee_engine.dart        — Fee estimation (EIP-1559 + legacy)        │
│  ├── tx_lifecycle.dart      — Send journey (rehearse→sign→broadcast)    │
│  ├── receipt_store.dart     — Encrypted receipt archive                 │
│  ├── encrypted_log_store.dart — Encrypted activity logs                 │
│  ├── net/privacy_client.dart — Central network layer (TLS, proxy, Tor)  │
│  ├── memory_protection.dart — FFI kernel hardening (Linux)              │
│  └── workers.dart           — Isolate-based KDF (Argon2id off UI thread)│
├─────────────────────────────────────────────────────────────────────────┤
│  Platform                                                               │
│  ├── Linux: flutter build linux → .deb (build-deb.sh)                   │
│  └── Android: flutter build apk → .apk (build-apk.sh, env-only signing) │
└─────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
/home/mhh06/BNB-Wallet-GUI/
├── AGENTS.md                    # This file
├── pubspec.yaml / pubspec.lock
├── analysis_options.yaml
├── dart_test.yaml
├── README.md
├── SECURITY_AUDIT.md
├── LICENSE (AGPL-3.0-or-later)
├── .gitignore
├── .github/workflows/verify.yml
├── scripts/
│   ├── build-apk.sh        # Android (requires env vars, no committed keystore)
│   ├── build-deb.sh        # Linux .deb release
│   ├── test-suite.sh       # Sequential test runner (KDF tests separate)
│   ├── secret-scan.sh      # CI secret scanning
│   ├── check_token_sources.py
│   └── sbom.py
├── lib/                    # All Dart source
├── test/                   # Flutter tests (unit + widget)
├── verification/           # Independent ethers.js cold-signature verification
├── docs/
│   ├── project/            # BASELINE.md, etc.
│   ├── security/           # THREAT_MODEL, SECURITY_CLAIMS, etc.
│   ├── testing/            # TEST_MATRIX.md
│   ├── hardware/           # COMPATIBILITY_MATRIX.md
│   ├── network/            # NETWORK_GUIDE.md
│   ├── DECISIONS/          # Architectural decisions
│   ├── evidence/           # Test reports, build metadata (NO SECRETS)
│   └── *.md                # Existing docs (ARCHITECTURE, CRYPTO, etc.)
├── assets/
│   ├── icon/               # App icons
│   └── token_sources.json
├── linux/                  # Flutter Linux config
├── android/                # Flutter Android config
└── build/                  # Build outputs (gitignored)
```

## Coding Conventions

- **Dart**: Follow `analysis_options.yaml` (flutter_lints + custom rules)
- **No `dart:io` in pure logic** — use platform-agnostic interfaces
- **No direct `http`/`HttpClient` in business logic** — all network via `RpcService`/`privacy_client.dart`
- **Secrets never in logs, URLs, or SharedPreferences** — only `flutter_secure_storage`
- **Worker isolates for Argon2id** — `workers.dart` via `compute()`
- **Immutable data classes** — `@immutable`, `final` fields, `const` constructors
- **Fail closed** — any validation error stops the operation
- **Explicit error types** — custom exceptions with stable messages
- **Documentation comments** on all public APIs

## Security Invariants

1. **Seed/private keys never leave local signing boundary**
   - No network transmission, no clipboard, no logs, no URLs
   - `ClipboardGuard.secretFree()` blocks seed-shaped text
2. **Vault encryption**: Argon2id (64 MiB, t=3, p=4) + XChaCha20-Poly1305, double-wrapped (password + device-bound secret)
3. **Cold wallet**: Offline signer has no network; online companion has no keys; pairing/request/response envelopes are versioned, checksummed, field-allowlisted
4. **TLS pinning**: Standard CA/hostname validation FIRST, then SPKI pin; never bypass validation
5. **Memory hardening (Linux)**: `prctl(PR_SET_DUMPABLE,0)`, `setrlimit(RLIMIT_CORE,0)`, best-effort `mlockall` via FFI
6. **No committed secrets**: `secret-scan.sh` runs in CI; `.gitignore` blocks keystores, `.jks`, `.p12`, `.pfx`, `key.properties`
7. **Offline mode enforced at network layer**: `NetworkPrivacyManager` blocks all outbound
8. **Strict privacy mode**: All traffic through configured route (Tor/proxy); fail closed; no silent fallback

## Network Invariants

1. **Single choke point**: All outbound via `lib/net/privacy_client.dart` → `RpcService`
2. **Supported transports**: Direct HTTPS, HTTP/HTTPS proxy (CONNECT), SOCKS5 (with auth), Tor (system daemon), Tor bridges
3. **DNS leak prevention**: SOCKS5h / Tor remote resolution; no local DNS before proxy
4. **Certificate validation never disabled**: Even with pins, standard validation runs first
5. **HTTP CONNECT with pins**: Refused before socket opens (not silently downgraded)
6. **No identifying headers**: `User-Agent` scrubbed; only `Content-Type`/`Accept`
7. **RPC chain ID validated on every connect**: Mismatch blocks the node

## Storage Invariants

1. **Vault location**: `$XDG_DATA_HOME/bnb-wallet/` (Linux), app documents (Android)
2. **Vault format**: `BNBVL004` (v2) — double AEAD, authenticated header, atomic write (tmp→rename), 0600 perms
3. **Legacy v1 (`BNBVL003`)**: Read-only migration on next save
4. **Secrets only in secure storage**: `device_secret_v2`, `app_lock_pin_hash`, `app_lock_backoff`, `bscscan_api_key`
5. **Preferences only public config**: Network, RPC nodes, tokens, profiles, auto-lock, Tor settings
6. **Activity logs encrypted at rest**: `BNBLOG01` envelope, wallet key + device secret
7. **Receipts encrypted at rest**: `BNBRCPT1` envelope, capped at 200 entries
8. **Erase all data**: Crypto-erasure (delete device secret) + best-effort overwrite + preference wipe

## Test Commands

```bash
# Full test suite (sequential-aware)
bash scripts/test-suite.sh

# Manual phases:
flutter test --exclude-tags kdf --concurrency=2    # Light suites (2-wide)
flutter test --tags kdf --concurrency=1            # KDF suites (sequential)

# Individual suites:
flutter test test/cold_wallet_protocol_test.dart
flutter test test/cold_wallet_service_test.dart
flutter test test/tls_pinning_test.dart
flutter test test/memory_protection_test.dart
flutter test test/vault_test.dart
flutter test test/workers_test.dart

# Static analysis
flutter analyze --no-pub

# Secret scan
bash scripts/secret-scan.sh

# Independent cold-signature verification (ethers.js)
cd verification && npm ci && node verify.cjs

# SBOM generation
python3 scripts/sbom.py --out docs/SBOM.json
```

## Build Commands

```bash
# Linux .deb release
bash scripts/build-deb.sh
# Output: /home/mhh06/Downloads/BNB Wallet/bnb-wallet-<version>-amd64.deb (+ .sha256 + .asc)

# Android APK (requires external keystore via env)
export BNB_KEYSTORE=/path/to/release.keystore
export BNB_KEY_ALIAS=myalias
export BNB_STORE_PASS=storepass
export BNB_KEY_PASS=keypass
bash scripts/build-apk.sh
# Output: ./dist/bnb-wallet-<version>-android-arm64.apk (+ .sha256 + optional .asc)
```

## Release Procedure

1. **Version bump** in `pubspec.yaml`
2. **Run full verification**: `flutter analyze`, `bash scripts/test-suite.sh`, `bash scripts/secret-scan.sh`, `cd verification && npm ci && node verify.cjs`
3. **Update CHANGELOG.md**
4. **Regenerate SBOM**: `python3 scripts/sbom.py --out docs/SBOM.json`
5. **Build Linux .deb**: `bash scripts/build-deb.sh` (sign with GPG key)
6. **Verify .deb**: Install on clean Ubuntu, test launch, vault, send, network
7. **Tag release**: `git tag -s v1.x.y -m "Release v1.x.y"`
8. **Push**: `git push origin main --tags`
9. **Android (separate)**: Use `build-apk.sh` with env credentials; never commit keystore

## Documentation Requirements

Every meaningful change must update:
- `CHANGELOG.md` (user-facing changes)
- `docs/PROJECT_STATUS.md` (current state)
- Relevant technical doc (CRYPTO, THREAT_MODEL, SECURITY, SPEC-COMPLIANCE, etc.)
- `docs/DECISIONS/` for architectural decisions

## Current Blockers (as of 2026-11-03)

| ID | Blocker | Status |
|----|---------|--------|
| BLK-01 | KDF tests exhaust memory on 2-core 4GB machine | Documented; tests pass individually with generous timeouts |
| BLK-02 | No two-device physical cold-wallet test | Requires second device; file/paste/QR tested in code |
| BLK-03 | No local Anvil integration test | `anvil` not installed; fake RPC used in tests |
| BLK-04 | Hardware wallet compatibility unverified | No physical devices; matrix is NOT TESTED |
| BLK-05 | Linux QR camera scanning not implemented | File/paste/QR display only; camera plugin needed |
| BLK-06 | Old release keystore in Git history | **COMPROMISED** — must rotate; cannot rewrite public history |
| BLK-07 | `mlockall` best-effort; may fail under low RLIMIT_MEMLOCK | Kernel-state test asserts dumpable=0, core=0 only |
| BLK-08 | HTTP CONNECT with pins refused, not enforced | Documented limitation |

## Rules Against Fake Implementations

- ❌ No placeholder buttons that show "success" without real action
- ❌ No dummy success indicators (green checkmarks without verification)
- ❌ No unfinished security features presented as complete
- ❌ No invented test results — run the actual tests
- ❌ No claim a build succeeded unless it actually succeeded
- ❌ No claim hardware works unless integration tested or explicitly qualified
- ❌ No weakening security to make a test pass
- ❌ No silent downgrade of privacy/security
- ❌ No automatic bypass of failed Tor/proxy connection
- ❌ No private keys/seed phrases outside local signing boundary
- ❌ No committed secrets, credentials, private keys, wallet files, release signing keys

## Rules Against Unverified Claims

- Distinguish **IMPLEMENTED** (code exists) from **TESTED** (automated test passes) from **VERIFIED WITH EVIDENCE** (independent reproduction, packet capture, hardware test)
- **NOT TESTED** = no automated test + no manual verification
- **BLOCKED** = explicit dependency preventing progress
- **NOT SUPPORTED** = intentionally out of scope
- Internal self-audit ≠ independent third-party audit — state this clearly
- "Testnet ready" ≠ "Production ready" — distinguish explicitly

---

**At session start**: Read this file, `docs/PROJECT_STATUS.md`, and `docs/PROJECT_MASTER_PLAN.md`.

**At session end**: Update `docs/PROJECT_STATUS.md`, `docs/PROJECT_MASTER_PLAN.md`, and task ledger. Record exact next steps.