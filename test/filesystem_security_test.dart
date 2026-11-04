// Dedicated Linux filesystem-security integration tests (M3 symlink/TOCTOU
// corrections round).
//
// These tests exercise the ACTUAL production implementation —
// `atomicWrite`, `readRegularFileNoFollow`, `classifyPathNoFollow`,
// `isSymlink` and the native `PosixFs` helper — no test-only reimplementations.
//
// Ledger of the 11 required cases is embedded in the test names
// ("case NN —"). Extra regression cases cover the dart:io conflation proof,
// creation-time permissions, temp cleanup and the validate→use race windows
// driven through the production StorageDebugHooks.
//
// The suite pins its own umask in setUp, so it runs standalone WITHOUT an
// external `umask 0077` shell prefix.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/posix_fs.dart';
import 'package:bnb_wallet_gui/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var prevUmask = 18; // 0022
  setUp(() {
    PosixFs.selfCheck();
    prevUmask = PosixFs.setUmask(63); // 077 restrictive, like the runner
  });
  tearDown(() {
    StorageDebugHooks.reset();
    PosixFs.restoreUmask(prevUmask);
  });

  /// Compares payload reads element-wise (Uint8List == is identity in Dart).
  bool listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Makes `dir` unreadable for anyone but root (requires non-root euid —
  /// this is an unprivileged test environment; chmod fails loudly otherwise).
  void makeInaccessible(String dir) {
    final r = Process.runSync('chmod', ['000', dir]);
    expect(r.exitCode, 0, reason: 'chmod 000 $dir failed in test setup');
  }

  void restoreAccess(String dir) {
    Process.runSync('chmod', ['755', dir]);
  }

  group('device classification (required cases 1–7)', () {
    test('case 00 — unavailable POSIX helper fails closed on Linux', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      final destination = File('${base.path}/vault.bnb');
      await destination.writeAsString('original');
      try {
        PosixFs.forceUnavailableForTesting = true;
        final result = await atomicWrite(destination, 'replacement');
        expect(result.committed, false);
        expect(result.error, contains('refusing insecure portable fallback'));
        expect(await destination.readAsString(), 'original');
      } finally {
        PosixFs.resetAvailabilityForTesting();
        await base.delete(recursive: true);
      }
    });

    test('case 01 — regular file: classified as regularFile', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final p = '${base.path}/regular.bin';
        await File(p).writeAsString('payload');
        expect(await classifyPathNoFollow(p), PosixPathClass.regularFile);
        expect(await isSymlink(p), false);
      } finally {
        await base.delete(recursive: true);
      }
    });

    test(
      'case 02 — directory: classified as directory (never writable dest)',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final p = '${base.path}/the-dir';
          await Directory(p).create();
          expect(await classifyPathNoFollow(p), PosixPathClass.directory);
          expect(await isSymlink(p), false);

          // atomicWrite refuses to clobber a directory destination.
          final result = await atomicWrite(File(p), 'data');
          expect(result.committed, false);
          expect(result.error, contains('Destination is a directory'));
          expect(
            await Directory(p).exists(),
            true,
            reason: 'directory survives',
          );
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test('case 03 — valid symlink: detected without following it', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final target = File('${base.path}/target.txt');
        await target.writeAsString('real');
        await Link('${base.path}/link.txt').create(target.path);
        expect(
          await classifyPathNoFollow('${base.path}/link.txt'),
          PosixPathClass.symlink,
        );
        expect(await isSymlink('${base.path}/link.txt'), true);
      } finally {
        await base.delete(recursive: true);
      }
    });

    test('case 04 — broken symlink: detected even though exists() is false', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        // Dart's exists() follows links: broken link => false. The production
        // no-follow classification must still see the link entry.
        await Link('${base.path}/broken.lnk')
            .create('${base.path}/missing-target');
        final dartSeesIt = await File('${base.path}/broken.lnk').exists();
        expect(
          dartSeesIt,
          false,
          reason: 'precondition: exists() is blind to broken links',
        );
        expect(
          await classifyPathNoFollow('${base.path}/broken.lnk'),
          PosixPathClass.symlink,
        );
        expect(await isSymlink('${base.path}/broken.lnk'), true);

        // The read path refuses it too (no-FOLLOW open fails from the kernel).
        await expectLater(
          readRegularFileNoFollow('${base.path}/broken.lnk', maxBytes: 1024),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('symbolic link'),
            ),
          ),
        );
      } finally {
        await base.delete(recursive: true);
      }
    });

    test(
      'case 05 — missing path: distinct clean answer (missing, not error)',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final p = '${base.path}/absent.bnb';
          expect(await classifyPathNoFollow(p), PosixPathClass.missing);
          expect(await isSymlink(p), false);
          // readRegularFileNoFollow: missing => null (clean absence).
          expect(await readRegularFileNoFollow(p, maxBytes: 1024), null);
          // atomicWrite: missing destination is the expected FRESH case.
          final result = await atomicWrite(File(p), 'fresh content');
          final written = result.getOrThrow();
          expect(written.path, p);
          expect(await File(p).readAsString(), 'fresh content');
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test('case 06 — inaccessible parent directory: EACCES fails closed, NOT "missing"', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      final priv = '${base.path}/priv';
      try {
        await Directory(priv).create();
        final childPath = '$priv/child.bnb';
        await File(childPath).writeAsString('x');
        makeInaccessible(priv);
        try {
          // dart:io conflates this with "missing". The production classifier
          // must NOT (regression proof that errno is used, not type()).
          final dartType = FileSystemEntity.typeSync(
            childPath,
            followLinks: false,
          );
          expect(
            dartType,
            FileSystemEntityType.notFound,
            reason: 'precondition: dart:io type() cannot distinguish this',
          );
          final dartExists = await File(childPath).exists();
          expect(dartExists, false, reason: 'precondition: exists() lies too');

          // Production behavior: honest "inaccessible", fail closed.
          expect(
            await classifyPathNoFollow(childPath),
            PosixPathClass.inaccessible,
          );
          expect(
            () async => isSymlink(childPath),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Failed to determine'),
              ),
            ),
          );

          // atomicWrite with the destination INSIDE an inaccessible
          // directory cannot even open it.
          final result = await atomicWrite(
            File('${base.path}/priv/fresh.bnb'),
            'data',
          );
          expect(result.committed, false);
          expect(
            result.error,
            anyOf(contains('inaccessible'), contains('Cannot')),
          );
        } finally {
          restoreAccess(priv);
        }
      } finally {
        await base.delete(recursive: true);
      }
    });

    test(
      'case 07 — inaccessible target: mode-000 regular file refused on read',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final p = '${base.path}/locked.bnb';
          await File(p).writeAsString('locked');
          makeInaccessible(p);
          try {
            // Classification still knows the TYPE (lstat needs no read access,
            // only directory traversal): regularFile — but reading must fail
            // closed with an honest error, never silently produce content.
            expect(await classifyPathNoFollow(p), PosixPathClass.regularFile);
            await expectLater(
              readRegularFileNoFollow(p, maxBytes: 1024),
              throwsA(isA<StateError>()),
            );
          } finally {
            restoreAccess(p);
          }
        } finally {
          await base.delete(recursive: true);
        }
      },
    );
  });

  group('atomicWrite destination handling (required cases 8–10)', () {
    test('case 08 — symlink destination in atomicWrite is refused, original preserved', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final victim = File('${base.path}/victim.bnb');
        final r1 = await atomicWrite(victim, 'victim original');
        r1.getOrThrow();
        final link = File('${base.path}/link.bnb');
        await Link(link.path).create(victim.path);

        final result = await atomicWrite(File(link.path), 'overwrite attempt');
        expect(result.committed, false);
        expect(result.error, contains('symbolic link'));
        // The symlink's TARGET is untouched and the link entry survives
        // (never deleted, never followed).
        expect(await victim.readAsString(), 'victim original');
        expect(await link.exists(), true);
        // No temporary files were left behind (the two entries are exactly
        // the victim and the link).
        final names = base
            .listSync(followLinks: false)
            .map((e) => e.path.split('/').last);
        expect(
          names.any((n) => n.startsWith('.')),
          false,
          reason: 'temp leftovers',
        );
      } finally {
        await base.delete(recursive: true);
      }
    });

    test('case 09 — broken-symlink destination in atomicWrite is refused', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final dest = File('${base.path}/dest.bnb');
        // exists() over a broken link is FALSE, which is the hole the previous
        // implementation had. Production must refuse regardless.
        await Link(dest.path).create('${base.path}/no-such-target');
        expect(
          await dest.exists(),
          false,
          reason: 'precondition: exists() is false over a broken link',
        );

        final result = await atomicWrite(dest, 'should never land');
        expect(result.committed, false);
        expect(result.error, contains('symbolic link'));
        expect(
          await dest.exists(),
          false,
          reason: 'broken link entry itself must survive',
        );
        // No temp leftovers (broken links list as Link, temps would too).
        final names = base
            .listSync(followLinks: false)
            .map((e) => e.path.split('/').last);
        expect(
          names.any((n) => n.startsWith('.')),
          false,
          reason: 'temp leftovers',
        );
      } finally {
        await base.delete(recursive: true);
      }
    });

    test(
      'case 10 — parent-directory symlink: refused via realpath equality',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final realDir = await Directory('${base.path}/real_parent').create();
          final linkDir = Link('${base.path}/link_parent');
          await linkDir.create(realDir.path);

          final result = await atomicWrite(
            File('${linkDir.path}/dest.txt'),
            'x',
          );
          expect(result.committed, false);
          expect(result.error, contains('parent directory is a symlink'));
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test(
      'atomicWrite preserves original contents when the write is refused',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final dest = File('${base.path}/dest.bnb');
          final r1 = await atomicWrite(dest, 'original');
          r1.getOrThrow();
          // Make the parent unreadable right before a second write.
          makeInaccessible(base.path);
          try {
            final result = await atomicWrite(dest, 'second');
            expect(result.committed, false);
          } finally {
            restoreAccess(base.path);
          }
          expect(await dest.readAsString(), 'original');
        } finally {
          await base.delete(recursive: true);
        }
      },
    );
  });

  group('validate→use race windows (required case 11, via production hooks)', () {
    test(
      'case 11a — symlink swapped in before commit: use-time recheck refuses',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final victimTarget = File('${base.path}/target.txt');
          await victimTarget.writeAsString('attacker target');

          final released = <bool>[];
          StorageDebugHooks.beforeCommit = (destPath) {
            // Attacker: between validation and commit, replace the (absent)
            // destination with a symlink to their own file.
            final link = Link(destPath);
            link.createSync(victimTarget.path);
            released.add(true);
          };

          final result = await atomicWrite(
            File('${base.path}/fresh.bnb'),
            'our data',
          );
          expect(result.committed, false);
          expect(result.error, contains('symbolic link'));
          expect(released.length, 1, reason: 'hook actually ran');
          // The attacker's symlink and its target are untouched, and our data
          // cannot be found through it.
          expect(await victimTarget.readAsString(), 'attacker target');
          expect(await Link('${base.path}/fresh.bnb').exists(), true);
          // No temp file leftovers: exactly two entries remain (attacker target
          // + the symlink they planted). listSync(followLinks:false) so links
          // are enumerated without silently resolving them.
          final names = base
              .listSync(followLinks: false)
              .map((e) => e.path.split('/').last)
              .toSet();
          expect(names, {'target.txt', 'fresh.bnb'});
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test(
      'case 11b — regular file appears under a fresh destination: refused',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          StorageDebugHooks.beforeCommit = (destPath) {
            // Attacker creates an innocent-looking file right before commit.
            File(destPath).writeAsStringSync('possum');
          };

          final result = await atomicWrite(
            File('${base.path}/fresh.bnb'),
            'our data',
          );
          expect(result.committed, false);
          expect(result.error, contains('appeared during write'));
          // The possum file was NOT overwritten by us.
          expect(await File('${base.path}/fresh.bnb').readAsString(), 'possum');
          // No temp leftovers.
          final strays = await base.list().toList();
          expect(strays.length, 1, reason: 'only the possum file remains');
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test('case 11c — existing destination deleted mid-write: replace-commit still atomic', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final dest = File('${base.path}/dest.bnb');
        final r1 = await atomicWrite(dest, 'old data');
        r1.getOrThrow();
        StorageDebugHooks.beforeCommit = (destPath) {
          // Attacker unlinks the destination between validation and commit.
          File(destPath).deleteSync();
        };
        final result = await atomicWrite(dest, 'new data');
        final written = result.getOrThrow();
        expect(written.path, dest.path);
        expect(await dest.readAsString(), 'new data');
        // Exactly one regular file remains — no temp leftovers.
        expect((await base.list().toList()).length, 1);
      } finally {
        await base.delete(recursive: true);
      }
    });
  });

  group('mechanism guarantees', () {
    test('temporary file is created 0600 AT CREATION TIME under a permissive umask', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final permissive = PosixFs.setUmask(2); // 0002 — typical desktop
        String? tempPath;
        StorageDebugHooks.afterTempCreation = (p) {
          tempPath = p;
          // Observed BEFORE any content is written.
          final st = File(p).statSync();
          expect(
            st.mode & 511,
            384,
            reason:
                'mkstemp mode must be 0600 at '
                'creation despite umask 0002',
          );
        };
        try {
          await atomicWrite(File('${base.path}/dest.bnb'), 'perm test');
          expect(tempPath, isNotNull);
          expect(
            await File('${base.path}/dest.bnb')
                .stat()
                .then((s) => s.mode & 511),
            384,
          );
        } finally {
          PosixFs.restoreUmask(permissive);
        }
      } finally {
        await base.delete(recursive: true);
      }
    });

    test('temp files are cleaned up on refusal and never on success', () async {
      final base = await Directory.systemTemp.createTemp('fssec-');
      try {
        final dest = File('${base.path}/dest.bnb');
        final r1 = await atomicWrite(dest, 'one');
        r1.getOrThrow();
        // (a) Successful write leaves exactly the destination.
        expect((await base.list().toList()).length, 1);

        // (b) Failure leaves nothing: fresh-destination race via the hook.
        StorageDebugHooks.beforeCommit = (destPath) {
          File(destPath).writeAsStringSync('possum');
        };
        final result = await atomicWrite(File('${base.path}/other.bnb'), 'two');
        expect(result.committed, false);
        expect(
          await File('${base.path}/other.bnb').readAsString(),
          'possum',
          reason: 'the racing entry was not overwritten',
        );
        StorageDebugHooks.reset();
        // Only dest.bnb and the possum file remain — no temps.
        expect((await base.list().toList()).length, 2);
      } finally {
        await base.delete(recursive: true);
      }
    });

    test(
      'atomic replacement of an existing regular destination works',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final dest = File('${base.path}/dest.bnb');
          final r1 = await atomicWrite(dest, 'version 1');
          r1.getOrThrow();
          expect(
            await File('${base.path}/dest.bnb')
                .stat()
                .then((s) => s.mode & 511),
            384,
          );
          final r2 = await atomicWrite(dest, 'version 2');
          r2.getOrThrow();
          expect(await dest.readAsString(), 'version 2');
          expect(await File(dest.path).stat().then((s) => s.mode & 511), 384);
          expect((await base.list().toList()).length, 1);
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test(
      'mkstempSecure: mode 0600 under umask 0002 verified via stat(1)',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final permissive = PosixFs.setUmask(2);
          try {
            final (fd, name) = PosixFs.mkstempSecure(base.path, 'mkt');
            final st = PosixFs.statFd(fd);
            expect(st.permissions.toRadixString(8), '600');
            final shell = Process.runSync('stat', ['-c', '%a', name]);
            expect(shell.stdout.trim(), '600', reason: 'stat(1) agrees');
            PosixFs.closeFd(fd);
            File(name).deleteSync();
          } finally {
            PosixFs.restoreUmask(permissive);
          }
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test(
      'readRegularFileNoFollow caps oversized content and honors missing',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final big = File('${base.path}/big.bin');
          await big.writeAsBytes(List<int>.filled(64, 65));
          await expectLater(
            readRegularFileNoFollow(big.path, maxBytes: 8),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('exceeds maximum size'),
              ),
            ),
          );
          expect(
            await readRegularFileNoFollow('${base.path}/absent', maxBytes: 8),
            null,
          );
          final content = await readRegularFileNoFollow(
            big.path,
            maxBytes: 128,
          );
          expect(listEq(content!.codeUnits, List<int>.filled(64, 65)), true);
        } finally {
          await base.delete(recursive: true);
        }
      },
    );

    test(
      'descriptor round trip through mkstemp+write+read matches byte for byte',
      () async {
        final base = await Directory.systemTemp.createTemp('fssec-');
        try {
          final payload = List<int>.generate(
            100000,
            (i) => (i * 31 + 7) & 0xFF,
          );
          final (fd, name) = PosixFs.mkstempSecure(base.path, 'io');
          try {
            PosixFs.writeAllToFd(fd, payload);
            PosixFs.fsyncFd(fd);
            PosixFs.rewindFd(fd);
            final back = PosixFs.readAllFromFd(fd, maxBytes: payload.length);
            expect(listEq(back, payload), true);
          } finally {
            PosixFs.closeFd(fd);
            File(name).deleteSync();
          }
        } finally {
          await base.delete(recursive: true);
        }
      },
    );
  });
}
