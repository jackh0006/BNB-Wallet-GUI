# Known Limitations

| ID | Limitation | Status |
|---|---|---|
| LIM-001 | A same-user process with write access to the wallet directory can race filesystem operations; descriptor-relative operations reduce but cannot eliminate this OS-level threat. | Documented residual risk |
| LIM-002 | Non-Linux uses a less capable `dart:io` storage pipeline. | Not release-verified |
| LIM-003 | Directory fsync failure after rename leaves crash durability uncertain. | Explicitly surfaced; never reported as verified durability |
| LIM-004 | Physical hardware-wallet and two-device cold-wallet testing is unavailable locally. | Unverified |
| LIM-005 | Clean-VM package installation and upgrade testing is unavailable locally. | Unverified |
| LIM-006 | A historical release keystore is reported exposed in Git history. | Operational rotation required |
