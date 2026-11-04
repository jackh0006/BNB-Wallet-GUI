# DECISION: M3 Filesystem Security Corrections Round

**Date**: 2026-11-04
**Baseline Commit**: `9a057fc005ecfe7df7946bf747497c5ebd03d87b`
**Status**: **IMPLEMENTED — M3 INCOMPLETE**

---

## Context

This round implements the user-specified "M3 Final Symlink and Filesystem Security Corrections" against commit `9a057fc`. The baseline had working but incomplete symlink/TOCTOU hardening — the previous implementation used `FileSystemEntity.type(followLinks:false)` which on Linux cannot distinguish missing from inaccessible, and the `atomicWrite` pipeline relied on path prechecks that cannot close the validate→use race window.

---

## Decisions Made

### 1. Linux-Specific Native Helper (dart:ffi libc)

**Decision**: Implement `lib/posix_fs.dart` as a dart:ffi wrapper around libc for errno-aware filesystem operations.

**Rationale**:
- `FileSystemEntity.type(followLinks:false)` on Linux returns `notFound` for both missing paths AND permission errors (EACCES) — silent conflation.
- `FileStat.stat` returns degenerate data (size -1, no exception) on errors.
- The only way to get real errno is `lstat`/`fstatat` with `AT_SYMLINK_NOFOLLOW` via FFI.
- Precedent: `memory_protection.dart` already uses dart:ffi for `prctl`/`setrlimit`/`mlockall`.

**Implementation**:
- `PosixFs.classifyNoFollow(path)` → `PosixPathClass{missing,regularFile,directory,symlink,special,inaccessible}`
- `PosixFs.classifyChildNoFollow(dirfd, name)` → `fstatat(dirfd, name, AT_SYMLINK_NOFOLLOW)`
- `PosixFs.openDirNoFollow`/`openReadNoFollow`/`openWriteNoFollow` with `O_NOFOLLOW|O_CLOEXEC|O_NONBLOCK`
- `PosixFs.mkstempSecure(dir, prefix)` → `mkstemp(template)` with explicit mode 0600
- `PosixFs.renameCommit` → `renameat` with `RENAME_NOREPLACE` (fallback to `rename` on ENOSYS)
- `PosixFs.resolveCanonical` → `realpath`
- `PosixFs.selfCheck()` validates struct stat layout (amd64 offsets: st_mode=24, st_size=48, 144-byte struct) and O_DIRECTORY sanity

**Non-Linux**: Falls back to dart:io with explicit ambiguity documentation.

### 2. `atomicWrite` Destination Classification Independent of `exists()`

**Decision**: `atomicWrite` on Linux classifies the destination via `fstatat(AT_SYMLINK_NOFOLLOW)` before any open/create — valid AND broken symlinks are refused; missing is the expected fresh case; directories/special files refused.

**Rationale**:
- `exists()` over a broken symlink returns `false` — the previous implementation's hole.
- `FileSystemEntity.type(followLinks:false)` on Linux returns `notFound` for broken symlinks — also blind.
- Only `fstatat` with `AT_SYMLINK_NOFOLLOW` sees the symlink entry regardless of target state.

### 3. Descriptor-Based Operations Close Validate→Use Window

**Decision**: The Linux pipeline uses pinned directory descriptors (`dirfd`) for every operation on the destination entry — `fstatat` classification, `openat` for create/open, `renameat` for commit. The **use-time recheck** immediately before `renameCommit` is what makes the commit safe, not the earlier path prechecks.

**Rationale**:
- Path prechecks alone can NEVER eliminate symlink races (TOCTOU is fundamental).
- A pinned dirfd + `O_NOFOLLOW` at open time makes the kernel re-prove the entry type.
- The `StorageDebugHooks.beforeCommit` callback allows tests to mutate the directory between validation and commit, proving the recheck closes the window.

### 4. Process umask(077) at Startup

**Decision**: Add `umask(077)` in `linux/runner/main.cc` before Flutter init.

