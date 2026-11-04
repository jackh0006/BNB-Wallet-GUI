# M3 Filesystem Security Corrections — Evidence Report

**Date**: 2026-11-04
**Baseline Commit**: `9a057fc005ecfe7df7946bf747497c5ebd03d87b` (HEAD before this round)
**Working Tree Commit**: (to be filled after push)
**Classification**: **Self-assessed — M3 INCOMPLETE** — M3-06, M3-08, crash-recovery journal pending

---

## Summary

This round implements the user-specified "M3 Final Symlink and Filesystem Security Corrections" against the baseline. The changes close remaining TOCTOU windows, add errno-aware symlink classification, enforce descriptor-based operations on Linux, add a dedicated Linux integration test suite (20 tests covering all 11 required cases + regression race cases), fix a pre-existing fire-and-forget log append race, and update documentation honestly.

**Verdict**: **M3 INCOMPLETE** — M3-06 (vault-version test-construction fix), M3-08 (import-rollback write-failure injection), and the persistent crash-recovery journal limitation remain deferred by user decision.

---

## Exact Commands, Exit Codes, Test Counts, and Logs

### 1. Analyzer (post log-lock fix)
```bash
cd /home/mhh06/BNB-Wallet-GUI && flutter analyze --no-pub
```
- **Exit code**: 1 (warnings only; zero errors)
- **Issues**: 124 total (127 at HEAD → 124 in WT; 3 pre-existing fixed)
- **All remaining items in changed files verified PRE-EXISTING at HEAD**

### 2. Non-KDF Full Battery
```bash
cd /home/mhh06/BNB-Wallet-GUI && umask 0077 && flutter test --exclude-tags kdf --concurrency=2
```
- **Exit code**: 0
- **Result**: **+238: All tests passed!**
- **Duration**: ~1m28s

### 3. KDF Suites (Individual, Sequential)
```bash
cd /home/mhh06/BNB-Wallet-GUI && umask 0077 && flutter test test/vault_test.dart --timeout 600s
```
- **Exit code**: 0
- **Result**: **+7 passed** (VaultCipher v2 envelope + v1 migration)

```bash
cd /home/mhh06/BNB-Wallet-GUI && umask 0077 && flutter test test/workers_test.dart --timeout 900s
```
- **Exit code**: 0
- **Result**: **+3 passed** (Argon2id 64 MiB isolate jobs)

```bash
cd /home/mhh06/BNB-Wallet-GUI && umask 0077 && flutter test test/vault_import_rollback_kdf_test.dart --timeout 900s
```
- **Exit code**: 1
- **Result**: **+9 passed, −1 failed** (pre-existing test-construction artifact identical to HEAD baseline)
- **Duration**: 52s
- **Baseline verification**: Ran same file at HEAD → **+9 −1 in 52s** (identical failure message)

### 4. New Linux Filesystem Security Integration Tests
```bash
cd /home/mhh06/BNB-Wallet-GUI && flutter test test/filesystem_security_test.dart
```
- **Exit code**: 0
- **Result**: **+20: All tests passed!**
- **Coverage**: All 11 required cases + race regression (11a/11b/11c) + mechanism tests

#### Required Cases Exercised (test names):
| # | Test Case | Test Name |
|---|-----------|-----------|
| 1 | Regular file classified as regularFile | `case 01 — regular file: classified as regularFile` |
| 2 | Directory classified as directory (never writable dest) | `case 02 — directory: classified as directory (never writable dest)` |
| 3 | Valid symlink detected without following | `case 03 — valid symlink: detected without following it` |
| 4 | Broken symlink detected (exists() false) | `case 04 — broken symlink: detected even though exists() is false` |
| 5 | Missing path → distinct clean answer | `case 05 — missing path: distinct clean answer (missing, not error)` |
| 6 | Inaccessible parent → EACCES fails closed | `case 06 — inaccessible parent directory: EACCES fails closed, NOT "missing"` |
| 7 | Inaccessible target → regularFile type but read fails closed | `case 07 — inaccessible target: mode-000 regular file refused on read` |
| 8 | Symlink destination in atomicWrite → refused | `case 08 — symlink destination in atomicWrite is refused, original preserved` |
| 9 | Broken-symlink destination in atomicWrite → refused | `case 09 — broken-symlink destination in atomicWrite is refused` |
| 10 | Parent-directory symlink → refused via realpath equality | `case 10 — parent-directory symlink: refused via realpath equality` |
| 11 | Path replacement between validation and use → use-time recheck closes it | `case 11a — symlink swapped in before commit: use-time recheck refuses` |

