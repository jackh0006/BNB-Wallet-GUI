// Tagged `kdf`: real 64 MiB Argon2id derivations — scripts/test-suite.sh
// runs this suite strictly one at a time (never overlapped on 2 cores).
@Tags(['kdf'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/posix_fs.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/vault.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock path provider for isolated test directories.
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

const _testKeyHex =
    '0x115b527ce6cb943286dee1503e7645b0d021cc0cd43b9cbf7cb80eeba9db6b49';
const _testPassword = 'test-password-123456';
const _wrongPassword = 'wrong-password-123456';

/// Creates a test vault with real encryption and returns the vault blob.
Future<String> createRealTestVault(
  String password, {
  String label = 'Test Wallet',
}) async {
  final key = WalletCore.privateKeyFromHex(_testKeyHex);
  final mnemonic =
      'test test test test test test test test test test test junk';
  final device = _testDeviceSecret;

  final account = {
    'label': label,
    'address': key.address.eip55With0x,
    'privateKeyHex':
        '0x${key.privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    'mnemonic': mnemonic,
    'savedAt': DateTime.now().toIso8601String(),
  };

  final blob = await VaultCipher.encrypt(
    password,
    jsonEncode([account]),
    device,
  );
  return blob;
}

// 32-byte device secret (base64 encoded) for testing - valid 32 bytes base64
const _testDeviceSecret = 'kyPz0/cp8BD5wc0dSlsfIjeptDwKRUKe5RGrW6d20ss=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppState appState;
  var previousUmask = 18; // 0022

  // The production vault path deliberately rejects an application-support
  // directory that was created with group/other permissions.  Keep this
  // regression suite self-contained: `flutter test` normally inherits a
  // developer-friendly umask such as 0022, whereas the vault test fixture
  // must model the wallet's required 0700 data directory.
  setUpAll(() {
    if (Platform.isLinux) {
      PosixFs.selfCheck();
      previousUmask = PosixFs.setUmask(63); // 0077
    }
  });

  tearDownAll(() {
    if (Platform.isLinux) PosixFs.restoreUmask(previousUmask);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp(
      'bnb-import-rollback-kdf-test-',
    );
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);

    await AppStorage.init();

    // Create the drawer file with test device secret in the vault directory
    final vaultFile = await AppStorage.vaultFile();
    final drawerFile = File('${vaultFile.parent.path}/device_secret_v2.drawer');
    await drawerFile.writeAsString(_testDeviceSecret, flush: true);

    appState = AppState();
    appState.lock();
  });

  tearDown(() async {
    // Do not call `lock()` here: it asynchronously appends an audit event,
    // which can recreate a file while this isolated data directory is being
    // deleted.  The following setUp always locks the shared state first.
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Creates a test vault with real encryption and writes it to the vault file.
  Future<String> setupTestVault(
    String password, {
    String label = 'Test Wallet',
  }) async {
    final blob = await createRealTestVault(password, label: label);
    final vaultFile = await AppStorage.vaultFile();
    await vaultFile.writeAsString(blob);
    // Use the public method to load vault accounts which will set _vaultExists
    await appState.loadVaultAccounts(password);
    return blob;
  }

  group('AppState.importVault rollback (real KDF)', () {
    test(
      'import with wrong password fails and preserves original vault',
      () async {
        // Create original vault with real encryption
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Export the vault (simulate backup)
        final backupFile = File('${tmp.path}/backup.bnb');
        await backupFile.writeAsString(originalBlob);

        // Try to import with wrong password
        await expectLater(
          appState.importVault(
            backupFile.path,
            password: _wrongPassword,
            confirmReplace: true,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Wrong password'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'import with malformed backup fails and preserves original vault',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Create malformed backup
        final badBackupFile = File('${tmp.path}/bad_backup.bnb');
        await badBackupFile.writeAsString('not a valid vault format');

        // Try to import malformed backup
        await expectLater(
          appState.importVault(
            badBackupFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Not a valid vault file'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'import with wrong version fails and preserves original vault',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Create backup with unsupported version (modify version byte in decoded blob)
        final originalBytes = base64Decode(originalBlob);
        // BNBVL004 = version 2 at byte 8, BNBVL003 = version 1 at byte 8
        // Change version to 0 (unsupported)
        final badVersionBytes = Uint8List.fromList(originalBytes);
        badVersionBytes[8] = 0; // Unsupported version
        final badVersionBackup = base64Encode(badVersionBytes);

        final badVersionFile = File('${tmp.path}/bad_version.bnb');
        await badVersionFile.writeAsString(badVersionBackup);

        // Try to import with wrong version
        await expectLater(
          appState.importVault(
            badVersionFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unsupported vault version'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'import with empty backup fails and preserves original vault',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Create empty backup
        final emptyBackupFile = File('${tmp.path}/empty_backup.bnb');
        await emptyBackupFile.writeAsString('');

        // Try to import empty backup
        await expectLater(
          appState.importVault(
            emptyBackupFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'import with oversized backup fails and preserves original vault',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Create oversized backup (> 5MB)
        final oversizedData = 'BNBVL004${'x' * (6 * 1024 * 1024)}';
        final oversizedFile = File('${tmp.path}/oversized_backup.bnb');
        await oversizedFile.writeAsString(oversizedData);

        // Try to import oversized backup
        await expectLater(
          appState.importVault(
            oversizedFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('too large'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'import without confirmReplace fails and preserves original vault',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Export the vault
        final backupFile = File('${tmp.path}/backup.bnb');
        await backupFile.writeAsString(originalBlob);

        // Try to import without confirmation
        await expectLater(
          appState.importVault(
            backupFile.path,
            password: _testPassword,
            confirmReplace: false,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Explicit confirmation required'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test('successful import replaces vault and validates', () async {
      // Create original vault
      final originalBlob = await setupTestVault(
        _testPassword,
        label: 'Original Wallet',
      );
      expect(originalBlob, isNotEmpty);

      // Export the vault
      final backupFile = File('${tmp.path}/backup.bnb');
      await backupFile.writeAsString(originalBlob);

      // Import with correct password and confirmation
      await appState.importVault(
        backupFile.path,
        password: _testPassword,
        confirmReplace: true,
      );

      // Verify vault was replaced (same content in this case since we're re-importing)
      final vaultFile = await AppStorage.vaultFile();
      final currentBlob = await vaultFile.readAsString();
      expect(
        currentBlob,
        originalBlob,
        reason: 'Vault should be successfully imported',
      );

      // Verify vault can be unlocked
      final accounts = await appState.loadVaultAccounts(_testPassword);
      expect(accounts, isNotEmpty);
      expect(accounts.first.label, 'Original Wallet');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('import rejects symlink source', () async {
      // Create original vault
      final originalBlob = await setupTestVault(
        _testPassword,
        label: 'Original Wallet',
      );

      // Export the vault
      final backupFile = File('${tmp.path}/backup.bnb');
      await backupFile.writeAsString(originalBlob);

      // Create symlink to backup
      final symlinkFile = File('${tmp.path}/symlink_backup.bnb');
      final link = Link(symlinkFile.path);
      await link.create(backupFile.path);

      // Try to import via symlink
      await expectLater(
        appState.importVault(
          symlinkFile.path,
          password: _testPassword,
          confirmReplace: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('symbolic link'),
          ),
        ),
      );

      // Verify original vault is preserved
      final vaultFile = await AppStorage.vaultFile();
      final currentBlob = await vaultFile.readAsString();
      expect(
        currentBlob,
        originalBlob,
        reason: 'Original vault should be unchanged after failed import',
      );
    }, timeout: const Timeout(Duration(minutes: 5)));

    test(
      'import with corrupted backup (tampered) fails and preserves original',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );
        expect(originalBlob, isNotEmpty);

        // Create tampered backup (flip a byte in the middle)
        final tamperedBytes = base64Decode(originalBlob);
        tamperedBytes[tamperedBytes.length ~/ 2] ^= 0xFF;
        final tamperedBlob = base64Encode(tamperedBytes);

        final tamperedFile = File('${tmp.path}/tampered_backup.bnb');
        await tamperedFile.writeAsString(tamperedBlob);

        // Try to import tampered backup
        await expectLater(
          appState.importVault(
            tamperedFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Wrong password'),
            ),
          ),
        );

        // Verify original vault is preserved
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(
          currentBlob,
          originalBlob,
          reason: 'Original vault should be unchanged after failed import',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  group('AppState.importVault concurrent operations (real KDF)', () {
    test(
      'concurrent import operations are serialized by vaultOperationLock',
      () async {
        // Create original vault
        final originalBlob = await setupTestVault(
          _testPassword,
          label: 'Original Wallet',
        );

        final backupFile = File('${tmp.path}/backup.bnb');
        await backupFile.writeAsString(originalBlob);

        // Start two concurrent imports (they should be serialized by vaultOperationLock)
        final futures = <Future<void>>[
          appState.importVault(
            backupFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
          appState.importVault(
            backupFile.path,
            password: _testPassword,
            confirmReplace: true,
          ),
        ];

        // Both should complete without throwing (serialized by lock)
        await Future.wait(futures);

        // Verify vault is still valid
        final vaultFile = await AppStorage.vaultFile();
        final currentBlob = await vaultFile.readAsString();
        expect(currentBlob, isNotEmpty);

        // Verify vault can be unlocked
        final accounts = await appState.loadVaultAccounts(_testPassword);
        expect(accounts, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
