# Release Verification

**Candidate:** `1.0.10+4`
**Source commit:** `142929315b7df572ffae93cbc5ab1a2ec2395724`
**Status:** **PARTIALLY VERIFIED / NOT RELEASABLE**

## Artifact record

| Field | Value |
|---|---|
| Filename | `bnb-wallet-1.0.10-amd64.deb` |
| Platform | Linux amd64 |
| Version | `1.0.10` |
| Built from | `142929315b7df572ffae93cbc5ab1a2ec2395724` |
| SHA-256 | `734ccd3bbf0754db6c67f8b00d484d6c0751001883cd18a9112a33fa680cf088` |
| Signature | **MISSING** |
| Signature verified | **NO** |
| Provenance | Workflow exists; no published attestation |
| Reproducibility | PASS at fixed path `/tmp/bnb-repro-final`, archive `134e6b064dcc22b57a23136031b3224b6594af2f9efeb2ad388dfc3b2e6c86d4`; different absolute paths not guaranteed |

## Verified checks

- Hosted CI on `1429293`: all required contexts pass (push `42278713164`,
  PR `42278724511`).
- Local full suite: 47/47 files; static analysis clean; secret scan current
  tree clean; dependency audit clean; SBOM current; test inventory current.
- Independent ethers.js cold-signature verification passes; 8 substitutions
  rejected.
- Linux release build succeeds; `.deb` extracts and all shared libraries
  resolve on the build host.
- Reproducibility procedure passes at the documented fixed path.

## Missing mandatory gates

| Gate | Status |
|---|---|
| GPG signature and verification | MISSING |
| Clean install / launch / upgrade / uninstall | PASS (smoke) — GitHub run `42273456783` |
| Android key rotation and denylist | BLOCKED |
| Independent security audit | NOT AVAILABLE |
| Independent-machine reproducibility | NOT TESTED |
| Real BSC/Anvil integration | NOT TESTED |

## Verification commands

```bash
sha256sum "/home/mhh06/Downloads/BNB Wallet/bnb-wallet-1.0.10-amd64.deb"
dpkg-deb -c "/home/mhh06/Downloads/BNB Wallet/bnb-wallet-1.0.10-amd64.deb"
python3 scripts/release-gate.py
```

## Machine-readable records

- `release/reproducibility.json` — fixed-path result and constraint.
- `release/package-smoke.json` — install/launch/upgrade/uninstall run.
- `release/manifest.json` — source/toolchain/SBOM/test-inventory identity.
- `docs/evidence/2026-11-06/` — logs and environment.

Do not call this release verified, signed, independently audited, or suitable
for significant funds. The evidence bundle names `1429293` as the source
commit. The artifact is unsigned and not published.
