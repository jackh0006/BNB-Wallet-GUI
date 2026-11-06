import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/memory_protection.dart';

/// These assertions inspect the actual kernel state of the test process, not a
/// shell child. The old implementation ran `sh -c 'ulimit -c 0'`, which only
/// changed the child shell and left the wallet process unchanged.
void main() {
  test('process is not dumpable and has no core-file limit', () async {
    await MemoryProtection.initialize();
    expect(MemoryProtection.dumpable, 0);
    expect(MemoryProtection.coreSoftLimit, 0);
  }, skip: !Platform.isLinux ? 'Linux-only kernel hardening' : false);

  test('initialization is idempotent', () async {
    await MemoryProtection.initialize();
    await MemoryProtection.initialize();
    expect(MemoryProtection.dumpable, 0);
    expect(MemoryProtection.coreSoftLimit, 0);
  }, skip: !Platform.isLinux ? 'Linux-only kernel hardening' : false);
}
