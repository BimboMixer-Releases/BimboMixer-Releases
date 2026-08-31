import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/models/dashboard_metrics.dart';

/// Pure calculation engine. Does not depend on UI, Firebase, or external state.
/// Ensures all financial mathematics are strictly controlled and tested.
class CalculationEngine {
  /// Computes all metrics for the dashboard for a specific year.
  static DashboardMetrics computeDashboardMetrics({
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> paymentsLastYear,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> deadlines,
    required Map<String, String> categoryNames,
    required Map<String, String> serviceNames,
    required int selectedYear,
  }) {
    double totalIn = 0.0;
    double totalOut = 0.0;
    Map<int, double> monthlyNet = {for (var i = 1; i <= 12; i++) i: 0.0};
    Map<String, double> tempCat = {};
    Map<String, double> tempSrv = {};
    Map<String, double> tempFatCon = {};
    
    // We keep track of event IDs to avoid double counting Invoices vs Payments
    // In many implementations, an invoice ID might be saved inside the payment.
    // However, since we might not have a direct relation, we'll try to match by date, amount, and customer?
    // Alternatively, the prompt indicated: "una fattura PAID non venga contata due volte se esiste anche un Payment associato".
    // For now, if a payment has an invoice_id, we can track it.
    Set<String> paidInvoiceIdsInPayments = {};

    for (var p in payments) {
      double amount = CurrencyUtils.parseCurrency(p['amount']?.toString());
      if (amount == 0) continue;

      String dateStr = p['date'] ?? '';
      if (dateStr.isEmpty) continue;
      
      int year = int.tryParse(dateStr.split('-')[0]) ?? 0;
      if (year != selectedYear) continue; // Safety check

      int month = int.tryParse(dateStr.split('-')[1]) ?? 1;
      String catName = categoryNames[p['category_id']] ?? 'Altro';
      String srvName = serviceNames[p['service_id']] ?? 'Altro';
      String paymentMethod = (p['payment_method'] ?? '').toString().toLowerCase();

      if (p['type'] == 'IN') {
        totalIn += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) + amount);
        
        // Track invoice if this payment comes from an invoice
        if (p['invoice_id'] != null && p['invoice_id'].toString().isNotEmpty) {
          paidInvoiceIdsInPayments.add(p['invoice_id'].toString());
        }
      } else {
        totalOut += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) - amount);
      }

      // Breakdown charts - count both IN and OUT as absolute values (as per previous logic)
      tempCat[catName] = CurrencyUtils.roundMoney((tempCat[catName] ?? 0.0) + amount);
      tempSrv[srvName] = CurrencyUtils.roundMoney((tempSrv[srvName] ?? 0.0) + amount);
      
      bool isCash = paymentMethod.contains('contant');
      String fatConKey = isCash ? 'Contante' : 'Fatturato';
      tempFatCon[fatConKey] = CurrencyUtils.roundMoney((tempFatCon[fatConKey] ?? 0.0) + amount);
    }
    
    // Invoices processing
    for (var i in invoices) {
      if (i['status'] == 'PAID' && i['date'] != null) {
        String invoiceId = i['id']?.toString() ?? '';
        
        int year = int.tryParse(i['date'].split('-')[0]) ?? 0;
        if (year == selectedYear) {
          // DOUBLE COUNTING PREVENTION
          // If this invoice is already paid by a payment record in the same year, skip adding it to IN
          if (paidInvoiceIdsInPayments.contains(invoiceId)) {
            continue;
          }

          double amount = CurrencyUtils.parseCurrency(i['amount']?.toString());
          int month = int.tryParse(i['date'].split('-')[1]) ?? 1;
          
          totalIn += amount;
          monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) + amount);
          tempFatCon['Fatturato'] = CurrencyUtils.roundMoney((tempFatCon['Fatturato'] ?? 0.0) + amount);
        }
      }
    }

    // Deadlines processing (filtered by selected year!)
    double totalDeadlinesPaid = 0.0;
    for (var d in deadlines) {
      if (d['status'] == 'PAID') {
        String? dateStr = d['date_from']?.toString();
        if (dateStr == null || dateStr.isEmpty) {
          dateStr = d['date']?.toString();
        }
        if (dateStr != null && dateStr.isNotEmpty) {
          int year = int.tryParse(dateStr.split('-')[0]) ?? 0;
          if (year == selectedYear) {
            totalDeadlinesPaid += CurrencyUtils.parseCurrency(d['amount']?.toString());
          }
        }
      }
    }

    // Calculate final metrics
    totalIn = CurrencyUtils.roundMoney(totalIn);
    totalOut = CurrencyUtils.roundMoney(totalOut);
    totalDeadlinesPaid = CurrencyUtils.roundMoney(totalDeadlinesPaid);
    
    double patrimonio = CurrencyUtils.roundMoney(totalIn - totalOut - totalDeadlinesPaid);
    
    double margine = 0.0;
    if (totalIn > 0) {
      margine = CurrencyUtils.roundMoney(((totalIn - totalOut) / totalIn) * 100);
    }

    return DashboardMetrics(
      totalIn: totalIn,
      totalOut: totalOut,
      patrimonio: patrimonio,
      margine: margine,
      monthlyNet: monthlyNet,
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
    double change = ((current - previous) / previous) * 100;
    String prefix = change > 0 ? '+' : '';
    return '$prefix${change.toStringAsFixed(1)}%';
  }
}

