// Low-level POSIX filesystem operations for Linux, reached through dart:ffi.
//
// WHY THIS FILE EXISTS
//
// dart:io quietly collapses filesystem lookup failures into benign answers:
//
//   * `FileSystemEntity.type(path, followLinks: false)` returns
//     `FileSystemEntityType.notFound` BOTH for a missing path AND for lookup
//     errors. Verified empirically (Dart 3.13.5, Ubuntu 25.04, euid 1000, no
//     capabilities): a regular file inside a `chmod 000` parent directory
//     classifies as `notFound` with no exception — indistinguishable from
//     "the file does not exist".
//   * `File.stat()` / `FileStat.stat()` on such a path does NOT throw either;
//     it returns a degenerate `FileStat` (type notFound, size -1,
//     changed = epoch). Only open/read attempts surface errno.
//
// A vault must fail closed when filesystem state cannot be established, and
// must never confuse "permission denied" with "path absent". So the
// security-critical classification and commit steps call libc directly and
// use the real errno:
//
//   * `lstat()` / `fstatat()` / `fstat()` — true no-follow classification
//       with errno. Regular files, directories, valid symlinks, broken
//       symlinks, missing paths and permission errors are distinct outcomes.
//       The struct stat is parsed at the fixed glibc amd64 layout (offsets
//       documented below); this release ships Linux amd64 only, and the
//       layout assumption is validated at runtime by `selfCheck()`.
//   * `openat()` — descriptor-anchored opens (O_NOFOLLOW, O_DIRECTORY,
//       O_CLOEXEC). A directory descriptor pins the parent; O_NOFOLLOW makes
//       a symlinked final component fail *at use time*.
//   * `mkstemp()` — O_CREAT|O_EXCL temp file creation with mode 0600. The
//       kernel applies the umask by CLEARING bits only, so an explicitly
//       requested 0600 is 0600 at creation time on any umask. Collisions are
//       handled inside glibc; hard-link attacks against the temp file are
//       excluded by O_EXCL.
//   * `renameat2()` — atomic commit with optional RENAME_NOREPLACE
//       (with a re-verified `renameat()` fallback for ancient kernels).
//   * `unlinkat()`, `fsync()`, `close()`, `fchmod()`, `realpath()`, `umask()`
//
// This closes the classic check→use symlink-follow races for the app's own
// writes: content is only ever written to a descriptor created with
// O_CREAT|O_EXCL (an exclusive, unguessable name), the commit renames
// through a pinned directory descriptor, and rename(2) never *follows* a
// symlink destination — it replaces the symlink entry atomically, and
// RENAME_NOREPLACE refuses a fresh-destination race outright.
//
// What this does NOT do: a same-uid process that already has write access to
// the directory can still interchange directory entries between our calls.
// That residual risk is mitigated operationally by the 0700 application data
// directory and documented as a limitation. Non-Linux platforms do not use
// this helper; their remaining dart:io ambiguity is documented in
// docs/security/SECURITY_CLAIMS.md.
//
// struct stat layout used (glibc, x86_64/amd64, 144 bytes):
//   0: st_dev(8) | 8: st_ino(8) | 16: st_nlink(8) | 24: st_mode(4)
//   28: st_uid(4) | 32: st_gid(4) | 36: __pad0(4) | 40: st_rdev(8)
//   48: st_size(8) | 56: st_blksize(8) | 64: st_blocks(8) | 72+: timespecs
//
// NOTE ON VARIADIC C DECLARATIONS: only `openat()` is variadic in C (the
// mode_t argument appears only with O_CREAT). It is bound with the fixed
// four-argument shape; every other symbol bound here is non-variadic.
// Same dart:ffi pattern as the existing memory_protection.dart.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Thrown when a POSIX operation fails or cannot be performed; carries the
/// errno so callers can distinguish "missing" (ENOENT) from "cannot
/// establish state" (EACCES, ELOOP, ...) — the distinction dart:io loses.
class PosixFsError implements Exception {
  PosixFsError(this.operation, this.path, this.errno);

  final String operation;
  final String path;
  final int errno;

  String get meaning => errnoName(errno) ?? 'errno $errno';

  @override
  String toString() =>
      'PosixFsError($operation, path=$path, errno=$errno $meaning)';
}

