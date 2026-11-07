import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'kdf.dart';

/// Encrypted local vault for X Wallet.
///
/// Version 2 envelope ("BNBVL004", version byte 2) — two independent wrappers
/// around a random data-encryption key (DEK):
///
/// ```
/// header  = magic8 | v(1)=2 | Argon2id m,t,p (uint32 LE) | salt(16)   [AAD]
/// secrets = XChaCha20-Poly1305(DEK, plaintext, AAD)
/// KEK_pw  = Argon2id(password, salt)            // something you know
/// KEK_dev = HKDF-SHA256(deviceSecret)           // something the device holds
/// paper   = XChaCha20-Poly1305(KEK_pw, DEK, AAD)
/// device  = XChaCha20-Poly1305(KEK_dev, DEK, AAD)
/// ```
///
/// Both wrappers must open before any secret is released, so a vault file
/// copied off the device without the device-bound secret is inert, and the
/// device-bound secret alone is not enough. All additional data is the entire
/// header, so tampering or parameter downgrades are authenticated failures.
/// Version 1 envelopes ("BNBVL003": a single Argon2id-keyed box) stay readable
/// for migration from v1.0.2.
class VaultCipher {
  VaultCipher._();

  static const List<int> _magicV2 = [
    0x42, 0x4e, 0x42, 0x56, 0x4c, 0x30, 0x30, 0x34, // "BNBVL004"
  ];
  static const List<int> _magicV1 = [
    0x42, 0x4e, 0x42, 0x56, 0x4c, 0x30, 0x30, 0x33, // "BNBVL003"
  ];
  static const int _versionV2 = 2;
  static const int _versionV1 = 1;
  static const int _saltLength = 16;
  static const int _nonceLength = 24;
  static const int _memoryKiB = 65536; // 64 MiB — RFC 9106 low-memory floor
  static const int _iterations = 3;
  static const int _parallelism = 4;
  static const int _keyLength = 32;
  static const int _macLength = 16;
  static const List<int> _hkdfInfo = [
    0x62,
    0x6e,
    0x62,
    0x2d,
    0x77,
    0x61,
    0x6c,
    0x6c,
    0x65,
    0x74,
    0x2f, // "bnb-wallet/"
    0x64,
    0x65,
    0x76,
    0x69,
    0x63,
    0x65,
    0x2d,
    0x6b,
    0x65,
    0x6b,
    0x2d,
    0x76,
    0x32, // "device-kek-v2"
  ];

