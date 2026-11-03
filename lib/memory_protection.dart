import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Process-level memory hardening for Linux.
///
/// The old implementation shelled out to `ulimit` and wrote pseudo-files; both
/// only affected the child shell, not this process. This version calls the
/// kernel directly:
///
///  * `prctl(PR_SET_DUMPABLE, 0)` — no core dumps and no ptrace of this process
///    by same-uid processes (best effort; the kernel may still allow root);
///  * `setrlimit(RLIMIT_CORE, 0)` — no core file can be written through the
///    ordinary core-dump path;
///  * `mlockall(MCL_CURRENT | MCL_FUTURE)` — best effort only; desktop limits
///    often deny it and the app must keep working when they do.
///
/// None of these are a sandbox and none can protect a compromised kernel or a
/// root attacker. They reduce accidental spillage, not a hostile OS.
class MemoryProtection {
  MemoryProtection._();

  static bool _initialized = false;
  static final DynamicLibrary? _libc = Platform.isLinux
      ? DynamicLibrary.open('libc.so.6')
      : null;

  static const int mclCurrent = 1;
  static const int mclFuture = 2;
  static const int prSetDumpable = 4;
  static const int prGetDumpable = 3;
  static const int rlimitCore = 4;

  static String? _lastError;
  static bool _mlockSucceeded = false;

  static String? get lastError => _lastError;
  static bool get memoryLocked => _mlockSucceeded;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isLinux || _libc == null) return;
    _disableDumpable();
    _disableCoreDumps();
    _lockMemory();
  }

  static void _disableDumpable() {
    try {
      final prctl = _libc!
          .lookupFunction<
            Int32 Function(Int32, Uint64, Uint64, Uint64, Uint64),
            int Function(int, int, int, int, int)
          >('prctl');
      final result = prctl(prSetDumpable, 0, 0, 0, 0);
      if (result != 0) {
        _lastError = 'prctl(PR_SET_DUMPABLE, 0) failed';
      }
    } catch (error) {
      _lastError = 'prctl unavailable: $error';
    }
  }

  static void _disableCoreDumps() {
    final limit = calloc<_Rlimit>();
    try {
      final setrlimit = _libc!
          .lookupFunction<
            Int32 Function(Int32, Pointer<_Rlimit>),
            int Function(int, Pointer<_Rlimit>)
          >('setrlimit');
      limit.ref.rlimCur = 0;
      limit.ref.rlimMax = 0;
      final result = setrlimit(rlimitCore, limit);
      if (result != 0) {
        _lastError = 'setrlimit(RLIMIT_CORE, 0) failed';
      }
    } catch (error) {
      _lastError = 'setrlimit unavailable: $error';
    } finally {
      calloc.free(limit);
    }
  }

  static void _lockMemory() {
    try {
      final mlockall = _libc!
          .lookupFunction<Int32 Function(Int32), int Function(int)>('mlockall');
      final result = mlockall(mclCurrent | mclFuture);
      _mlockSucceeded = result == 0;
      if (!_mlockSucceeded) {
        _lastError =
            'mlockall failed (common on desktops with low RLIMIT_MEMLOCK)';
      }
    } catch (error) {
      _lastError = 'mlockall unavailable: $error';
    }
  }

  /// Current `PR_GET_DUMPABLE` value, or null on non-Linux platforms.
  static int? get dumpable {
    if (!Platform.isLinux || _libc == null) return null;
    try {
      final prctl = _libc!
          .lookupFunction<
            Int32 Function(Int32, Uint64, Uint64, Uint64, Uint64),
            int Function(int, int, int, int, int)
          >('prctl');
      final value = prctl(prGetDumpable, 0, 0, 0, 0);
      return value < 0 ? null : value;
    } catch (_) {
      return null;
    }
  }

  /// Soft core-file limit, or null when unavailable.
  static int? get coreSoftLimit {
    if (!Platform.isLinux || _libc == null) return null;
    final limit = calloc<_Rlimit>();
    try {
      final getrlimit = _libc!
          .lookupFunction<
            Int32 Function(Int32, Pointer<_Rlimit>),
            int Function(int, Pointer<_Rlimit>)
          >('getrlimit');
      final result = getrlimit(rlimitCore, limit);
      if (result != 0) return null;
      return limit.ref.rlimCur;
    } catch (_) {
      return null;
    } finally {
      calloc.free(limit);
    }
  }
}

final class _Rlimit extends Struct {
  @Uint64()
  external int rlimCur;

  @Uint64()
  external int rlimMax;
}
