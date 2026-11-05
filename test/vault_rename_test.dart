import 'dart:io';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

const _testKeyHex =
    '0x115b527ce6cb943286dee1503e7645b0d021cc0cd43b9cbf7cb80eeba9db6b49';
const _testPassword = 'test-password-123456';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bnb-vault-rename-test-');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
    appState.lock();
  });
  tearDown(() async {
    appState.lock();
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('renaming a vault account preserves its recovery phrase', () async {
    final key = WalletCore.privateKeyFromHex(_testKeyHex);
    const phrase =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    await appState.saveVaultAccount(
      _testPassword,
      label: 'Before rename',
      key: key,
      mnemonic: phrase,
    );

    await appState.renameVaultAccount(_testPassword, 0, 'After rename');
    final accounts = await appState.loadVaultAccounts(_testPassword);

    expect(accounts, hasLength(1));
    expect(accounts.single.label, 'After rename');
    expect(accounts.single.mnemonic, phrase);
    expect(accounts.single.address, key.address.eip55With0x);
  });
}
