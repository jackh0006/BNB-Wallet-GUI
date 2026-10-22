import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'app_state.dart';
import 'storage.dart';

/// Encrypted on-disk log store (spec §8, R2).
/// Ring-buffer with size cap, keyed by wallet private key + device drawer secret.
/// Every entry is a JSON line; never logs seeds/keys/passwords.
class EncryptedLogStore {
  EncryptedLogStore._();

  static const _filename = 'bnb-wallet-log.bin';
  static const _envelopeMagic = 'BNBLOG01';
  static const _maxBytes = 5 * 1024 * 1024; // 5 MB cap
  static const _maxEntries = 10000;

  static Future<File> _file() async {
    final dir = await AppStorage.getDataDirectory();
    return File('${dir.path}/$_filename');
  }

  /// Derives the log key from wallet private key + device drawer secret.
  /// Uses the same HKDF-SHA256 path as the receipt store.
  static Future<Uint8List> _deriveKey() async {
    final pk = appState.privateKey;
    if (pk == null) throw StateError('No wallet loaded.');
    final device = await AppStorage.getOrGenerateDeviceSecret();
    if (device.isEmpty) throw StateError('No device secret.');

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(pk.privateKey),
      nonce: utf8.encode(device),
      info: utf8.encode('bnb-wallet/log-v1'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Appends a log line (JSON object) to the encrypted ring buffer.
  /// Truncates to cap if needed.
  static Future<void> append(Map<String, dynamic> entry) async {
    final key = await _deriveKey();
    final file = await _file();

    // Read existing
    List<String> lines = [];
    if (await file.exists()) {
      try {
        final blob = await file.readAsBytes();
        lines = (await _decrypt(key, blob)).split('\n').where((l) => l.isNotEmpty).toList();
      } catch (_) {
        lines = [];
      }
    }

    // Add new entry with timestamp
    final entryWithMeta = Map<String, dynamic>.from(entry);
    entryWithMeta['ts'] = DateTime.now().toUtc().toIso8601String();
    final jsonLine = jsonEncode(entryWithMeta);
    lines.add(jsonLine);

    // Truncate to cap
    if (lines.length > _maxEntries) {
      lines = lines.sublist(lines.length - _maxEntries);
    }
    final joined = lines.join('\n');
    if (utf8.encode(joined).length > _maxBytes) {
      while (utf8.encode(lines.join('\n')).length > _maxBytes && lines.length > 1) {
        lines.removeAt(0);
      }
    }

    await _write(key, file, lines.join('\n'));
  }

  /// Reads all log entries (newest first).
  static Future<List<Map<String, dynamic>>> readAll() async {
    final key = await _deriveKey();
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final blob = await file.readAsBytes();
      final text = await _decrypt(key, blob);
      return text
          .split('\n')
          .where((l) => l.isNotEmpty)
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Reads entries filtered by category/level/time.
  static Future<List<Map<String, dynamic>>> readFiltered({
    String? category,
    String? level,
    DateTime? since,
    int limit = 500,
  }) async {
    final all = await readAll();
    var filtered = all;
    if (category != null) {
      filtered = filtered.where((e) => e['category'] == category).toList();
    }
    if (level != null) {
      filtered = filtered.where((e) => e['level'] == level).toList();
    }
    if (since != null) {
      filtered = filtered
          .where((e) => DateTime.parse(e['ts'] as String).isAfter(since))
          .toList();
    }
    if (filtered.length > limit) filtered = filtered.sublist(0, limit);
    return filtered;
  }

  /// Exports log as plain text or JSON (with warning).
  static Future<String> export({bool json = false}) async {
    final entries = await readAll();
    if (json) {
      return const JsonEncoder.withIndent('  ').convert(entries);
    }
    return entries.map((e) {
      final ts = e['ts'] ?? '';
      final cat = e['category'] ?? '';
      final lvl = e['level'] ?? '';
      final msg = e['msg'] ?? '';
      return '$ts [$lvl] [$cat] $msg';
    }).join('\n');
  }

  static Future<void> _write(Uint8List key, File file, String plaintext) async {
    final cipher = Xchacha20.poly1305Aead();
    final nonce = _random(24);
    final box = await cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final out = BytesBuilder();
    out.add(Uint8List.fromList(_envelopeMagic.codeUnits));
    out.add(Uint8List.fromList(box.nonce));
    out.add(Uint8List.fromList(box.cipherText));
    out.add(Uint8List.fromList(box.mac.bytes));
    await file.writeAsBytes(out.toBytes(), flush: true, mode: FileMode.writeOnly);
  }

  static Future<String> _decrypt(Uint8List key, List<int> blob) async {
    final magic = _envelopeMagic.codeUnits;
    final bytes = Uint8List.fromList(blob);
    if (bytes.length < magic.length + 24 + 16) {
      throw StateError('Log blob too short');
    }
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) throw StateError('Invalid log envelope');
    }
    var offset = magic.length;
    final nonce = Uint8List.sublistView(bytes, offset, offset + 24);
    offset += 24;
    final cipherText = Uint8List.sublistView(bytes, offset, bytes.length - 16);
    final mac = Uint8List.sublistView(bytes, bytes.length - 16);
    final cipher = Xchacha20.poly1305Aead();
    final clear = await cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
    );
    return utf8.decode(clear);
  }

  /// Clears the log file (for "Erase everything" / privacy).
  static Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Uint8List _random(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
  }
}

/// Log categories (matching spec §8).
enum LogCategory {
  vault,
  keys,
  network,
  tor,
  fees,
  tx,
  tokens,
  security,
  system,
}

/// Log levels.
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// Helper to log a structured entry.
Future<void> logEvent({
  required LogCategory category,
  required LogLevel level,
  required String message,
  Map<String, dynamic>? extra,
}) async {
  final entry = <String, dynamic>{
    'category': category.name,
    'level': level.name,
    'msg': message,
    if (extra != null) ...extra,
  };
  // Fire-and-forget; log failures must never break the app
  EncryptedLogStore.append(entry).catchError((_) {});
}