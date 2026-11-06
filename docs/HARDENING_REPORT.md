# Linux hardening report

Status labels: **DONE** means the listed command completed successfully in
this workspace. **PARTIAL** means source controls exist but cannot establish a
real-world claim alone. **NEEDS OWNER** means it requires a device, key, or
operational decision outside this repository.

The evidence record for version 1.0.10 is
[`docs/releases/1.0.10.md`](releases/1.0.10.md). Its status is partial, not a
full-release confirmation.

## Current Linux release gate

| Item | Status | Evidence |
|---|---|---|
| Current-tree secret scan | DONE | `bash scripts/secret-scan.sh` — `Secret scan: current tree has no tracked keystores, private key blocks, or known leaked credentials.` |
| Independent signature parsing | DONE | `cd verification && npm ci && node verify.cjs` — `independent ethers verification: PASS`; 8 field substitutions rejected. |
| SBOM regeneration | DONE | `python3 scripts/sbom.py --out docs/SBOM.json` — 116 packages recorded (26 direct and 90 transitive Dart, 9 npm, 1 direct npm). |
| Production Argon2id backend | DONE | `test/kdf_production_test.dart` — fixed 64 MiB/t=3/p=4, native reference vs pure-Dart agreement, one real round-trip measured at 344 ms native. |
| Dependency advisory review | DONE | `python3 scripts/dependency-audit.py` — no current pub.dev advisory flags reported. This is advisory metadata, not an audit. |
| Static analysis | DONE | `flutter analyze --no-pub` — no issues found. |
| Full Flutter test suite | LOCAL PASS — HOSTED RERUN PENDING | Local serial run on 2026-11-06: 47 files / 299 declarations, 0 failed, 0 timed out. The previous hosted run failed for the reasons recorded in `docs/TESTING_STRATEGY.md`; the fixed runner and KDF backend must pass on the candidate PR before this row becomes hosted-verified. |
| Linux `.deb` artifact integrity | NOT BUILT FOR 1.0.10 | The earlier 1.0.9 package and its signature are historical. A 1.0.10 package must be built from the tagged candidate and verified with `release-check.sh`. |
| Full Linux rebuild from source | PASS (single build) | `flutter build linux --release` completed in 2m03s for 1.0.10. |
| Bit-for-bit reproducibility | PASS with constraint | Two clean builds at fixed path `/tmp/bnb-repro-final` produced identical archive `388f94bf…` and file manifests. Different absolute paths differ because Flutter embeds them; independent-machine proof is still required. |
| Clean Ubuntu 24.04 install, launch, upgrade, uninstall, reinstall | PASS (smoke) | GitHub `ubuntu-24.04` run `42273456783`: install, Xvfb launch, upgrade from 1.0.9 with data marker, uninstall, reinstall. A full interactive UI walkthrough is still not tested. |
| Large-value mainnet safety | NEEDS OWNER | Automated tests cannot prove safety against malware, phishing, a compromised OS, or an incorrect recipient. Perform paper-backup restoration and progressively sized transfers. |

## Release decision

This document does not award a numeric security score. Such a score would be
misleading without an independent review, reproducible clean-machine install,
and operational testing. The release must remain blocked until every required
Linux gate has a current **DONE** entry and the owner completes the device
checks in `docs/FAMILY_GUIDE.md`.

## Residual risks

- A compromised Linux account, kernel, desktop session, clipboard manager, or
  input method can capture secrets before memory hardening helps.
- A recovery phrase copied to cloud storage, a screenshot, or a message can
  bypass all vault encryption.
- BSC transactions are irreversible; RPC redundancy and transaction review do
  not prove a recipient controls an address.
- No independent external security review is recorded for this project.
- Flash storage secure deletion is best-effort because wear leveling can retain
  old physical blocks; crypto-erasure reduces the practical exposure.
