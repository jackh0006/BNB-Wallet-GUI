import 'dart:io';

import 'package:bnb_wallet_gui/screens/donations_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every displayed donation address matches DONATE.md exactly', () {
    final text = File('DONATE.md').readAsStringSync();
    final published = RegExp(r'`([^`]+)`')
        .allMatches(text)
        .map((match) => match.group(1)!)
        .where((value) => value.length >= 26 && !value.contains(' '))
        .toSet();
    final displayed = donationAddresses.map((item) => item.address).toSet();
    expect(displayed, published);
    expect(donationAddresses.length, 14);
  });

  testWidgets('dialog lists each address with copy and QR controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDonationsDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Project donations'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(14));
    expect(find.byIcon(Icons.copy), findsNWidgets(14));
    expect(find.byIcon(Icons.qr_code), findsNWidgets(14));
    expect(
      find.textContaining('never appears in a transaction confirmation'),
      findsOneWidget,
    );
  });
}
