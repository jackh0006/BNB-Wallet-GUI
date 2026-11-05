# Release Checklist

Release status: **development only**. This file is a gate list, not a claim
that items are complete.

- [ ] Full automated suite, analyzer, secret scan, dependency review and independent verifier have current recorded results in `docs/HARDENING_REPORT.md`.
- [ ] No unresolved critical/high storage, signing, routing, or secret-exposure finding.
- [ ] Linux AMD64 `.deb` built, detached GPG signature and `SHA256SUMS` generated, installed and launched on a clean Ubuntu environment.
- [ ] Fresh install, upgrade, uninstall, user-data preservation, permissions and offline-routing behavior verified.
- [ ] Release signing key rotation/history exposure response documented and completed.
- [ ] Threat model, security claims, known limitations and traceability reflect the release commit.
- [ ] `BNB_RELEASE_DEB=<artifact> bash scripts/release-check.sh` passes against the exact release artifact.
# M3 storage acceptance addendum

- [ ] Full two-phase test-suite command has a recorded terminal exit status; focused test passes are not a substitute.
- [ ] Cross-process storage coordination is either implemented and tested, or explicitly remains unsupported for release.
- [ ] Process-kill and power-loss limitations remain documented; no crash-recovery journal is currently implemented.
