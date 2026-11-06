# Self-Audit — 2026-11-06

**Scope:** `1.0.10+4`, wallet code commit
`142929315b7df572ffae93cbc5ab1a2ec2395724`, final release tooling/docs
`03839a0`. Internal self-audit, **not an independent professional audit**.

Three passes were performed: cryptography/key security; blockchain/transaction
security; release/supply-chain/operations. Every finding records evidence and
residual risk. A finding is not closed merely because a code change exists.

---

## Pass A — cryptography and key security

| ID | Finding | Severity | Status | Evidence / residual |
|---|---|---|---|---|
| A-01 | Vault used pure-Dart Argon2id; ~110 s per 64 MiB derivation and repeated derivations crashed the test device | High | Remediated | `lib/kdf.dart` now uses the reference C library (344 ms); `kdf_production_test` cross-checks native vs pure-Dart; parameters unchanged |
| A-02 | Attacker-selected Argon2 header could request unbounded memory/CPU before authentication | High | Remediated | Header policy rejects non-fixed parameters before KDF; `vault_header_validation_test` |
| A-03 | A test-only KDF seam could be shipped by mistake | Medium | Mitigated | `debugKdfOverride` is set inside an `assert`; release builds ignore it; production test remains |
| A-04 | Native library failure could silently change behavior | Medium | Mitigated | Fallback is the same Argon2id algorithm/parameters; no downgrade; measured and documented |
| A-05 | Dart GC memory cannot be securely erased; `mlockall` is best-effort | High | Open residual | `memory_protection_test` asserts dumpable=0/core=0 only; no secure-erase claim |
| A-06 | Linux device secret is a 0600 drawer, not a hardware secure element | High | Open residual | Documented in `CRYPTO.md`/`THREAT_MODEL.md`; same-UID attacker out of scope |
| A-07 | No independent cryptographic audit | High | Open | `SECURITY_SCORECARD.md` awards no audit credit |

Verdict: no known critical cryptographic implementation defect remains in the
candidate; the residual risks are device/OS and audit limitations, not a
parameter downgrade.

---

## Pass B — blockchain and transaction security

| ID | Finding | Severity | Status | Evidence / residual |
|---|---|---|---|---|
| B-01 | ERC-20 intent decoder accepted trailing calldata | High | Remediated | Exact `4+32+32` bytes required; `send_intent_test` regression |
| B-02 | Wrong-chain RPC response could mislead the UI | High | Mitigated | Chain-ID check on connect/probe; `rpc_adversarial_test` wrong-chain and switch cases |
| B-03 | Malicious RPC can lie about balance/nonce/fees/simulation | High | Open residual | No light-client proof; review screen and local signing limit impact |
| B-04 | Token metadata can be fake or decimals wrong | Medium | Mitigated | Contract/decimals shown; bounds; unknown metadata not trusted; tests |
| B-05 | Address poisoning | High | Mitigated heuristic | Full checksummed address, grouped display, affix warning; user can still confirm a wrong valid address |
| B-06 | Approval/unlimited-allowance abuse | Medium | Not applicable today | No approval UI; any future approval requires a cap and review |
| B-07 | Ambiguous broadcast could be retried and double-send | High | Mitigated | Unknown outcome is explicit; no automatic retry; `tx_lifecycle_test` |
| B-08 | Real BSC/Anvil integration not tested | High | Open | Mock RPC only; `TEST_RESULTS.md` marks NOT TESTED |
| B-09 | Cold-signing two-device physical test absent | Medium | Open | Codec/protocol/service tests and ethers.js cross-check pass; no two-device exercise |

Verdict: the transfer path is substantially constrained and tested, but real
node integration and full token-contract semantics remain unverified.

---

## Pass C — release, supply chain and operations

| ID | Finding | Severity | Status | Evidence / residual |
|---|---|---|---|---|
| C-01 | Historical Android signing keystore exposed | Critical | **BLOCKED** | Rotation `NOT VERIFIED`; denylist empty; `INCIDENT_2026-11-KEYSTORE.md` |
| C-02 | Builds differ at different absolute paths | High | Mitigated with constraint | Flutter embeds paths; fixed-path builds match `388f94bf…`; independent-machine proof still missing |
| C-03 | Candidate `.deb` is unsigned | High | **BLOCKED** | No GPG key in this environment; `RELEASE_VERIFICATION.md` |
| C-04 | Clean install/launch/upgrade/uninstall untested locally | High | Mitigated | GitHub `ubuntu-24.04` package-smoke run `42273456783` passed; full interactive UI walkthrough still untested |
| C-05 | No independent audit | High | Open | Self-audit only |
| C-06 | Stale/superseded PRs and unreviewed Dependabot updates | Medium | Open | PRs #2–#9; owner decision |
| C-07 | A failing/timed-out test could be mistaken for a pass | High | Mitigated | `record_check.py`, per-file watchdog, explicit status vocabulary |
| C-08 | Release documentation could drift from evidence | Medium | Mitigated | Manifest/inventory/generated docs drift checks |

Verdict: release integrity is improved but remains blocked by the signing key,
unsigned artifact, and absent independent audit.

---

## Overall

- Critical/high code defects found in this audit were remediated or explicitly
  documented as residual.
- The release remains **PARTIALLY VERIFIED / NOT RELEASABLE**.
- The largest remaining risks are owner-controlled signing, absence of an
  independent audit, RPC trust, and device/OS compromise.
- Provisional self-assessed score: **73/100** (see
  `SECURITY_SCORECARD.md`), not 100.

## Reproduction

Every command and result is listed in `docs/TEST_RESULTS.md`. The exact
candidate commit and artifact hashes are in `release/manifest.json` and
`docs/RELEASE_VERIFICATION.md`.
