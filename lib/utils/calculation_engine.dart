import 'package:contabile_app/models/dashboard_metrics.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/date_utils_app.dart';

class FiscalMetrics {
  final double entrateFiscale;
  final double usciteFiscale;
  final double utileFiscale;
  final List<Map<String, dynamic>> fiscalRecords;

  const FiscalMetrics({
    required this.entrateFiscale,
    required this.usciteFiscale,
    required this.utileFiscale,
    required this.fiscalRecords,
  });
}

/// Pure calculation engine. Does not depend on UI, Firebase, or external state.
/// Ensures all financial mathematics strictly follow the 4-point accounting rule:
/// 1) Fattura Saldata -> Dashboard + Bilancio Fisco
/// 2) Movimento Saldato con (FATTURA, CARTA, BANCOMAT, BONIFICO, ASSEGNO, POS) -> Dashboard + Bilancio Fisco
/// 3) Movimento Saldato con (CONTANTE) -> SOLO Dashboard
/// 4) Tutto ciò che è IN ATTESA o DA SOLLECITARE -> MAI conteggiato
class CalculationEngine {
  static int extractYear(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 0;
    final parsed = DateUtilsApp.tryParseDate(dateStr);
    if (parsed != null) return parsed.year;

    final cleaned = dateStr.trim();
    if (cleaned.contains('/')) {
      final parts = cleaned.split('/');
      if (parts.length == 3) {
        final y = int.tryParse(parts[2].split(' ').first) ?? 0;
        return (y > 0 && y < 100) ? y + 2000 : y;
      }
    } else if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      if (parts[0].length == 4) return int.tryParse(parts[0]) ?? 0;
      if (parts.length == 3) {
        final y = int.tryParse(parts[2].split('T').first.split(' ').first) ?? 0;
        return (y > 0 && y < 100) ? y + 2000 : y;
      }
    }
    return 0;
  }

  static int extractMonth(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 1;
    final parsed = DateUtilsApp.tryParseDate(dateStr);
    if (parsed != null) return parsed.month.clamp(1, 12);

    final cleaned = dateStr.trim();
    int month = 1;
    if (cleaned.contains('/')) {
      final parts = cleaned.split('/');
      if (parts.length > 1) month = int.tryParse(parts[1]) ?? 1;
    } else if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      if (parts.length > 1) month = int.tryParse(parts[1]) ?? 1;
    }
    return month.clamp(1, 12);
  }

  /// Regola 2, 3, 4: Un movimento è saldato se lo stato è vuoto/nullo (retrocompatibilità record legacy)
  /// oppure esplicitamente PAID / SALDATO / PAGATO / INCASSATA.
  /// Qualsiasi stato IN ATTESA, PENDING, DA SOLLECITARE, SOLLECITARE, LATE ritorna false.
  static bool isPaymentSettled(Map<String, dynamic> payment) {
    final status = (payment['status'] ?? '').toString().trim().toUpperCase();
    if (status.isEmpty) return true;
    return status == 'PAID' ||
        status == 'SALDATO' ||
        status == 'SALDATA' ||
        status == 'PAGATO' ||
        status == 'PAGATA' ||
        status == 'INCASSATA' ||
        status == 'INCASSATO';
  }

  /// Regola 1 & 4: Una fattura è saldata solo se esplicitamente marcata come saldata/pagata/incassata.
  static bool isInvoiceSettled(Map<String, dynamic> invoice) {
    final status = (invoice['status'] ?? '').toString().trim().toUpperCase();
    return status == 'PAID' ||
        status == 'INCASSATA' ||
        status == 'INCASSATO' ||
        status == 'SALDATO' ||
        status == 'SALDATA' ||
        status == 'PAGATO' ||
        status == 'PAGATA';
  }

  /// Una scadenza è saldata solo se esplicitamente marcata come saldata/pagata.
  static bool isDeadlineSettled(Map<String, dynamic> deadline) {
    final status = (deadline['status'] ?? '').toString().trim().toUpperCase();
    return status == 'PAID' ||
        status == 'SALDATO' ||
        status == 'SALDATA' ||
        status == 'PAGATO' ||
        status == 'PAGATA';
  }

  /// Regola 3: Contante / Contanti
  static bool isCashMethod(String? method) {
    final m = (method ?? '').trim().toLowerCase();
    return m.contains('contant');
  }

  /// Regola 2: Metodi tracciati / fiscali (Fattura, Carta, Bancomat, POS, Bonifico, Assegno).
  /// Contante o vuoto ritornano false.
  static bool isFiscalPaymentMethod(String? method) {
    final m = (method ?? '').trim().toLowerCase();
    if (m.isEmpty || m.contains('contant')) return false;
    return m.contains('fattur') ||
        m.contains('carta') ||
        m.contains('bancomat') ||
        m.contains('pos') ||
        m.contains('bonifico') ||
        m.contains('assegn') ||
        m.contains('tracciat') ||
        m.contains('elettronic');
  }

  /// Trova tutti gli ID delle fatture che hanno già un movimento (pagamento) associato
  /// per evitare qualsiasi doppio conteggio tra Fatture e Movimenti (tracking incrociato).
  static Set<String> findPaidInvoiceIds(
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> invoices,
  ) {
    final Set<String> matchedInvoiceIds = {};
    final Set<String> matchedPaymentIds = {};

    String norm(dynamic s) => (s ?? '').toString().trim().toLowerCase();

    // 1. Match diretto su invoice_id memorizzato nel pagamento
    for (final p in payments) {
      if (!isPaymentSettled(p)) continue;
      final pInvId = (p['invoice_id'] ?? '').toString().trim();
      if (pInvId.isNotEmpty) {
        matchedInvoiceIds.add(pInvId);
        final pId = p['id']?.toString() ?? '';
        if (pId.isNotEmpty) matchedPaymentIds.add(pId);

        // Se pInvId corrisponde a un 'number' di fattura anziché all'ID documento
        for (final inv in invoices) {
          final invId = inv['id']?.toString() ?? '';
          final invNum = (inv['number'] ?? '').toString().trim();
          if (invId.isNotEmpty &&
              (pInvId == invId || (invNum.isNotEmpty && pInvId == invNum))) {
            matchedInvoiceIds.add(invId);
          }
        }
      }
    }

    // 2. Tracking incrociato euristico tra fatture saldate e pagamenti saldati
    for (final inv in invoices) {
      if (!isInvoiceSettled(inv)) continue;
      final invId = inv['id']?.toString() ?? '';
      if (invId.isEmpty || matchedInvoiceIds.contains(invId)) continue;

      final invAmt = CurrencyUtils.parseCurrency(inv['amount']?.toString());
      if (invAmt <= 0) continue;

      final invDateStr = (inv['date'] ?? '').toString().trim();
      final invYear = extractYear(invDateStr);
      final invMonth = extractMonth(invDateStr);
      final invCustId = norm(inv['customer_id'] ?? inv['client_id']);
      final invCustName = norm(inv['client_name'] ?? inv['customer_name']);
      final invNumber = norm(inv['number']);
      final invType = (inv['type'] ?? 'IN').toString().trim().toUpperCase();

      for (final p in payments) {
        if (!isPaymentSettled(p)) continue;
        final pId = p['id']?.toString() ?? '';
        if (pId.isNotEmpty && matchedPaymentIds.contains(pId)) continue;

        final pType = (p['type'] ?? 'IN').toString().trim().toUpperCase();
        if (pType != invType) continue;

        final pAmt = CurrencyUtils.parseCurrency(p['amount']?.toString());
        if ((pAmt - invAmt).abs() > 0.01) continue;

        final pDateStr = (p['date'] ?? '').toString().trim();
        final pYear = extractYear(pDateStr);
        if (pYear != invYear && invYear != 0 && pYear != 0) continue;

        final pCustId = norm(p['customer_id'] ?? p['client_id']);
        final pCustName = norm(p['customer_name'] ?? p['client_name']);
        final pMethod = norm(p['payment_method']);
        final pTitle = norm(p['title']);
        final pNotes = norm(p['notes']);

        bool isMatch = false;

        // A) Riferimento al numero fattura o id nel titolo o note
        if (invNumber.isNotEmpty &&
            (pTitle.contains(invNumber) || pNotes.contains(invNumber))) {
          isMatch = true;
        } else if (pTitle.contains(invId.toLowerCase()) ||
            pNotes.contains(invId.toLowerCase())) {
          isMatch = true;
        }
        // B) Stesso cliente (ID o Nome) e stesso importo
        else if ((invCustId.isNotEmpty && invCustId == pCustId) ||
            (invCustName.isNotEmpty && invCustName == pCustName)) {
          final pMonth = extractMonth(pDateStr);
          if (pDateStr == invDateStr ||
              pMethod.contains('fattur') ||
              pMonth == invMonth) {
            isMatch = true;
          }
        }
        // C) Metodo esplicitamente 'Fattura' con stessa data o stesso cliente
        else if (pMethod.contains('fattur') &&
            (pDateStr == invDateStr ||
                (invCustId.isNotEmpty && invCustId == pCustId))) {
          isMatch = true;
        }

        if (isMatch) {
          matchedInvoiceIds.add(invId);
          if (pId.isNotEmpty) matchedPaymentIds.add(pId);
          break;
        }
      }
    }

    return matchedInvoiceIds;
  }

  /// Computes fiscal metrics for Bilancio Fisco using the exact same rules and deduplication as Dashboard.
  static FiscalMetrics computeFiscalMetrics({
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> invoices,
    int? selectedYear,
  }) {
    double entrateF = 0.0;
    double usciteF = 0.0;
    final Set<String> allCountedFiscalInvoiceIds = findPaidInvoiceIds(payments, invoices);
    final List<Map<String, dynamic>> fiscalRecords = [];

    // 1. Raccogli tutti gli invoice_id già coperti da movimenti fiscali saldati (anche su altri anni)
    for (final p in payments) {
      if (!isPaymentSettled(p)) continue;
      final method = p['payment_method']?.toString();
      if (!isFiscalPaymentMethod(method)) continue;

      final amt = CurrencyUtils.parseCurrency(p['amount']?.toString());
      if (amt == 0) continue;
      final dateStr = (p['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) continue;

      final invId = p['invoice_id']?.toString() ?? '';
      if (invId.isNotEmpty) {
        allCountedFiscalInvoiceIds.add(invId);
      }

      if (selectedYear != null && extractYear(dateStr) != selectedYear) {
        continue;
      }

      final isIn = (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
      if (isIn) {
        entrateF += amt;
      } else {
        usciteF += amt;
      }
      fiscalRecords.add(Map<String, dynamic>.from(p));
    }

    // 2. Aggiungi le fatture saldate non già coperte da un movimento fiscale
    for (final inv in invoices) {
      if (!isInvoiceSettled(inv)) continue;
      final invId = inv['id']?.toString() ?? '';
      if (invId.isNotEmpty && allCountedFiscalInvoiceIds.contains(invId)) {
        continue;
      }

      final dateStr = (inv['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) continue;
      if (selectedYear != null && extractYear(dateStr) != selectedYear) {
        continue;
      }

      final amt = CurrencyUtils.parseCurrency(inv['amount']?.toString());
      if (amt <= 0) continue;

      final invType = (inv['type'] ?? 'IN').toString().trim().toUpperCase();
      final isOut = invType == 'OUT';
      if (isOut) {
        usciteF += amt;
      } else {
        entrateF += amt;
      }

      final invNumber = inv['number']?.toString() ?? invId;
      fiscalRecords.add({
        'id': invId,
        'type': isOut ? 'OUT' : 'IN',
        'amount': amt,
        'date': dateStr,
        'payment_method': 'Fattura Diretta',
        'title': (inv['title'] != null && inv['title'].toString().trim().isNotEmpty)
            ? inv['title'].toString()
            : 'Fattura N. $invNumber',
        'notes': inv['notes'] ?? '',
        'customer_name': inv['client_name'] ?? '',
        'is_invoice': true,
      });
    }

    entrateF = CurrencyUtils.roundMoney(entrateF);
    usciteF = CurrencyUtils.roundMoney(usciteF);
    final utileF = CurrencyUtils.roundMoney(entrateF - usciteF);

    return FiscalMetrics(
      entrateFiscale: entrateF,
      usciteFiscale: usciteF,
      utileFiscale: utileF,
      fiscalRecords: fiscalRecords,
    );
  }

  /// Computes all metrics for the dashboard for a specific year.
  static DashboardMetrics computeDashboardMetrics({
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> paymentsLastYear,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> deadlines,
    required List<Map<String, dynamic>> scheduledPayments,
    required List<Map<String, dynamic>> scheduledPaymentsLastYear,
    required Map<String, String> categoryNames,
    required Map<String, String> serviceNames,
    required int selectedYear,
    List<Map<String, dynamic>>? allPayments,
    List<Map<String, dynamic>>? allInvoices,
  }) {
    double totalIn = 0.0;
    double totalOut = 0.0;
    double globalPatrimonio = 0.0;

    // Fallback for tests or missing arguments
    final effectiveAllPayments = allPayments ?? payments;
    final effectiveAllInvoices = allInvoices ?? invoices;

    // Compute Global Net Worth using allPayments and allInvoices (deduplicating linked invoices)
    final Set<String> allPaidInvoiceIds = findPaidInvoiceIds(
      effectiveAllPayments,
      effectiveAllInvoices,
    );
    for (final p in effectiveAllPayments) {
      if (!isPaymentSettled(p)) continue;
      final double amt = CurrencyUtils.parseCurrency(p['amount']?.toString());
      if (amt == 0) continue;
      final String dateStr = (p['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) continue;

      final bool isIn = (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
      if (isIn) {
        globalPatrimonio += amt;
      } else {
        globalPatrimonio -= amt;
      }
    }

    for (final inv in effectiveAllInvoices) {
      if (!isInvoiceSettled(inv)) continue;
      final String invId = inv['id']?.toString() ?? '';
      if (invId.isNotEmpty && allPaidInvoiceIds.contains(invId)) continue;
      final String dateStr = (inv['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) continue;

      final double invAmt = CurrencyUtils.parseCurrency(inv['amount']?.toString());
      if (invAmt <= 0) continue;

      final bool isOut = (inv['type'] ?? 'IN').toString().trim().toUpperCase() == 'OUT';
      if (isOut) {
        globalPatrimonio -= invAmt;
      } else {
        globalPatrimonio += invAmt;
      }
    }

    // Subtract all PAID deadlines from globalPatrimonio
    for (final d in deadlines) {
      if (isDeadlineSettled(d)) {
        globalPatrimonio -= CurrencyUtils.parseCurrency(d['amount']?.toString());
      }
    }
    globalPatrimonio = CurrencyUtils.roundMoney(globalPatrimonio);

    final Map<int, double> monthlyNet = {for (var i = 1; i <= 12; i++) i: 0.0};
    final Map<int, double> monthlyIn = {for (var i = 1; i <= 12; i++) i: 0.0};
    final Map<int, double> monthlyOut = {for (var i = 1; i <= 12; i++) i: 0.0};
    final Map<String, double> tempCat = {};
    final Map<String, double> tempSrv = {};
    final Map<String, double> tempFatCon = {};

    // Estrai i pagamenti associati ad una fattura per evitare doppi conteggi (anche cross-anno)
    final Set<String> paidInvoiceIds = findPaidInvoiceIds(
      payments,
      invoices,
    )..addAll(allPaidInvoiceIds);

    for (final p in payments) {
      if (!isPaymentSettled(p)) continue;

      final double amount = CurrencyUtils.parseCurrency(p['amount']?.toString());
      if (amount == 0) continue;

      final String dateStr = (p['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) continue;

      final int year = extractYear(dateStr);
      if (year != selectedYear) continue;

      final int month = extractMonth(dateStr);
      final String catName = categoryNames[p['category_id']] ?? 'Altro';
      final String srvName = serviceNames[p['service_id']] ?? 'Altro';
      final String? paymentMethod = p['payment_method']?.toString();

      final bool isIn = (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
      if (isIn) {
        totalIn += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) + amount);
        monthlyIn[month] = CurrencyUtils.roundMoney((monthlyIn[month] ?? 0.0) + amount);

        // Fatturato vs Contante mostra esclusivamente quanto guadagnato/incassato (ENTRATE)
        final String fatConKey = isCashMethod(paymentMethod) ? 'Contante' : 'Fatturato';
        tempFatCon[fatConKey] = CurrencyUtils.roundMoney((tempFatCon[fatConKey] ?? 0.0) + amount);
      } else {
        totalOut += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) - amount);
        monthlyOut[month] = CurrencyUtils.roundMoney((monthlyOut[month] ?? 0.0) + amount);
      }

      tempCat[catName] = CurrencyUtils.roundMoney((tempCat[catName] ?? 0.0) + amount);
      tempSrv[srvName] = CurrencyUtils.roundMoney((tempSrv[srvName] ?? 0.0) + amount);
    }

    // Processa Invoices: aggiungi le fatture saldate che non hanno già un pagamento associato
    for (final inv in invoices) {
      if (!isInvoiceSettled(inv)) continue;
      final String invId = inv['id']?.toString() ?? '';
      if (invId.isNotEmpty && paidInvoiceIds.contains(invId)) continue;

      final String dateStr = (inv['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) continue;

      final int year = extractYear(dateStr);
      if (year != selectedYear) continue;

      final double amount = CurrencyUtils.parseCurrency(inv['amount']?.toString());
      if (amount <= 0) continue;

      final int month = extractMonth(dateStr);
      final bool isOut = (inv['type'] ?? 'IN').toString().trim().toUpperCase() == 'OUT';
      if (isOut) {
        totalOut += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) - amount);
        monthlyOut[month] = CurrencyUtils.roundMoney((monthlyOut[month] ?? 0.0) + amount);
      } else {
        totalIn += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) + amount);
        monthlyIn[month] = CurrencyUtils.roundMoney((monthlyIn[month] ?? 0.0) + amount);
        tempFatCon['Fatturato'] = CurrencyUtils.roundMoney((tempFatCon['Fatturato'] ?? 0.0) + amount);
      }
    }

    // Deadlines processing (filtered by selected year)
    double totalDeadlinesPaid = 0.0;
    for (final d in deadlines) {
      if (isDeadlineSettled(d)) {
        String? dateStr = d['date_from']?.toString();
        if (dateStr == null || dateStr.trim().isEmpty) {
          dateStr = d['date']?.toString();
        }
        if (dateStr != null && dateStr.trim().isNotEmpty) {
          final int year = extractYear(dateStr);
          if (year == selectedYear) {
            final double amount = CurrencyUtils.parseCurrency(d['amount']?.toString());
            totalDeadlinesPaid += amount;
          }
        }
      }
    }

    // Calculate final metrics
    totalIn = CurrencyUtils.roundMoney(totalIn);
    totalOut = CurrencyUtils.roundMoney(totalOut);
    totalDeadlinesPaid = CurrencyUtils.roundMoney(totalDeadlinesPaid);

    double margine = 0.0;
    if (totalIn > 0) {
      margine = CurrencyUtils.roundMoney(((totalIn - totalOut) / totalIn) * 100);
    }

    return DashboardMetrics(
      totalIn: totalIn,
      totalOut: totalOut,
      patrimonio: globalPatrimonio,
      margine: margine,
      monthlyNet: monthlyNet,
      monthlyIn: monthlyIn,
      monthlyOut: monthlyOut,
      categoryBreakdown: tempCat,
      serviceBreakdown: tempSrv,
      paymentMethodBreakdown: tempFatCon,
      totalDeadlinesPaid: totalDeadlinesPaid,
    );
  }

  /// Calculates percentage change between two double values.
  /// Handles division by zero gracefully.
  static String computePercentageChange(double current, double previous) {
    if (previous == 0) {
      return current > 0 ? 'N/D' : '0%';
    }
    final double change = ((current - previous) / previous) * 100;
    final String prefix = change > 0 ? '+' : '';
    return '$prefix${change.toStringAsFixed(1)}%';
  }
}
