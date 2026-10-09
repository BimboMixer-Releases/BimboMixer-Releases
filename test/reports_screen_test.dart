import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/reports_screen.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('ReportsScreen shows Back button and pops if canPop is true', (tester) async {
    final fakeDb = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeDb);
    
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
                child: const Text('Go to Reports'),
              ),
            ),
          ),
        ),
      ),
    );
    
    await tester.tap(find.text('Go to Reports'));
    await tester.pumpAndSettle();
    
    expect(find.byType(ReportsScreen), findsOneWidget);
    
    final backButton = find.byIcon(Icons.arrow_back);
    expect(backButton, findsOneWidget, reason: 'Il pulsante indietro deve essere presente');
    
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    
    expect(find.byType(ReportsScreen), findsNothing, reason: 'La navigazione deve tornare indietro');
  });
}