/// True POSIX classification of a path. [PosixPathClass.special] covers
/// FIFOs, sockets, device nodes and anything that is not a regular file,
/// directory or symlink — vault operations must refuse those.
enum PosixPathClass {
  missing,
  regularFile,
  directory,
  symlink,
  special,

  /// A filesystem error prevents establishing state (EACCES, EPERM, ELOOP,
  /// EIO, ...). Callers must fail closed: never treat this as "missing" or
  /// as "not a symlink".
  inaccessible,
}

/// errno values referenced here (Linux).
const int errnoEperm = 1;
const int errnoEnoent = 2;
const int errnoEio = 5;
const int errnoEacces = 13;
const int errnoEexist = 17;
const int errnoEnotdir = 20;
const int errnoEnametoolong = 36;
const int errnoEnosys = 38;
const int errnoEloop = 40;

String? errnoName(int code) {
  switch (code) {
    case errnoEperm:
      return 'EPERM';
    case errnoEnoent:
      return 'ENOENT';
    case errnoEacces:
      return 'EACCES';
    case errnoEnametoolong:
      return 'ENAMETOOLONG';
    case errnoEexist:
      return 'EEXIST';
    case errnoEnotdir:
      return 'ENOTDIR';
    case errnoEnosys:
      return 'ENOSYS';
    case errnoEloop:
      return 'ELOOP';
    case errnoEio:
      return 'EIO';
    default:
      return null;
  }
}

/// POSIX open(2) flag values — x86_64/amd64 Linux (O_DIRECTORY = 00200000
/// octal, O_NOFOLLOW = 00400000 octal, O_CLOEXEC = 02000000 octal).
const int posixORdonly = 0;
const int posixOWronly = 1;
const int posixORdwr = 2;
const int posixOCreat = 0x40;
const int posixOExclusive = 0x80;
const int posixONonblock = 0x800;
const int posixODirectory = 0x10000;
const int posixONofollow = 0x20000;
const int posixOCloexec = 0x80000;

const int posixAtFdcwd = -100;
const int posixAtSymlinkNofollow = 0x100;

/// renameat2 flag: refuse the commit if the destination already exists.
const int posixRenameNoreplace = 1 << 0;

/// Mode bits: S_IRUSR | S_IWUSR (0600).
const int posixMode0600 = 0x180;

/// S_IFMT file-type classes (Linux).
const int posixSIfifo = 0x1000;
const int posixSIfchr = 0x2000;
const int posixSIfdir = 0x4000;
const int posixSIfblk = 0x6000;
const int posixSIfreg = 0x8000;
const int posixSIflnk = 0xA000;
const int posixSIfmt = 0xF000;

/// struct stat on x86_64 Linux is 144 bytes; buffers are allocation
/// placeholders — mode and size are parsed at fixed offsets below.
const int _statBufSize = 256;
const int _stModeOffset = 24;
const int _stSizeOffset = 48;

/// The fields we parse from struct stat: mode and size.
class PosixStat {
  PosixStat._(this.mode, this.size);

  final int mode;
  final int size;

  bool get isRegular => (mode & posixSIfmt) == posixSIfreg;
  bool get isDirectory => (mode & posixSIfmt) == posixSIfdir;
  bool get isSymlink => (mode & posixSIfmt) == posixSIflnk;
  bool get isSpecial {
    final kind = mode & posixSIfmt;
    return kind == posixSIfifo ||
        kind == posixSIfchr ||
        kind == posixSIfblk ||
        kind == 0xC000; // socket
  }

  /// The rwxrwxrwx component of the mode.
  int get permissions => mode & 0xFFF;
}

class _PosixBindings {
  _PosixBindings(this.libc);

  final DynamicLibrary libc;

