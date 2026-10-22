import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/widgets/hold_to_confirm.dart';

void main() {
  testWidgets('signing fires only after the full hold (spec §9)', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: HoldToConfirm(
                label: 'Hold to sign',
                duration: const Duration(milliseconds: 500),
                onConfirmed: () => fired++,
              ),
            ),
          ),
        ),
      ),
    );

    // A short tap must not sign anything.
    final tap = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirm)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tap.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(fired, 0);

    // Releasing early drains the fill and also does not sign.
    final early = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirm)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await early.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fired, 0);

    // A complete hold signs exactly once, even if the pointer stays down.
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirm)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await hold.up();
    await tester.pump();
    expect(fired, 1);
  });
}
