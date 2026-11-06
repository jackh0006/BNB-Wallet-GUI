# Implementation Status

**Last updated:** 2026-11-06
**Source of truth:** `release/manifest.json`, `docs/testing/test-inventory.json`,
`docs/GENERATED_STATUS.md`, and the GitHub Actions runs. This file is a
human-readable index, not a second source of truth.

## Current candidate

| Item | Value |
|---|---|
| Version | `1.0.10+4` |
| Branch | `release/1.0.10` |
| HEAD | `142929315b7df572ffae93cbc5ab1a2ec2395724` |
| Code commit | `e474b8956a68febf44ef780c7decf898e9050018` |
| Pull request | <https://github.com/jackh0006/BNB-Wallet-GUI/pull/10> |
| Hosted CI | All required checks pass on `1429293` (push `42273447503`, PR `42273456740`) |
| Release status | **PARTIALLY VERIFIED / NOT RELEASABLE** |
| Final unsigned package | `bnb-wallet-1.0.10-amd64.deb`, SHA-256 `734ccd3bbf0754db6c67f8b00d484d6c0751001883cd18a9112a33fa680cf088` |

## Verified

- Native Argon2id (`lib/kdf.dart`) with fixed 64 MiB / t=3 / p=4; measured
  **344 ms** vs ~110 s for the debug pure-Dart fallback.
- Exact ERC-20 transfer calldata in `SendIntent`; trailing bytes rejected.
- 47 test files / 299 declarations; local 47/47 pass and hosted CI pass.
- Independent ethers.js cold-signature verification; 8 substitutions rejected.
- Linux `flutter build linux --release` pass; `.deb` package built.
- Secret scan, dependency advisory audit, licence inventory, SBOM, test
  inventory, generated-doc drift, dependency review, and CodeQL pass.
- Reproducibility: two clean builds at fixed path `/tmp/bnb-repro-final` with
  `SOURCE_DATE_EPOCH=0` and `gzip -n` produced archive
  `134e6b064dcc22b57a23136031b3224b6594af2f9efeb2ad388dfc3b2e6c86d4`.
  Different absolute paths are not guaranteed to match because Flutter embeds
  the path in `libapp.so` and plugin libraries.
- Clean install/launch/upgrade/uninstall smoke: GitHub `ubuntu-24.04` run
  `42273456783` installs the `.deb`, launches under Xvfb, upgrades from the
  public 1.0.9 package with a data marker, uninstalls, and reinstalls.

## Not verified / blocked

| Item | Status | Reason |
|---|---|---|
| Android signing key rotation | **BLOCKED** | Owner must rotate; denylist is empty; no APK may be published |
| `.deb` GPG signature | **MISSING** | No release GPG key in this environment |
| Independent security audit | **NOT AVAILABLE** | None performed |
| Hardware wallet | **NOT IMPLEMENTED** | No Ledger/Trezor code path or device |
| Real BSC/Anvil integration | **NOT TESTED** | Mock RPC only |
| Windows / macOS / ARM64 | **NOT TESTED** | No builds or hardware |
| Startup / RSS performance | **NOT TESTED** | Needs a real display session |
| Multisig / large-value architecture | **RESEARCH ONLY** | No custom contract deployed |

## Next actions

1. Owner: rotate Android key, record old fingerprint in
   `release/android-signer-denylist.txt`, approve the new signer.
2. Owner: provide GPG signing key/approved release host; sign and verify the
   final `.deb`.
3. Engineering: add an Anvil integration job and a clean-install CI job.
4. Engineering: complete the three-pass self-audit and update
   `docs/SECURITY_SCORECARD.md`.
5. Owner: review and merge PR #10; do not publish while any gate is incomplete.
