import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/main.dart';
import 'package:bnb_wallet_gui/rpc_story.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Hermetic setup mirroring real startup: mock prefs, then AppStorage.init.
  // No network connect happens (AppState.init is not called), matching the
  // old tests' runtime behaviour.
  Future<void> bootstrap() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  }

  testWidgets('app launches with X Wallet branding', (tester) async {
    await bootstrap();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const XWalletApp());

    expect(find.text('X Wallet'), findsOneWidget);
  });

  testWidgets('connection story lines appear on the Home tab', (tester) async {
    await bootstrap();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    appState.rpc.clearStory();
    appState.rpc.note(
      'I knocked on example-door.org and it answered.',
      kind: RpcStoryKind.ok,
      detail: 'in 123 ms',
    );
    await tester.pumpWidget(const XWalletApp());
    await tester.pump();

    expect(find.textContaining('knocked on example-door.org'), findsOneWidget);
    expect(find.textContaining('end-to-end encrypted'), findsOneWidget);
  });

  testWidgets('app lock screen shows when PIN is enabled', (tester) async {
    await bootstrap();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await appState.setUsePin(true);
    await tester.pumpWidget(const XWalletApp());
    await tester.pump();

    expect(find.text('Enter your PIN to continue'), findsOneWidget);
  });
}