#### Race Regression Tests (via production hooks):
| Test | Scenario | Result |
|------|----------|--------|
| 11a | Symlink swapped in before commit | Refused; attacker's target untouched |
| 11b | Regular file appears under fresh destination | Refused; possum file preserved |
| 11c | Existing destination deleted mid-write | Atomic replace still works |

#### Mechanism Guarantee Tests:
| Test | Guarantee Verified |
|------|-------------------|
| `temporary file is created 0600 AT CREATION TIME under a permissive umask` | mkstemp mode 0600 despite umask 0002 |
| `temp files are cleaned up on refusal and never on success` | Cleanup semantics correct |
| `atomic replacement of an existing regular destination works` | RENAME_NOREPLACE + renameat path |
| `mkstempSecure: mode 0600 under umask 0002 verified via stat(1)` | Shell `stat -c '%a'` confirms 600 |
| `readRegularFileNoFollow caps oversized content and honors missing` | Size cap + null-for-missing |
| `descriptor round trip through mkstemp+write+read matches byte for byte` | 100KB fd I/O element-wise compare |

### 5. Linux Release Build
```bash
cd /home/mhh06/BNB-Wallet-GUI && flutter build linux --release
```
- **Exit code**: 0
- **Output**: `build/linux/x64/release/bundle/bnb_wallet_gui`

### 6. Linux `.deb` Build + Verification
```bash
cd /home/mhh06/BNB-Wallet-GUI && bash scripts/build-deb.sh
```
- **Exit code**: 0
- **Artifact**: `/home/mhh06/Downloads/BNB Wallet/bnb-wallet-1.0.7-amd64.deb`

```bash
sha256sum -c bnb-wallet-1.0.7-amd64.deb.sha256
```
- **Exit code**: 0
- **SHA256**: `b5c6aaa4eee70f53ce7596c9da43b6129fb1391a65b510c4d9c2bc68489317dc`

```bash
gpg --verify bnb-wallet-1.0.7-amd64.deb.asc bnb-wallet-1.0.7-amd64.deb
```
- **Exit code**: 0
- **Signature**: Good (EDDSA key `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`, keyid `D8C0CEC84BCCE06B`)

```bash
dpkg -c bnb-wallet-1.0.7-amd64.deb | grep -iE 'jks|keystore|p12|pfx|key.properties|mnemonic|seed|private_key|drawer|vault'
```
- **Exit code**: 0
- **Secret matches**: 0 (clean)

### 7. Independent Ethers.js Cold-Signature Verification
```bash
cd /home/mhh06/BNB-Wallet-GUI/verification && npm ci && node verify.cjs
```
- **Exit code**: 0
- **Result**: `independent ethers verification: PASS`
- **Signer**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- **8 substitution checks rejected**

### 8. Staged `.deb` Install Test (Unprivileged, User-Approved)
```bash
stage=/tmp/opencode/debtest
dpkg-deb -x bnb-wallet-1.0.7-amd64.deb "$stage/root"
HOME="$stage/home" XDG_DATA_HOME="$stage/home/.local/share" ... DISPLAY=:0 XAUTHORITY=... "$stage/root/usr/lib/bnb-wallet/bnb_wallet_gui"
```
- **Shell umask**: 0002 (desktop default, intentionally NOT touched)
- **Result**: App launched, created data directories
- **Permission verification** (`stat -c '%A %a'` on all created entries):
  - **All directories**: `drwx------ 700` (including `.local/share/com.jackh0006.bnb_wallet_gui`)
  - **All files**: `-rw------- 600` (pulse cookie, mesa shader cache, ibus)
- **Mechanism**: `umask(077)` in `linux/runner/main.cc` enforced at process start; mkstemp 0600 is umask-independent

### 9. Secret Scan
```bash
cd /home/mhh06/BNB-Wallet-GUI && bash scripts/secret-scan.sh
```
- **Exit code**: 1 (by design)
- **Finding**: "old hardcoded release keystore password" — **BLK-06** (known compromised keystore in git history; rotation tracked, no history rewrite)

---

## Changed Files (Full List)

