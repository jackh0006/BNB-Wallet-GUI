// End-to-end encrypted backup/restore using synthetic wallet material only.
// Tagged `kdf` because it exercises the real production Argon2id backend.
@Tags(['kdf'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bnb_wallet_gui/vault.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _password = 'backup-restore-password-2026';
const _device = 'backup-restore-device-secret-32b';
const _mnemonic = 'test test test test test test test test test test test junk';

void main() {
  test(
    'create → encrypted backup → wipe → restore preserves the address',
    () async {
      final key = WalletCore.derivePrivateKey(phrase: _mnemonic);
      final address = key.address.eip55With0x;
      final vaultJson = jsonEncode([
        {
          'label': 'Synthetic backup wallet',
          'address': address,
          'privateKeyHex': WalletCore.privateKeyHex(key),
          'mnemonic': _mnemonic,
          'savedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
      ]);

      final backup = await VaultCipher.encrypt(_password, vaultJson, _device);
      expect(base64Decode(backup).sublist(0, 8), 'BNBVL004'.codeUnits);

      // Simulate a wipe: only the encrypted backup survives.
      final restoredJson = await VaultCipher.decrypt(
        _password,
        backup,
        _device,
      );
      final restored = (jsonDecode(restoredJson) as List).single as Map;
      expect(restored['address'], address);
      expect(restored['privateKeyHex'], WalletCore.privateKeyHex(key));
      expect(restored['mnemonic'], _mnemonic);

      final restoredKey = WalletCore.privateKeyFromHex(
        restored['privateKeyHex'] as String,
      );
      expect(restoredKey.address.eip55With0x, address);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('wrong password cannot restore', () async {
    final backup = await VaultCipher.encrypt(
      _password,
      '{"label":"synthetic"}',
      _device,
    );
    await expectLater(
      VaultCipher.decrypt('wrong-password', backup, _device),
      throwsA(isA<VaultException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('tampered ciphertext cannot restore', () async {
    final backup = await VaultCipher.encrypt(
      _password,
      '{"label":"synthetic"}',
      _device,
    );
    final bytes = base64Decode(backup);
    // Flip a byte in the payload ciphertext, away from the header.
    final index = bytes.length - 40;
    bytes[index] ^= 0x01;
    await expectLater(
      VaultCipher.decrypt(_password, base64Encode(bytes), _device),
      throwsA(isA<VaultException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('truncated backup cannot restore', () async {
    final backup = await VaultCipher.encrypt(
      _password,
      '{"label":"synthetic"}',
      _device,
    );
    final bytes = base64Decode(backup);
    await expectLater(
      VaultCipher.decrypt(
        _password,
        base64Encode(Uint8List.fromList(bytes.sublist(0, bytes.length - 20))),
        _device,
      ),
      throwsA(isA<VaultException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
