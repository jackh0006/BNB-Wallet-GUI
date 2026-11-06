# Security Scorecard

**Date:** 2026-11-06
**Source commit:** `142929315b7df572ffae93cbc5ab1a2ec2395724`
**Status:** provisional, internal self-assessment. **This is not an independent
audit.** A score never overrides a release blocker.

## Scoring rules

- Every point must cite evidence.
- No credit for unimplemented features.
- Mock-only tests are not real-network integration.
- A failed reproducibility check gets no reproducibility credit.
- An unsigned artifact gets no signed-release credit.
- A self-audit gets no independent-audit credit.
- An untested platform gets no compatibility credit.
- Any critical/high unresolved finding blocks production approval regardless of
  score.

## Provisional score: 79 / 100

| Category | Weight | Score | Evidence | Why not full |
|---|---:|---:|---|---|
| Cryptography and key protection | 20 | 16 | Native Argon2id + pure-Dart cross-check; fixed 64 MiB/t=3/p=4; double-wrapped vault; tamper/wrong-password/v1-migration tests; no plaintext logs | No independent audit; no hardware-backed key; Dart memory cannot be securely erased; same-UID malware remains out of scope |
| Transaction and blockchain security | 15 | 12 | Exact ERC-20 calldata; chain-ID validation; EIP-1559 codec; fee/nonce/zero-address checks; signature verification; independent ethers.js check; real Anvil native/ERC-20 tests | No token-approval UI (scope); RPC data is not light-client verified |
| Testing, fuzzing and reliability | 15 | 14 | 49 files / 308 declarations; deterministic fuzz/property; mock-RPC adversarial; real Anvil integration; mutation score 5/5; backup E2E; UI/a11y; hosted CI green | No coverage-guided fuzzing; no long-running soak |
| Supply-chain and CI/CD | 10 | 8 | Pinned action SHAs; CodeQL; secret scan; dependency review; licence inventory; SBOM; least-privilege workflows | Dependabot PRs unreviewed; no published artifact provenance yet; no independent rebuild |
| Reproducible builds and release integrity | 10 | 6 | Fixed-path reproducible archive `388f94bf…`; deterministic gzip; SBOM; release gate; provenance workflow | Different absolute paths differ; no independent-machine proof; `.deb` unsigned; no published attestation |
| Backup, recovery and operational safety | 10 | 8 | Atomic writes; rollback; encrypted backup create/wipe/restore E2E; wrong-password/tamper/truncation; v1 migration | No clean-machine UI restore; disk-full/power-loss coverage incomplete |
| Privacy and network security | 5 | 4 | HTTPS-only policy; SPKI pinning after CA validation; Tor/SOCKS fail-closed; UA scrubbing | No light-client proof; traffic analysis and compromised OS remain out of scope |
| Platform compatibility and performance | 5 | 3 | Ubuntu 24.04 build + `.deb`; package-smoke install/launch/upgrade/uninstall; KDF measured (344 ms) | No startup/RSS; Debian/Fedora/ARM64/Windows/macOS untested |
| UI, accessibility and user safety | 5 | 4 | Keyboard hold-to-confirm; semantics; 200% text scale; full address review; donation separation | No screen-reader session or real display test; warning UX not independently evaluated |
| Documentation, transparency and governance | 5 | 4 | Threat model; known limitations; incident record; generated status; manifest; PR evidence; self-audit | Some records still to be consolidated; stale PRs; no independent review |
| **Total** | **100** | **79** | | |

## Blockers regardless of score

1. Android historical signing key not rotated (`docs/security/INCIDENT_2026-11-KEYSTORE.md`).
2. `.deb` unsigned.
3. Full interactive clean-desktop test and non-Ubuntu installs not tested.
4. No independent security audit.
5. Hardware wallet and real-chain integration not implemented/tested.

## What would raise the score honestly

- Owner-signed artifact with a published fingerprint and verified signature.
- Clean-install CI on Ubuntu 24.04 and Debian 12.
- Independent-machine reproducibility proof at a fixed path.
- (done) Anvil/real-EVM integration tests.
- Mutation testing and coverage reporting.
- Android key rotation and denylist verification.
- Independent professional audit.

## What would not raise the score

- Re-labelling the same tests.
- Removing a failing check.
- Claiming a platform works because it compiles.
- Claiming an audit that did not happen.
- Lowering KDF parameters for speed.
