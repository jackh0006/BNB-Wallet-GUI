# CHANGELOG.md

All notable changes to this wallet. Dates in 2026; version 1.0.5 is the
release line built as a deb for Debian/Ubuntu (no APK — the deb is the
distribution form for this device).

## 2026-11-03 — M3 Security Fixes: Vault Backup/Restore Hardening

- **Export (Backup) Security Hardening:**
  - Verifies the supplied password against the active vault BEFORE exporting
  - Rejects incorrect passwords immediately
  - Validates the vault envelope format (magic, version, structure, size limits)
  - Uses atomic output creation (tmp → rename) with restrictive permissions (0600)
  - Refuses to overwrite an existing backup file without explicit user action
  - Reads back and validates the exported file (content match + envelope validation)
  - Never logs passwords, vault contents, seeds, or private keys

- **Import (Restore) Security Hardening:**
  - Reads and validates the SELECTED BACKUP file, not the current vault
  - Enforces regular-file checks, sensible size limits (5 MB), recognized format/version (BNBVL003/BNBVL004)
  - Verifies the supplied password by decrypting THE IMPORTED BACKUP (not the current vault)
  - Verifies all required cryptographic authentication tags and device-key dependencies
  - Rejects truncated, malformed, corrupted, unsupported-version, wrong-password, and tampered files
  - Does NOT replace the active vault until validation and decryption succeed completely
  - Preserves the original vault if any step fails (atomic tmp → rename replacement)
  - Requires explicit user confirmation before replacing an existing vault
  - Reports success only after the new vault has been read back and validated

- **Cross-device Recovery:**
  - The vault format uses a device-bound secret (second factor)
  - Backup files can be restored on another device with the same password + device secret
  - Device secret migration documented; cross-device recovery tested via independent decryption

## 2026-11-03 — cold-wallet and verification hardening (unreleased)

- **Cold wallet end-to-end:** pairing/request/signature envelopes with
  version, kind, canonical JSON, SHA-256 checksum, strict field allow-lists
  and size limits; public-address-only pairing; runtime-offline cold signer;
  online companion with no keys; strict verify-before-broadcast; replay and
  already-broadcast guards; bounded public storage.
- **EIP-1559 correctness:** new `cold_tx_codec.dart` replaces the broken
  `rlp` package usage. One canonical codec now produces the unsigned payload,
  digest, signed bytes and parsed transaction. The parser rejects
  non-canonical RLP, bad scalars, high-s, wrong field counts and access lists.
- **Independent verification:** `verification/verify.cjs` uses ethers.js
  6.13.2 (not web3dart) to check the exact bytes, digest, fields, `r`/`s`/
  `yParity`, hash and recovered signer, and rejects 8 substitutions.
- **TLS pinning:** standard CA/hostname validation first, then SPKI pin;
  corrected the v3 certificate SPKI index (extensions were hashed instead of
  the public key); pinned HTTP CONNECT refused; 6 integration tests.
- **Memory hardening:** FFI `prctl(PR_SET_DUMPABLE,0)`, `setrlimit(RLIMIT_CORE,0)`
  and best-effort `mlockall`; kernel-state tests. The old `sh -c ulimit` was a
  no-op.
- **Release hygiene:** removed the committed keystore and hardcoded password;
  `build-apk.sh` requires environment credentials and never creates a
  keystore; `.gitignore` blocks signing material; `secret-scan.sh` runs in CI.
- **Cold account index:** signer derives the matching default BIP-44 account
  instead of always index 0.
- **Test stability:** keyring read bounded and skipped under `FLUTTER_TEST`;
  proxy dialog overflow fixed; realistic KDF timeouts.
- Docs: `SECURITY_AUDIT.md`, `docs/COLD_WALLET.md`, `docs/TESTING.md`;
  updated THREAT_MODEL, CRYPTO, SECURITY, SPEC-COMPLIANCE and README.
- **Not changed into a claim:** no third-party audit; old release key remains
  compromised and must be rotated; no OS-enforced air gap; no camera QR on
  Linux; no two-device field test.

## 1.0.5 — release rounds 1–8 plus verification rounds R0–R3 (2026)

### Vault & keys
- Encrypted vault (`bnb-wallet-vault.bin`): Argon2id 64 MiB / t=3 / p=4,
  XChaCha20-Poly1305 envelope; a drawer key for the wallet stays on device.
- Creation ceremony with verified seed backup, duplicate-offer testing,
  and an auto-created wallet on first run.
- App unlock, optional PIN/biometric gate after background, auto-lock
  choices (0/background-only · 60 s · 300 s).

### Network & node manager (§10d)
- RPC node phone book per side (mainnet/testnet): add, edit, use, remove,
  reset-to-official, enable/disable per row, reorder (book order =
  priority order), import/export as JSON.
