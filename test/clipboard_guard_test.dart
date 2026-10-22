import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  group('ClipboardGuard — nothing secret-shaped reaches the clipboard', () {
    test('seed-phrase-shaped text (12 or 24 words) is refused', () {
      const twelve =
          'abandon ability able about above absent absorb abstract absurd abuse access accident';
      final twentyFour = List.filled(24, 'abandon').join(' ');
      expect(ClipboardGuard.secretFree(twelve), isFalse,
          reason: 'a 12-word phrase must never be copied');
      expect(ClipboardGuard.secretFree(twentyFour), isFalse,
          reason: 'a 24-word phrase must never be copied');
    });

    test('a bare 64-hex private key is refused', () {
      const key =
          '4c0883a69102937d6231471b5e6d5b7a4c3f9e2a8d1b0c7f6a5e4d3c2b1a0987';
      expect(ClipboardGuard.secretFree(key), isFalse);
    });

    test('ordinary wallet content stays copyable', () {
      expect(
          ClipboardGuard.secretFree(
              '0x55d398326f99059fF775485246999027B3197955'),
          isTrue,
          reason: 'contract address');
      expect(
          ClipboardGuard.secretFree(
              '0x5c4dd1e2c0d3e2a1a4f00a42f6aa5cba6a5de2e3f1b6c4a4e4b3d2c1d0f9e8a7'),
          isTrue,
          reason: 'tx hash (0x + 64 hex) — copyable by design');
      expect(ClipboardGuard.secretFree('https://bscscan.com/address'), isTrue,
          reason: 'trusted-source link');
      expect(ClipboardGuard.secretFree('Collapse we must. Yes, hrrm.'), isTrue,
          reason: 'plain text, not secret-shaped');
    });

    test('near-miss shapes are documented honestly', () {
      expect(ClipboardGuard.secretFree(''), isFalse, reason: 'empty = no copy');
      // 13 alpha words is NOT one of the real mnemonic lengths (12/15/18/21/24):
      final thirteenWord = List.filled(13, 'abandon').join(' ');
      expect(ClipboardGuard.secretFree(thirteenWord), isTrue,
          reason: '13-word text cannot be a standard seed — stays copyable');
      final twentyOneWord = List.filled(21, 'abandon').join(' ');
      expect(ClipboardGuard.secretFree(twentyOneWord), isFalse,
          reason: 'the 21-word mnemonic family is refused too');
    });
  });
}