  static final Xchacha20 _cipher = Xchacha20.poly1305Aead();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: _keyLength);

  /// Encrypts [plaintext] with [password], bound to the [deviceSecret] held
  /// by the platform (Android Keystore-backed storage / libsecret).
  static Future<String> encrypt(
    String password,
    String plaintext,
    String deviceSecret,
  ) async {
    final salt = _random(_saltLength);
    final dekBytes = _random(_keyLength);
    final payloadNonce = _random(_nonceLength);
    final paperNonce = _random(_nonceLength);
    final deviceNonce = _random(_nonceLength);

    final header = _header(
      memory: _memoryKiB,
      iterations: _iterations,
      parallelism: _parallelism,
      salt: salt,
    );
    final aad = header;

    final kekPw = SecretKey(
      await _argon2Kek(
        password,
        salt,
        memoryKiB: _memoryKiB,
        iterations: _iterations,
        parallelism: _parallelism,
      ),
    );
    final kekDev = SecretKey(await _deviceKek(deviceSecret));

    final payloadBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(dekBytes),
      nonce: payloadNonce,
      aad: aad,
    );
    final paperBox = await _cipher.encrypt(
      dekBytes,
      secretKey: kekPw,
      nonce: paperNonce,
      aad: aad,
    );
    final deviceBox = await _cipher.encrypt(
      dekBytes,
      secretKey: kekDev,
      nonce: deviceNonce,
      aad: aad,
    );

    final out = BytesBuilder();
    out.add(aad);
    out.add(paperBox.nonce);
    out.add(paperBox.cipherText);
    out.add(paperBox.mac.bytes);
    out.add(deviceBox.nonce);
    out.add(deviceBox.cipherText);
    out.add(deviceBox.mac.bytes);
    out.add(payloadBox.nonce);
    out.add(payloadBox.cipherText);
    out.add(payloadBox.mac.bytes);
    return base64Encode(out.toBytes());
  }

  /// Decrypts a base64 vault blob written by v2 (or the legacy v1 format).
  /// Throws [VaultException] on ANY failure and never says which check failed.
  static Future<String> decrypt(
    String password,
    String encoded,
    String deviceSecret,
  ) async {
    final bytes = base64Decode(encoded);
    if (_startsWith(bytes, _magicV2)) {
      return _decryptV2(password, bytes, deviceSecret);
    }
    if (_startsWith(bytes, _magicV1)) {
      return _decryptV1(password, bytes);
    }
    throw const VaultException('Vault data is malformed.');
  }

  /// Decrypts and validates a vault blob using the provided password and device secret.
  /// This is a public method for validating imported backup files.
  /// Throws [VaultException] if the blob is invalid, password is wrong, or device secret mismatches.
  static Future<String> validateAndDecrypt(
    String encoded,
    String password,
    String deviceSecret,
  ) async {
    return decrypt(password, encoded, deviceSecret);
  }

  // ------------------------------------------------------------------ v2---

  static Future<String> _decryptV2(
    String password,
    Uint8List bytes,
    String deviceSecret,
  ) async {
    // Fixed layout: magic(8) | v(1) | m,t,p(12) | salt(16) = 37 bytes.
    final headerLength = _magicV2.length + 1 + 12 + _saltLength;
    // Floor = header + 2 wrapped-DEK boxes + payload box with ≥1 byte plaintext.
    final minLength =
        headerLength +
        2 * (_nonceLength + _keyLength + _macLength) +
        _nonceLength +
        _macLength +
        1;
    if (bytes.length < minLength) {
      throw const VaultException('Vault data is malformed.');
    }
    if (bytes[_magicV2.length] != _versionV2) {
      throw const VaultException('Unsupported vault version.');
    }
    final memory = _readUint32(bytes, _magicV2.length + 1);
    final iterations = _readUint32(bytes, _magicV2.length + 5);
    final parallelism = _readUint32(bytes, _magicV2.length + 9);
    // The parameters are header-authenticated, but authentication happens
    // only *after* Argon2id has consumed the requested resources.  Accepting
    // arbitrary values at this point lets a malicious backup request
    // unbounded memory/CPU before its AEAD tag is checked.  V2 is a fixed
    // profile format: every released writer uses these exact values.  Keeping
    // the parser equally strict is therefore both backwards-compatible with
    // released vaults and fail-closed for hostile/future profiles.
    if (memory != _memoryKiB ||
        iterations != _iterations ||
        parallelism != _parallelism) {
      throw const VaultException('Unsafe vault parameters.');
    }
    final aad = Uint8List.sublistView(bytes, 0, headerLength);
    final salt = Uint8List.sublistView(
      bytes,
      headerLength - _saltLength,
      headerLength,
    );

    var offset = headerLength;

    SecretBox paperBox;
    SecretBox deviceBox;
    SecretBox payloadBox;
    try {
      paperBox = SecretBox.fromConcatenation(
        Uint8List.sublistView(
          bytes,
          offset,
          offset + _nonceLength + _keyLength + _macLength,
        ),
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      offset += _nonceLength + _keyLength + _macLength;
      deviceBox = SecretBox.fromConcatenation(
        Uint8List.sublistView(
          bytes,
          offset,
          offset + _nonceLength + _keyLength + _macLength,
        ),
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      offset += _nonceLength + _keyLength + _macLength;
      payloadBox = SecretBox.fromConcatenation(
        Uint8List.sublistView(bytes, offset),
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
    } catch (_) {
      throw const VaultException('Vault data is malformed.');
    }

    final kekPw = SecretKey(
      await _argon2Kek(
        password,
        salt,
        memoryKiB: memory,
        iterations: iterations,
        parallelism: parallelism,
      ),
    );
    final kekDev = SecretKey(await _deviceKek(deviceSecret));

    Uint8List paperDek;
    Uint8List deviceDek;
    try {
      paperDek = Uint8List.fromList(
        await _cipher.decrypt(paperBox, secretKey: kekPw, aad: aad),
      );
      deviceDek = Uint8List.fromList(
        await _cipher.decrypt(deviceBox, secretKey: kekDev, aad: aad),
      );
    } catch (_) {
      // One generic error covering: wrong password, wrong/missing device key,
      // corrupted or tampered file. No oracle about which one it was.
      throw const VaultException(
        'Wrong password, device key unavailable, or corrupted vault.',
      );
    }
    if (!_constantEquals(paperDek, deviceDek)) {
      // The two wrappers disagree — the vault was edited. Fail closed.
      throw const VaultException('Vault integrity check failed.');
    }

    try {
      final clear = await _cipher.decrypt(
        payloadBox,
        secretKey: SecretKey(paperDek),
        aad: aad,
      );
      return utf8.decode(clear);
    } catch (_) {
      throw const VaultException(
        'Wrong password, device key unavailable, or corrupted vault.',
      );
    }
  }

  // ------------------------------------------------------------- helpers ---

  static Uint8List _header({
    required int memory,
    required int iterations,
    required int parallelism,
    required List<int> salt,
  }) {
    final header = BytesBuilder();
    header.add(_magicV2);
    header.addByte(_versionV2);
    header.add(_uint32(memory));
    header.add(_uint32(iterations));
    header.add(_uint32(parallelism));
    header.add(salt);
    return header.toBytes();
  }

  static Future<List<int>> _argon2Kek(
    String password,
    List<int> salt, {
    required int memoryKiB,
    required int iterations,
    required int parallelism,
  }) async {
    final override = _debugKdfOverride;
    if (override != null) {
      // Test-only seam. It is set through an assert-guarded setter, so it is
      // compiled out of release builds and can never weaken production.
      return override(password, salt, memoryKiB, iterations, parallelism);
    }
    return Argon2Kdf.derive(
      password: utf8.encode(password),
      salt: salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
    );
  }

  static Future<List<int>> Function(
    String password,
    List<int> salt,
    int memoryKiB,
    int iterations,
    int parallelism,
  )?
  _debugKdfOverride;

  /// Test-only: inject a fast KDF for envelope/format tests.
  ///
  /// The body is inside `assert`, so release builds ignore the assignment and
  /// `_argon2Kek` always uses [Argon2Kdf]. A dedicated `kdf`-tagged test still
  /// exercises the real production parameters.
  static set debugKdfOverride(
    Future<List<int>> Function(
      String password,
      List<int> salt,
      int memoryKiB,
      int iterations,
      int parallelism,
    )?
    value,
  ) {
    assert(() {
      _debugKdfOverride = value;
      return true;
    }());
  }

  /// Test-only: remove a previously injected KDF.
  static void clearDebugKdfOverride() {
    assert(() {
      _debugKdfOverride = null;
      return true;
    }());
  }

  /// Production Argon2id parameters, exposed for the parameter-integrity test.
  static const Map<String, int> productionKdf = {
    'memoryKiB': _memoryKiB,
    'iterations': _iterations,
    'parallelism': _parallelism,
    'keyLength': _keyLength,
  };

  static Future<List<int>> _deviceKek(String deviceSecret) {
    return _hkdf
        .deriveKey(
          secretKey: SecretKey(utf8.encode(deviceSecret)),
          nonce: List<int>.filled(32, 0),
          info: _hkdfInfo,
        )
        .then((key) => key.extractBytes());
  }

  /// Legacy v1 format: single Argon2id-keyed box (unchanged behaviour).
  static Future<String> _decryptV1(String password, Uint8List bytes) async {
    // Validate the whole fixed header before reading its version or KDF
    // fields.  A truncated hostile file must be a normal vault failure, never
    // an out-of-range exception from the parser.
    final headerLength = _magicV1.length + 1 + 12 + _saltLength;
    if (bytes.length < headerLength + _nonceLength + _macLength + 1) {
      throw const VaultException('Vault data is malformed.');
    }
    if (bytes[_magicV1.length] != _versionV1) {
      throw const VaultException('Unsupported vault version.');
    }
    var offset = _magicV1.length + 1;
    final memory = _readUint32(bytes, offset);
    final iterations = _readUint32(bytes, offset + 4);
    final parallelism = _readUint32(bytes, offset + 8);
    offset += 12;
    if (memory != _memoryKiB ||
        iterations != _iterations ||
        parallelism != _parallelism) {
      throw const VaultException('Unsafe vault parameters.');
    }
    final salt = Uint8List.sublistView(bytes, offset, offset + _saltLength);
    offset += _saltLength;
    final nonce = Uint8List.sublistView(bytes, offset, offset + _nonceLength);
    offset += _nonceLength;
    final cipherText = Uint8List.sublistView(
      bytes,
      offset,
      bytes.length - _macLength,
    );
    final macBytes = Uint8List.sublistView(bytes, bytes.length - _macLength);
    final aad = Uint8List.sublistView(
      bytes,
      0,
      _magicV1.length + 1 + 12 + _saltLength,
    );

    final keyBytes = await _argon2Kek(
      password,
      salt,
      memoryKiB: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
    try {
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: SecretKey(keyBytes),
        aad: aad,
      );
      return utf8.decode(clear);
    } catch (_) {
      throw const VaultException('Wrong vault password or corrupted vault.');
    }
  }

  static bool _startsWith(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  /// Constant-time equality (no early return on first difference).
  static bool _constantEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _random(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _uint32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  static int _readUint32(Uint8List bytes, int offset) => ByteData.sublistView(
    bytes,
    offset,
    offset + 4,
  ).getUint32(0, Endian.little);
}

/// Vault failure that never reveals whether the password, the device key or
/// the file itself was wrong.
class VaultException implements Exception {
  const VaultException(this.message);
  final String message;

  @override
  String toString() => message;
}
