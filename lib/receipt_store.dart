import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'models.dart';

/// Encrypted store for locally kept transaction receipts.
///
/// The receipts are public chain facts, but the set of them says who this
/// device paid — so they are not kept in the clear. Envelope:
///
/// ```
/// "BNBRCPT1" | nonce(24) | XChaCha20-Poly1305 ciphertext | mac(16)
/// key = HKDF-SHA256(ikm = wallet private key, salt = device drawer secret,
///                   info = "bnb-wallet/receipts-v1")
/// ```
///
/// The key exists only while the wallet is unlocked on this machine: losing
/// the wallet or the drawer secret makes the file inert, exactly like the
/// vault. No new key scheme — the same two factors the vault already uses.
class ReceiptStore {
  ReceiptStore._();

  static const List<int> _magic = [
    0x42, 0x4e, 0x42, 0x52, 0x43, 0x50, 0x54, 0x31, // "BNBRCPT1"
  ];
  static const int _nonceLength = 24;
  static const int _macLength = 16;
  static const int maxReceipts = 200;
  static const List<int> _info = [
    0x62, 0x6e, 0x62, 0x2d, 0x77, 0x61, 0x6c, 0x6c, 0x65, 0x74, 0x2f, // "bnb-wallet/"
    0x72, 0x65, 0x63, 0x65, 0x69, 0x70, 0x74, 0x73, 0x2d, 0x76, 0x31, // "receipts-v1"
  ];

  static final Xchacha20 _cipher = Xchacha20.poly1305Aead();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Derives the store key from the wallet's own private key plus the
  /// device-bound drawer secret. Deterministic, versioned, no key storage.
  static Future<Uint8List> deriveKey(
    Uint8List privateKeyBytes,
    String deviceSecret,
  ) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(privateKeyBytes),
      nonce: utf8.encode(deviceSecret),
      info: _info,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Encodes the receipt list into the encrypted envelope (base64 text).
  static Future<String> encode(
    Uint8List key,
    List<LocalReceipt> receipts,
  ) async {
    final payload = utf8.encode(jsonEncode({
      'v': 1,
      'receipts': [
        for (final receipt in receipts.take(maxReceipts)) receipt.toJson(),
      ],
    }));
    final nonce = _random(_nonceLength);
    final box = await _cipher.encrypt(
      payload,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final out = BytesBuilder();
    out.add(_magic);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  /// Decodes the envelope. Returns null on ANY failure (wrong key, tamper,
  /// truncation) — the store then simply appears empty instead of showing
  /// invented data or an alarming dialog for a file the user cannot fix.
  static Future<List<LocalReceipt>?> decode(
    Uint8List key,
    String encoded,
  ) async {
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length < _magic.length + _nonceLength + _macLength) return null;
      for (var i = 0; i < _magic.length; i++) {
        if (bytes[i] != _magic[i]) return null;
      }
      var offset = _magic.length;
      final nonce = Uint8List.sublistView(bytes, offset, offset + _nonceLength);
      offset += _nonceLength;
      final cipherText =
          Uint8List.sublistView(bytes, offset, bytes.length - _macLength);
      final mac = Uint8List.sublistView(bytes, bytes.length - _macLength);
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );
      final decoded = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final rows = decoded['receipts'] as List? ?? [];
      return [
        for (final row in rows)
          if (row is Map<String, dynamic>) LocalReceipt.fromJson(row),
      ];
    } catch (_) {
      return null;
    }
  }

  static Uint8List _random(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
