import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/calculation_engine.dart';

void main() {
  Map<String, dynamic> makePayment({
    required double amount,
    required String date,
    required String type,
    String? invoiceId,
    String? customerId,
    String? customerName,
    String paymentMethod = 'Fattura',
  }) {
    final map = <String, dynamic>{
      'amount': amount,
      'date': date,
      'type': type,
      'category_id': 'cat1',
      'service_id': 'srv1',
      'payment_method': paymentMethod,
    };
    if (invoiceId != null) map['invoice_id'] = invoiceId;
    if (customerId != null) map['customer_id'] = customerId;
    if (customerName != null) map['customer_name'] = customerName;
    return map;
  }

  Map<String, dynamic> makeInvoice({
    required String id,
    required double amount,
    required String date,
    String? number,
    String? customerId,
    String? clientName,
    String status = 'PAID',
    String type = 'IN',
  }) {
    final map = <String, dynamic>{
      'id': id,
      'amount': amount,
      'date': date,
      'status': status,
      'type': type,
    };
    if (number != null) map['number'] = number;
    if (customerId != null) map['customer_id'] = customerId;
    if (clientName != null) map['client_name'] = clientName;
    return map;
  }

  group('Grafico a torta Fatturato vs Contante & Deduplicazione', () {
    test('OUT (uscite) non vengono incluse in Fatturato o Contante', () {
      final payments = [
        makePayment(amount: 1000, date: '2026-03-01', type: 'IN', paymentMethod: 'Fattura'),
        makePayment(amount: 400, date: '2026-03-05', type: 'IN', paymentMethod: 'Contante'),
        makePayment(amount: 300, date: '2026-03-10', type: 'OUT', paymentMethod: 'Contante'),
        makePayment(amount: 200, date: '2026-03-12', type: 'OUT', paymentMethod: 'Bonifico'),
      ];
      final m = CalculationEngine.computeDashboardMetrics(
        payments: payments,
        paymentsLastYear: [],
        invoices: [],
        deadlines: [],
        scheduledPayments: [],
        scheduledPaymentsLastYear: [],
        categoryNames: {},
        serviceNames: {},
        selectedYear: 2026,
      );

      // Entrate totali: 1000 + 400 = 1400
      expect(m.totalIn, 1400.0);
      expect(m.totalOut, 500.0);

      // Il grafico a torta deve riflettere esclusivamente quanto guadagnato (1400.0)
      expect(m.paymentMethodBreakdown['Fatturato'], 1000.0);
      expect(m.paymentMethodBreakdown['Contante'], 400.0);

      final sumBreakdown = (m.paymentMethodBreakdown['Fatturato'] ?? 0.0) +
          (m.paymentMethodBreakdown['Contante'] ?? 0.0);
      expect(sumBreakdown, m.totalIn);
    });

    test('Tracking incrociato: fattura e movimento corrispondenti non vengono duplicati', () {
      final payments = [
        makePayment(
          amount: 850.0,
          date: '2026-05-10',
          type: 'IN',
          customerId: 'cust-mario',
          customerName: 'Mario Rossi',
          paymentMethod: 'Fattura',
        ),
        makePayment(
          amount: 150.0,
          date: '2026-05-12',
          type: 'IN',
          paymentMethod: 'Contante',
        ),
      ];
      // Fattura corrispondente al movimento PAY-1 (stesso cliente, stesso importo, stesso mese/anno)
      final invoices = [
        makeInvoice(
          id: 'INV-100',
          number: '15/2026',
          amount: 850.0,
          date: '2026-05-10',
          customerId: 'cust-mario',
          clientName: 'Mario Rossi',
          status: 'PAID',
        ),
      ];

      final m = CalculationEngine.computeDashboardMetrics(
        payments: payments,
        paymentsLastYear: [],
        invoices: invoices,
        deadlines: [],
        scheduledPayments: [],
        scheduledPaymentsLastYear: [],
        categoryNames: {},
        serviceNames: {},
        selectedYear: 2026,
      );

      // Senza deduplicazione il totale sarebbe 850 + 850 + 150 = 1850.
      // Con deduplicazione corretta è esattamente 850 + 150 = 1000.
      expect(m.totalIn, 1000.0);
      expect(m.paymentMethodBreakdown['Fatturato'], 850.0);
      expect(m.paymentMethodBreakdown['Contante'], 150.0);
      expect((m.paymentMethodBreakdown['Fatturato'] ?? 0.0) + (m.paymentMethodBreakdown['Contante'] ?? 0.0), m.totalIn);
    });

    test('Fattura non ancora saldata o fattura passiva OUT non gonfia il Fatturato', () {
      final invoices = [
        makeInvoice(
          id: 'INV-OUT',
          amount: 500.0,
          date: '2026-06-01',
          status: 'PAID',
          type: 'OUT',
        ),
        makeInvoice(
          id: 'INV-PENDING',
          amount: 1200.0,
          date: '2026-06-01',
          status: 'PENDING',
          type: 'IN',
        ),
      ];

      final m = CalculationEngine.computeDashboardMetrics(
        payments: [],
        paymentsLastYear: [],
        invoices: invoices,
        deadlines: [],
        scheduledPayments: [],
        scheduledPaymentsLastYear: [],
        categoryNames: {},
        serviceNames: {},
        selectedYear: 2026,
      );

      expect(m.totalIn, 0.0);
      expect(m.paymentMethodBreakdown['Fatturato'], isNull);
      expect(m.paymentMethodBreakdown['Contante'], isNull);
    });

    test('isDeadlineSettled identifica scadenze pagate/saldate ed esclude da scadenze in arrivo', () {
      final deadlines = [
        {'id': '1', 'title': 'Affitto', 'amount': 600, 'status': 'PAID'},
        {'id': '2', 'title': 'Fornitore Luce', 'amount': 250, 'status': 'SALDATO'},
        {'id': '3', 'title': 'Fornitore Gas', 'amount': 180, 'status': 'pagato'},
        {'id': '4', 'title': 'Tassa Rifiuti', 'amount': 120, 'status': 'PENDING'},
        {'id': '5', 'title': 'Commercialista', 'amount': 300, 'status': ''},
      ];

      final upcoming = deadlines.where((d) => !CalculationEngine.isDeadlineSettled(d)).toList();

      expect(upcoming.length, 2);
      expect(upcoming.map((d) => d['id']).toList(), ['4', '5']);
    });
  });
}
