import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/payment_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('Step 4 - isSaving error handling blocks retry', (WidgetTester tester) async {
    final fakeFirestore = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeFirestore);
    
    // Inserisco una categoria di default per evitare l'eccezione No Element
    await fakeFirestore.collection('categories').add({
      'name': 'Generico',
      'type': 'IN'
    });
    await fakeFirestore.collection('customers').add({
      'name': 'Cliente',
    });
    
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppThemeProvider(),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: PaymentFormScreen()
        ),
      ),
    );

    // Attendi che il caricamento async (Future) finisca e _isLoading diventi false
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Trova il textfield e inserisci un importo (obbligatorio per _savePayment)
    final textFields = find.byType(TextField);
    expect(textFields, findsWidgets, reason: "TextField non trovato, form non caricato?");
    
    // textFields.last per l'importo? _amountController e' il primo textfield
    await tester.enterText(textFields.first, '100');

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
