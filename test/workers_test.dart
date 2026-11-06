// Tagged `kdf`: real 64 MiB Argon2id derivations on worker isolates —
// scripts/test-suite.sh runs this suite strictly one at a time.
@Tags(['kdf'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/workers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every test here performs real 64 MiB Argon2id derivations on a worker
  // isolate. On a slow or loaded machine each derivation can take tens of
  // seconds; the default 30 s test timeout used to kill the shared test
  // device mid-KDF and take the rest of the file down with it. KDF tests get
  // real headroom below.

  test(
    'vaultEncryptJob → vaultDecryptJob round-trips through a worker isolate',
    () async {
      const payload = '{"label":"taste","address":"0xabc"}';
      final blob = await vaultEncryptJob(<String>[
        'correct horse',
        payload,
        'device-secret-0123456789',
      ]);
      final clear = await vaultDecryptJob(<String>[
        'correct horse',
        blob,
        'device-secret-0123456789',
      ]);
      expect(clear, payload);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test(
    'vaultDecryptJob refuses the wrong device key (same stack as v1.0.4)',
    () async {
      final blob = await vaultEncryptJob(<String>[
        'pw',
        '{"x":1}',
        'right-device-key',
      ]);
      await expectLater(
        vaultDecryptJob(<String>['pw', blob, 'wrong-device-key']),
        throwsA(anything),
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test(
    'pinHashJob keeps the exact v1.0.4 record format (64 MiB Argon2id)',
    () async {
      final a = await pinHashJob(<String>[
        '123456',
        'c2FsdHNhbHRzYWx0c2FsdA==',
      ]);
      final b = await pinHashJob(<String>[
        '123456',
        'c2FsdHNhbHRzYWx0c2FsdA==',
      ]);
      final other = await pinHashJob(<String>[
        '654321',
        'c2FsdHNhbHRzYWx0c2FsdA==',
      ]);

      // 32-byte tag → 44-char base64 (with padding), stable across runs.
      expect(a, b);
      expect(a.length, 44);
      expect(base64Decode(a).length, 32);
      expect(a, isNot(other));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
