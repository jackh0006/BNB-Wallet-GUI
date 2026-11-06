# Test Results

**Date:** 2026-11-06
**Code commit:** `e474b8956a68febf44ef780c7decf898e9050018`
**Final candidate commit:** `3aef4b908fded5e92823c76f02d4016265c8bf12`
**Environment:** Ubuntu 24.04.5 LTS, x86_64, 2 cores, 3.8 GiB RAM,
Flutter 3.47.6 stable, Dart 3.13.5.

Do not treat a timeout, OOM, cancellation, or skipped test as a pass.

| # | Test | Command | Commit | Result | Duration | Evidence |
|---|---|---|---|---|---|---|
| 1 | Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | `e474b89` | PASS | 1.5 s | local terminal; CI `flutter` job |
| 2 | Static analysis | `flutter analyze --no-pub` | `e474b89` | PASS (no issues) | 11.3 s | local; CI `flutter` job |
| 3 | Full suite (local) | `bash scripts/test-suite.sh` | `e474b89` | PASS 47/47 files, 0 failed, 0 timed out | 577 s | `/tmp/opencode/evidence/full-suite-3.log`; summary in `docs/IMPLEMENTATION_LOG.md` |
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
| 14 | `.deb` build | `bash scripts/build-deb.sh` | `b37cede` | PASS (unsigned) | 26 s | `0ab7e99faf4639d3a66fe18509c19d8a5843793cafe6d2addde9e77b4de58349` |
| 15 | Package sanity | `dpkg-deb -x` + `ldd` + secret-name scan | `b37cede` | PASS; all libs resolve; no secret-bearing names | — | local |
| 16 | Reproducibility (fixed path) | `BNB_REPRO_PATH=/tmp/bnb-repro-final bash scripts/reproducibility-check.sh 3aef4b9` | `3aef4b9` | PASS; identical archive `388f94bf…` and manifests | ~4 min | `docs/evidence/2026-11-06/reproducibility-fixed.log` |
| 17 | Hosted CI | GitHub Actions push `42261933060`, PR `42261942195` | `3aef4b9` | PASS: all required contexts | 4m05s / 3m53s | GitHub Actions |
| 18 | Install/launch/upgrade/uninstall | `scripts/package-smoke.sh` on GitHub `ubuntu-24.04` | `f55dc00` | PASS: install, Xvfb launch, upgrade with data marker, uninstall, reinstall | 2m17s | GitHub run `42268826642` |
| 19 | Real BSC/Anvil integration | — | — | NOT TESTED | — | mock RPC only |
| 20 | Startup / RSS | — | — | NOT TESTED | — | needs real display session |
| 21 | Independent audit | — | — | NOT AVAILABLE | — | none performed |

## Notes on commit binding

The local suite and KDF run identify `e474b89`. The final candidate `3aef4b9`
changes documentation only; the code/test tree is identical. Hosted CI reran
the full suite on `3aef4b9` and passed. The `.deb` was built from `b37cede`
(also documentation-only relative to `3aef4b9`), and its hash is recorded in
`3aef4b9`.
