# Release Checklist

Release status: **development only**. This file is a gate list, not a claim
that items are complete.

- [ ] Full automated suite, analyzer, secret scan, dependency review and independent verifier have current recorded results.
- [ ] No unresolved critical/high storage, signing, routing, or secret-exposure finding.
- [ ] Linux AMD64 `.deb` built, checksum generated, installed and launched on a clean Ubuntu environment.
- [ ] Fresh install, upgrade, uninstall, user-data preservation, permissions and offline-routing behavior verified.
- [ ] Release signing key rotation/history exposure response documented and completed.
- [ ] Threat model, security claims, known limitations and traceability reflect the release commit.
