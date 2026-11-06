import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trusted token sources (spec §10e)', () {
    late final List<Map<String, dynamic>> entries;

    setUpAll(() {
      final raw = File('assets/token_sources.json').readAsStringSync();
      final decoded = jsonDecode(raw);
      expect(decoded, isA<List>(), reason: 'the shipped file must be a list');
      entries = [
        for (final e in decoded as List)
          if (e is Map<String, dynamic>) e,
      ];
    });

    test('has enough starting points, every row shaped correctly', () {
      expect(entries.length, greaterThanOrEqualTo(4));
      for (final e in entries) {
        expect(
          (e['name'] as String?)?.isNotEmpty ?? false,
          isTrue,
          reason: 'row without a name: $e',
        );
        expect(
          (e['description'] as String?)?.isNotEmpty ?? false,
          isTrue,
          reason: 'row without a description: $e',
        );
        final url = e['url'] as String?;
        expect(
          url,
          startsWith('https://'),
          reason: 'every source must be https',
        );
      }
    });

    test('an issuer-official and an explorer/aggregator source exist', () {
      final names = entries.map((e) => e['name'].toString().toLowerCase());
      expect(
        names.any((n) => n.contains('tether')),
        isTrue,
        reason: 'USDT issuer-official link missing',
      );
      expect(
        names.any((n) => n.contains('circle')),
        isTrue,
        reason: 'USDC issuer-official link missing',
      );
      expect(
        names.any((n) => n.contains('bscscan')),
        isTrue,
        reason: 'explorer cross-check missing',
      );
      expect(
        names.any(
          (n) => n.contains('coingecko') || n.contains('coinmarketcap'),
        ),
        isTrue,
        reason: 'aggregator cross-check missing',
      );
    });

    test('bot-protected rows declare themselves (honest CI skip)', () {
      for (final e in entries) {
        final url = e['url'] as String;
        if (url.contains('bscscan.com')) {
          expect(
            e['bot_protected'],
            isTrue,
            reason: 'BscScan refuses scripted probes; the list must say so',
          );
        }
      }
    });

    test('exact spec URLs where the spec fixes them', () {
      final urls = entries.map((e) => e['url']);
      // Spec §10e names these two exactly:
      expect(urls, contains('https://tether.to/en/supported-protocols/'));
      expect(
        urls,
        contains(
          'https://developers.circle.com/stablecoins/usdc-contract-addresses',
        ),
      );
    });
  });
}
