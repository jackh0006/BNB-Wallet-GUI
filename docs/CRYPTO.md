# Cryptography Spec — BNB Wallet v1.0.5

Created by jackh0006 (jackh109867@gmail.com)

Implementation: `lib/vault.dart`, `lib/security.dart`, `lib/storage.dart`.
Primitives are provided by the `cryptography` package (Argon2id,
XChaCha20-Poly1305, HKDF-SHA256); SOCKS5 transport by `socks5_proxy`.
Nothing crypto-primitive was hand-rolled.

## Vault envelope v2 ("BNBVL004", version byte 2)

Stored at `<app-support>/bnb-wallet-vault.bnb`, base64 of the binary
envelope. Total binary layout, in order:

```
offset  size  field
0       8     magic   "BNBVL004" (0x42 0x4e 0x42 0x56 0x4c 0x30 0x30 0x34)
8       1     version 0x02
9       4     Argon2id memory KiB, uint32 LE   (65536)
13      4     Argon2id iterations, uint32 LE   (3)
17      4     Argon2id parallelism, uint32 LE  (4)
21      16    salt (random)
37      24    paperBox nonce
61      32    paperBox ciphertext  (DEK, 32 bytes)
93      16    paperBox MAC (Poly1305)
109     24    deviceBox nonce
133     32    deviceBox ciphertext  (same DEK)
165     16    deviceBox MAC
181     24    payloadBox nonce
205     N     payloadBox ciphertext (JSON vault)
205+N   16    payloadBox MAC
```

AAD for ALL THREE AEAD boxes is bytes [0..37) — the header including
parameters and salt. Consequences:

- Any modification of magic, version, KDF parameters or salt makes every
  box fail authentication. Parameter downgrade attacks are impossible
  without also holding the DEK (i.e. having broken the wrappers already).
- The payload integrity covers the header: cut-and-mix attacks across
  historical vaults fail because each vault has its own random salt.

Keys:

```
KEK_pw   = Argon2id(password, salt, 64 MiB, t=3, p=4, 32-byte tag)
KEK_dev  = HKDF-SHA256(ikm=deviceSecret, salt=0x00×32,
                       info="bnb-wallet/device-kek-v2", L=32)

Where deviceSecret lives: Android/iOS keep it in the platform keyring
(Android Keystore-backed), read at most once per session. Desktops (Linux,
macOS, Windows) deliberately keep it in an owner-only (0600) drawer file
beside the vault in the app's data directory — the Linux keyring plugin
performs libsecret calls synchronously inside the GTK window thread, which
froze weak machines mid-wallet-creation. Machine binding either way: a
copied vault is inert without the secret from THIS machine. Existing vaults
migrate once (keyring → drawer on the first vault operation after the
update); if a vault's keyring secret cannot be read, the wallet retries once
and FAILS CLOSED — it never mints a replacement that would orphan the vault.
DEK      = 32 random bytes (CSPRNG), never stored in the clear
paperBox = XChaCha20-Poly1305(KEK_pw,  DEK, AAD=header)
deviceBox= XChaCha20-Poly1305(KEK_dev, DEK, AAD=header)
payload  = XChaCha20-Poly1305(DEK, plaintext-JSON, AAD=header)
```

Decryption opens BOTH wrappers and then compares the two recovered DEKs in
constant time; a mismatch ("both boxes authenticate but disagree") is a
tampering indicator and fails closed. Any failure surfaces one generic
message — "Wrong password, device key unavailable, or corrupted vault" — so
there is no oracle that says which factor was wrong.

Device secret: 32 fresh CSPRNG bytes, base64 in the platform secure store
under key `device_secret_v2` (Android: Keystore-backed
flutter_secure_storage; Linux: libsecret). It is created on first vault
write and destroyed by "Erase all data". If the secure store is unreadable,
vault operations fail closed with DeviceKeyException rather than weaken.

## Legacy read-only path (v1, "BNBVL003", version byte 1)

v1.0.2 envelopes are single-box: header(AAD) ‖ nonce ‖ ct ‖ mac, keyed by
Argon2id(password, salt) directly. v1.0.3 accepts them with the same
parameter floor and upgrades nothing silently: the next vault save re-wraps
the data in v2. The version byte must be 1 for the v1 path.

## App-lock PIN

- Record format: `a2:<saltB64(16 bytes)>:<hashB64(32 bytes)>` in secure
  storage key `app_lock_pin_hash`.
- `hash = base64(Argon2id(pin, nonce=ascii(saltString), 64 MiB, t=3, p=4))`
  — the base64 salt string itself (22 bytes) is the Argon2 salt, so the
  record is deterministic for a given PIN+salt.
- Comparison is constant-time over the raw bytes.
- Records without the `a2:` prefix (v1.0.2 SHA-256) are refused and
  deleted; the lock screen then takes the user to a fresh setup.
- Failed-unlock backoff: after the n-th failure, the next attempt waits
  `min(2^(n-1), 900)` seconds. State is `"<count>:<untilEpochMs>"` in
  secure-storage key `app_lock_backoff`; reading the remaining window
  re-anchors it to "now + remaining", so booting backwards/forwards does
  not reset it. Vault password attempts are already rate-limited by
  Argon2id's cost.

## Preferences and secrets separation

SharedPreferences (`*Preferences` plugin, plaintext files) may contain ONLY:
`network`, `rpc`, `nodes`, `tokens`, `profiles`, `auto_lock_seconds`,
`tor_enabled`, `tor_host`, `tor_port` — public configuration, no secrets.

Secure storage (`flutter_secure_storage`) contains ONLY:
`device_secret_v2`, `app_lock_pin_hash`, `app_lock_backoff`,
`bscscan_api_key` — all of which "Erase all data" removes.

The live Home history is never written to disk (in-memory only). The receipt
archive (`bnb-wallet-receipts.bin`, `BNBRCPT1`) and the activity log
(`bnb-wallet-log.bin`, `BNBLOG01`) are encrypted at rest with per-file keys
derived from the wallet key plus the device drawer secret; the plain pending-tx
status list holds public data only.

## Vault write path

`AppStorage.writeVaultAtomic`: serialize base64 → write `<file>.tmp`
→ flush → `rename(tmp, file)` (atomic on POSIX; unlink+rename fallback on
platforms refusing replace) → `chmod 600` on Linux/macOS. A crash before
the rename leaves the previous vault byte-identical; after the rename, the
new one.

## Erase all data

1. Overwrite vault + `.tmp` with CSPRNG bytes of equal size (best effort;
   flash wear-leveling prevents guarantees) then unlink both.
2. Delete secure-storage keys (crypto-erasure of the DEK's device factor).
3. Remove every preference key the app owns.
4. Clear in-memory caches and UI state.

Recovery afterwards requires the 24-word seed phrase. Nothing in the app
can recover funds without it.

## Honest caveats

- The composition (this repo) has no third-party audit. See THREAT_MODEL.
- Argon2id in a Dart VM is software-level: it provides the standard
  64 MiB/t=3 cost per guess; it is not a memory-hardness innovation.
- CSPRNG is `Random.secure()` (getrandom(2) on Linux/Android).
- On-chain data is public; Tor mode protects the transport path only.
