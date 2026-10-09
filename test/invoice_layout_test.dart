import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/invoice_summary_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('Invoice layout avoids RenderFlex overflow on narrow screens', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeFirestore = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeFirestore);
    
    await fakeFirestore.collection('invoices').doc('FATT-100').set({
      'number': 'FATT-100',
      'date': '2024-10-01',
      'customer_id': 'cust1',
      'amount': 1500.00,
      'status': 'PAID',
      'items': [
        {'name': 'Servizio A', 'qty': '1', 'price': 500.0, 'total': 500.0},
        {'name': 'Servizio B', 'qty': '2', 'price': 500.0, 'total': 1000.0},
      ],
      'notes': 'Test notes',
    });
    
    await fakeFirestore.collection('customers').doc('cust1').set({
      'id': 'cust1',
      'name': 'Mario Rossi',
    });
    
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InvoiceSummaryScreen(
            invoiceId: 'FATT-100',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('FATT-100'), findsWidgets);
    expect(find.textContaining('1.500,00'), findsWidgets);
  });
}
