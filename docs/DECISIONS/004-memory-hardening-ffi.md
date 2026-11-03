# DECISION-004: Memory Hardening via FFI (Linux)

**Date**: 2026-11-03
**Status**: ACCEPTED
**Authors**: jackh0006

## Context

Previous implementation used `sh -c 'ulimit -c 0'` which only affects a child shell, leaving the wallet process dumpable with core files enabled.

## Decision

**Use FFI to call Linux kernel APIs directly** in `lib/memory_protection.dart`.

### Implemented Controls

| Control | Syscall | Purpose | Verified |
|---------|---------|---------|----------|
| **Dumpable** | `prctl(PR_SET_DUMPABLE, 0)` | Prevents same-UID `ptrace`/core dump inspection | ✅ `PR_GET_DUMPABLE == 0` |
| **Core limit** | `setrlimit(RLIMIT_CORE, 0)` | No core files written | ✅ soft limit = 0 |
| **Memory lock** | `mlockall(MCL_CURRENT \| MCL_FUTURE)` | Best-effort prevent swap | ⚠️ May fail (RLIMIT_MEMLOCK) |

### Why Not Alternatives

| Alternative | Problem |
|-------------|---------|
| `Process.run('sh', ['-c', 'ulimit -c 0'])` | Changes child shell only; parent unchanged |
| `dart:io` `ResourceLimit` | No `RLIMIT_CORE` support in Dart 3.13 |
| `mlock` per allocation | Impractical; `mlockall` is atomic |
| Encrypted memory (libodium) | Not available in pure Dart; adds native dep |

### Failure Handling

- `prctl`/`setrlimit` failure → **hard error** (log + continue; not silent)
- `mlockall` failure → **warning logged**; continue (best-effort documented)
- No false "hardening active" claims

### Verification

`test/memory_protection_test.dart` reads **actual kernel state** of test process:
```dart
expect(MemoryProtection.dumpable, 0);        // PR_GET_DUMPABLE
expect(MemoryProtection.coreSoftLimit, 0);   // RLIMIT_CORE soft limit
```

### Platform Scope

| Platform | Dumpable | Core Limit | mlockall |
|----------|----------|------------|----------|
| **Linux** | ✅ FFI | ✅ FFI | ✅ FFI (best-effort) |
| Android | ❌ N/A | ❌ N/A | ❌ N/A (use Keystore) |
| macOS | ❌ N/A | ❌ N/A | ❌ N/A |
| Windows | ❌ N/A | ❌ N/A | ❌ N/A |

**Linux-only** — documented in `SECURITY_CLAIMS.md` and `THREAT_MODEL.md`.

## What This Does NOT Protect Against

- Compromised kernel / root
- Same-UID process before `initialize()` call
- Cold boot attacks (RAM remanence)
- DMA attacks
- Side-channels (cache, timing)

## Related

- `lib/memory_protection.dart`
- `test/memory_protection_test.dart`
- `docs/security/SECURITY_CLAIMS.md` (Memory/Process Hardening Claims)
- `docs/THREAT_MODEL.md` (Compromised device section)