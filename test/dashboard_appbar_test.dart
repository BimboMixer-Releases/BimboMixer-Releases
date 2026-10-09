import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';

void main() {
  testWidgets('Dashboard Mobile AppBar Test: layout stretto, testo ingrandito e Drawer', (WidgetTester tester) async {
    // Override platform e dimensioni
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;

    // Ripristini
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: MobileDashboardAppBar(role: 'admin', selectedYear: 2026),
            drawer: Drawer(child: Text('Menu Drawer Content')),
            body: Center(child: Text('Body Neutro')),
          ),
        ),
      ),
    );

    // NON USARE pumpAndSettle! L'appBar contiene AutoScrollText (Marquee) che non si ferma mai.
    // Usiamo pump manuali per evitare timeout.
    await tester.pump(const Duration(milliseconds: 100));

    // Controllo apertura Drawer
    final menuIcon = find.byIcon(Icons.menu);
    expect(menuIcon, findsOneWidget);

    await tester.tap(menuIcon);
    
    // Avanziamo il tempo manualmente per l'animazione del Drawer (invece di pumpAndSettle)
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verifica che il Drawer sia aperto
    expect(find.text('Menu Drawer Content'), findsOneWidget);

    // Nessuna eccezione fino a qui (incluso overflow)
    expect(tester.takeException(), isNull);

    // Per prevenire "A Timer is still pending" causato dal Marquee:
    // 1. Rimpiazziamo l'albero per chiamare il dispose() di Marquee
    await tester.pumpWidget(Container());
    // 2. Facciamo avanzare il tempo per consumare i timer orfani nella coda di fake_async
    await tester.pump(const Duration(seconds: 10));

    debugDefaultTargetPlatformOverride = null;
  });
}

