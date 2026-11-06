# Release Verification

**Candidate:** `1.0.10+4`
**Source commit:** `3aef4b908fded5e92823c76f02d4016265c8bf12`
**Status:** **PARTIALLY VERIFIED / NOT RELEASABLE**

## Artifact record

| Field | Value |
|---|---|
| Filename | `bnb-wallet-1.0.10-amd64.deb` |
| Platform | Linux amd64 |
| Version | `1.0.10` |
| Built from | `b37cede4671617c72f644d0c1e22861ac537e13b` (documentation-only ancestor of `3aef4b9`) |
| SHA-256 | `0ab7e99faf4639d3a66fe18509c19d8a5843793cafe6d2addde9e77b4de58349` |
| Signature | **MISSING** |
| Signature verified | **NO** |
| Provenance | Workflow exists; no published attestation |
| Reproducibility | PASS at fixed path `/tmp/bnb-repro-final`, archive `388f94bf49c946c9d3da89c5df8f2de1e8cfeae389c0733b155001d3c40165ab`; different absolute paths not guaranteed |

## Verified checks

- Hosted CI on `3aef4b9`: all required contexts pass (push `42261933060`,
  PR `42261942195`).
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
| Clean install / launch / upgrade / uninstall | NOT TESTED |
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

Do not call this release verified, signed, independently audited, or suitable
for significant funds. The exact evidence commit for CI is `3aef4b9`; the
artifact was produced from `b37cede` and is recorded here, but it is unsigned
and not install-tested.