  late final Pointer<Int32> Function() errnoLocation = libc
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        '__errno_location',
      );

  late final int Function(Pointer<Uint8>, Pointer<Uint8>) lstat = libc
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint8>),
        int Function(Pointer<Uint8>, Pointer<Uint8>)
      >('lstat');

  late final int Function(int, Pointer<Uint8>, Pointer<Uint8>, int) fstatat =
      libc.lookupFunction<
        Int32 Function(Int32, Pointer<Uint8>, Pointer<Uint8>, Int32),
        int Function(int, Pointer<Uint8>, Pointer<Uint8>, int)
      >('fstatat');

  late final int Function(int, Pointer<Uint8>) fstat = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Uint8>),
        int Function(int, Pointer<Uint8>)
      >('fstat');

  /// openat is variadic in C (mode_t only appears with O_CREAT); bound with
  /// the fixed four-argument shape (dirfd, path, flags, mode).
  late final int Function(int, Pointer<Uint8>, int, int) openat = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Uint8>, Int32, Uint32),
        int Function(int, Pointer<Uint8>, int, int)
      >('openat');

  late final int Function(Pointer<Uint8>) mkstemp = libc
      .lookupFunction<
        Int32 Function(Pointer<Uint8>),
        int Function(Pointer<Uint8>)
      >('mkstemp');

  /// ssize_t write(int fd, const void *buf, size_t count) — non-variadic.
  late final int Function(int, Pointer<Uint8>, int) write = libc
      .lookupFunction<
        Int64 Function(Int32, Pointer<Uint8>, Uint64),
        int Function(int, Pointer<Uint8>, int)
      >('write');

  /// ssize_t read(int fd, void *buf, size_t count) — non-variadic.
  late final int Function(int, Pointer<Uint8>, int) read = libc
      .lookupFunction<
        Int64 Function(Int32, Pointer<Uint8>, Uint64),
        int Function(int, Pointer<Uint8>, int)
      >('read');

  late final int Function(int, int) fchmod = libc
      .lookupFunction<Int32 Function(Int32, Uint32), int Function(int, int)>(
        'fchmod',
      );

  late final int Function(int) fsync = libc
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');

  late final int Function(int) close = libc
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  late final int Function(int, Pointer<Uint8>, int) unlinkat = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Uint8>, Int32),
        int Function(int, Pointer<Uint8>, int)
      >('unlinkat');

  /// off_t lseek(int fd, off_t offset, int whence)
  late final int Function(int, int, int) lseek = libc
      .lookupFunction<
        Int64 Function(Int32, Int64, Int32),
        int Function(int, int, int)
      >('lseek');

  /// renameat takes exactly four arguments (no flags parameter).
  late final int Function(int, Pointer<Uint8>, int, Pointer<Uint8>) renameat =
      libc.lookupFunction<
        Int32 Function(Int32, Pointer<Uint8>, Int32, Pointer<Uint8>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint8>)
      >('renameat');

  late final int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int)
  renameat2 = libc
      .lookupFunction<
        Int32 Function(Int32, Pointer<Uint8>, Int32, Pointer<Uint8>, Uint32),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int)
      >('renameat2');

  late final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Uint8>) realpath =
      libc.lookupFunction<
        Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Uint8>),
        Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Uint8>)
      >('realpath');

  late final int Function(int) umask = libc
      .lookupFunction<Uint32 Function(Uint32), int Function(int)>('umask');
}

/// Native POSIX filesystem helper. Operations are synchronous single
/// syscalls; the Dart layer in storage.dart wraps them in async APIs.
class PosixFs {
  PosixFs._();

  static _PosixBindings? _bindings;
  static String? _loadError;

  /// Test-only switch for proving that Linux storage fails closed when the
  /// native descriptor-based implementation cannot be initialized.  This is
  /// deliberately consulted by [available], rather than a caller-side flag,
  /// so the exercised path is the same availability boundary used in
  /// production.
  @visibleForTesting
  static bool forceUnavailableForTesting = false;

  @visibleForTesting
  static void resetAvailabilityForTesting() {
    forceUnavailableForTesting = false;
  }

  /// True when the native helper can be used. Security-critical callers on
  /// Linux must check this and fail closed otherwise.
  static bool get available {
    if (forceUnavailableForTesting) return false;
    if (_bindings != null) return true;
    if (_loadError != null) return false;
    if (!Platform.isLinux) {
      _loadError = 'not a Linux platform';
      return false;
    }
    try {
      final libc = DynamicLibrary.open('libc.so.6');
      final b = _PosixBindings(libc);
      // Touch a few symbols once: a missing symbol must fail at init, never
      // in the middle of a vault transaction.
      b.errnoLocation();
      b.lstat;
      b.fstatat;
      b.openat;
      b.mkstemp;
      b.renameat;
      b.renameat2;
      b.unlinkat;
      b.fsync;
      b.fchmod;
      b.close;
      b.realpath;
      b.umask;
      b.read;
      b.write;
      b.lseek;
      _bindings = b;
      return true;
    } catch (e) {
      _loadError = e.toString();
      return false;
    }
  }

