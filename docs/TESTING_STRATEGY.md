# Testing Strategy

Status labels are evidence, not promises: **IMPLEMENTED**, **TESTED**, and
**VERIFIED** are distinct. A passing mock or an exception-only assertion is
not verification.

## Required gates

| Gate | Command | Current status |
|---|---|---|
| Static analysis | `flutter analyze --no-pub` | Fails quality gate: baseline has warnings/information diagnostics. |
| Full unit/widget suite | `bash scripts/test-suite.sh` | Passed 2026-11-04 on Linux/Flutter 3.47.6: 239 non-KDF tests (1m09s) and 22 KDF tests (2m00s). The runner sets `umask 0077` to match the production storage invariant. |
| Linux M3 security tests | `bash scripts/test-suite.sh test/filesystem_security_test.dart test/rollback_injection_test.dart` | Historical result: 23 tests. Focused post-rename run: `/home/mhh06/develop/flutter/bin/flutter test test/filesystem_security_test.dart` passed 23/23 on 2026-11-04. |
| Log persistence and same-process concurrency | `/home/mhh06/develop/flutter/bin/flutter test test/log_canary_test.dart test/filesystem_security_test.dart` | Passed 2026-11-04: 26/26. Covers atomic/no-follow log persistence, clear, canary confidentiality, and twelve concurrent appends in one process. |
| Secret scan | `bash scripts/secret-scan.sh` | Failed 2026-11-04: detects old hardcoded release-keystore password in history/current-tree scan. Rotation remains required; removal from HEAD alone is insufficient. |
| Independent transaction verification | `cd verification && npm ci && node verify.cjs` | Required before release. |

Every new defect needs a regression test that asserts the intended code path,
the observable state, and preservation of unrelated data.