| File | Lines Changed | Description |
|------|---------------|-------------|
| `lib/posix_fs.dart` | NEW (+720) | dart:ffi libc helper: `PosixFsError`, `PosixPathClass`, `classifyNoFollow`/`classifyChildNoFollow` (lstat/fstatat AT_SYMLINK_NOFOLLOW), `PosixStat`, `openDirNoFollow`/`openReadNoFollow`/`openWriteNoFollow` (O_NOFOLLOW), `mkstempSecure` (0600 O_CREAT\|O_EXCL), `renameCommit` (RENAME_NOREPLACE + renameat ENOSYS fallback), `unlinkChild`, `resolveCanonical` (realpath), `statFd`/`fchmodFd`/`fsyncFd`/`closeFd`, `setUmask`/`restoreUmask`, `writeAllToFd`/`readAllFromFd`/`rewindFd`, `selfCheck()` |
| `lib/storage.dart` | ~1014 ± (rework) | errno-aware `classifyPathNoFollow`/`isSymlink`; `readRegularFileNoFollow` (descriptor-pinned); `StorageDebugHooks`; `_lexicalNormalize`/`_basenameOf`/`_parentOf`/`_sanitizeTempPrefix`; `atomicWrite` Linux pipeline (canonical parent → dirfd → classify → mkstemp → write+fsync+verify → beforeCommit hook → use-time recheck → renameCommit → fsync(dirfd) → final statFd); portable fallback; `AppStorage` reworks (vaultExists/readVault/writeVault/deleteVault/readReceipts/_readDrawerSecret/_writeDrawerSecret/eraseAllData/_shredAndUnlink) |
| `lib/app_state.dart` | ~47 ± | `exportVault` exists()-gate removed → no-follow `isSymlink` + pinned read; `importVault` → `isSymlink` + `readRegularFileNoFollow` (preserves exact error messages) |
| `linux/runner/main.cc` | +8 | `#include <sys/stat.h>` + `umask(077)` with comment before Flutter init |
| `lib/encrypted_log_store.dart` | ~110 ± | `_fileLock` (Lock from synchronized) serializing `append`/`readAll`/`clear` (fixes pre-existing fire-and-forget append race) |
| `test/filesystem_security_test.dart` | NEW (+650) | 20 tests covering all 11 required cases + 3 race regressions + 6 mechanism guarantees |
| `.gitignore` | +3 | Added `verification/node_modules/` |

---

## Security Claims Updated (SECURITY_CLAIMS.md)

| Claim | Previous Status | Updated Status | Notes |
|-------|-----------------|----------------|-------|
| Symlink classification (errno-aware) | IMPLEMENTED | **TESTED** (Linux) | 7 classification tests + 3 destination tests + 3 race tests |
| `atomicWrite` destination no-follow independent of `exists()` | IMPLEMENTED | **TESTED** (Linux) | Valid & broken symlinks refused; missing = expected fresh case |
| Descriptor-based ops (openat, O_NOFOLLOW, dirfds) | IMPLEMENTED | **TESTED** (Linux) | Pin-based; no path prechecks claimed to eliminate races |
| Temp files same filesystem + atomic replacement | IMPLEMENTED | **TESTED** | mkstemp in dest dir; renameat replace/NOREPLACE |
| Non-Linux ambiguity (dart:io `notFound` = missing OR EACCES) | Not documented | **DOCUMENTED** | Explicit non-claim in SECURITY_CLAIMS.md |
| Crash safety / persistent recovery journal | Not claimed | **EXPLICIT NON-CLAIM** | Outstanding limitation documented |
| `umask(077)` at process start protects plugin-created files | NOT TESTED | **TESTED** | Staged `.deb` first-run under umask 0002 → dirs 0700, files 0600 |
| `mkstemp` mode 0600 at creation (kernel umask only clears bits) | IMPLEMENTED | **TESTED** | `stat(1)` confirms 600 under umask 0002 |
| Log append race (background + test concurrent) | NOT FIXED | **FIXED** | `_fileLock` around append/readAll/clear |

---

## Outstanding / Deferred (Per User Decision)

| Item | Status | Notes |
|------|--------|-------|
| **M3-06** Vault-version test-construction fix | ⏳ DEFERRED | Test splices `'BNBVL002'` header; fails magic before version check |
| **M3-08** Import-rollback write-failure injection | ⏳ DEFERRED | User decision for later round |
| Persistent crash-recovery journal | ❌ NON-CLAIM | Explicitly documented as outstanding limitation |
| `renameat` ENOSYS fallback → `rename` | PARTIAL | Documented residual; `renameat2` (5 args) not used |

---

## Commit Trail (This Round)

All changes will be committed in two commits:
1. **Code + Tests**: `lib/posix_fs.dart`, `lib/storage.dart`, `lib/app_state.dart`, `linux/runner/main.cc`, `lib/encrypted_log_store.dart`, `test/filesystem_security_test.dart`, `.gitignore`
2. **Documentation**: `docs/security/SECURITY_CLAIMS.md`, `docs/CHANGELOG.md`, `docs/PROJECT_STATUS.md`, `docs/PROJECT_MASTER_PLAN.md`, `docs/DECISIONS/005-m3-filesystem-corrections.md`, `docs/evidence/m3-filesystem-security-round.md`

Full SHA + changed-file list to be recorded after `git push origin main`.

---

*This evidence report distinguishes implementation from verification. Internal self-audit ≠ independent third-party audit. All claims qualified with verification status.*