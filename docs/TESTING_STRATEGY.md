# Testing Strategy

Status labels are evidence, not promises: **IMPLEMENTED**, **TESTED**, and
**VERIFIED** are distinct. A passing mock or an exception-only assertion is
not verification.

## Required gates

| Gate | Command | Current status |
|---|---|---|
| Static analysis | `flutter analyze --no-pub` | Fails quality gate: baseline has warnings/information diagnostics. |
| Full unit/widget suite | `bash scripts/test-suite.sh` | Passed 2026-11-04 on Linux/Flutter 3.47.6: 239 non-KDF tests (1m09s) and 22 KDF tests (2m00s). The runner sets `umask 0077` to match the production storage invariant. |
| Linux M3 security tests | `bash scripts/test-suite.sh test/filesystem_security_test.dart test/rollback_injection_test.dart` | Passed 2026-11-04: 23 tests. |
| Secret scan | `bash scripts/secret-scan.sh` | Required; historical-key exposure remains a blocker until operational rotation is evidenced. |
| Independent transaction verification | `cd verification && npm ci && node verify.cjs` | Required before release. |

Every new defect needs a regression test that asserts the intended code path,
the observable state, and preservation of unrelated data.
