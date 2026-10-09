import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/quotes_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('Quotes list scrolls properly and avoids overflow', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeFirestore = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeFirestore);
    
    for (int i = 0; i < 20; i++) {
      String numStr = i.toString().padLeft(4, '0');
      await fakeFirestore.collection('quotes').doc('PREV-$numStr').set({
        'code': 'PREV-$numStr',
        'serial_number': i + 1,
        'date': '2024-10-01',
        'customer_id': 'cust1',
        'total': 1500.00,
        'status': 'DRAFT',
      });
    }
    
    await fakeFirestore.collection('customers').doc('cust1').set({
      'id': 'cust1',
      'name': 'Mario Rossi',
    });
    
    final snapshot = await fakeFirestore.collection('quotes').get();
    expect(snapshot.docs.length, 20);
    
    tester.view.physicalSize = const Size(390 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuotesScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('PREV-0019'), findsWidgets);
    
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    
    final targetQuoteFinder = find.textContaining('PREV-0000');
    
    bool found = false;
    for (int i = 0; i < 30; i++) {
      if (tester.any(targetQuoteFinder.hitTestable())) {
        found = true;
        break;
      }
      await tester.dragFrom(const Offset(150, 600), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(found, true, reason: 'PREV-0000 should be hitTestable after scrolling');
    
    expect(targetQuoteFinder.hitTestable(), findsWidgets);
    
    await tester.tap(targetQuoteFinder.hitTestable().first);
    await tester.pumpAndSettle();
    
    final dialogFinder = find.byType(Dialog);
    expect(dialogFinder, findsWidgets);
    expect(find.descendant(of: dialogFinder, matching: find.textContaining('PREV-0000')), findsWidgets);
  });
}
