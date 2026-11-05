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

## Verification record

| Check | Result |
|---|---|
| Current-tree secret scan | Passed: no tracked keystore/private-key block/known credential pattern. |
| Historical secret scan | Historical Android signing material or credential pattern found; rotation status unknown. |
| SBOM generation | Passed: 141 Dart packages (27 direct, 114 transitive) plus 9 locked npm verifier packages (1 direct). |
| Shell/Python syntax | Passed: `bash -n` release/test/scan scripts; `python3 -m py_compile scripts/sbom.py`. |
| Flutter static analysis | Passed: `flutter analyze --no-pub` completed with “No issues found.” |
| Focused vault cipher | Passed: `test/vault_test.dart`, 9/9 tests, run under `umask 0077` in a local transient user service. |
| Focused vault header | Passed: `test/vault_header_validation_test.dart`, 2/2 tests. |
| Focused vault import / rollback | Passed: `test/vault_import_rollback_kdf_test.dart`, 10/10 real-KDF cases in three terminal bounded runs. The suite now sets its own Linux `umask 0077` so its mock application-support directory satisfies the production permission invariant. |
| Focused vault management | Passed: `test/vault_management_test.dart`, 9/9 tests. |
| Complete Flutter suite | NOT VERIFIED for the current working tree. The terminal result for the full suite, including widget/integration coverage, has not been captured. |
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

Score: **60/100**. Cryptographic format and cold-signing validation have
substantial code/test coverage, but the project does not meet release-ready
criteria: unresolved historical signing exposure (−20), no full test result
(−10), unverified dependencies/token sources (−5), unverified platform
builds/hardware workflows (−3), and the
remaining documented OS/filesystem limits (−2). This score is not an
independent audit opinion and is not a security guarantee.

Release is blocked until AUD-02 and AUD-05 are resolved, Flutter tests and
analysis are clean, dependency/secret/SBOM checks are reproducibly recorded,
and supported Linux/Android artifacts are built and verified.
