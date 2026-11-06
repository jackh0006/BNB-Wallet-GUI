# Security audit register — 2026-11-04

This is a self-audit, not an independent certification. Evidence is limited
to the checkout at `adf6ab7bcc294a0f2f3254b5c84c547df386d49b` before this
remediation branch and to commands recorded below.

## Scope and method

Inventoried all 196 tracked files and reviewed the security-critical
Dart/Flutter source, Android and Linux configuration, lockfiles, workflows,
scripts, test inventory, release documentation, and the current local commits
ahead of `origin/main`. Security boundaries are the vault/password/device-
secret boundary, local filesystem, UI signing boundary, cold-wallet envelope
boundary, RPC/privacy transport boundary, and release-signing pipeline. No
real secret, wallet, or transaction was used.

## Findings register

| ID | Severity | Status | Affected files | Finding and disposition |
|---|---|---|---|---|
| AUD-01 | High | Remediated in this branch; locally verified, CI pending | `lib/vault.dart`, `test/vault_header_validation_test.dart`, `test/vault_test.dart` | V1/V2 accepted attacker-selected Argon2id upper costs before AEAD validation, enabling resource exhaustion from a malicious vault. Parser now accepts only the published fixed profile and validates the v1 header before indexing. Focused hostile-header and full vault-cipher regression suites passed locally. |
| AUD-02 | High | Open operational blocker | public Git history; `docs/security/RELEASE_SECURITY.md` | Historical Android release key/password exposure is confirmed by history scan. Current key rotation/revocation and published-artifact migration are NOT VERIFIED. |
| AUD-03 | High | Remediated in this branch; release verification pending | `scripts/build-apk.sh` | APK build accepted any supplied key and did not bind output to an approved signer. Build now requires and checks an external SHA-256 signer fingerprint. |
| AUD-04 | Medium | Remediated in this branch | `scripts/sbom.py`, `docs/SBOM.json`, `scripts/build-deb.sh` | SBOM and Debian package used stale hard-coded application versions. Generator/package script now reads `pubspec.yaml`; SBOM was expanded to inventory both Dart and independent-verifier npm lockfiles, then regenerated. |
| AUD-05 | Medium | Remediated in this branch; GitHub CI pending | `.github/workflows/verify.yml`, `scripts/dependency-audit.py`, dependency lockfile | CI now fails if pub.dev reports an advisory for a resolved package, and actions are pinned to commits resolved from their official release tags. |
| AUD-06 | Medium | Partially remediated | `android/app/build.gradle.kts` | Release APK remains arm64-v8a only, but now supports Android 8.0+ (API 26), including 64-bit Android 8/9 devices such as the Huawei Y9 2019. This is a compatibility limitation, not a cryptographic relaxation. |
| AUD-07 | Medium | Open | Linux drawer implementation, `docs/THREAT_MODEL.md` | Linux device secret is a 0600 local drawer, not a hardware secure element. Same-UID/compromised-OS attackers remain out of scope; documentation corrected. |
| AUD-08 | Low | Remediated in this branch | `lib/screens/settings_page.dart` | Flutter `Radio` controls were migrated to `RadioGroup` and local identifiers were normalized. `flutter analyze --no-pub` completes with no issues; no diagnostics were suppressed. |
| AUD-09 | Medium | Code remediation implemented; NOT VERIFIED by a dedicated widget regression | `lib/screens/send_page.dart`, `lib/screens/settings_page.dart`, `lib/screens/wallet_page.dart` | UI callbacks used a `BuildContext` after asynchronous work with an unrelated liveness guard. Exact state/context `mounted` guards now abort safely if the page disappears. A dedicated dispose-during-await widget regression is still required before this finding can be closed. |
| AUD-10 | High | Remediated; tested | `lib/vault.dart`, `lib/workers.dart`, `lib/kdf.dart` | The vault used the pure-Dart `cryptography` Argon2id implementation while `dargon2_flutter` was declared but unused. On the release-check machine a 64 MiB/t=3/p=4 derivation took ~110 s in debug and repeated derivations segfaulted the test device. The reference native library is now wired in with an explicit pure-Dart fallback; measured 344 ms native. Production parameters are unchanged; `kdf_production_test` cross-checks both implementations and one real round-trip. |
| AUD-11 | Medium | Remediated; tested | `lib/send_intent.dart` | `decodeErc20Transfer` accepted trailing calldata after the address/amount words while the review described a plain transfer. A non-standard token could act on those bytes. The decoder now requires the exact 4+32+32-byte shape; a regression test rejects trailing data. |
| AUD-12 | Medium | Remediated; tested | `scripts/test-suite.sh`, `test/navigation_flow_test.dart`, storage fixtures | Navigation awaited real filesystem I/O in a fake-async zone and HomePage started real RPC timeouts; storage teardown raced encrypted-log appends. The fixture is offline, unlock uses `runAsync`, and deletion flushes/retries. Local full suite is 44/44 (47 files after the new layers). |
| AUD-13 | Low | Remediated | `docs/hardware/COMPATIBILITY_MATRIX.md` | The hardware table implied devices were "NOT TESTED" when no integration exists. Every entry is now `NOT IMPLEMENTED`, with a prominent design-note warning. |
| AUD-14 | Low | Remediated | `release/manifest.json`, `scripts/*`, `README.md` | Release claims were duplicated across hand-written docs. A machine-readable manifest, generated status page/README block, test inventory, and release gate now provide one evidence path; CI rejects drift. |

