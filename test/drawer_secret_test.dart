import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feeds path_provider a real temporary directory so the locked-drawer
/// fallback actually writes files we can inspect.
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bnb-drawer-test');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
  });
  tearDown(() async {
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('device secret — weak/old desktop behaviour (taste round 3)', () {
    test('keyring unavailable → secret minted into the locked drawer, honestly flagged', () async {
      // flutter_secure_storage has no plugin under flutter_test: its calls
      // throw immediately, which is exactly the "keyring did not answer"
      // branch the fallback exists for.
      final secret = await AppStorage.getOrGenerateDeviceSecret();

      expect(secret.length, greaterThan(0));
      expect(AppStorage.lastDeviceSecretFromDrawer, isTrue);

      final drawer = File('${tmp.path}/device_secret_v2.drawer');
      expect(await drawer.exists(), isTrue);
      expect((await drawer.readAsString()).trim(), secret);
    });

    test(
      'repeat calls are stable (memoized or re-read from the drawer)',
      () async {
        final first = await AppStorage.getOrGenerateDeviceSecret();
        final second = await AppStorage.getOrGenerateDeviceSecret();
        expect(second, first);
        // No additional drawer files appear either.
        final files = tmp.listSync().map((f) => f.path).toList();
        expect(files.where((p) => p.contains('drawer')).length, 1);
      },
    );

    test('eraseAllData shreds the drawer and clears the memo', () async {
      await AppStorage.getOrGenerateDeviceSecret();
      final drawer = File('${tmp.path}/device_secret_v2.drawer');
      expect(await drawer.exists(), isTrue);

      await AppStorage.eraseAllData();
      expect(await drawer.exists(), isFalse);
      expect(AppStorage.lastDeviceSecretFromDrawer, isFalse);
    });

    test(
      'existing vault + dead keyring → fail closed, never re-key silently',
      () async {
        AppStorage.resetDeviceSecretMemo();
        // Simulate an older session's vault: a vault file exists on disk and
        // its device key is "stuck" inside an unreachable keyring (the test
        // plugin throws). Minting a new secret would orphan that vault, so
        // the wallet must fail closed instead.
        await File('${tmp.path}/bnb-wallet-vault.bnb')
            .writeAsString('BNBVLnotareallyvault', flush: true);

        await expectLater(
          AppStorage.getOrGenerateDeviceSecret(),
          throwsA(isA<DeviceKeyException>()),
        );
        // No drawer was minted over the legacy key: nothing was replaced.
        final drawer = File('${tmp.path}/device_secret_v2.drawer');
        expect(await drawer.exists(), isFalse);
      },
    );

    test('fresh machine: drawer mint happens with nothing else involved '
        '(wallet creation can never freeze)', () async {
      AppStorage.resetDeviceSecretMemo();
      final secret = await AppStorage.getOrGenerateDeviceSecret();
      expect(AppStorage.lastDeviceSecretFromDrawer, isTrue);
      expect(
        (await File(
          '${tmp.path}/device_secret_v2.drawer',
        ).readAsString()).trim(),
        secret,
      );
      // Exactly one storage artefact exists: the drawer.
      final files = tmp.listSync().map((f) => f.uri.pathSegments.last).toList();
      expect(files, contains('device_secret_v2.drawer'));
      expect(
        files.where((f) => f.contains('keyring') || f.contains('secure')),
        isEmpty,
      );
    });
  });
}
