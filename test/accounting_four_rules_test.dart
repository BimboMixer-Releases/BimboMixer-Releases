import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Regola Fondamentale 4 Punti: Dashboard vs Bilancio Fisco', () {
    test('Verifica completa delle 4 regole contabili + fatture passive OUT + date italiane', () {
      final payments = <Map<String, dynamic>>[
        // Regola 2: Movimento Saldato con CARTA (1000 €) -> Dashboard + Bilancio Fisco
        {
          'id': 'A001',
          'amount': 1000.0,
          'date': '15/05/2026',
          'type': 'IN',
          'payment_method': 'Carta',
          'status': 'PAID',
        },
        // Regola 2: Movimento Saldato con BANCOMAT in uscita (200 €) -> Dashboard + Bilancio Fisco
        {
          'id': 'A002',
          'amount': 200.0,
          'date': '16/05/2026',
          'type': 'OUT',
          'payment_method': 'Bancomat',
          'status': 'SALDATO',
        },
        // Regola 2: Movimento legacy senza campo status con FATTURA (500 €) -> Dashboard + Bilancio Fisco
        {
          'id': 'A003',
          'amount': 500.0,
          'date': '17/05/2026',
          'type': 'IN',
          'payment_method': 'Fattura',
        },
        // Regola 3: Movimento Saldato con CONTANTE (300 €) -> SOLO Dashboard, NO Bilancio Fisco
        {
          'id': 'A004',
          'amount': 300.0,
          'date': '18/05/2026',
          'type': 'IN',
          'payment_method': 'Contante',
          'status': 'PAID',
        },
        // Regola 4: Movimento IN ATTESA / PENDING / DA SOLLECITARE -> MAI conteggiato
        {
          'id': 'A005',
          'amount': 9999.0,
          'date': '19/05/2026',
          'type': 'IN',
          'payment_method': 'Carta',
          'status': 'PENDING',
        },
        {
          'id': 'A006',
          'amount': 8888.0,
          'date': '20/05/2026',
          'type': 'IN',
          'payment_method': 'Bonifico',
          'status': 'DA SOLLECITARE',
        },
      ];

      final invoices = <Map<String, dynamic>>[
        // Regola 1: Fattura attiva Saldata (400 €) -> Dashboard + Bilancio Fisco
        {
          'id': 'INV-1',
          'number': '1/2026',
          'amount': 400.0,
          'date': '21/05/2026',
          'type': 'IN',
          'status': 'PAID',
        },
        // Fattura passiva Saldata (150 €) -> Uscite sia Dashboard che Bilancio Fisco
        {
          'id': 'INV-2',
          'number': 'PASS-1',
          'amount': 150.0,
          'date': '22/05/2026',
          'type': 'OUT',
          'status': 'SALDATO',
        },
        // Regola 4: Fattura IN ATTESA / DA SOLLECITARE -> MAI conteggiata
        {
          'id': 'INV-3',
          'number': '2/2026',
          'amount': 7777.0,
          'date': '23/05/2026',
          'type': 'IN',
          'status': 'IN ATTESA',
        },
      ];

      final dash = CalculationEngine.computeDashboardMetrics(
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

      final fisco = CalculationEngine.computeFiscalMetrics(
        payments: payments,
        invoices: invoices,
        selectedYear: 2026,
      );

      // Dashboard:
      // Entrate = 1000 (Carta) + 500 (Fattura legacy) + 300 (Contante) + 400 (INV-1) = 2200
      // Uscite  = 200 (Bancomat) + 150 (INV-2 passiva) = 350
      // Patrimonio = 2200 - 350 = 1850
      expect(dash.totalIn, 2200.0);
      expect(dash.totalOut, 350.0);
      expect(dash.patrimonio, 1850.0);

      // Bilancio Fisco (esclude i 300 € in Contante!):
      // Entrate Fiscali = 1000 (Carta) + 500 (Fattura legacy) + 400 (INV-1) = 1900
      // Uscite Fiscali  = 200 (Bancomat) + 150 (INV-2 passiva) = 350
      // Utile Fiscale   = 1900 - 350 = 1550
      expect(fisco.entrateFiscale, 1900.0);
      expect(fisco.usciteFiscale, 350.0);
      expect(fisco.utileFiscale, 1550.0);

      // La differenza tra Dashboard e Fisco è esattamente il Contante (300 €)
      expect(dash.totalIn - fisco.entrateFiscale, 300.0);
      expect(dash.totalOut, fisco.usciteFiscale);
    });
  });
}
