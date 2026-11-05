# M3 continuation — locking and crash consistency

## Checkpoint

`e36fe80` introduced a Linux advisory-lock implementation. The follow-up
work must start by checking the current HEAD: account mutation paths were
found to bypass that wrapper and have now been brought under it; do not claim
M3 acceptance until the changes and tests below are independently rerun.

## Lock contract (Linux AMD64 only)

`PosixFs` parses the glibc AMD64 `struct stat` layout, so the supported claim
is Ubuntu/Linux AMD64, not generic Linux. `flock(LOCK_EX | LOCK_NB)` is held
on `.bnb-wallet-storage.lock`, a zero-byte `0600` regular file opened through
a pinned application-data directory descriptor with `O_CREAT|O_NOFOLLOW|
O_CLOEXEC`. The opened descriptor is checked against the named entry before
locking. Contention returns a `StateError`; it never waits indefinitely.

Lock order is: `vaultOperationLock` (VM-local, vault operations only), then
the VM-local process-lock gate, then the OS advisory lock. Log operations take
only the latter two. Do not acquire the vault lock while holding a log lock.
Closing the lock descriptor releases the OS lock on normal return, exceptions,
and process death. `flock` is cooperative and cannot stop a same-UID process
that ignores it or replaces the lock entry after the bounded identity check.

## Current coverage

| Operation | Lock coverage |
|---|---|
| Vault account create/delete/rename | Full read → encrypt → atomic write → notify |
| Vault import/rollback, move, export, password change, reset, erase | Full transaction including reads, writes, identity checks, rollback/cleanup |
| Encrypted-log append/read/clear | Full read/modify/write or unlink cycle |
| Generic `atomicWrite` | Deliberately not self-locking; callers must supply operation-level locking to avoid reentrant deadlock |
| Receipt and preference writes | Not covered; not vault/log transactions |

## Reproducible lock verifier

Run `bash scripts/verify-lock-processes.sh`. It launches independent Dart OS
processes through `tool/lock_process_helper.dart` and proves nonblocking
contention, normal release, exception exit release, SIGKILL release, and
lock-file `0600:0` state. It does **not** prove full AppState vault/log race
semantics, because those require Flutter platform setup and explicit operation
barriers.

## Crash consistency

Existing `StorageDebugHooks` cover selected in-process temp/rename/readback,
directory-fsync, and rollback failures. There is no journal/WAL and no
next-launch recovery protocol. Process-kill tests can prove descriptor release
but cannot prove OS-crash or power-loss durability. A directory-fsync failure
is surfaced as `committedDurabilityUncertain`; callers must not report it as a
verified durable save. M3 remains NOT ACCEPTED until a reproducible subprocess
fault harness covers every specified atomic-write/log boundary and documents
the resulting next-launch behavior.
