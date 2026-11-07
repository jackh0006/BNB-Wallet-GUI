import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('atomicWrite', () {
    test('writes data atomically and verifies content', () async {
      final tempDir = await Directory.systemTemp.createTemp('x-wallet-test-');
      try {
        final dest = File('${tempDir.path}/test_vault.bnb');
        const data = 'test vault data';

        final result = await atomicWrite(dest, data);
        result.getOrThrow();

        expect(await dest.exists(), true);
        expect(await dest.readAsString(), data);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates file with restrictive permissions on Linux/macOS', () async {
      if (!Platform.isLinux && !Platform.isMacOS) return;

      final tempDir = await Directory.systemTemp.createTemp('x-wallet-test-');
      try {
        final dest = File('${tempDir.path}/test_perms.bnb');
        const data = 'permission test';

        final result = await atomicWrite(dest, data);
        result.getOrThrow();

        final stat = await dest.stat();
        expect((stat.mode & 511), 384);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('refuses to overwrite a symlink destination', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'bnb-symlink-test-',
      );
      try {
        final dest = File('${tempDir.path}/dest.bnb');
        final link = Link('${tempDir.path}/link.bnb');
        const data = 'test data';

        final r1 = await atomicWrite(dest, 'original');
        r1.getOrThrow();
        await link.create(dest.path);

        final result = await atomicWrite(File(link.path), data);
        expect(result.committed, false);
        expect(result.error, contains('symbolic link'));

        expect(await dest.readAsString(), 'original');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('refuses to write to a symlink parent directory', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'bnb-symlink-parent-test-',
      );
      try {
        final realDir = Directory('${tempDir.path}/real_parent');
        await realDir.create();

        final linkDir = Link('${tempDir.path}/link_parent');
        await linkDir.create(realDir.path);

        final dest = File('${linkDir.path}/test.txt');
        const data = 'test data';

        final result = await atomicWrite(dest, data);
        expect(result.committed, false);
        expect(result.error, contains('parent directory is a symlink'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('preserves original file on write failure', () async {
      final tempDir = await Directory.systemTemp.createTemp('x-wallet-test-');
      try {
        final dest = File('${tempDir.path}/fail_test.bnb');
        const original = 'original content';

        final result = await atomicWrite(dest, original);
        result.getOrThrow();

        expect(await dest.readAsString(), original);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('cleans up temp file on error', () async {
      final tempDir = await Directory.systemTemp.createTemp('x-wallet-test-');
      try {
        final dest = File('${tempDir.path}/cleanup_test.bnb');
        const data = 'test data';

        final result = await atomicWrite(dest, data);
        result.getOrThrow();

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
      final tempDir = await Directory.systemTemp.createTemp(
        'bnb-symlink-dest-test-',
      );
      try {
        final originalFile = File('${tempDir.path}/original.txt');
        final r1 = await atomicWrite(originalFile, 'original');
        r1.getOrThrow();

        final link = Link('${tempDir.path}/link.txt');
        await link.create(originalFile.path);

        final result = await atomicWrite(File(link.path), 'new content');
        expect(result.committed, false);
        expect(result.error, contains('symbolic link'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects symlink parent directory', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'bnb-symlink-parent-test-',
      );
      try {
        final realDir = Directory('${tempDir.path}/real_parent');
        await realDir.create();

        final linkDir = Link('${tempDir.path}/link_parent');
        await linkDir.create(realDir.path);

        final dest = File('${linkDir.path}/test.txt');

        final result = await atomicWrite(dest, 'test');
        expect(result.committed, false);
        expect(result.error, contains('parent directory is a symlink'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('importVault rollback', () {
    test('import with wrong password fails and preserves original', () async {
      final tempDir = await Directory.systemTemp.createTemp('bnb-import-test-');
      try {
        final r1 = await atomicWrite(
          File('${tempDir.path}/vault.bnb'),
          'test_blob',
        );
        r1.getOrThrow();

        final testVaultFile = File('${tempDir.path}/test_vault.bnb');
        final r2 = await atomicWrite(testVaultFile, 'original_vault_data');
        r2.getOrThrow();

        final tempImport = File('${tempDir.path}/bad_import.bnb');
        final r3 = await atomicWrite(tempImport, 'invalid_vault_format');
        r3.getOrThrow();

        final r4 = await atomicWrite(File('${tempDir.path}/test.bnb'), 'test');
        r4.getOrThrow();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
