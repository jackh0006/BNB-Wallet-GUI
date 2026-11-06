// Tagged `kdf`: real production-parameter Argon2id. Kept small and isolated so
// a low-memory machine can still prove the production path.
@Tags(['kdf'])
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart' as pure;
import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/kdf.dart';
import 'package:bnb_wallet_gui/vault.dart';

void main() {
  test('production KDF parameters are fixed', () {
    expect(VaultCipher.productionKdf, {
      'memoryKiB': 65536,
      'iterations': 3,
      'parallelism': 4,
      'keyLength': 32,
    });
  }, timeout: const Timeout(Duration(minutes: 1)));

  test(
    'native Argon2id matches the independent pure-Dart implementation',
    () async {
      final password = List<int>.generate(32, (i) => i + 1);
      final salt = List<int>.generate(16, (i) => 0xa0 + i);

      final native = await Argon2Kdf.derive(
        password: password,
        salt: salt,
        memoryKiB: 1024,
        iterations: 2,
        parallelism: 1,
      );
      final independent = pure.Argon2id(
        parallelism: 1,
        memory: 1024,
        iterations: 2,
        hashLength: 32,
      );
      final derived = await independent.deriveKey(
        secretKey: pure.SecretKey(password),
        nonce: salt,
      );
      expect(native, await derived.extractBytes());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('one real 64 MiB / t=3 / p=4 vault round-trip', () async {
    const password = 'production-kdf-round-trip';
    const device = 'real-device-secret-for-production-kdf';
    const payload = '{"label":"real-parameters","address":"0xabc"}';

    final watch = Stopwatch()..start();
    final blob = await VaultCipher.encrypt(password, payload, device);
    final clear = await VaultCipher.decrypt(password, blob, device);
    watch.stop();

    expect(clear, payload);
    expect(base64Decode(blob).sublist(0, 8), 'BNBVL004'.codeUnits);
    // This is a performance guard, not a cryptographic test: with the
    // reference native backend it is well under a second on the release
    // machine.  A pure-Dart fallback fails this bound on purpose and is
    // reported instead of silently shipping a two-minute unlock.
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 60)),
      reason: 'KDF backend was ${Argon2Kdf.lastBackend}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
