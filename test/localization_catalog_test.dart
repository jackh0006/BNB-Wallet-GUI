import 'package:bnb_wallet_gui/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every supported navigation catalog supplies Inspect', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final strings = lookupAppLocalizations(Locale(locale.languageCode));
      expect(strings.inspect, isNotEmpty, reason: locale.languageCode);
    }
  });
}
