import 'dart:convert';
import 'dart:typed_data';

import 'package:bnb_wallet_gui/vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void put32(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  test('v2 rejects hostile Argon2id memory before deriving a key', () async {
    // v2's shortest structurally valid envelope is 37-byte header, two
    // 72-byte wrapped DEKs, and a 41-byte non-empty payload box.  None of
    // the ciphertext needs to authenticate: validation must stop at header
    // policy before Argon2id receives attacker-selected parameters.
    final bytes = Uint8List(222);
    bytes.setRange(0, 8, 'BNBVL004'.codeUnits);
    bytes[8] = 2;
    put32(bytes, 9, 0x7fffffff);
    put32(bytes, 13, 3);
    put32(bytes, 17, 4);

    await expectLater(
      VaultCipher.decrypt('password', base64Encode(bytes), 'device-secret'),
      throwsA(isA<VaultException>().having(
        (error) => error.message,
        'message',
        'Unsafe vault parameters.',
      )),
    );
  });

  test('truncated v1 header is a normal vault failure', () async {
    await expectLater(
      VaultCipher.decrypt(
        'password',
        base64Encode('BNBVL003'.codeUnits),
        'device-secret',
      ),
      throwsA(isA<VaultException>().having(
        (error) => error.message,
        'message',
        'Vault data is malformed.',
      )),
    );
  });
}
