# STORAGE_SECURITY.md — Local Encrypted Storage Architecture

**Date**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`

---

## Vault Format (BNBVL004 — Version 2)

### Binary Layout

```
Offset  Size  Field
0       8     Magic: "BNBVL004" (0x42 0x4e 0x42 0x56 0x4c 0x30 0x30 0x34)
8       1     Version: 0x02
9       4     Argon2id memory (KiB), uint32 LE  → 65536 (64 MiB)
13      4     Argon2id iterations, uint32 LE    → 3
17      4     Argon2id parallelism, uint32 LE   → 4
21      16    Salt (random, per vault)
37      24    paperBox nonce (XChaCha20-Poly1305)
61      32    paperBox ciphertext (DEK, 32 bytes)
93      16    paperBox MAC (Poly1305)
109     24    deviceBox nonce
133     32    deviceBox ciphertext (same DEK)
165     16    deviceBox MAC
181     24    payloadBox nonce
205     N     payloadBox ciphertext (JSON vault)
205+N   16    payloadBox MAC
```

### Key Derivation

```
KEK_pw   = Argon2id(password, salt, 64 MiB, t=3, p=4, 32-byte tag)
KEK_dev  = HKDF-SHA256(ikm=deviceSecret, salt=0x00×32,
                       info="bnb-wallet/device-kek-v2", L=32)
