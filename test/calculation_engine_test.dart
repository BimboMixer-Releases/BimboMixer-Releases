import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/calculation_engine.dart';

void main() {
  group('CalculationEngine Tests', () {
    test('computePercentageChange handles division by zero', () {
      expect(CalculationEngine.computePercentageChange(100.0, 0.0), 'N/D');
      expect(CalculationEngine.computePercentageChange(0.0, 0.0), '0%');
    });

    test('computePercentageChange calculates correctly', () {
      expect(CalculationEngine.computePercentageChange(150.0, 100.0), '+50.0%');
      expect(CalculationEngine.computePercentageChange(50.0, 100.0), '-50.0%');
      expect(CalculationEngine.computePercentageChange(100.0, 100.0), '0.0%');
    });

    test('computeDashboardMetrics processes standard inputs correctly', () {
      final payments = [
        {'amount': 100.0, 'date': '2026-01-15', 'type': 'IN', 'category_id': 'c1', 'service_id': 's1', 'payment_method': 'bonifico'},
        {'amount': 50.0, 'date': '2026-02-10', 'type': 'OUT', 'category_id': 'c2', 'service_id': 's2', 'payment_method': 'contante'},
      ];

      final invoices = [
        {'id': 'inv1', 'amount': 200.0, 'date': '2026-03-01', 'status': 'PAID'}, // Should be added to IN
        {'id': 'inv2', 'amount': 300.0, 'date': '2026-04-01', 'status': 'DRAFT'}, // Ignored
      ];

      final deadlines = [
        {'amount': 30.0, 'date': '2026-05-01', 'status': 'PAID'},
        {'amount': 20.0, 'date': '2026-06-01', 'status': 'PENDING'}, // Ignored
      ];

      final categories = {'c1': 'Cat 1', 'c2': 'Cat 2'};
      final services = {'s1': 'Serv 1', 's2': 'Serv 2'};

      final metrics = CalculationEngine.computeDashboardMetrics(
        payments: payments,
        paymentsLastYear: [],
        invoices: invoices,
        deadlines: deadlines,
        categoryNames: categories,
        serviceNames: services,
        selectedYear: 2026,
      );

      // totalIn = 100 (payment IN) + 200 (invoice PAID) = 300
      expect(metrics.totalIn, 300.0);
      
      // totalOut = 50 (payment OUT)
      expect(metrics.totalOut, 50.0);

      // totalDeadlinesPaid = 30
      expect(metrics.totalDeadlinesPaid, 30.0);

      // patrimonio = 300 - 50 - 30 = 220
      expect(metrics.patrimonio, 220.0);

      // margine = ((300 - 50) / 300) * 100 = 83.33
      expect(metrics.margine, closeTo(83.33, 0.01));
    });

    test('computeDashboardMetrics prevents double counting of paid invoices', () {
      final payments = [
        // Payment that pays invoice 'inv1'
        {'amount': 150.0, 'date': '2026-01-15', 'type': 'IN', 'invoice_id': 'inv1', 'payment_method': 'bonifico'},
      ];

      final invoices = [
        // Invoice 'inv1' is PAID. It should NOT be double counted because it's linked in the payment above.
        {'id': 'inv1', 'amount': 150.0, 'date': '2026-01-10', 'status': 'PAID'}, 
      ];

      final metrics = CalculationEngine.computeDashboardMetrics(
        payments: payments,
        paymentsLastYear: [],
        invoices: invoices,
        deadlines: [],
        categoryNames: {},
        serviceNames: {},
        selectedYear: 2026,
      );

      // totalIn should just be 150.0 once.
      expect(metrics.totalIn, 150.0);
    });
  });
}
