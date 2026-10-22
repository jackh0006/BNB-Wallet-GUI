import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  group('watch-only profile (spec §2)', () {
    const address = '0x7ea499b984050c75192387b5a0e81d6d39db50cd';

    test('opens a readable profile with no key and no seed', () async {
      final state = AppState();
      await state.openWatchOnly(address);
      expect(state.watchOnly, isTrue);
      expect(state.unlocked, isTrue);
      expect(state.privateKey, isNull);
      expect(state.mnemonic, isNull);
      expect(state.address, isNotNull);
      expect(state.address!.toLowerCase(), address);
      expect(AppStorage.watchAddress, state.address);
      await state.closeWatchOnly();
      expect(state.watchOnly, isFalse);
      expect(state.unlocked, isFalse);
      expect(AppStorage.watchAddress, isNull);
    });

    test(
      'refuses an invalid address instead of showing a bogus profile',
      () async {
        final state = AppState();
        expect(
          () => state.openWatchOnly('0x1234'),
          throwsA(isA<ArgumentError>()),
        );
        expect(state.watchOnly, isFalse);
      },
    );
  });
}
