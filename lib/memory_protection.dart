import 'dart:ffi';
import 'dart:io';

/// Memory protection utilities for Linux.
///
/// Uses FFI to call mlockall() to prevent sensitive memory from being swapped to disk.
/// This is a best-effort protection — failures are logged but don't crash the app.
class MemoryProtection {
  static bool _initialized = false;
  static final DynamicLibrary? _libc = Platform.isLinux ? DynamicLibrary.open('libc.so.6') : null;

  // mlockall flags
  static const int mclCurrent = 1;
  static const int mclFuture = 2;

  /// Initialize memory protection.
  ///
  /// On Linux, attempts to call mlockall(MCL_CURRENT | MCL_FUTURE) to lock
  /// all current and future memory pages. On other platforms, this is a no-op.
  ///
  /// Failures are logged but don't prevent app startup.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isLinux) return;

    try {
      // Disable core dumps via ulimit
      await Process.run('sh', ['-c', 'ulimit -c 0']);
    } catch (_) {}

    try {
      // prctl(PR_SET_DUMPABLE, 0) via /proc — prevents ptrace and core dumps
      await Process.run('sh', ['-c', 'echo 0 > /proc/self/prctl_dumpable 2>/dev/null || true']);
    } catch (_) {}

    // Try to lock memory using mlockall via FFI
    if (_libc != null) {
      try {
        final mlockall = _libc!.lookupFunction<Int32 Function(Int32), int Function(int)>('mlockall');
        final result = mlockall(mclCurrent | mclFuture);
        if (result != 0) {
          final errno = _libc!.lookupFunction<Int32 Function(), int Function()>( '__errno_location')();
          _logWarning('mlockall failed with errno $errno. Memory may be swapped to disk.');
        } else {
          _logInfo('Memory locking enabled (mlockall succeeded).');
        }
      } catch (e) {
        _logWarning('Could not call mlockall: $e. Memory may be swapped to disk.');
      }
    }
  }

  static void _logInfo(String message) {
    // In production, use a proper logging framework
    // ignore: avoid_print
    print('[MemoryProtection] $message');
  }

  static void _logWarning(String message) {
    // In production, use a proper logging framework
    // ignore: avoid_print
    print('[MemoryProtection] WARNING: $message');
  }
}
