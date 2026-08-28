import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:contabile_app/models/dashboard_metrics.dart';

void main() {
  group('CalculationEngine Tests', () {
    test('computeDashboardMetrics should handle empty lists', () {
      final metrics = CalculationEngine.computeDashboardMetrics(
        payments: [],
        paymentsLastYear: [],
        invoices: [],
        deadlines: [],
        categoryNames: {},
        serviceNames: {},
        selectedYear: 2026,
      );

      expect(metrics.totalIn, 0.0);
      expect(metrics.totalOut, 0.0);
      expect(metrics.patrimonio, 0.0);
      expect(metrics.margine, 0.0);
      expect(metrics.totalDeadlinesPaid, 0.0);
    });

    test('computeDashboardMetrics should prevent double counting of paid invoices and payments', () {
      final payments = [
        {'amount': 1000.0, 'date': '2026-05-10', 'type': 'IN', 'invoice_id': 'INV-001', 'category_id': 'cat1', 'service_id': 'srv1'},
        {'amount': 500.0, 'date': '2026-05-11', 'type': 'IN', 'category_id': 'cat2', 'service_id': 'srv2'},
        {'amount': 200.0, 'date': '2026-06-15', 'type': 'OUT', 'category_id': 'cat3', 'service_id': 'srv1'},
      ];

      final invoices = [
        {'id': 'INV-001', 'amount': 1000.0, 'date': '2026-05-10', 'status': 'PAID'}, // Already in payments!
        {'id': 'INV-002', 'amount': 300.0, 'date': '2026-07-20', 'status': 'PAID'}, // Not in payments
      ];

      final deadlines = [
        {'amount': 100.0, 'date': '2026-08-01', 'status': 'PAID'},
      ];

      final metrics = CalculationEngine.computeDashboardMetrics(
        payments: payments,
        paymentsLastYear: [],
        invoices: invoices,
        deadlines: deadlines,
        categoryNames: {'cat1': 'Cat1'},
        serviceNames: {'srv1': 'Srv1'},
        selectedYear: 2026,
      );

      // Total IN should be 1000 (payment 1) + 500 (payment 2) + 300 (invoice 2, not double counted) = 1800
      expect(metrics.totalIn, 1800.0);
      
      // Total OUT should be 200
      expect(metrics.totalOut, 200.0);

      // Total Deadlines Paid = 100
      expect(metrics.totalDeadlinesPaid, 100.0);

      // Patrimonio = IN (1800) - OUT (200) - Deadlines (100) = 1500
      expect(metrics.patrimonio, 1500.0);
    });
  });
}
