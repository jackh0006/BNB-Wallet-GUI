# Testing and verification guide

This page records how the wallet is tested, what the checks actually prove,
and where the limits are. A green run is **not** a security audit.

## Prerequisites

- Flutter 3.47.6 / Dart 3.13.5 (the versions used for the recorded runs).
- Node.js 24 and npm (for the independent ethers.js check).
- OpenSSL 3 for the TLS pinning integration test.
- Linux for the kernel memory-hardening test (`prctl`/`setrlimit`).
- `anvil`/Foundry is **not required** by the automated suite; no local-chain
  integration test is included (see Limits).

## Commands

```sh
flutter pub get
flutter analyze --no-pub

# Full test driver: light suites two-wide, KDF suites strictly one at a time.
bash scripts/test-suite.sh

# Or run the two phases yourself:
flutter test --exclude-tags kdf --concurrency=2
flutter test --tags kdf --concurrency=1

# One file / one test:
flutter test test/cold_wallet_service_test.dart
flutter test test/workers_test.dart --plain-name 'pinHashJob keeps the exact v1.0.4 record format (64 MiB Argon2id)'

# Independent, non-Dart verification of the cold-signing bytes:
cd verification && npm ci && node verify.cjs && cd ..

# Release hygiene:
bash scripts/secret-scan.sh
```

The KDF-tagged tests perform real 64 MiB Argon2id derivations. On the 2-core
release machine each derivation takes roughly 1m45s; the whole KDF phase can
take ~10 minutes. Run it sequentially — overlapping derivations is the
"did not complete" cascade described in `scripts/test-suite.sh`.

## Recorded runs (2026-11-03)

| Suite | Count | Result |
|---|---|---|
| `test/cold_tx_codec_test.dart` | 4 | pass |
| `test/cold_wallet_protocol_test.dart` | 15 | pass |
| `test/cold_wallet_service_test.dart` | 15 | pass |
| `test/cold_wallet_test.dart` | 8 | pass |
| `test/tls_pinning_test.dart` | 6 | pass |
| `test/memory_protection_test.dart` | 2 | pass |
| `test/widget_test.dart` | 3 | pass |
| `test/privacy_dialogs_test.dart` | 2 | pass |
| Full non-KDF suite | 209 | pass |
| KDF suite (`--tags kdf`) | 10 (7 vault + 3 workers) | known crash on this 2-core 4 GB machine after ~2.5 h; individual tests pass when run with generous timeouts; resource exhaustion documented in SECURITY_AUDIT.md |
| `verification/verify.cjs` (ethers.js) | 1 script, 8 substitution cases | pass |
| `scripts/secret-scan.sh` | 1 scan | pass |
| `flutter analyze --no-pub` | — | no errors; warnings/infos recorded below |

`flutter analyze` currently reports no errors. It does report pre-existing
info-level lints (mostly `use_build_context_synchronously` and
`curly_braces_in_flow_control_structures`) and one unused private helper
warning in `lib/rpc_service.dart`; these are not treated as test failures but
are not hidden either.

## What each area proves

### Cold transaction codec

`test/cold_tx_codec_test.dart` pins the exact EIP-1559 payload and digest for
a known public vector, and rejects non-canonical RLP, wrong field lengths and
invalid signature scalars.

`verification/verify.cjs` is the independent oracle. It imports only
ethers.js, parses the raw signed transaction emitted by the Dart codec,
recomputes the payload/digest, checks `r`/`s`/`yParity` and the transaction
hash, recovers the signer, and repeats the digest/recovery check after
changing each of eight signed fields (recipient, value, chain, nonce, gas,
fees and calldata). It does not use web3dart or the Dart codec.

### Cold protocol and service

`test/cold_wallet_protocol_test.dart` covers envelope integrity, expiry,
unknown/missing fields, duplicate addresses, native/calldata mismatch,
checksum tampering and `v`/`yParity` disagreement.

`test/cold_wallet_service_test.dart` covers persistence, bounded storage,
single-use request ids, offline signing, replay with different bytes, a
foreign signer, response verification against a changed request, a response
for a non-pending request, future timestamps, strict broadcast, a mismatched
node hash (bytes burned), and a tampered response that must never reach the
node (the fake RPC records zero broadcasts).

### TLS pinning

`test/tls_pinning_test.dart` generates an ephemeral CA and server certificate
with OpenSSL, verifies that Dart and OpenSSL compute the same SPKI SHA-256
pin, and proves:

- a correct pin succeeds only after standard TLS validation;
- a wrong pin fails even though the chain is trusted;
- a correct pin cannot bypass hostname validation;
- a correct pin cannot bypass CA validation;
- an empty pin list fails closed;
- pinned HTTP CONNECT is refused before any socket is opened.

### Memory hardening

`test/memory_protection_test.dart` reads the actual kernel state of the test
process: `PR_GET_DUMPABLE` is 0 and the core-file soft limit is 0. It does not
prove that every page is locked; `mlockall` is best-effort and may fail under
a low `RLIMIT_MEMLOCK`.

### Widget and dialog tests

`test/widget_test.dart` boots the app with mock preferences and no network.
`test/privacy_dialogs_test.dart` opens the proxy/Tor dialogs and checks the
options and URL parsing. `AppStorage.init()` deliberately skips the OS keyring
under `FLUTTER_TEST`; without that, the test runner's fake-async zone can wait
forever on an unserviced platform channel.

## What is not tested

- **No third-party audit.** The tests are written by the same project that
  wrote the code.
- **No real-chain broadcast.** The broadcast gate is tested with a fake RPC.
  `anvil` is not installed, so no local EVM accepted or rejected a signed
  transaction in this run.
- **No two-device cold transfer.** File/paste/QR display paths are exercised
  in code/tests, not by carrying a file between two physical machines.
- **No camera QR scanning on Linux.**
- **No APK/deb build in this run.** The release keystore is intentionally not
  in the repository; `scripts/build-apk.sh` requires an external keystore.
- **No Windows/macOS run.** The memory-hardening test is Linux-only.
- **No hardware wallet.**

## Interpreting failures

- `TimeoutException ... Test timed out` in a KDF test usually means the
  machine is too slow or another derivation is running. Re-run the KDF phase
  alone with `--concurrency=1`; do not lower the Argon2id parameters to make a
  test pass.
- `Bad state: Cannot close sink while adding stream` from the Flutter test
  runner means the runner was killed mid-test (often by a timeout), not that
  an assertion failed. Read the earlier output for the real cause.
- Any failure in `verification/verify.cjs` means the signed bytes, digest,
  fields or recovered signer drifted. Do not "fix" the fixture without an
  independent reason; investigate the codec first.
