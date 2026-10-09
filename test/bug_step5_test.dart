import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/reports_screen.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('Step 5 - ReportsScreen should have a back button on Desktop if canPop', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    
    final fakeDb = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeDb);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
                child: const Text('Vai ai Report'),
              ),
            ),
          ),
        ),
      )
    );

    await tester.tap(find.text('Vai ai Report'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportsScreen), findsOneWidget);

    final backButton = find.byIcon(Icons.arrow_back);
    
    expect(backButton, findsOneWidget, reason: 'Il back button deve essere presente se canPop e true.');
  });
}
