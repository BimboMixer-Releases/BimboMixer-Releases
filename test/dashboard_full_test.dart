import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('Dashboard Completa Test: no RenderFlex overflow on narrow 320px screens', (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final fakeFirestore = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeFirestore);

    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;

    bool overflowOccurred = false;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        overflowOccurred = true;
      }
      if (originalOnError != null) {
        originalOnError(details);
      }
    };
    
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            drawer: Drawer(child: Text('DUMMY MAIN DRAWER')),
            body: DashboardScreen(role: 'admin'),
          ),
        ),
      ),
    );

    for(int i = 0; i < 5; i++) {
       await tester.pump(const Duration(milliseconds: 100));
    }

    expect(overflowOccurred, isFalse, reason: "Il RenderFlex overflow non deve piu verificarsi");

    final menuIcon = find.byIcon(Icons.menu);
    expect(menuIcon, findsOneWidget);
    await tester.tap(menuIcon);
    
    for(int i = 0; i < 5; i++) {
       await tester.pump(const Duration(milliseconds: 100));
    }
    
    expect(find.text('DUMMY MAIN DRAWER'), findsOneWidget);
    
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });
}
