# Linux hardening report

Status labels: **DONE** means the listed command completed successfully in
this workspace. **PARTIAL** means source controls exist but cannot establish a
real-world claim alone. **NEEDS OWNER** means it requires a device, key, or
operational decision outside this repository.

The evidence record for version 1.0.9 is
[`docs/releases/1.0.9.md`](releases/1.0.9.md). Its status is partial, not a
full-release confirmation.

## Current Linux release gate

| Item | Status | Evidence |
|---|---|---|
| Current-tree secret scan | DONE | `bash scripts/secret-scan.sh` — `Secret scan: current tree has no tracked keystores, private key blocks, or known leaked credentials.` |
| Independent signature parsing | DONE | `cd verification && npm ci && node verify.cjs` — `independent ethers verification: PASS`; 8 field substitutions rejected. |
| SBOM regeneration | DONE | `python3 scripts/sbom.py --out docs/SBOM.json` — 116 packages recorded (25 direct and 91 transitive Dart, 9 npm, 1 direct npm). |
| Dependency advisory review | DONE | `python3 scripts/dependency-audit.py` — no current pub.dev advisory flags reported. This is advisory metadata, not an audit. |
| Static analysis | DONE | `flutter analyze --no-pub` — no issues found. |
| Full Flutter test suite | FIXED — NOT VERIFIED | Hosted Ubuntu run [42060236057](https://github.com/jackh0006/BNB-Wallet-GUI/actions/runs/42060236057) exited 1: 37 files passed and 5 files did not. Its exact root causes were: absent `rg` made the driver apply the ordinary 120-second budget to every file (including KDF-tagged suites); redundant teardown calls to `lock()` raced asynchronous encrypted audit logging with removal of the fixture directory; and `vault_rename_test.dart` used real Argon2id without a `kdf` tag. The driver now uses portable `grep`, records discovery/execution/skips, and fails if any file is unexecuted; the teardown races are removed and the rename suite is tagged. A fresh hosted run is required before a pass is claimed. |
| Linux `.deb` artifact integrity | DONE | `bnb-wallet-1.0.9-amd64.deb` was packaged with the current release documents. `dpkg-deb --info`, `sha256sum --check SHA256SUMS`, and `gpg --verify` passed; the detached release signature is by fingerprint `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`. The exact checksum belongs in the matching external `SHA256SUMS`, not this packaged document. |
| Full Linux rebuild from source | NOT COMPLETED | The current Flutter build did not complete in the resource-constrained session. The application source is unchanged from the bundle used for the package; only release scripts and documentation changed. A clean full rebuild remains a release gate. |
| Clean Ubuntu 22.04/24.04 install and launch | NEEDS OWNER | No clean Ubuntu VM/container with desktop launch support is available in this workspace. |
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
