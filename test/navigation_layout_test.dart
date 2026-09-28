import 'package:contabile_app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Long dashboard title has bounded height on narrow screens', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
      SizedBox(width: 120, child: AutoScrollText(text: 'BIMBOMIXER CONTABILITÀ 2026', style: TextStyle(fontSize: 16))),
    ]))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