DEK      = 32 random bytes (CSPRNG)
```

### Encryption (All Three Boxes)

- **Algorithm**: XChaCha20-Poly1305 (AEAD)
- **AAD for ALL boxes**: Bytes [0..37) — header including KDF parameters and salt
- **Nonce**: 24 random bytes per box (never reused)
- **DEK**: Encrypted by both `paperBox` (password KEK) and `deviceBox` (device KEK)
- **Payload**: Encrypted by `payloadBox` (DEK)

### Decryption

1. Derive `KEK_pw` from password + salt
2. Decrypt `paperBox` → recover `DEK_pw`
3. Derive `KEK_dev` from device secret
4. Decrypt `deviceBox` → recover `DEK_dev`
5. **Constant-time compare** `DEK_pw` == `DEK_dev` (mismatch = tampering)
6. Decrypt `payloadBox` with `DEK` → plaintext JSON vault

**Any failure** → single generic error: "Wrong password, device key unavailable, or corrupted vault" (no oracle).

---

## Vault v1 Legacy Format (BNBVL003 — Read-Only Migration)

```
Magic: "BNBVL003" (0x42 0x4e 0x42 0x56 0x4c 0x30 0x30 0x33)
Version: 0x01
KDF params: same (64 MiB, t=3, p=4)
Single AEAD box: nonce || ciphertext || MAC, keyed by Argon2id(password, salt)
```

- **Read-only**: v1 vaults decrypt with password only (no device secret)
- **Migration**: On next save, re-wrapped to v2 format
- **No silent downgrade**: v1 never written; v2 parameters authenticated in AAD

---

## Device-Bound Secret

| Platform | Storage | Notes |
|----------|---------|-------|
| **Android** | `flutter_secure_storage` → Keystore-backed preferences | Hardware-backed if available |
| **iOS** | `flutter_secure_storage` → Keychain | Hardware-backed |
| **Linux** | **Owner-only drawer file** (`0600`) beside vault | **NOT libsecret** — avoids GTK thread freeze |
| **macOS** | `flutter_secure_storage` → Keychain | |
| **Windows** | `flutter_secure_storage` → DPAPI | |

- **Created**: On first vault write (32 random bytes, base64)
- **Key**: `device_secret_v2` in secure storage
- **Destroyed**: "Erase All Data" → crypto-erasure
- **Migration**: Linux keyring → drawer file (one-time, fail-closed if keyring unreadable)

---

## App-Lock PIN

- **Format**: `a2:<saltB64(16 bytes)>:<hashB64(32 bytes)>`
- **Storage**: Secure storage key `app_lock_pin_hash`
- **KDF**: Argon2id(password, nonce=ASCII(saltString), 64 MiB, t=3, p=4)
- **Comparison**: Constant-time over raw bytes
- **Backoff**: After n failures, wait `min(2^(n-1), 900)` seconds
- **State**: `"<count>:<untilEpochMs>"` in secure storage key `app_lock_backoff`
- **Persistence**: Wall-clock window survives process restarts
- **Legacy v1 (SHA-256)**: Refused and deleted; forces fresh PIN setup

---

## Secure Storage Contents (ONLY)

| Key | Content | Erased by "Erase All Data" |
|-----|---------|---------------------------|
| `device_secret_v2` | 32-byte device secret (base64) | ✅ |
| `app_lock_pin_hash` | `a2:<salt>:<hash>` | ✅ |
| `app_lock_backoff` | `"<count>:<untilMs>"` | ✅ |
| `bscscan_api_key` | User-provided API key | ✅ |

---

## SharedPreferences Contents (PUBLIC CONFIG ONLY)

| Category | Keys | Secrets? |
|----------|------|----------|
| Network | `network`, `rpc`, `nodes`, `tor_enabled`, `tor_host`, `tor_port` | ❌ |
| Wallet | `wallet_mode`, `watch_address`, `profiles`, `active_profile` | ❌ |
| Tokens | `tokens`, `token_sources`, `token_sources_notice` | ❌ |
| UI | `theme_mode`, `locale`, `lite_mode`, `auto_lock_seconds` | ❌ |
| Cold Wallet | `cold_pairing_v1`, `cold_pending_requests_v1`, `cold_signed_responses_v1`, `cold_signed_request_ids_v1`, `cold_broadcast_hashes_v1` | ❌ (public only) |
| Pending TX | `pending_txs` | ❌ (public status) |

**No secrets ever in SharedPreferences.**

---

## Atomic Vault Write

```dart
// AppStorage.writeVaultAtomic
1. Serialize vault JSON → base64
2. Create a 0600 exclusive temporary inode beneath a pinned parent-directory descriptor
3. Write, descriptor-readback verify, and fsync that inode
4. Recheck destination state then `renameat`/`renameat2` through the pinned descriptor
5. Compare no-follow destination `st_dev`/`st_ino` with the still-open committed descriptor, then fsync the parent directory
```

- **Crash before rename**: Original vault intact
- **Crash after rename**: New vault may be visible; durability is uncertain until parent-directory fsync succeeds
- **No partial writes**: Rename is atomic
- **Same-user concurrent writer**: identity is checked immediately after rename, but a writer with directory access can replace the pathname after that check; no pathname API can make a lasting race-free claim.

---

## Encrypted Activity Logs (BNBLOG01)

- **Envelope**: `BNBLOG01` magic + version + AEAD (XChaCha20-Poly1305)
- **Key**: Derived from wallet key + device drawer secret
- **Content**: Structured events (wallet, network, tx, security, cold, hardware)
- **Retention**: In-memory ring buffer; persisted encrypted on interval
- **No secrets**: Passwords, seeds, keys, tokens, sensitive bodies redacted

---

## Encrypted Receipt Store (BNBRCPT1)

- **Envelope**: `BNBRCPT1` magic + version + AEAD
- **Key**: Derived from wallet key + device drawer secret
- **Cap**: 200 entries (oldest evicted)
- **Receipt fields**: Hash, status, from/to, asset/amount, nonce, gas, fee, confirmations, finality, node/transport, block hash/index, tx type, balances, decoded calldata, decoded Transfer logs
- **Double-check**: Independent node verification badge ("2 nodes ✓" / "1 node only")

---

## Erase All Data Workflow

1. **Confirm**: User types `ERASE` explicitly
2. **Overwrite**: Vault + `.tmp` with CSPRNG bytes (equal size), then unlink
3. **Crypto-erasure**: Delete `device_secret_v2` from secure storage (DEK unrecoverable)
4. **Secure storage**: Delete `app_lock_pin_hash`, `app_lock_backoff`, `bscscan_api_key`
5. **Preferences**: Remove every app-owned key
6. **In-memory**: Clear keys, profiles, nodes, tokens, logs
7. **Result**: App returns to first-run state

**Recovery**: ONLY with 24-word seed phrase.

---

## SSD Wear-Leveling Limitation

- Overwrite is **best-effort**; flash controllers may remap blocks
- **Real guarantee**: Crypto-erasure (deleting device secret)
- Without device secret, ciphertext is permanently unverifiable
- Documented honestly in UI and THREAT_MODEL.md

---

## Backup / Restore

### Backup (Encrypted Export)
- **Format**: Same vault envelope (BNBVL004) — portable
- **Contains**: Encrypted vault only (no device secret)
- **Restoration**: Requires password + device secret of target device
- **Verification**: Decrypt test before confirming restore

### Restore
1. Select backup file
2. Enter password
3. Decrypt with current device secret
4. Verify integrity (magic, version, MAC)
5. Atomic write to destination
6. Switch app to new vault

---

## Multiple Vault Support

- **Vault list**: Stored in preferences (paths + labels)
- **Active vault**: Single active at a time
- **Switch**: Lock current → unlock target (password + device secret)
- **Isolation**: Each vault has independent device secret binding

---

## Security Boundaries

| Boundary | Protection |
|----------|------------|
| **Vault file at rest** | Double AEAD (password + device), authenticated header |
| **Vault in memory** | Keys cleared on lock/background/erase |
| **Device secret** | Platform secure storage (Android Keystore / iOS Keychain / Linux drawer) |
| **PIN hash** | Argon2id + secure storage + persistent backoff |
| **Activity logs** | Encrypted at rest, wallet+device key |
| **Receipts** | Encrypted at rest, wallet+device key, capped |
| **Clipboard** | Secret detection + 30s auto-clear (if unchanged) |
| **Network** | No secrets in requests; signing local only |

---

## Test Coverage

| Test | Status | File |
|------|--------|------|
| Vault v2 round-trip | ✅ TESTED | `test/vault_test.dart` |
| Wrong password rejection | ✅ TESTED | `test/vault_test.dart` |
| Wrong device secret rejection | ✅ TESTED | `test/vault_test.dart` |
| Fresh nonce per encryption | ✅ TESTED | `test/vault_test.dart` |
| Downgraded KDF params rejection | ✅ TESTED | `test/vault_test.dart` |
| Single error message (no oracle) | ✅ TESTED | `test/vault_test.dart` |
| Vault v1 migration | ✅ TESTED | `test/vault_test.dart` |
| Worker isolate KDF (off UI) | ✅ TESTED | `test/workers_test.dart` (3 tests) |
| Atomic write (crash simulation) | ⚠️ NOT TESTED | Manual only |
| Erase all data flow | ✅ TESTED | `test/erase_flow_test.dart` |
| Backup/restore | ⚠️ NOT TESTED | Manual only |

---

## Evidence Locations

| Evidence | Location |
|----------|----------|
| Vault implementation | `lib/vault.dart` |
| Storage management | `lib/storage.dart` |
| Security (PIN, KDF) | `lib/security.dart` |
| Worker isolates | `lib/workers.dart` |
| Test results | `test/vault_test.dart`, `test/workers_test.dart` |

---

*This document describes the implemented storage architecture. All cryptographic claims are qualified in SECURITY_CLAIMS.md.*
