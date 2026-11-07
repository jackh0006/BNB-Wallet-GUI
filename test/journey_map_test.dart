import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/widgets/journey_map.dart';

List<JourneyStop> _stops() => const [
  JourneyStop(
    icon: Icons.phone_android,
    label: 'My phone',
    plainStatus: 'signed here',
    technical: 'LOCAL-SIGN-DETAIL',
  ),
  JourneyStop(
    icon: Icons.shield_outlined,
    label: 'Privacy',
    plainStatus: 'direct',
    technical: 'ROUTE-DETAIL',
  ),
  JourneyStop(
    icon: Icons.dns_outlined,
    label: 'Node',
    plainStatus: 'node.example',
    technical: 'NODE-DETAIL',
  ),
  JourneyStop(
    icon: Icons.link,
    label: 'Network',
    plainStatus: 'in a block',
    technical: 'CHAIN-DETAIL',
  ),
  JourneyStop(
    icon: Icons.check_circle_outline,
    label: 'Done',
    plainStatus: 'waiting',
    technical: 'DONE-DETAIL',
  ),
];

void main() {
  testWidgets('journey map shows five stops in order (spec §10b)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyMap(
            stops: _stops(),
            states: const [
              JourneyState.ok,
              JourneyState.ok,
              JourneyState.working,
              JourneyState.waiting,
              JourneyState.waiting,
            ],
          ),
        ),
      ),
    );
    expect(find.text('My phone'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Node'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('working'), findsOneWidget);
    expect(find.text('waiting'), findsNWidgets(2));
  });

  testWidgets('reduce motion behaves like Lite mode (spec §10b)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: JourneyMap(
              stops: _stops(),
              states: const [
                JourneyState.ok,
                JourneyState.ok,
                JourneyState.working,
                JourneyState.waiting,
                JourneyState.waiting,
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Static arrow + progress bar instead of the endless pulse.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(JourneyMap),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(find.text('working'), findsOneWidget);
  });

  testWidgets('tapping a stop opens its own detail card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyMap(
            stops: _stops(),
            states: const [
              JourneyState.ok,
              JourneyState.ok,
              JourneyState.ok,
              JourneyState.working,
              JourneyState.waiting,
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Node'));
    // The working stop is a deliberately endless pulse, so pump a fixed
    // number of frames instead of waiting for "no animations".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('More — technical details'), findsOneWidget);
    expect(find.text('NODE-DETAIL'), findsOneWidget);
    // A card only ever shows its own stop's detail.
    expect(find.text('CHAIN-DETAIL'), findsNothing);
  });
}
