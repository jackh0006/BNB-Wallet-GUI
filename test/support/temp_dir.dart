import 'dart:io';

import 'package:bnb_wallet_gui/encrypted_log_store.dart';

/// Deletes a fixture's application-data directory without racing a pending
/// encrypted-log append.
///
/// [AppState.lock] and several storage paths append audit records without
/// awaiting them. On a fast CI runner the append can create its file after
/// `Directory.delete(recursive: true)` has listed the directory, producing
/// `Directory not empty (errno 39)`. Waiting for the log lock and retrying a
/// bounded number of times distinguishes that transient case from a genuine
/// permission or I/O failure.
Future<void> deleteTestDirectory(
  Directory dir, {
  int attempts = 40,
  Duration retryDelay = const Duration(milliseconds: 25),
}) async {
  try {
    await EncryptedLogStore.flush();
  } catch (_) {
    // The store may not have been initialised in this fixture; deletion is
    // still attempted and retried below.
  }
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == attempts - 1) rethrow;
      await Future<void>.delayed(retryDelay);
    }
  }
}
