# Test Results

**Date:** 2026-11-06
**Code commit:** `e474b8956a68febf44ef780c7decf898e9050018`
**Final candidate commit:** `142929315b7df572ffae93cbc5ab1a2ec2395724`
**Environment:** Ubuntu 24.04.5 LTS, x86_64, 2 cores, 3.8 GiB RAM,
Flutter 3.47.6 stable, Dart 3.13.5.

Do not treat a timeout, OOM, cancellation, or skipped test as a pass.

| # | Test | Command | Commit | Result | Duration | Evidence |
|---|---|---|---|---|---|---|
| 1 | Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | `e474b89` | PASS | 1.5 s | local terminal; CI `flutter` job |
| 2 | Static analysis | `flutter analyze --no-pub` | `e474b89` | PASS (no issues) | 11.3 s | local; CI `flutter` job |
| 3 | Default suite (local) | `bash scripts/test-suite.sh` | `90d0f7c` | PASS 48/48 files, 0 failed, 0 timed out (49 files total incl. integration) | 533 s | `release/checks.json` (f4 record) |
| 4 | Production KDF | `flutter test test/kdf_production_test.dart` | `e474b89` | PASS | < 10 s | native 344 ms; pure-Dart cross-check; one real 64 MiB round-trip |
| 5 | Independent cold signature | `(cd verification && npm ci && node verify.cjs)` | `e474b89` | PASS; 8 substitutions rejected | ~7 s | local; CI `cold-signature` |
| 6 | Secret scan (current tree) | `bash scripts/secret-scan.sh` | `e474b89` | PASS | 1.8 s | local; CI `secret-scan` |
| 7 | Secret scan (history) | `bash scripts/secret-scan.sh --history` | `e474b89` | KNOWN EXPOSURE | — | commit IDs only; see incident record |
| 8 | Dependency advisory audit | `python3 scripts/dependency-audit.py` | `e474b89` | PASS (no current pub.dev flags) | 4.6 s | local; CI `flutter` job |
| 9 | Licence inventory | `python3 scripts/license-check.py` | `e474b89` | PASS for inventory; owner review required | 0.4 s | local; CI |
| 10 | SBOM | `python3 scripts/sbom.py --out docs/SBOM.json` | `e474b89` | PASS; 116 packages | 0.05 s | `docs/SBOM.json` |
| 11 | Test inventory | `python3 scripts/test_inventory.py --check` | `e474b89` | PASS; 47 files / 299 declarations | 0.1 s | `docs/testing/test-inventory.json` |
| 12 | Release evidence | `python3 scripts/check_release_evidence.py` | `e474b89` | PASS | 0.05 s | `docs/releases/1.0.10.md` |
| 13 | Linux build | `flutter build linux --release` | `e474b89` | PASS | 123 s | local; CI `linux-build` |
| 14 | `.deb` build | `bash scripts/build-deb.sh` | `90d0f7c` | PASS (unsigned) | 26 s | `d25ecdb2de3a8e706950158639d0366dc147f339957500a98b3f429c6b549244` |
| 15 | Package sanity | `dpkg-deb -x` + `ldd` + secret-name scan | `90d0f7c` | PASS; all libs resolve; no secret-bearing names | — | local |
| 16 | Reproducibility (fixed path) | `bash scripts/reproducibility-check.sh 90d0f7c` | `90d0f7c` | PASS; identical archive `134e6b06…` and manifests | 275 s | `release/checks.json` |
| 17 | Hosted CI | GitHub Actions push `42278713164`, PR `42278724511` | `1429293` | PASS: all required contexts | 3m52s / 3m52s | GitHub Actions |
| 18 | Install/launch/upgrade/uninstall | `scripts/package-smoke.sh` on GitHub `ubuntu-24.04` | `90d0f7c` | PASS: install, Xvfb launch, upgrade with data marker, uninstall, reinstall | 2m49s | GitHub run `42289751525` |
| 19 | Real EVM integration | `scripts/run-anvil-tests.sh` against Anvil 1.9.0, chain 97 | `90d0f7c` | PASS 3/3: native transfer, wrong-chain rejection, ERC-20 deploy/mint/transfer/approve/revoke/revert | 14 s | `release/checks.json` |
| 22 | Mutation testing | `python3 scripts/security_mutation_check.py` | `90d0f7c` | PASS 5/5 mutations killed | 97 s | `release/checks.json` |
| 23 | Backup/restore E2E | `flutter test test/backup_restore_e2e_test.dart` | `90d0f7c` | PASS 4/4: create/backup/wipe/restore, wrong password, tamper, truncation | included in suite | `release/checks.json` |
| 24 | Release signing tools | `bash scripts/test_release_signing.sh` | `90d0f7c` | PASS: valid, wrong key, tampered package/sums, missing sig, unknown key | 1.6 s | `release/checks.json` |
| 25 | Android signer inventory | `bash scripts/test_android_inventory.sh` | `90d0f7c` | PASS: synthetic keystore fingerprint, no password leak | local run | `docs/evidence/2026-11-06/` |
| 20 | Startup / RSS | — | — | NOT TESTED | — | needs real display session |
| 21 | Independent audit | — | — | NOT AVAILABLE | — | none performed |

## Notes on commit binding

The original wallet-code commit is `e474b89`. The final candidate
`1429293` includes release/test-tooling fixes (package smoke, test watchdog,
test inventory) and documentation; the wallet crypto/transaction code is
unchanged. Hosted CI ran the full suite on `1429293` and passed. The `.deb`
and reproducibility archives were built from `1429293`; the artifact is
unsigned and is not published.
