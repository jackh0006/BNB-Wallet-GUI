# Release Checklist

Release status: **development only**. This file is a gate list, not a claim
that items are complete.

## Source and evidence

- [ ] `dart format --output=none --set-exit-if-changed lib test tool` passes.
- [ ] `flutter analyze --no-pub` has no issues.
- [ ] `bash scripts/test-suite.sh` has a recorded zero exit status from this
      exact commit. Focused passes are not a substitute.
- [ ] `bash scripts/secret-scan.sh` passes on the current tree.
- [ ] `bash scripts/secret-scan.sh --history` is recorded as a report, not a
      pass: the historical Android exposure remains public.
- [ ] `python3 scripts/dependency-audit.py` reports no unresolved advisory.
- [ ] `python3 scripts/license-check.py` has release-owner review.
- [ ] `python3 scripts/sbom.py --out docs/SBOM.json` is committed and current.
- [ ] `python3 scripts/test_inventory.py --check` passes.
- [ ] `python3 scripts/release_manifest.py --check` passes.
- [ ] `python3 scripts/generate_docs.py --check` passes.
- [ ] `python3 scripts/release-gate.py` reports `VERIFIED` for the exact
      tagged commit and artifact. Anything else is not a confirmed release.

## Security

- [ ] No unresolved critical/high storage, signing, routing, or
      secret-exposure finding.
- [ ] `docs/security/INCIDENT_2026-11-KEYSTORE.md` is closed: the old Android
      fingerprint is denylisted and the replacement signer is approved.
- [ ] No Android artifact is published while the incident is open.
- [ ] Threat model, security claims, known limitations and the self-assessment
      reference this release commit.
- [ ] No independent audit is claimed. If one exists, link its scope and date.

## Linux artifact

- [ ] Linux AMD64 `.deb` built from the tagged source, with detached GPG
      signature and `SHA256SUMS`.
- [ ] `BNB_RELEASE_DEB=<artifact> bash scripts/release-check.sh` passes against
      that exact artifact.
- [ ] Installed and launched on a clean supported Ubuntu environment.
- [ ] Fresh install, upgrade, uninstall, data preservation, file permissions,
      and offline-routing failure behavior verified.
- [ ] Artifact SHA-256 and signature fingerprint are recorded in the release
      evidence bundle.

## Reproducibility

- [ ] `bash scripts/reproducibility-check.sh` has a recorded result. If the
      archives differ, the release is marked **not reproducible**; provenance
      evidence must not be described as reproducibility.
- [ ] The exact Flutter/Dart toolchain is pinned for the release build.

## Documentation

- [ ] README, `docs/GENERATED_STATUS.md`, release notes, SBOM references,
      compatibility and performance tables are generated from verified
      evidence and committed.
- [ ] Known limitations are published, including: no independent audit, no
      hardware-wallet support, no secure-erase guarantee, no anonymity claim.
- [ ] Donation addresses match the source repository exactly and are never
      shown inside a transaction confirmation.
