import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/calculation_engine.dart';

void main() {
  // Helper per creare un pagamento
  Map<String, dynamic> makePayment({
    required double amount,
    required String date,
    required String type,
    String? invoiceId,
    String? categoryId,
    String? serviceId,
    String paymentMethod = 'Fattura',
  }) {
    return {
      'amount': amount,
      'date': date,
      'type': type,
      if (invoiceId != null) 'invoice_id': invoiceId,
      'category_id': categoryId ?? 'cat1',
      'service_id': serviceId ?? 'srv1',
      'payment_method': paymentMethod,
    };
  }

  // Helper per creare una fattura
  Map<String, dynamic> makeInvoice({
    required String id,
    required double amount,
    required String date,
    String status = 'PAID',
  }) {
    return {'id': id, 'amount': amount, 'date': date, 'status': status};
  }

  // Helper per creare una scadenza
  Map<String, dynamic> makeDeadline({
    required double amount,
    required String date,
    String status = 'PAID',
  }) {
    return {'amount': amount, 'date': date, 'status': status};
  }

  group('CalculationEngine.computeDashboardMetrics', () {
    // ─── CASI BASE ───
    group('casi base', () {
      test('liste vuote producono metriche a zero', () {
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [],
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 0.0);
        expect(m.totalOut, 0.0);
        expect(m.patrimonio, 0.0);
        expect(m.margine, 0.0);
        expect(m.totalDeadlinesPaid, 0.0);
        expect(m.categoryBreakdown, isEmpty);
        expect(m.serviceBreakdown, isEmpty);
        expect(m.paymentMethodBreakdown, isEmpty);
      });

      test('un singolo incasso', () {
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [makePayment(amount: 1000, date: '2026-03-15', type: 'IN')],
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {'cat1': 'Consulenza'},
          serviceNames: {'srv1': 'Web Dev'},
          selectedYear: 2026,
        );
        expect(m.totalIn, 1000.0);
        expect(m.totalOut, 0.0);
        expect(m.patrimonio, 1000.0);
        expect(m.margine, 100.0);
      });

      test('un singolo pagamento in uscita', () {
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [makePayment(amount: 300, date: '2026-04-10', type: 'OUT')],
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 0.0);
        expect(m.totalOut, 300.0);
        expect(m.patrimonio, -300.0);
        expect(m.margine, 0.0);
      });
    });

    // ─── DOPPIO CONTEGGIO ───
    group('prevenzione doppio conteggio', () {
      test('fattura PAID con pagamento associato non viene contata due volte', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-05-10', type: 'IN', invoiceId: 'INV-001'),
          makePayment(amount: 500, date: '2026-05-11', type: 'IN'),
        ];
        final invoices = [
          makeInvoice(id: 'INV-001', amount: 1000, date: '2026-05-10'),
          makeInvoice(id: 'INV-002', amount: 300, date: '2026-07-20'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        // IN = 1000 (payment) + 500 (payment) + 300 (invoice INV-002 non duplicata) = 1800
        expect(m.totalIn, 1800.0);
      });

      test('fattura PAID senza pagamento associato viene correttamente conteggiata', () {
        final invoices = [
          makeInvoice(id: 'INV-SOLO', amount: 750, date: '2026-06-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [],
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 750.0);
      });

      test('fattura NON PAID viene ignorata', () {
        final invoices = [
          makeInvoice(id: 'INV-PENDING', amount: 500, date: '2026-01-15', status: 'PENDING'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [],
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 0.0);
      });

      test('multiple fatture duplicate: solo quelle senza payment vengono aggiunte', () {
        final payments = [
          makePayment(amount: 500, date: '2026-02-01', type: 'IN', invoiceId: 'INV-A'),
          makePayment(amount: 800, date: '2026-03-01', type: 'IN', invoiceId: 'INV-B'),
        ];
        final invoices = [
          makeInvoice(id: 'INV-A', amount: 500, date: '2026-02-01'),
          makeInvoice(id: 'INV-B', amount: 800, date: '2026-03-01'),
          makeInvoice(id: 'INV-C', amount: 200, date: '2026-04-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        // 500 + 800 (dai payments) + 200 (INV-C non duplicata) = 1500
        expect(m.totalIn, 1500.0);
      });
    });

    // ─── FILTRO PER ANNO ───
    group('filtro per anno', () {
      test('pagamenti di anni diversi vengono esclusi', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-06-15', type: 'IN'),
          makePayment(amount: 500, date: '2025-06-15', type: 'IN'),
          makePayment(amount: 200, date: '2027-01-01', type: 'IN'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 1000.0);
      });

      test('fatture di anni diversi vengono escluse', () {
        final invoices = [
          makeInvoice(id: 'I1', amount: 1000, date: '2026-06-01'),
          makeInvoice(id: 'I2', amount: 500, date: '2025-06-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [],
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 1000.0);
      });

      test('scadenze di anni diversi vengono escluse', () {
        final deadlines = [
          makeDeadline(amount: 100, date: '2026-08-01'),
          makeDeadline(amount: 200, date: '2025-08-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [],
          paymentsLastYear: [],
          invoices: [],
          deadlines: deadlines,
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalDeadlinesPaid, 100.0);
      });
    });

    // ─── SCADENZE ───
    group('scadenze (deadlines)', () {
      test('scadenze PAID riducono il patrimonio', () {
        final payments = [
          makePayment(amount: 5000, date: '2026-01-10', type: 'IN'),
        ];
        final deadlines = [
          makeDeadline(amount: 1000, date: '2026-03-01'),
          makeDeadline(amount: 500, date: '2026-06-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: deadlines,
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalDeadlinesPaid, 1500.0);
        // patrimonio = IN (5000) - OUT (0) - deadlines (1500) = 3500
        expect(m.patrimonio, 3500.0);
      });

      test('scadenze NON PAID vengono ignorate', () {
        final deadlines = [
          makeDeadline(amount: 1000, date: '2026-03-01', status: 'PENDING'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: [],
          paymentsLastYear: [],
          invoices: [],
          deadlines: deadlines,
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalDeadlinesPaid, 0.0);
      });
    });

    // ─── RIPARTIZIONE MENSILE ───
    group('ripartizione mensile', () {
      test('incassi e uscite vengono assegnati al mese corretto', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-01-15', type: 'IN'),
          makePayment(amount: 300, date: '2026-01-20', type: 'OUT'),
          makePayment(amount: 500, date: '2026-06-10', type: 'IN'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.monthlyNet[1], 700.0); // gennaio: 1000 - 300
        expect(m.monthlyNet[6], 500.0); // giugno: 500
        expect(m.monthlyNet[12], 0.0);  // dicembre: 0
      });
    });

    // ─── BREAKDOWN CATEGORIE E SERVIZI ───
    group('breakdown categorie e servizi', () {
      test('gli importi vengono ripartiti per categoria', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-02-01', type: 'IN', categoryId: 'cat-a'),
          makePayment(amount: 500, date: '2026-02-15', type: 'IN', categoryId: 'cat-a'),
          makePayment(amount: 200, date: '2026-03-01', type: 'OUT', categoryId: 'cat-b'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {'cat-a': 'Consulenza', 'cat-b': 'Materiali'},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.categoryBreakdown['Consulenza'], 1500.0);
        expect(m.categoryBreakdown['Materiali'], 200.0);
      });

      test('gli importi vengono ripartiti per servizio', () {
        final payments = [
          makePayment(amount: 800, date: '2026-04-01', type: 'IN', serviceId: 'srv-web'),
          makePayment(amount: 400, date: '2026-04-15', type: 'IN', serviceId: 'srv-design'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {'srv-web': 'Web Dev', 'srv-design': 'Design'},
          selectedYear: 2026,
        );
        expect(m.serviceBreakdown['Web Dev'], 800.0);
        expect(m.serviceBreakdown['Design'], 400.0);
      });

      test('categorie/servizi mancanti usano Altro come fallback', () {
        final payments = [
          makePayment(amount: 100, date: '2026-05-01', type: 'IN', categoryId: 'unknown', serviceId: 'unknown'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.categoryBreakdown['Altro'], 100.0);
        expect(m.serviceBreakdown['Altro'], 100.0);
      });
    });

    // ─── FATTURATO VS CONTANTE ───
    group('ripartizione fatturato vs contante', () {
      test('pagamento in contanti va nel bucket Contante', () {
        final payments = [
          makePayment(amount: 500, date: '2026-01-10', type: 'IN', paymentMethod: 'Contante'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.paymentMethodBreakdown['Contante'], 500.0);
        expect(m.paymentMethodBreakdown['Fatturato'], isNull);
      });

      test('pagamento con fattura va nel bucket Fatturato', () {
        final payments = [
          makePayment(amount: 800, date: '2026-02-10', type: 'IN', paymentMethod: 'Fattura'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.paymentMethodBreakdown['Fatturato'], 800.0);
        expect(m.paymentMethodBreakdown['Contante'], isNull);
      });

      test('mix di contanti e fatture', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-03-01', type: 'IN', paymentMethod: 'Fattura'),
          makePayment(amount: 300, date: '2026-03-15', type: 'IN', paymentMethod: 'Contante'),
        ];
        final invoices = [
          makeInvoice(id: 'INV-MIX', amount: 500, date: '2026-04-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        // Fatturato: 1000 (payment) + 500 (invoice) = 1500
        expect(m.paymentMethodBreakdown['Fatturato'], 1500.0);
        expect(m.paymentMethodBreakdown['Contante'], 300.0);
      });
    });

    // ─── MARGINE ───
    group('calcolo margine', () {
      test('margine al 100% quando non ci sono uscite', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-01-01', type: 'IN'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.margine, 100.0);
      });

      test('margine al 50% quando uscite sono meta degli incassi', () {
        final payments = [
          makePayment(amount: 1000, date: '2026-01-01', type: 'IN'),
          makePayment(amount: 500, date: '2026-02-01', type: 'OUT'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.margine, 50.0);
      });

      test('margine a 0% quando non ci sono incassi', () {
        final payments = [
          makePayment(amount: 500, date: '2026-01-01', type: 'OUT'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.margine, 0.0);
      });
    });

    // ─── FORMULA PATRIMONIO COMPLETA ───
    group('patrimonio formula completa', () {
      test('patrimonio = IN - OUT - deadlines', () {
        final payments = [
          makePayment(amount: 10000, date: '2026-01-01', type: 'IN'),
          makePayment(amount: 2000, date: '2026-02-01', type: 'OUT'),
        ];
        final invoices = [
          makeInvoice(id: 'I1', amount: 3000, date: '2026-03-01'),
        ];
        final deadlines = [
          makeDeadline(amount: 1500, date: '2026-06-01'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: invoices,
          deadlines: deadlines,
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        // IN = 10000 + 3000 = 13000
        // OUT = 2000
        // Deadlines = 1500
        // Patrimonio = 13000 - 2000 - 1500 = 9500
        expect(m.totalIn, 13000.0);
        expect(m.totalOut, 2000.0);
        expect(m.totalDeadlinesPaid, 1500.0);
        expect(m.patrimonio, 9500.0);
      });
    });

    // ─── EDGE CASES ───
    group('edge cases', () {
      test('pagamento con importo zero viene ignorato', () {
        final payments = [
          makePayment(amount: 0, date: '2026-01-01', type: 'IN'),
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 0.0);
      });

      test('pagamento con data vuota viene ignorato', () {
        final payments = [
          {'amount': 1000.0, 'date': '', 'type': 'IN', 'category_id': 'c1', 'service_id': 's1', 'payment_method': 'Fattura'},
        ];
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 0.0);
      });

      test('molti pagamenti piccoli non perdono centesimi', () {
        final payments = List.generate(100, (i) =>
          makePayment(amount: 0.01, date: '2026-01-15', type: 'IN'),
        );
        final m = CalculationEngine.computeDashboardMetrics(
          payments: payments,
          paymentsLastYear: [],
          invoices: [],
          deadlines: [],
          categoryNames: {},
          serviceNames: {},
          selectedYear: 2026,
        );
        expect(m.totalIn, 1.0);
      });
    });
  });

  // ─── PERCENTAGE CHANGE ───
  group('CalculationEngine.computePercentageChange', () {
    test('crescita del 100%', () {
      expect(CalculationEngine.computePercentageChange(2000, 1000), '+100.0%');
    });

    test('calo del 50%', () {
      expect(CalculationEngine.computePercentageChange(500, 1000), '-50.0%');
    });

    test('nessuna variazione', () {
      expect(CalculationEngine.computePercentageChange(1000, 1000), '0.0%');
    });

    test('anno precedente a zero con valore corrente positivo', () {
      expect(CalculationEngine.computePercentageChange(500, 0), 'N/D');
    });

    test('entrambi a zero', () {
      expect(CalculationEngine.computePercentageChange(0, 0), '0%');
    });

    test('variazione negativa con current a zero', () {
      expect(CalculationEngine.computePercentageChange(0, 1000), '-100.0%');
    });
  });
}