  static String get loadError => _loadError ?? '';

  static _PosixBindings get _b {
    final b = _bindings;
    if (b == null) {
      throw StateError('PosixFs is not available: $loadError');
    }
    return b;
  }

  static int _errno() => _b.errnoLocation().value;

  static Pointer<Uint8> _toNative(String s) => s.toNativeUtf8().cast<Uint8>();

  static int _modeOf(Pointer<Uint8> buf) {
    // struct stat st_mode: mode_t (uint32) at byte offset 24 on amd64.
    final bytes = buf.asTypedList(_statBufSize);
    return bytes[_stModeOffset] |
        (bytes[_stModeOffset + 1] << 8) |
        (bytes[_stModeOffset + 2] << 16) |
        (bytes[_stModeOffset + 3] << 24);
  }

  static int _sizeOf(Pointer<Uint8> buf) {
    final bytes = buf.asTypedList(_statBufSize);
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v |= bytes[_stSizeOffset + i] << (8 * i);
    }
    // off_t is signed; a misparsed layout yields absurd values that the
    // supported-size checks reject.
    return v.toSigned(64);
  }

  static PosixStat _statFromBuffer(Pointer<Uint8> buf) =>
      PosixStat._(_modeOf(buf), _sizeOf(buf));

  static PosixPathClass _classFrom(PosixStat? stat) {
    if (stat == null) return PosixPathClass.missing;
    if (stat.isSymlink) return PosixPathClass.symlink;
    if (stat.isRegular) return PosixPathClass.regularFile;
    if (stat.isDirectory) return PosixPathClass.directory;
    return PosixPathClass.special;
  }

  /// lstat() with real errno semantics. Returns null for a missing path;
  /// throws [PosixFsError] otherwise (callers map EACCES/EPERM to a
  /// fail-closed "inaccessible" answer).
  static PosixStat? tryLstatNoFollow(String path) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final native = _toNative(path);
    final buf = calloc<Uint8>(_statBufSize);
    try {
      final rc = _b.lstat(native, buf);
      if (rc == 0) return _statFromBuffer(buf);
      throw PosixFsError('lstat', path, _errno());
    } finally {
      calloc.free(native);
      calloc.free(buf);
    }
  }

  /// No-follow classification of [path] with error distinctness:
  /// missing (ENOENT), regular file, directory, symlink (valid or broken),
  /// special (FIFO/socket/device), inaccessible (EACCES/EPERM and other
  /// lookup errors — the caller must fail closed).
  static PosixPathClass classifyNoFollow(String path) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    try {
      final stat = tryLstatNoFollow(path);
      return _classFrom(stat);
    } on PosixFsError catch (e) {
      switch (e.errno) {
        case errnoEnoent:
          return PosixPathClass.missing;
        case errnoEacces:
        case errnoEperm:
          return PosixPathClass.inaccessible;
        default:
          rethrow;
      }
    }
  }

  /// Classifies [name] inside the already-open directory [dirfd]. Uses
  /// fstatat with AT_SYMLINK_NOFOLLOW: NO path component beyond the pinned
  /// directory descriptor is ever resolved, so intermediate-component swaps
  /// cannot redirect this check.
  static PosixPathClass classifyChildNoFollow(int dirfd, String name) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final native = _toNative(name);
    final buf = calloc<Uint8>(_statBufSize);
    try {
      final rc = _b.fstatat(dirfd, native, buf, posixAtSymlinkNofollow);
      if (rc == 0) return _classFrom(_statFromBuffer(buf));
      final errno = _errno();
      if (errno == errnoEnoent) return PosixPathClass.missing;
      if (errno == errnoEacces || errno == errnoEperm) {
        return PosixPathClass.inaccessible;
      }
      throw PosixFsError('fstatat', name, errno);
    } finally {
      calloc.free(native);
      calloc.free(buf);
    }
  }

  /// Stats an already-open descriptor (post-creation and post-rename
  /// verification). Descriptor-pinned: immune to path swaps.
  static PosixStat statFd(int fd) {
    final buf = calloc<Uint8>(_statBufSize);
    try {
      final rc = _b.fstat(fd, buf);
      if (rc != 0) {
        throw PosixFsError('fstat', 'fd=$fd', _errno());
      }
      return _statFromBuffer(buf);
    } finally {
      calloc.free(buf);
    }
  }

  /// Opens [dirPath] with O_RDONLY|O_DIRECTORY|O_NOFOLLOW. A symlinked
  /// directory path fails from the kernel (ELOOP): no check→open window on
  /// the final component. Returns the pinned directory fd.
  static int openDirNoFollow(String dirPath) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final native = _toNative(dirPath);
    try {
      final fd = _b.openat(
        posixAtFdcwd,
        native,
        posixORdonly | posixODirectory | posixONofollow | posixOCloexec,
        0,
      );
      if (fd < 0) {
        throw PosixFsError('openat(O_DIRECTORY|O_NOFOLLOW)', dirPath, _errno());
      }
      return fd;
    } finally {
      calloc.free(native);
    }
  }

  /// Opens [name] inside the pinned directory [dirfd] for reading with
  /// O_NOFOLLOW|O_NONBLOCK (O_NONBLOCK so a FIFO cannot block a classifier;
  /// non-regular files are rejected immediately after via [statFd]).
  static int openReadNoFollow(int dirfd, String name) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final native = _toNative(name);
    try {
      final fd = _b.openat(
        dirfd,
        native,
        posixORdonly | posixONofollow | posixONonblock | posixOCloexec,
        0,
      );
      if (fd < 0) {
        throw PosixFsError('openat(O_RDONLY|O_NOFOLLOW)', name, _errno());
      }
      return fd;
    } finally {
      calloc.free(native);
    }
  }

  /// Opens [name] inside the pinned directory [dirfd] for writing with
  /// O_WRONLY|O_NOFOLLOW|O_NONBLOCK. Used by the erase-flow shred step; the
  /// entry must have been classified as a regular file first, and O_NOFOLLOW
  /// makes the kernel re-prove it at open time.
  static int openWriteNoFollow(int dirfd, String name) {
    final native = _toNative(name);
    try {
      final fd = _b.openat(
        dirfd,
        native,
        posixOWronly | posixONofollow | posixONonblock | posixOCloexec,
        0,
      );
      if (fd < 0) {
        throw PosixFsError('openat(O_WRONLY|O_NOFOLLOW)', name, _errno());
      }
      return fd;
    } finally {
      calloc.free(native);
    }
  }

  /// Creates a 0600 O_CREAT|O_EXCL temporary file inside the pinned directory
  /// [dirfd] using openat(). Returns (fd, basename). The name is unique
  /// inside the directory — same filesystem as the destination, as the atomic
  /// rename requires. Uses cryptographically secure random name component with
  /// bounded collision retries. No path components beyond the pinned descriptor
  /// are ever resolved.
  static (int, String) mkstempAt(int dirfd, String prefix) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final random = math.Random.secure();
    // Try up to 10 times with fresh random names
    for (var attempt = 0; attempt < 10; attempt++) {
      final randomPart = List<int>.generate(16, (_) => random.nextInt(256));
      final hex = randomPart
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final tempBase = '.$prefix-$hex';
      final native = _toNative(tempBase);
      try {
        final fd = _b.openat(
          dirfd,
          native,
          posixORdwr |
              posixOCreat |
              posixOExclusive |
              posixOCloexec |
              posixONofollow,
          posixMode0600,
        );
        if (fd >= 0) {
          // Verify the created descriptor is a regular file with exact 0600 permissions
          final st = statFd(fd);
          if (!st.isRegular) {
            closeFd(fd);
            throw PosixFsError('mkstempAt', tempBase, errnoEexist);
          }
          if (st.permissions != posixMode0600) {
            closeFd(fd);
            throw PosixFsError('mkstempAt', tempBase, errnoEexist);
          }
          return (fd, tempBase);
        }
        // EEXIST means name collision — retry with new random name
        final errno = _errno();
        if (errno != errnoEexist) {
          throw PosixFsError('openat(O_CREAT|O_EXCL)', tempBase, errno);
        }
      } finally {
        calloc.free(native);
      }
    }
    throw StateError(
      'Could not generate unique temporary filename after 10 attempts',
    );
  }

  /// Creates a 0600 O_CREAT|O_EXCL temporary file inside [directory] via
  /// mkstemp(). Returns (fd, absolutePath). The name is unique inside the
  /// directory — same filesystem as the destination, as the atomic rename
  /// requires.
  /// @deprecated Use [mkstempAt] for descriptor-anchored creation.
  static (int, String) mkstempSecure(String directory, String prefix) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final template = '$directory/.$prefix-XXXXXX';
    final bytes = utf8.encode(template);
    final native = calloc<Uint8>(bytes.length + 1);
    try {
      for (var i = 0; i < bytes.length; i++) {
        native[i] = bytes[i];
      }
      native[bytes.length] = 0;
      final fd = _b.mkstemp(native);
      if (fd < 0) {
        throw PosixFsError('mkstemp', template, _errno());
      }
      // glibc rewrote the trailing XXXXXX in place and kept the buffer
      // NUL-terminated: read the final absolute name back.
      var len = 0;
      while (len < bytes.length + 1 && native[len] != 0) {
        len++;
      }
      final name = utf8.decode(native.asTypedList(len));
      return (fd, name);
    } finally {
      calloc.free(native);
    }
  }

  /// Corrective tightening of an already-created descriptor (never used on
  /// the normal path; the creation itself requests mode 0600 explicitly and
  /// the umask cannot re-add cleared bits).
  static void fchmodFd(int fd, int mode) {
    if (_b.fchmod(fd, mode) < 0) {
      throw PosixFsError('fchmod', 'fd=$fd', _errno());
    }
  }

  static void fsyncFd(int fd) {
    if (_b.fsync(fd) < 0) {
      throw PosixFsError('fsync', 'fd=$fd', _errno());
    }
  }

  static void closeFd(int fd) {
    _b.close(fd);
  }

  /// Unlinks [name] (a plain filename) inside the pinned directory [dirfd];
  /// a clean ENOENT is not an error.
  static void unlinkChild(int dirfd, String name) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final native = _toNative(name);
    try {
      final rc = _b.unlinkat(dirfd, native, 0);
      if (rc < 0) {
        final errno = _errno();
        if (errno == errnoEnoent) return;
        throw PosixFsError('unlinkat', name, errno);
      }
    } finally {
      calloc.free(native);
    }
  }

  /// Atomically renames [oldName] → [newName] inside the pinned directory
  /// [dirfd]. With replace: false, refuses (EEXIST) if newName already
  /// exists — the kill-switch for the fresh-destination race.
  static void renameCommit(
    int dirfd,
    String oldName,
    String newName, {
    required bool replace,
  }) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final oldNative = _toNative(oldName);
    final newNative = _toNative(newName);
    final probeBuf = calloc<Uint8>(_statBufSize);
    try {
      if (!replace) {
        final rc = _b.renameat2(
          dirfd,
          oldNative,
          dirfd,
          newNative,
          posixRenameNoreplace,
        );
        if (rc == 0) return;
        final errno = _errno();
        if (errno != errnoEnosys) {
          throw PosixFsError('renameat2(RENAME_NOREPLACE)', newName, errno);
        }
        // Ancient kernel without renameat2: re-verify absence under the
        // pinned dirfd, then plain renameat (documented residual window).
        final existed = _b.fstatat(
          dirfd,
          newNative,
          probeBuf,
          posixAtSymlinkNofollow,
        );
        if (existed == 0) {
          throw PosixFsError(
            'renameat(no-replace fallback)',
            newName,
            errnoEexist,
          );
        }
        // fstatat failed - check errno
        final probeErrno = _errno();
        if (probeErrno != errnoEnoent) {
          // Any error other than ENOENT means we cannot establish state;
          // fail closed instead of silently treating as absent.
          throw PosixFsError(
            'renameat(no-replace fallback): fstatat',
            newName,
            probeErrno,
          );
        }
        final rc2 = _b.renameat(dirfd, oldNative, dirfd, newNative);
        if (rc2 < 0) {
          throw PosixFsError(
            'renameat(no-replace fallback)',
            newName,
            _errno(),
          );
        }
        return;
      }
      final rc = _b.renameat(dirfd, oldNative, dirfd, newNative);
      if (rc < 0) {
        throw PosixFsError('renameat', newName, _errno());
      }
    } finally {
      calloc.free(oldNative);
      calloc.free(newNative);
      calloc.free(probeBuf);
    }
  }

  /// Returns the canonical (fully resolved) absolute path, or throws. A path
  /// containing symlinked components canonicalizes to a DIFFERENT string,
  /// which callers compare against their own normalization to refuse
  /// non-canonical (symlinked) destinations.
  static String resolveCanonical(String path) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final native = _toNative(path);
    final buf = calloc<Uint8>(4097); // PATH_MAX + 1
    try {
      final result = _b.realpath(native, buf);
      if (result == nullptr) {
        throw PosixFsError('realpath', path, _errno());
      }
      var len = 0;
      while (len < 4097 && buf[len] != 0) {
        len++;
      }
      return utf8.decode(buf.asTypedList(len));
    } finally {
      calloc.free(native);
      calloc.free(buf);
    }
  }

  /// Installs [mask] as the process umask and returns the previous value.
  /// Used by tests to match the runner (which pins umask 077 at process
  /// start) and to run permission-critical tests under a normal desktop
  /// umask without external shell prefixes.
  static int setUmask(int mask) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    return _b.umask(mask);
  }

  /// Restores a previous umask value (see [setUmask]).
  static void restoreUmask(int previous) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    _b.umask(previous);
  }

  /// Writes all of [bytes] to [fd], looping over short writes. The fd was
  /// obtained with O_CREAT|O_EXCL, so this content lands on our exclusive
  /// inode no matter what happens to directory entries afterwards.
  static void writeAllToFd(int fd, List<int> bytes) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    if (bytes.isEmpty) return;
    final buf = calloc<Uint8>(bytes.length);
    try {
      for (var i = 0; i < bytes.length; i++) {
        buf[i] = bytes[i] & 0xFF;
      }
      var offset = 0;
      while (offset < bytes.length) {
        final n = _b.write(fd, buf + offset, bytes.length - offset);
        if (n < 0) {
          throw PosixFsError('write', 'fd=$fd', _errno());
        }
        if (n == 0) {
          throw PosixFsError('write(progress)', 'fd=$fd', errnoEio);
        }
        offset += n;
      }
    } finally {
      calloc.free(buf);
    }
  }

  /// Reads until EOF or [maxBytes], looping over chunk reads. Returns the
  /// bytes; fails closed if the content exceeds [maxBytes].
  static Uint8List readAllFromFd(int fd, {required int maxBytes}) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final chunkSize = 65536;
    final buf = calloc<Uint8>(chunkSize);
    final out = BytesBuilder(copy: true);
    try {
      while (true) {
        final n = _b.read(fd, buf, chunkSize);
        if (n < 0) {
          throw PosixFsError('read', 'fd=$fd', _errno());
        }
        if (n == 0) break; // EOF
        final chunk = buf.asTypedList(n);
        if (out.length + n > maxBytes) {
          throw StateError('Content exceeds maximum of $maxBytes bytes');
        }
        out.add(chunk);
      }
    } finally {
      calloc.free(buf);
    }
    return out.takeBytes();
  }

  /// Rewinds [fd] to offset 0 (lseek). Needed for the write→verify-read step
  /// on the same descriptor.
  static void rewindFd(int fd) {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final lseek = _b.lseek(fd, 0, 0); // SEEK_SET = 0
    if (lseek < 0) {
      throw PosixFsError('lseek', 'fd=$fd', _errno());
    }
  }

  /// Runtime validation of the baked-in amd64 struct stat layout and open
  /// flag values. Throws if the environment disagrees (the release target is
  /// Ubuntu Linux amd64 only; this makes any mismatch loud instead of
  /// silently corrupt).
  static void selfCheck() {
    if (!available) {
      throw StateError('PosixFs is not available: $loadError');
    }
    final nullStat = tryLstatNoFollow('/dev/null');
    if (nullStat == null || nullStat.mode & posixSIfmt != posixSIfchr) {
      throw StateError(
        'PosixFs.selfCheck: /dev/null is not a char device; '
        'struct stat layout mismatch',
      );
    }
    if (!nullStat.isSpecial) {
      throw StateError('PosixFs.selfCheck: char-device detection failed');
    }
    // O_DIRECTORY must fail on a non-directory (flags sanity).
    try {
      openDirNoFollow('/dev/null');
    } on PosixFsError catch (e) {
      if (e.errno != errnoEnotdir) {
        throw StateError(
          'PosixFs.selfCheck: O_DIRECTORY flag mismatch (${e.meaning})',
        );
      }
      return;
    }
    throw StateError(
      'PosixFs.selfCheck: opening /dev/null as a directory '
      'unexpectedly succeeded (flag mismatch)',
    );
  }
}
