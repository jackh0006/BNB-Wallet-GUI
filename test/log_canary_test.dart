import 'dart:convert';
import 'dart:io';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/encrypted_log_store.dart';
import 'package:bnb_wallet_gui/posix_fs.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

/// Feeds path_provider a real temporary directory so the encrypted log file
/// can be inspected byte-for-byte.
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

@Tags(['sequential'])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late int previousUmask;
  const canary = 'CANARY-SECRET-6e1f4c2a-DO-NOT-PERSIST';

  setUp(() async {
    PosixFs.selfCheck();
    previousUmask = PosixFs.setUmask(63); // match Linux launcher (0077)
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bnb-log-canary');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
    final key = EthPrivateKey.fromHex('0x${List.filled(32, '11').join()}');
    await appState.unlock(key);
    await EncryptedLogStore.clear();
  });

  tearDown(() async {
    appState.lock();
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
    PosixFs.restoreUmask(previousUmask);
  });

  group('log canary (spec §8: no secret reaches the log sink)', () {
    test('a canary in a message is readable only after decryption', () async {
      await EncryptedLogStore.append({
        'category': 'security',
        'level': 'info',
        'msg': 'canary probe $canary',
      });

      final file = File('${tmp.path}/bnb-wallet-log.bin');
      expect(await file.exists(), isTrue);
      final raw = await file.readAsBytes();
      final asText = utf8.decode(raw, allowMalformed: true);
      expect(
        asText.contains(canary),
        isFalse,
        reason: 'the on-disk log must never contain plaintext',
      );
      expect(
        base64Decode(asText).sublist(0, 8),
        'BNBLOG01'.codeUnits,
        reason: 'the atomic text envelope must contain BNBLOG01 ciphertext',
      );

      final entries = await EncryptedLogStore.readAll();
      expect(entries, hasLength(1));
      expect('${entries.single['msg']}', contains(canary));
    });

    test('clearing the log removes the encrypted file', () async {
      await EncryptedLogStore.append({
        'category': 'security',
        'level': 'info',
        'msg': 'probe',
      });
      final file = File('${tmp.path}/bnb-wallet-log.bin');
      expect(await file.exists(), isTrue);
      await EncryptedLogStore.clear();
      expect(await file.exists(), isFalse);
    });

    test('same-process concurrent appends retain every entry', () async {
      await Future.wait(
        List.generate(
          12,
          (i) => EncryptedLogStore.append({
            'category': 'security',
            'level': 'info',
            'msg': 'entry-$i',
          }),
        ),
      );
      final messages = (await EncryptedLogStore.readAll())
          .map((entry) => entry['msg'])
          .toSet();
      expect(messages, {for (var i = 0; i < 12; i++) 'entry-$i'});
    });
  });
}
