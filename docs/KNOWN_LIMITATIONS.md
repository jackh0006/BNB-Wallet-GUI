# Known Limitations

| ID | Limitation | Status |
|---|---|---|
| LIM-001 | A same-user process with write access to the wallet directory can race filesystem operations. Linux verifies destination device/inode against the committed descriptor immediately after rename, but no pathname check can prevent a replacement after that final check (or after return). The 0700 application data directory is the primary boundary. | Documented residual risk |
| LIM-002 | Non-Linux uses a less capable `dart:io` storage pipeline. | Not release-verified |
| LIM-003 | Directory fsync failure after rename leaves crash durability uncertain. | Explicitly surfaced; never reported as verified durability |
| LIM-004 | Physical hardware-wallet and two-device cold-wallet testing is unavailable locally. | Unverified |
| LIM-005 | Clean-VM package installation and upgrade testing is unavailable locally. | Unverified |
| LIM-006 | A historical release keystore is reported exposed in Git history. | Operational rotation required |
| LIM-007 | Linux now uses a shared nonblocking `flock(2)` advisory lock on a no-follow, 0600 object in the app-data directory for vault and encrypted-log operations. It coordinates cooperating wallet processes only; it does not stop a same-UID program that ignores locks or replaces the lock pathname after the bounded identity check. Non-Linux remains process-local only. Independent-process race and crash-kill coverage is still incomplete. | Partially tested; release blocker |
| LIM-008 | Hosted run 42060236057 exposed a nonportable `rg` dependency in the per-file driver, teardown races between `lock()` audit logging and fixture deletion, and an untagged real-Argon2id rename suite. These are fixed locally: portable `grep` detects KDF tags, the driver reports discovered/executed/skipped counts and fails closed on unexecuted files, teardown no longer starts a competing audit write, and the rename suite is KDF-tagged. A fresh hosted full-suite result is still required. | Release blocker until verified in CI |