- "Use ONLY my node" strict mode: no fallback doors, ever.
- Full per-node test checklist with visible results: reachable, right
  chain (blocking), chain-head freshness vs the active door, gas price,
  EIP-1559 fee-history support, pending nonce, eth_call, estimateGas,
  sendRawTransaction availability (invalid payload — nothing is ever
  broadcast by a test), answer time.
- One-time per-node privacy warning ("what a node sees") before first use.
- Chain verification on every connect; no hardcoded doors outside the
  single default table.

### Privacy (§5–§7)
- One mandatory client factory: identifying `User-Agent` scrubbed, only
  content-type/accept headers sent.
- Optional Tor routing through a local SOCKS5 port, no fallback to direct.
- Clipboard: refuses secret-shaped text, self-clears after 30 s (iff still
  the same content). Seed words never enter the clipboard.
- FLAG_SECURE (Android) and backup-disabled manifests.

### Fees (§9)
- Live multi-node fee quote with sanity drop of outliers, EIP-1559 +
  legacy routes where history is unsupported; presets show expected wait
  in blocks and seconds measured from the chain, never invented.

### Sending journey (§8.4, §9)
- Staged send with narration: validation → fee pick → rehearsal
  (eth_call from the real sender) → sign → broadcast → block wait →
  receipt → honest impossible-refusals (e.g. out of gas money) that
  explain the math on screen.
- Pending-tx tracking in plain prefs with live finality estimates;
  receipt double-check against an independent door (skipped honestly in
  strict mode).

### Receipts archive (§10c)
- Encrypted on-device receipt archive (`BNBRCPT1`, XChaCha20-Poly1305,
  HKDF-derived keys), capped at 200, per-receipt disclosure, search by
  address/contract, details page with hash/nonce/logs/UTC time.

### Tokens (§10e)
- Custom BEP-20 add flow verified on-chain before save.
- Trusted sources: shipped `assets/token_sources.json`, 3-step checklist,
  scam warning, one-time notice, open/copy buttons, user-editable own
  links (add/remove/reorder), CI link checker.
- Component inventory: `docs/SBOM.json` (deterministic, from the lock).

### Packaging & docs (§11)
- deb with sha256 + GPG signature; version pinned 1.0.5.
- LICENSE (AGPL-3.0-or-later), PRIVACY.md, THREAT_MODEL.md ("no third-
  party audit yet" — stated exactly once, truthfully), ARCHITECTURE.md,
  CONTRIBUTING.md, CHANGELOG.md, SECURITY.md, STANDARDS.md, SBOM.json,
  CI workflow for analyzer + tests + link checks.
- About screen: version, license, build-verification how-to, SBOM pointer,
  security notice without marketing.

### Verification round R0 (source integrity)
- Rebuilt the truncated RPC service in ordered chunks; every original
  behavior (story budget, per-node transport, measured fees, simulation,
  sign/broadcast, receipts, finality) re-verified.
- Corrected `docs/SPEC-COMPLIANCE.md` against the actual code and kept
  audit statements factual (one truthful note in THREAT_MODEL.md only).

### Logs and privacy (R2)
- Encrypted activity log (`BNBLOG01`) with a Simple timeline and Expert
  filtered record, session headers, category/level filters, search, live
  tail, copy/export with an activity warning, and clear.
- "View raw request": the last 50 real exchanges (method, status, exact
  request body, exact response) from memory only.
- Log canary test proving ciphertext at rest never contains the canary.

### Keys, tokens, display (R3 / R6 subset)
- Seed backup quiz: three random words must be re-typed before creation;
  Settings can re-verify an existing phrase.
- Watch-only import: public address only, sends refused, no key stored.
- Built-in/custom token visibility switches; hidden tokens leave the send
  picker but keep their on-chain balance.
- Lite mode: static journey states and progress bar instead of the pulse.
- Reduce-motion support: the system setting switches the Journey Map to the
  same static Lite presentation automatically.
- Hold-to-confirm signing: after typing the last 6 recipient characters, the
  user must hold a fill button for 1.6 s; early release cancels before signing.
- Home node card now has a latency sparkline, session request count and a
  direct "Switch node" path to the node manager.
- "Compare another" asks one independent node the same chain-id question and
  reports same/different chain and block distance (never changes the active
  node, never signs or broadcasts).

### Journey and receipts (R3)
- Five-stop Journey Map (phone → privacy → node → chain → done) with
  waiting/working/ok/problem states and per-stop detail cards.
- Home node card: answer-time gauge, latest block, right-chain badge,
  privacy route, and a check-now probe.
- Receipts now store block hash/index, transaction type, calldata and raw
  event logs; the page decodes `transfer(...)` and Transfer logs, shows a
  hash QR, copies/saves JSON, renders a full PNG, warns before sharing or
  opening an explorer, and sends a local Linux notification on confirmation.
- Tests: all non-KDF suites (140) plus the 10 real 64 MiB KDF tests are
  green; analyzer reports 0 errors and 0 warnings.

## 1.0.4 — earlier rounds
- Terminal wallet core port, first GUI screens, initial deb packaging.
