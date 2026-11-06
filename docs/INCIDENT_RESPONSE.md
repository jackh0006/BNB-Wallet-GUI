# Incident Response

**Status:** internal plan. No incident is closed by this document.

## Severity

- **Critical:** private key/seed theft, signed malicious release, active fund
  loss.
- **High:** signing-identity compromise, vault bypass, remote code execution,
  supply-chain compromise.
- **Medium:** denial of service, metadata leak, local file permission issue.
- **Low:** documentation error, non-exploitable UI defect.

## Immediate steps

1. Stop distribution of the affected artifact; do not delete evidence.
2. Preserve logs, commit IDs, artifact hashes, and timestamps. Never copy
   secrets into the incident record.
3. Determine whether keys, seeds, signing identities, or user funds are
   affected.
4. Rotate exposed credentials outside the repository. Do not commit a
   replacement key.
5. Publish a clear notice with affected versions, hashes, and user actions.
6. Add a regression test and a release-gate rule that would have caught it.

## Historical Android keystore

The old `scripts/release.keystore` is compromised. Rotation remains
`NOT VERIFIED`; the denylist is empty; Android releases are blocked. See
`docs/security/INCIDENT_2026-11-KEYSTORE.md`. The old signing identity must
never be reused.

## Communication

- Security reports: `jackh109867@gmail.com` (private, no public issue).
- Do not request seeds, private keys, or vault passwords.
- Publish the signing-key fingerprint and artifact hashes through an
  independent channel.

## Post-incident

- Record root cause, detection gap, fix, regression test, and residual risk.
- Update the threat model and scorecard.
- Re-run the full release gate from a clean checkout.
- Do not claim the incident is resolved until the owner action is verified.
