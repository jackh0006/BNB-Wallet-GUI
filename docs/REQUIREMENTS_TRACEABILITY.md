# Requirements Traceability

This is the living, audit-first matrix. Historical IDs are retained even
where earlier documentation duplicated them.

| ID | Requirement | Implementation | Test evidence | Status |
|---|---|---|---|---|
| M3-08 | Rollback failure injection reaches rollback write | `AppState.importVault`, `atomicWrite` | `rollback_injection_test.dart` | TESTED |
| M3-09 | Linux must not downgrade to portable storage | `storage.dart`, `PosixFs` | filesystem case 00 | TESTED |
| M3-15 | Persisted write outcome distinguishes commit states | `AtomicWriteState` | rollback/fs tests | TESTED |
| M3-24 | Verify that destination pathname still names committed inode after rename; never unlink a concurrently reused temp name | `posix_fs.dart::statChildNoFollow`, `storage.dart::atomicWrite` | `filesystem_security_test.dart`: cases 11d and 11e; `/home/mhh06/develop/flutter/bin/flutter test test/filesystem_security_test.dart` (23/23, 2026-11-04) | TESTED |
| M3-25 | Every atomic-write caller must not report an unverified result as success | `storage.dart` wrappers; `app_state.dart` move/export/import rollback | caller inventory: direct `atomicWrite` uses in `storage.dart` and `app_state.dart`; focused `/home/mhh06/develop/flutter/bin/flutter test test/filesystem_security_test.dart test/rollback_injection_test.dart` (2026-11-04) | TESTED (focused) |
| M4-05 | EVM transaction signing | `wallet_core.dart`, cold codec | codec/cold tests | IMPLEMENTED; broader audit pending |
| M5-01 | Central network routing/offline enforcement | `net/privacy_client.dart`, `rpc_service.dart` | partial tests | IN PROGRESS |
| M7-01 | Hardware wallet support | — | no physical evidence | BLOCKED |
| M10-01 | Linux package installation/upgrade | packaging scripts | no clean environment evidence | BLOCKED |

All other requirements from the master directive remain **NOT STARTED**,
**IN PROGRESS**, or **UNVERIFIED** until this matrix is expanded with direct
implementation and test evidence. They must not be inferred complete from
historical prose.