## Verification record

| Check | Result |
|---|---|
| Current-tree secret scan | Passed: no tracked keystore/private-key block/known credential pattern. |
| Historical secret scan | Historical Android signing material or credential pattern found; rotation status unknown. |
| SBOM generation | Passed: 141 Dart packages (27 direct, 114 transitive) plus 9 locked npm verifier packages (1 direct). |
| Shell/Python syntax | Passed: `bash -n` release/test/scan scripts; `python3 -m py_compile scripts/sbom.py`. |
| Flutter static analysis | Passed: `flutter analyze --no-pub` completed with “No issues found.” |
| Focused vault cipher | Passed: `test/vault_test.dart`, 9/9 tests, 10 s with the test KDF; real production KDF is covered by `test/kdf_production_test.dart`. |
| Production KDF | Passed: fixed 64 MiB/t=3/p=4; native reference vs independent pure-Dart agreement; one real vault round-trip measured at 344 ms native. |
| Complete Flutter suite | Passed locally on 2026-11-06: 44/44 files before the new RPC/donation/accessibility layers (47 files total in the current inventory). Hosted rerun is required. |
| Token-source HTTPS check | NOT VERIFIED: all nine DNS lookups failed in this environment. |
| Linux production build | NOT VERIFIED: expected x64 bundle executable was produced, but Flutter did not return a terminal exit result in this runner. No signing or publication occurred. |
| Android production build | NOT VERIFIED; no release build or signing material was used. |
| Dependency vulnerability scan | Passed for current pub.dev metadata: no resolved package was flagged by `isCurrentAffectedByAdvisory`; CI now enforces the same check. |

## Compatibility and performance

Linux release packaging targets amd64/x64; Android release packaging targets
arm64-v8a with minSdk 26. Neither a lower Android API nor other CPU ABI is
verified/supported by this release script. Argon2id is fixed at 64 MiB, three
iterations and four lanes; this is intentionally retained. The new header
check runs before KDF allocation and adds negligible normal-unlock cost.

## Adversarial conclusion and readiness score

Score: **60/100** (2026-11-04 baseline). This is not a current score and is
not an independent audit opinion. The current candidate's status is computed
only by `scripts/release-gate.py`; it is not a numeric security score. Release
remains blocked until AUD-02 and AUD-05 are resolved, the full candidate suite
passes in hosted CI, and the release artifacts/install/reproducibility gates
pass.
