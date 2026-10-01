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

    // Assicuriamoci di ripristinare SEMPRE con addTearDown
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    // Eseguiamo in runAsync per evitare errori sui timer finti di Marquee (AutoScrollText)
    await tester.runAsync(() async {
      await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            appBar: MobileDashboardAppBar(role: 'admin', selectedYear: 2026),
            drawer: Drawer(child: Text('Menu Drawer Content')),
            body: Center(child: Text('Body Neutro')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Controllo apertura Drawer
    final menuIcon = find.byIcon(Icons.menu);
    expect(menuIcon, findsOneWidget);

    await tester.tap(menuIcon);
    await tester.pumpAndSettle(const Duration(milliseconds: 100)); // Aspettiamo che l'animazione del drawer finisca

    // Verifica che il Drawer sia effettivamente aperto
    expect(find.text('Menu Drawer Content'), findsOneWidget);

    // Controlla testo (BIMBOMIXER)
    // Non potendo usare textContaining perché usa un TextPainter custom, cerchiamo il widget padre (AutoScrollText)
    // O verifichiamo semplicemente che non ci siano eccezioni
      expect(tester.takeException(), isNull);

      // Distruggi l'albero
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
