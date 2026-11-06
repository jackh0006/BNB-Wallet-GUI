# Security Audit — Index

This is an internal self-audit index, **not an independent audit**.

- Current findings register: [`../SECURITY_AUDIT.md`](../SECURITY_AUDIT.md)
- 2026-11-04 adversarial audit: [`SECURITY_AUDIT_2026-11-04.md`](SECURITY_AUDIT_2026-11-04.md)
- Threat model: [`THREAT_MODEL.md`](THREAT_MODEL.md)
- Three-pass self-audit: [`SELF_AUDIT_2026-11-06.md`](SELF_AUDIT_2026-11-06.md)
- Independent review guide: [`INDEPENDENT_REVIEW_GUIDE.md`](INDEPENDENT_REVIEW_GUIDE.md)
- Risk register: [`SECURITY_RISK_REGISTER.md`](SECURITY_RISK_REGISTER.md)
- Scorecard: [`SECURITY_SCORECARD.md`](SECURITY_SCORECARD.md)
- Incident: [`security/INCIDENT_2026-11-KEYSTORE.md`](security/INCIDENT_2026-11-KEYSTORE.md)

## Current blocking findings

| ID | Severity | Status | Summary |
|---|---|---|---|
| AUD-02 | High | Open, owner action | Historical Android signing key exposed; rotation `NOT VERIFIED` |
| R-14 | High | Partially mitigated | Reproducibility proven only at a fixed path on one machine |
| R-16 | High | Open | No independent security audit |
| Package signature | High | Missing | Candidate `.deb` is unsigned |
| Clean install | High | Not tested | No install/launch/upgrade evidence |

## Remediated findings (this candidate)

| ID | Severity | Evidence |
|---|---|---|
| AUD-10 | High | Native Argon2id wired in; 344 ms; production parameters unchanged |
| AUD-11 | Medium | Exact ERC-20 calldata; trailing bytes rejected |
| AUD-12 | Medium | Test stability: 47/47 files; no KDF segfault |
| AUD-13 | Low | Hardware matrix corrected to `NOT IMPLEMENTED` |
| AUD-14 | Low | Machine-readable manifest + generated docs + gate |

A finding is not closed because a code change exists. It closes only when the
issue is reproduced, the fix is tested, and the exact commit/result is recorded.
