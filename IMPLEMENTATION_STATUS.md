# Implementation Status

**Last updated:** 2026-11-06
**Source of truth:** `release/manifest.json`, `docs/testing/test-inventory.json`,
`docs/GENERATED_STATUS.md`, and the GitHub Actions runs. This file is a
human-readable index, not a second source of truth.

## Current candidate

| Item | Value |
|---|---|
| Version | `1.1.0+5` |
| Branch | `release/1.0.10` |
| Tested source commit | `0cd7cd6ccc390abeb66d973f79dd5ec9c16d0f54` |
| Evidence bundle | `release/evidence.json` (source `b50ad2c`, checks/artifact `0cd7cd6`) |
| Code commit | `e474b8956a68febf44ef780c7decf898e9050018` |
| Pull request | <https://github.com/jackh0006/X-Wallet/pull/10> |
| Hosted CI | All required checks pass on `dd57ea9` (push `42306383769`, PR `42306389744`) |
| Release status | **PARTIALLY VERIFIED / NOT RELEASABLE** |
| Final unsigned package | `x-wallet-1.1.0-amd64.deb`, SHA-256 `see the SHA-256 published on the v1.1.0 GitHub release` |

## Verified

- Native Argon2id (`lib/kdf.dart`) with fixed 64 MiB / t=3 / p=4; measured
  **344 ms** vs ~110 s for the debug pure-Dart fallback.
- Exact ERC-20 transfer calldata in `SendIntent`; trailing bytes rejected.
- 49 test files / 308 declarations; default suite 48/48 pass in 600 s; 3 real-Anvil tests; mutation score 5/5; backup E2E 4/4.
- Independent ethers.js cold-signature verification; 8 substitutions rejected.
- Linux `flutter build linux --release` pass; `.deb` package built.
- Secret scan, dependency advisory audit, licence inventory, SBOM, test
  inventory, generated-doc drift, dependency review, and CodeQL pass.
- Reproducibility: two clean builds at fixed path `/tmp/bnb-repro-final` with
  `SOURCE_DATE_EPOCH=0` and `gzip -n` produced archive
  `0e3cb4c1465ad0ac35f8104560ed623b79c4d7194bdb625119f858de1d0e8d4c`.
  Different absolute paths are not guaranteed to match because Flutter embeds
  the path in `libapp.so` and plugin libraries.
- Clean install/launch/upgrade/uninstall smoke: GitHub `ubuntu-24.04` run
  `42302764476` installs the `.deb`, launches under Xvfb, upgrades from the
  public 1.0.9 package with a data marker, uninstalls, and reinstalls.

## Not verified / blocked

| Item | Status | Reason |
|---|---|---|
| Android signing key rotation | **BLOCKED** | Owner must rotate; denylist is empty; no APK may be published |
| `.deb` GPG signature | **MISSING** | No release GPG key in this environment |
| Independent security audit | **NOT AVAILABLE** | None performed |
| Hardware wallet | **NOT IMPLEMENTED** | No Ledger/Trezor code path or device |
| Real BSC/Anvil integration | **PASS (local Anvil)** | Native transfer, wrong chain, ERC-20 deploy/transfer/approve/revoke/revert on Anvil 1.9.0 chain 97 |
| Windows / macOS / ARM64 | **NOT TESTED** | No builds or hardware |
| Startup / RSS performance | **NOT TESTED** | Needs a real display session |
| Multisig / large-value architecture | **RESEARCH ONLY** | No custom contract deployed |

## Next actions

1. Owner: rotate Android key, record old fingerprint in
   `release/android-signer-denylist.txt`, approve the new signer.
2. Owner: provide GPG signing key/approved release host; sign and verify the
   final `.deb`.
3. Engineering: integration and package-smoke CI jobs are implemented and passing.
4. Engineering: complete the three-pass self-audit and update
   `docs/SECURITY_SCORECARD.md`.
5. Owner: review and merge PR #10; do not publish while any gate is incomplete.