**Rationale**:
- Desktop sessions launch apps with permissive umask (e.g., 0002).
- `mkstemp` mode argument 0600 yields 0600 AT CREATION on ANY umask (kernel umask only clears bits).
- But plugin-created files/dirs (vault data dir, logs, cache fragments) need the restrictive umask too.
- Verified: staged `.deb` first-run under desktop umask 0002 → all app-created dirs 0700, files 0600.

### 5. Log Append Race Fix (Pre-Existing Bug Exposed)

**Decision**: Add `static final Lock _fileLock` (package:synchronized) around `append`/`readAll`/`clear` in `encrypted_log_store.dart`.

**Root Cause Discovered**:
- `unlock()` → `unawaited(logEvent(...))` (fire-and-forget) raced test's `append` → two concurrent `writeAsBytes` on `bnb-wallet-log.bin` interleaved ciphertext → `SecretBoxAuthenticationError`.
- Baseline passed only by scheduling luck; my tree's timing exposed it.
- This is a pre-existing concurrency bug, not introduced by my changes.

### 6. Recheck-Switch Polarity Correction

**Decision**: During `atomicWrite` use-time recheck, `PosixPathClass.missing` with `replaceExisting == false` (fresh path) → **PROCEED** (commit with RENAME_NOREPLACE). Only `PosixPathClass.regularFile` with `replaceExisting == false` → **REFUSE** (fresh-destination race).

**Bug Found**: Initial implementation had the polarity inverted — refused fresh missing paths, which broke all fresh writes.

### 7. Honest Non-Claims for Residual Limitations

**Decision**: Explicitly document what is NOT claimed:

| Non-Claim | Reason |
|-----------|--------|
| Crash safety / persistent recovery journal | Atomic write + fsync is best-effort; power loss between file fsync and directory fsync can lose data; no write-ahead log |
| `renameat` ENOSYS fallback → `rename` atomicity | `rename` lacks `RENAME_NOREPLACE`; directory update not guaranteed atomic on old kernels |
| Non-Linux symlink/permission ambiguity | dart:io `FileSystemEntity.type(followLinks:false)` returns `notFound` for both missing and EACCES; fail-closed where possible |

---

## Deferred (User Decision)

| Item | Status | Notes |
|------|--------|-------|
| M3-06: Vault-version test-construction fix | ⏳ DEFERRED | Test splices `'BNBVL002'` header; fails magic check before version check |
| M3-08: Import-rollback write-failure injection | ⏳ DEFERRED | User decision for later round |

---

## Verification Evidence

All commands, exit codes, test counts, and logs recorded in `docs/evidence/m3-filesystem-security-round.md`.

Key results:
- **Analyzer**: 124 issues (127 at HEAD → 124 WT; 3 fixed; zero new)
- **Non-KDF**: +238 pass, exit 0
- **KDF Individual**: vault_test +7, workers_test +3, rollback +9/−1 (identical to HEAD)
- **filesystem_security_test**: +20 pass (all 11 required cases + race + mechanism)
- **Linux release build**: exit 0
- **.deb build**: SHA256 OK, GPG OK, `dpkg -c` 0 secret matches
- **ethers.js verify**: PASS, 8 substitutions rejected
- **Staged `.deb` install**: dirs 0700, files 0600 under umask 0002
- **Secret scan**: Designed fail (BLK-06: old keystore in git history)

---

## Changed Files

| File | Type |
|------|------|
| `lib/posix_fs.dart` | NEW |
| `lib/storage.dart` | REWORK |
| `lib/app_state.dart` | MODIFIED |
| `linux/runner/main.cc` | MODIFIED |
| `lib/encrypted_log_store.dart` | MODIFIED |
| `test/filesystem_security_test.dart` | NEW |
| `.gitignore` | MODIFIED |

---

## Verdict

**M3 INCOMPLETE** — M3-06, M3-08, crash-recovery journal remain pending per user decision. All implemented work is TESTED with dedicated Linux integration tests and full verification battery. No regression of existing guarantees. Documentation is honest about residuals.