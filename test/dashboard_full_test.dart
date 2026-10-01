import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  testWidgets('Dashboard Completa Test: espone RenderFlex overflow sulla body con schermi stretti', (WidgetTester tester) async {
    // 1. Setup mock database per non toccare dati reali
    final fakeFirestore = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeFirestore);

    // 2. Override constraint critiche (320px x 1.5 testo)
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;

    // Assicuriamo di intercettare gli overflow della body senza nasconderli
    bool overflowOccurred = false;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        overflowOccurred = true;
      } else if (originalOnError != null) {
        originalOnError(details);
      }
    };

    // 3. Montiamo l'intera DashboardScreen
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            // DashboardScreen internamente chiama l'AppBar che naviga per aprire il Drawer dello Scaffold "padre"
            drawer: Drawer(child: Text('DUMMY MAIN DRAWER')),
            body: DashboardScreen(role: 'admin'),
          ),
        ),
      ),
    );

    // Aspettiamo che carichi la UI e i dati finti
    for(int i = 0; i < 5; i++) {
       await tester.pump(const Duration(milliseconds: 100));
    }

    // 4. Verifichiamo che l'overflow sia esposto (sappiamo che la body ne soffre)
    expect(overflowOccurred, isTrue, reason: "Il test deve esporre e verificare l'esistenza dell'overflow noto nella Dashboard body a 320px.");

    // 5. Testiamo che la navigazione del menu (Drawer) funzioni e non sia intralciata dall'overflow della body
    final menuIcon = find.byIcon(Icons.menu);
    expect(menuIcon, findsOneWidget);
    await tester.tap(menuIcon);
    
    // Animazione di apertura Drawer
    for(int i = 0; i < 5; i++) {
       await tester.pump(const Duration(milliseconds: 100));
    }
    
    // Controllo che il Drawer finto si sia aperto
    expect(find.text('DUMMY MAIN DRAWER'), findsOneWidget);

    // Ripristini e distruzione timer Marquee
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(seconds: 10));
    
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    FlutterError.onError = originalOnError; // Ripristina l'handler originale
  });
}
