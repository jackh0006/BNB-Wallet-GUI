# Known Limitations

| ID | Limitation | Status |
|---|---|---|
| LIM-001 | A same-user process with write access to the wallet directory can race filesystem operations. Linux verifies destination device/inode against the committed descriptor immediately after rename, but no pathname check can prevent a replacement after that final check (or after return). The 0700 application data directory is the primary boundary. | Documented residual risk |
| LIM-002 | Non-Linux uses a less capable `dart:io` storage pipeline. | Not release-verified |
| LIM-003 | Directory fsync failure after rename leaves crash durability uncertain. | Explicitly surfaced; never reported as verified durability |
| LIM-004 | Physical hardware-wallet and two-device cold-wallet testing is unavailable locally. | Unverified |
| LIM-005 | Clean-VM package installation and upgrade testing is unavailable locally. | Unverified |
| LIM-006 | A historical release keystore is reported exposed in Git history. | Operational rotation required |
| LIM-007 | `vaultOperationLock` and `EncryptedLogStore`'s `_fileLock` are process-local `synchronized.Lock`s only. Multiple application instances have no cross-process serialization; log appends can lose updates, while vault pathname hardening still detects the tested replacement boundaries. | Not cross-process verified |
| LIM-008 | The test runner's full two-phase invocation has not produced a reliable terminal result in this execution environment; focused commands are recorded separately and a full-suite pass is not claimed. | Release blocker |
