// Test-only independent-process harness for the production flock bindings.
// Protocol: `hold` prints LOCKED, waits for one stdin line, then exits 0.
// `try` prints ACQUIRED or CONTENDED and exits 0; `throw` acquires then exits
// 70, proving descriptor-close release on exceptional process termination.
import 'dart:io';

import 'package:bnb_wallet_gui/posix_fs.dart';

const _lockName = '.bnb-wallet-storage.lock';

Future<void> main(List<String> args) async {
  if (args.length != 2 || !{'hold', 'try', 'throw'}.contains(args[1])) {
    stderr.writeln('usage: lock_process_helper.dart DIRECTORY hold|try|throw');
    exitCode = 64;
    return;
  }
  if (!Platform.isLinux || !PosixFs.available) {
    stderr.writeln('Linux PosixFs unavailable: ${PosixFs.loadError}');
    exitCode = 69;
    return;
  }
  final dirfd = PosixFs.openDirNoFollow(args[0]);
  var lockfd = -1;
  try {
    lockfd = PosixFs.openLockFileAt(dirfd, _lockName);
    if (!PosixFs.tryExclusiveLock(lockfd)) {
      stdout.writeln('CONTENDED');
      return;
    }
    stdout.writeln('ACQUIRED');
    if (args[1] == 'try') return;
    if (args[1] == 'throw') {
      throw StateError('intentional test exception');
    }
    stdout.writeln('LOCKED $pid');
    await stdin.transform(const SystemEncoding().decoder).first;
  } finally {
    if (lockfd >= 0) PosixFs.closeFd(lockfd);
    PosixFs.closeFd(dirfd);
  }
}
