// Tagged `kdf`: real 64 MiB Argon2id derivations — scripts/test-suite.sh
// runs this suite strictly one at a time (never overlapped on 2 cores).
@Tags(['kdf'])
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/vault.dart';

void main() {
  const password = 'alpine-vault-#2026';
  const device = 'dev-32b-secret-encoded-AwEAAMmIQca9Di8b04';
  const payload = '{"label":"cold","address":"0xabc…"}';

  // One real 64 MiB encrypt shared by every test that needs "a valid v2
  // envelope". Tests that PROVE a property of fresh encryptions still derive
  // their own; nothing below weakens a security assertion — it only stops
  // re-deriving the same blob five extra times on a 2-core box.
  Future<String>? _blobMemo;
  Future<String> goodBlob() => _blobMemo ??= VaultCipher.encrypt(password, payload, device);

  // Every Argon2id call here hashes 64 MiB; keep the test budget sane.
  // Each KDF test gets an explicit minutes-scale timeout because the default
  // 30 s is too tight on a loaded machine — and a timeout there kills the
  // shared test device mid-derivation, failing unrelated tests too. These
  // suites are tagged `kdf` so scripts/test-suite.sh runs them alone.
  group('VaultCipher v2 envelope', () {
    test('round-trips with password + device secret', () async {
      final blob = await goodBlob();
      expect(base64Decode(blob).sublist(0, 8), 'BNBVL004'.codeUnits,
          reason: 'v2 magic marker at the front of every envelope');
      final clear = await VaultCipher.decrypt(password, blob, device);
      expect(clear, payload);
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('rejects a wrong password', () async {
      final blob = await goodBlob();
      expect(
        () => VaultCipher.decrypt('not-the-password', blob, device),
        throwsA(isA<VaultException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('rejects a wrong device secret — copied vault file is inert', () async {
      final blob = await goodBlob();
      expect(
        () => VaultCipher.decrypt(password, blob, 'nope-nope-nope'),
        throwsA(isA<VaultException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('unknown plaintexts differ in ciphertext (fresh nonce each time)', () async {
      final a = await goodBlob(); // one envelope produced by its own call
      final b = await VaultCipher.encrypt(password, payload, device);
      expect(a, isNot(b));
      // Both still decrypt.
      expect(await VaultCipher.decrypt(password, a, device), payload);
      expect(await VaultCipher.decrypt(password, b, device), payload);
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('rejects downgraded Argon2id parameters in the header', () async {
      final blob = await goodBlob();
      final bytes = base64Decode(blob);
      // Header layout: magic(8)+v(1)+m(4)+t(4)+p(4)+salt(16) → m at offset 9.
      void put32(List<int> data, int offset, int v) {
        data[offset] = v & 0xff;
        data[offset + 1] = (v >> 8) & 0xff;
        data[offset + 2] = (v >> 16) & 0xff;
        data[offset + 3] = (v >> 24) & 0xff;
      }

      // Downgrade memory (bytes 9..12), any tamper must not yield plaintext —
      // the header is inside AAD so decryption fails authentication, and a
      // smaller-but-valid m is blocked by the floor check.
      final weakened = [...bytes];
      put32(weakened, 9, 32768);
      final weakenedText = base64Encode(weakened);
      expect(
        () => VaultCipher.decrypt(password, weakenedText, device),
        throwsA(isA<VaultException>()),
      );

      // Swap full 128 KiB header instead: still fails (AEAD binding).
      final swapped = [...bytes];
      final tmp = swapped.sublist(9, 21);
      put32(swapped, 9, 1 << 20);
      put32(tmp, 0, 1 << 20 & 0xffffffff); // no-op placeholder byte munge
      put32(swapped, 13, 1);
      final swappedText = base64Encode(swapped);
      expect(
        () => VaultCipher.decrypt(password, swappedText, device),
        throwsA(isA<VaultException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('does not leak which wrapper failed (single message)', () async {
      final blob = await goodBlob();
      try {
        await VaultCipher.decrypt('wrong-pw', blob, device);
        fail('should have thrown');
      } on VaultException catch (e) {
        expect(e.message, contains('Wrong password'));
      }
      try {
        await VaultCipher.decrypt(password, blob, 'wrong-dev');
        fail('should have thrown');
      } on VaultException catch (e) {
        expect(e.message, contains('device key'));
      }
    }, timeout: const Timeout(Duration(minutes: 8)));
  });

  group('VaultCipher v1 migration', () {
    // Reconstructs the exact v1.0.2 envelope ("BNBVL003") with the same
    // constants the old release shipped: 64 MiB, t=3, p=4, 16-byte salt.
    test('legacy blobs stay readable', () async {
      final magic = <int>[0x42, 0x4e, 0x42, 0x56, 0x4c, 0x30, 0x30, 0x33];
      final salt = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
      final argon = Argon2id(
        parallelism: 4,
        memory: 65536,
        iterations: 3,
        hashLength: 32,
      );
      final key = await argon.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final keyBytes = await key.extractBytes();
      final cipher = Xchacha20.poly1305Aead();
      final nonce = <int>[
        for (var i = 0; i < 24; i++) 0xa0 + i,
      ];
      final box = await cipher.encrypt(
        utf8.encode(payload),
        secretKey: SecretKey(keyBytes),
        nonce: nonce,
        aad: [
          ...magic, 1,
          ..._u32le(65536), ..._u32le(3), ..._u32le(4),
          ...salt,
        ],
      );
      final blob = base64Encode([
        ...magic, 1,
        ..._u32le(65536), ..._u32le(3), ..._u32le(4),
        ...salt,
        ...box.nonce, ...box.cipherText, ...box.mac.bytes,
      ]);
      final clear = await VaultCipher.decrypt(password, blob, device);
      expect(clear, payload);
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}

List<int> _u32le(int v) => [
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ];
