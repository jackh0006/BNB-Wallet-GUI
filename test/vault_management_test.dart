import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('atomicWrite', () {
    test('writes data atomically and verifies content', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-wallet-test-');
      try {
        final dest = File('${tempDir.path}/test_vault.bnb');
        const data = 'test vault data';

        await atomicWrite(dest, data);

        expect(await dest.exists(), true);
        expect(await dest.readAsString(), data);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates file with restrictive permissions on Linux/macOS', () async {
      if (!Platform.isLinux && !Platform.isMacOS) return;

      final tempDir = await Directory.systemTemp.createTemp('bnb-wallet-test-');
      try {
        final dest = File('${tempDir.path}/test_perms.bnb');
        const data = 'permission test';

        await atomicWrite(dest, data);

        final stat = await dest.stat();
        expect((stat.mode & 511), 384);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('refuses to overwrite a symlink destination', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-symlink-test-');
      try {
        final dest = File('${tempDir.path}/dest.bnb');
        final link = Link('${tempDir.path}/link.bnb');
        const data = 'test data';

        await atomicWrite(dest, 'original');
        await link.create(dest.path);

        await expectLater(
          atomicWrite(File(link.path), data),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('symbolic link'),
          )),
        );

        expect(await dest.readAsString(), 'original');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('refuses to write to a symlink parent directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-symlink-parent-test-');
      try {
        final realDir = Directory('${tempDir.path}/real_parent');
        await realDir.create();

        final linkDir = Link('${tempDir.path}/link_parent');
        await linkDir.create(realDir.path);

        final dest = File('${linkDir.path}/test.txt');
        const data = 'test data';

        await expectLater(
          atomicWrite(dest, data),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('parent directory is a symlink'),
          )),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('preserves original file on write failure', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-wallet-test-');
      try {
        final dest = File('${tempDir.path}/fail_test.bnb');
        const original = 'original content';

        await atomicWrite(dest, original);

        expect(await dest.readAsString(), original);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('cleans up temp file on error', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-wallet-test-');
      try {
        final dest = File('${tempDir.path}/cleanup_test.bnb');
        const data = 'test data';

        await atomicWrite(dest, data);

        final files = tempDir.listSync().whereType<File>().toList();
        expect(files.length, 1);
        expect(files.first.path, dest.path);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('atomicWrite with symlink checks', () {
    test('rejects symlink destination', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-symlink-dest-test-');
      try {
        final originalFile = File('${tempDir.path}/original.txt');
        await atomicWrite(originalFile, 'original');

        final link = Link('${tempDir.path}/link.txt');
        await link.create(originalFile.path);

        await expectLater(
          atomicWrite(File(link.path), 'new content'),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('symbolic link'),
          )),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects symlink parent directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-symlink-parent-test-');
      try {
        final realDir = Directory('${tempDir.path}/real_parent');
        await realDir.create();

        final linkDir = Link('${tempDir.path}/link_parent');
        await linkDir.create(realDir.path);

        final dest = File('${linkDir.path}/test.txt');

        await expectLater(
          atomicWrite(dest, 'test'),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('parent directory is a symlink'),
          )),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('importVault rollback', () {
    test('import with wrong password fails and preserves original', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-import-test-');
      try {
        const password = 'correct_password';
        const wrongPassword = 'wrong_password';

        await atomicWrite(File('${tempDir.path}/vault.bnb'), 'test_blob');

        final testVaultFile = File('${tempDir.path}/test_vault.bnb');
        await atomicWrite(testVaultFile, 'original_vault_data');

        final tempImport = File('${tempDir.path}/bad_import.bnb');
        await atomicWrite(tempImport, 'invalid_vault_format');

        expect(await atomicWrite(File('${tempDir.path}/test.bnb'), 'test'), isA<File>());
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}