# Requirements Traceability

This is the living, audit-first matrix. Historical IDs are retained even
where earlier documentation duplicated them.

| ID | Requirement | Implementation | Test evidence | Status |
|---|---|---|---|---|
| M3-08 | Rollback failure injection reaches rollback write | `AppState.importVault`, `atomicWrite` | `rollback_injection_test.dart` | TESTED |
| M3-09 | Linux must not downgrade to portable storage | `storage.dart`, `PosixFs` | filesystem case 00 | TESTED |
| M3-15 | Persisted write outcome distinguishes commit states | `AtomicWriteState` | rollback/fs tests | TESTED |
| M4-05 | EVM transaction signing | `wallet_core.dart`, cold codec | codec/cold tests | IMPLEMENTED; broader audit pending |
| M5-01 | Central network routing/offline enforcement | `net/privacy_client.dart`, `rpc_service.dart` | partial tests | IN PROGRESS |
| M7-01 | Hardware wallet support | — | no physical evidence | BLOCKED |
| M10-01 | Linux package installation/upgrade | packaging scripts | no clean environment evidence | BLOCKED |

All other requirements from the master directive remain **NOT STARTED**,
**IN PROGRESS**, or **UNVERIFIED** until this matrix is expanded with direct
implementation and test evidence. They must not be inferred complete from
historical prose.
