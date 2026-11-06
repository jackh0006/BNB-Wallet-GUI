/// Worker-isolate jobs for the memory-hard crypto.
///
/// On Linux (all Flutter desktops), the Dart UI isolate runs on the GTK main
/// thread. Argon2id at 64 MiB therefore froze the window for seconds and
/// Ubuntu showed the "Force Quit / Wait" dialog. These jobs move the exact
/// same math onto worker isolates via `compute()` — identical bytes, same
/// security, but the window keeps answering the desktop while the work runs.
library;

import 'dart:convert';

import 'kdf.dart';
import 'vault.dart';

/// [password, plaintext(=vault JSON), deviceSecret] → envelope base64.
Future<String> vaultEncryptJob(List<String> args) {
  return VaultCipher.encrypt(args[0], args[1], args[2]);
}

/// [password, envelope base64, deviceSecret] → plaintext JSON.
Future<String> vaultDecryptJob(List<String> args) {
  return VaultCipher.decrypt(args[0], args[1], args[2]);
}

/// [pin, salt] → base64 Argon2id hash. Same parameters and record format the
/// main-isolate version used (64 MiB, t=3, p=4, 32-byte tag, salt string as
/// the raw nonce), so old records keep verifying.
Future<String> pinHashJob(List<String> args) async {
  final derived = await Argon2Kdf.derive(
    password: utf8.encode(args[0]),
    salt: utf8.encode(args[1]),
    memoryKiB: 65536,
    iterations: 3,
    parallelism: 4,
  );
  return base64Encode(derived);
}
