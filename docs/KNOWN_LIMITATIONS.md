# Known Limitations

| ID | Limitation | Status |
|---|---|---|
| LIM-001 | A same-user process with write access to the wallet directory can race filesystem operations. Linux verifies destination device/inode against the committed descriptor immediately after rename, but no pathname check can prevent a replacement after that final check (or after return). The 0700 application data directory is the primary boundary. | Documented residual risk |
| LIM-002 | Non-Linux uses a less capable `dart:io` storage pipeline. | Not release-verified |
| LIM-003 | Directory fsync failure after rename leaves crash durability uncertain. | Explicitly surfaced; never reported as verified durability |
| LIM-004 | Hardware-wallet integration is **not implemented**. Physical Ledger/Trezor/SafePal support cannot be tested because no code path exists. | Not implemented |
| LIM-005 | Clean-VM package installation and upgrade testing is unavailable locally. | Unverified |
| LIM-006 | A historical Android release keystore is exposed in public Git history. Rotation is **NOT VERIFIED**; the denylist is empty; Android releases are blocked. See `docs/security/INCIDENT_2026-11-KEYSTORE.md`. | Operational rotation required; release blocker |
| LIM-007 | Linux now uses a shared nonblocking `flock(2)` advisory lock on a no-follow, 0600 object in the app-data directory for vault and encrypted-log operations. It coordinates cooperating wallet processes only; it does not stop a same-UID program that ignores locks or replaces the lock pathname after the bounded identity check. Non-Linux remains process-local only. Independent-process race and crash-kill coverage is still incomplete. | Partially tested; release blocker |
| LIM-008 | The previous hosted full-suite failure had three causes: a nonportable `rg` dependency, teardown races with encrypted audit logging, and a real-Argon2id rename suite without the `kdf` tag. All three are fixed locally; the 44/44-file suite passed before the newest layers. A hosted rerun of the current 47-file inventory is still required. | Release blocker until hosted CI passes |
| LIM-009 | This wallet has **no independent third-party security audit**. The self-audit, tests, SBOM, and gate are engineering evidence, not an audit opinion. | Unverified |
| LIM-010 | The wallet only builds plain transfers. It has no token-approval or unlimited-allowance UI, so that class of approval abuse is absent today. Adding approvals later requires an explicit cap and a separate review. | Scope limitation |
| LIM-011 | Dart strings and garbage-collected memory cannot be reliably zeroised. `mlockall` is best-effort and `PR_SET_DUMPABLE=0`/core-limit are Linux-only. No secure-erase guarantee is made. | Documented residual risk |
| LIM-012 | Balances, nonces, fees, and history are trusted from the selected RPC endpoint. No light-client or Merkle-proof verification is implemented; a lying endpoint can mislead the review screen, though it cannot forge a local signature. | Documented residual risk |
| LIM-013 | Bit-for-bit reproducibility passes only when both builds use the same absolute path (Flutter embeds `libapp.so`/plugin paths). Two clean builds at `/tmp/bnb-repro-final` matched (`388f94bf…`), but builds at different paths differ. An independent-machine proof is still required. | Partially verified; documented constraint |
| LIM-014 | Linux camera QR scanning is not implemented. Offline cold-wallet transport is file/paste plus QR **display** only. | Not implemented |
