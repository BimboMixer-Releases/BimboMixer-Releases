import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:contabile_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Financial Scenarios Integration Tests', () {
    testWidgets('App starts and Dashboard loads without crashing', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // We expect to find the "PATRIMONIO NETTO" text on the dashboard
      expect(find.text('PATRIMONIO NETTO'), findsWidgets);
    });
  });
}
