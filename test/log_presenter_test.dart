import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/encrypted_log_store.dart';
import 'package:bnb_wallet_gui/log_presenter.dart';

void main() {
  group('Simple log presentation (spec §10b-E)', () {
    test(
      'every category and level maps to an icon, a short title and a colour',
      () {
        for (final category in LogCategory.values) {
          for (final level in LogLevel.values) {
            final view = presentLogEntry({
              'category': category.name,
              'level': level.name,
              'msg': 'technical detail that stays in Expert mode',
            });
            expect(
              view.icon,
              isNotNull,
              reason: '${category.name}/${level.name} needs an icon',
            );
            expect(
              view.title.trim(),
              isNotEmpty,
              reason: '${category.name}/${level.name} needs words',
            );
            expect(
              view.title.split(' ').length,
              lessThanOrEqualTo(4),
              reason: 'Simple mode keeps steps to 2–4 words',
            );
            expect(view.levelLabel, level.name.toUpperCase());
          }
        }
      },
    );

    test('an explicit plain-words title wins over the category fallback', () {
      final view = presentLogEntry({
        'category': 'network',
        'level': 'ok',
        'msg': 'eth_chainId answered 0x38',
        'simple': 'Node agrees',
      });
      expect(view.title, 'Node agrees');
    });

    test('old or unknown entries fall back instead of throwing', () {
      final view = presentLogEntry({
        'category': 'from-a-newer-version',
        'level': 'trace',
        'msg': 'future event',
      });
      expect(view.title, isNotEmpty);
      expect(view.icon, isNotNull);
      expect(view.levelLabel, 'INFO');
    });
  });
}
