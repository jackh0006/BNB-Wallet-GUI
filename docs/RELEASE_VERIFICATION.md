# Release Verification

**Candidate:** `1.1.0+5`
**Source commit:** `0cd7cd6ccc390abeb66d973f79dd5ec9c16d0f54`
**Status:** **PARTIALLY VERIFIED / NOT RELEASABLE**

## Artifact record

| Field | Value |
|---|---|
| Filename | `x-wallet-1.1.0-amd64.deb` |
| Platform | Linux amd64 |
| Version | `1.1.0` |
| Built from | `0cd7cd6ccc390abeb66d973f79dd5ec9c16d0f54` (clean archive) |
| SHA-256 | `see the SHA-256 published on the v1.1.0 GitHub release` |
| Signature | **MISSING** |
| Signature verified | **NO** |
| Provenance | Workflow exists; no published attestation |
| Reproducibility | PASS at fixed path `/tmp/bnb-repro-final`, archive `0e3cb4c1465ad0ac35f8104560ed623b79c4d7194bdb625119f858de1d0e8d4c`; different absolute paths not guaranteed |

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
| Clean install / launch / upgrade / uninstall | PASS (smoke) — GitHub run `42302764476` |
| Android key rotation and denylist | BLOCKED |
| Independent security audit | NOT AVAILABLE |
| Independent-machine reproducibility | NOT TESTED |
| Real BSC/Anvil integration | PASS (Anvil 1.9.0, 3/3) |

## Verification commands

```bash
sha256sum "/home/mhh06/Downloads/X Wallet/x-wallet-1.1.0-amd64.deb"
dpkg-deb -c "/home/mhh06/Downloads/X Wallet/x-wallet-1.1.0-amd64.deb"
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
