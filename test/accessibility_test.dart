import 'package:bnb_wallet_gui/widgets/hold_to_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('hold-to-confirm exposes a label and a keyboard hold', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var confirmed = false;
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _host(
        HoldToConfirm(
          label: 'Sign transaction',
          duration: const Duration(milliseconds: 120),
          focusNode: focus,
          autofocus: true,
          onConfirmed: () => confirmed = true,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(HoldToConfirm)).label,
      contains('Press and hold'),
    );

    focus.requestFocus();
    FocusScope.of(tester.element(find.byType(HoldToConfirm)))
        .requestFocus(focus);
    await tester.pump();
    expect(focus.context, isNotNull);
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(confirmed, isTrue);
    semantics.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('an early key release does not confirm', (tester) async {
    var confirmed = false;
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _host(
        HoldToConfirm(
          label: 'Sign transaction',
          duration: const Duration(milliseconds: 500),
          focusNode: focus,
          onConfirmed: () => confirmed = true,
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 600));
    expect(confirmed, isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('200% text scale does not overflow the confirmation widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 360,
          child: HoldToConfirm(
            label: 'Sign a transaction with a long label',
            onConfirmed: _noop,
          ),
        ),
        textScale: 2.0,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('press and hold'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

void _noop() {}
