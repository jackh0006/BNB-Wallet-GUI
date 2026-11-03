# ARCHITECTURE.md — how this wallet is built

Version 1.0.5 · AGPL-3.0-or-later

```
┌───────────────────────────── lib/ ─────────────────────────────┐
│ main.dart            bootstrap, app-level lock watcher        │
│ app_state.dart       the one source of truth (extends         │
│                      ChangeNotifier): wallet lifecycle, node   │
│                      phone book, custom tokens, strict mode    │
│ storage.dart         plain preferences + secure API-key store │
│ wallet_core.dart     pure cryptography/validation (BIP-39     │
│                      seeds, EIP-55 addresses, guards, cold    │
│                      signing + strict verification)           │
│ cold_tx_codec.dart   strict canonical EIP-1559/RLP codec      │
│ cold_wallet_protocol.dart  versioned pairing/request/response  │
│ cold_wallet_service.dart   public cold state, replay, broadcast│
│ memory_protection.dart FFI prctl/setrlimit/mlockall (Linux)   │
│ vault_engine.dart    Argon2id(64MiB,t=3,p=4) + XChaCha20-     │
│                      Poly1305 vault envelope                   │
│ receipt_store.dart   encrypted receipt archive (BNBRCPT1,     │
│                      cap 200, encoded receipts)                │
│ fee_engine.dart      pure fee math: EIP-1559/legacy presets,  │
│                      multi-node merge, sanity clamp            │
│ tx_lifecycle.dart    send journey stages: rehearse → sign →   │
│                      broadcast → wait → receipt → narrate      │
│ rpc_service.dart     the ONLY network module: node book       │
│                      pools, probes + full testNodeDeep         │
│                      checklist, quotes, sends, subscriptions   │
│ net/privacy_client.dart  one client factory: UA scrub,        │
│                      optional SOCKS5/Tor, no fallback          │
│ rpc_story.dart       in-memory narration of network acts      │
│ encrypted_log_store.dart  BNBLOG01 encrypted activity log     │
│ backup_quiz.dart     pure 3-word backup verification logic    │
│ receipt_image.dart   full-receipt PNG rendering (dart:ui)     │
│ widgets/journey_map.dart, hold_to_confirm.dart                │
│ screens/             wallet_page, send_page, settings_page,   │
│                      receipt_page, logs_page, common.dart,    │
│                      cold_wallet_dialogs.dart (QR/file/paste) │
│                      (dialogs, clipboard auto-clear)          │
└───────────────────────────────────────────────────────────────┘
```

## The network rule

Everything that touches the internet goes through `RpcService`, whose pools
are fed by the **node phone book** in `app_state` (§10d "node manager"):

1. **feeCandidatePool** (pure, unit-tested) = active door → configured door
   → enabled book doors → built-in fallbacks; in strict mode = exactly one
   door.
2. **independentNodeList** (pure) = other enabled book doors, else built-in
   fallbacks; empty in strict mode (single-node receipts say so honestly).
3. Built-in door lists live in ONE place (`BnbNetworks`); no other module
   hardcodes an endpoint.

## The trust rules

- Signing happens in process memory; neither seed nor keys ever reach
  `RpcService` or disk unencrypted.
- The clipboard helper refuses secret-shaped text and self-clears after
  30 s (only if the clipboard still holds what was copied).
- Receipts and vault are sealed with device-bound secrets; receipts expire
  past the cap.

## Language decision — documented deviation

The wallet spec's original port would have moved the crypto core to a Rust
crate bridged through `flutter_rust_bridge`. This build is **pure Dart**:

- the core is `package:wallet` (a thin pure-Dart crate of BIP-39/32/44 and
  secp256k1 via web3dart), fully inside review reach of any reader of an
  AGPL deb;
- no FFI, no native artifacts in the deb, a smaller attack surface per
  platform, and reproducible builds from a standard flutter build;
- the deviation is recorded here and in `docs/THREAT_MODEL.md`; the security
  result that the spec's Rust core was chosen for (deterministic signing,
  zero-copy secrets) is preserved by Dart-side patterns and pure-function
  tests instead.

If a third-party audit ever finds a Dart-side crypto need the ecosystem
cannot satisfy, the bridge decision can be revisited then.

## Testing stance

`test/` covers the pure layers (fee engine, guards, storage, monitor,
receipts story) and drives `AppState` flows with mock preferences. Network
code paths are exercised through `testNodeDeep`'s checklist rows only in
manual verification against live nodes — the automated suite stays
offline-deterministic by design (`RpcService()` is never constructed in
pure tests; the deb machine is weak, so the suite is sequential).
