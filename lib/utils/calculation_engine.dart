import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/models/dashboard_metrics.dart';

/// Pure calculation engine. Does not depend on UI, Firebase, or external state.
/// Ensures all financial mathematics are strictly controlled and tested.
class CalculationEngine {
  static int _extractYear(String dateStr) {
    if (dateStr.isEmpty) return 0;
    if (dateStr.contains('/')) {
      final parts = dateStr.split('/');
      if (parts.length == 3) return int.tryParse(parts[2]) ?? 0;
    } else if (dateStr.contains('-')) {
      final parts = dateStr.split('-');
      if (parts[0].length == 4) return int.tryParse(parts[0]) ?? 0;
      if (parts.length == 3 && parts[2].length == 4) return int.tryParse(parts[2]) ?? 0;
    }
    return 0;
  }

  static int _extractMonth(String dateStr) {
    if (dateStr.isEmpty) return 1;
    if (dateStr.contains('/')) {
      final parts = dateStr.split('/');
      if (parts.length > 1) return int.tryParse(parts[1]) ?? 1;
    } else if (dateStr.contains('-')) {
      final parts = dateStr.split('-');
      if (parts[0].length == 4 && parts.length > 1) return int.tryParse(parts[1]) ?? 1;
      if (parts.length > 1) return int.tryParse(parts[1]) ?? 1;
    }
    return 1;
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
    allPayments ??= payments;
    allInvoices ??= invoices;
    
    // Compute Global Net Worth using allPayments and allInvoices
    Set<String> allPaidInvoiceIds = {};
    if (allPayments != null) {
      for (var p in allPayments) {
        String status = (p['status'] ?? '').toString().toUpperCase();
        if (status.isNotEmpty && status != 'PAID' && status != 'SALDATO' && status != 'PAGATO') continue;
        double amt = CurrencyUtils.parseCurrency(p['amount']?.toString());
        if (p['type'] == 'IN') globalPatrimonio += amt;
        else globalPatrimonio -= amt;
        String? invId = p['invoice_id']?.toString();
        if (invId != null && invId.isNotEmpty) allPaidInvoiceIds.add(invId);
      }
    }
    if (allInvoices != null) {
      for (var inv in allInvoices) {
        String status = (inv['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'INCASSATA' || status == 'SALDATO') {
          String invId = inv['id']?.toString() ?? '';
          if (invId.isNotEmpty && !allPaidInvoiceIds.contains(invId)) {
            globalPatrimonio += CurrencyUtils.parseCurrency(inv['amount']?.toString());
          }
        }
      }
    }
    
    // Subtract all PAID deadlines from globalPatrimonio
    for (var d in deadlines) {
      String status = (d['status'] ?? '').toString().toUpperCase();
      if (status == 'PAID' || status == 'SALDATO' || status == 'PAGATO') {
        globalPatrimonio -= CurrencyUtils.parseCurrency(d['amount']?.toString());
      }
    }

    Map<int, double> monthlyNet = {for (var i = 1; i <= 12; i++) i: 0.0};
    Map<int, double> monthlyIn = {for (var i = 1; i <= 12; i++) i: 0.0};
    Map<int, double> monthlyOut = {for (var i = 1; i <= 12; i++) i: 0.0};
    Map<String, double> tempCat = {};
    Map<String, double> tempSrv = {};
    Map<String, double> tempFatCon = {};

    // Estrai i pagamenti che sono associati ad una fattura per evitare doppi conteggi
    Set<String> paidInvoiceIds = {};
    
    for (var p in payments) {
      String status = (p['status'] ?? '').toString().toUpperCase();
      if (status.isNotEmpty && status != 'PAID' && status != 'SALDATO' && status != 'PAGATO') {
        continue;
      }
      
      double amount = CurrencyUtils.parseCurrency(p['amount']?.toString());
      if (amount == 0) continue;

      String dateStr = p['date'] ?? '';
      if (dateStr.isEmpty) continue;
      
      int year = _extractYear(dateStr);
      if (year != selectedYear) continue; // Safety check

      String? invId = p['invoice_id']?.toString();
      if (invId != null && invId.isNotEmpty) {
        paidInvoiceIds.add(invId);
      }

      int month = _extractMonth(dateStr);
      String catName = categoryNames[p['category_id']] ?? 'Altro';
      String srvName = serviceNames[p['service_id']] ?? 'Altro';
      String paymentMethod = (p['payment_method'] ?? '').toString().toLowerCase();

      if (p['type'] == 'IN') {
        totalIn += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) + amount);
        monthlyIn[month] = CurrencyUtils.roundMoney((monthlyIn[month] ?? 0.0) + amount);
      } else {
        totalOut += amount;
        monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) - amount);
        monthlyOut[month] = CurrencyUtils.roundMoney((monthlyOut[month] ?? 0.0) + amount);
      }

      tempCat[catName] = CurrencyUtils.roundMoney((tempCat[catName] ?? 0.0) + amount);
      tempSrv[srvName] = CurrencyUtils.roundMoney((tempSrv[srvName] ?? 0.0) + amount);
      
      bool isCash = paymentMethod.contains('contant');
      String fatConKey = isCash ? 'Contante' : 'Fatturato';
      tempFatCon[fatConKey] = CurrencyUtils.roundMoney((tempFatCon[fatConKey] ?? 0.0) + amount);
    }
    
    // Processa Invoices: aggiungi al totalIn e al Fatturato le fatture pagate che non hanno un pagamento associato
    for (var inv in invoices) {
      String status = (inv['status'] ?? '').toString().toUpperCase();
      if (status == 'PAID' || status == 'INCASSATA' || status == 'SALDATO') {
        String invId = inv['id']?.toString() ?? '';
        if (invId.isNotEmpty && !paidInvoiceIds.contains(invId)) {
          String dateStr = inv['date'] ?? '';
          if (dateStr.isNotEmpty) {
            int year = _extractYear(dateStr);
            if (year == selectedYear) {
              double amount = CurrencyUtils.parseCurrency(inv['amount']?.toString());
              if (amount > 0) {
                int month = _extractMonth(dateStr);
                totalIn += amount;
                monthlyNet[month] = CurrencyUtils.roundMoney((monthlyNet[month] ?? 0.0) + amount);
                monthlyIn[month] = CurrencyUtils.roundMoney((monthlyIn[month] ?? 0.0) + amount);
                tempFatCon['Fatturato'] = CurrencyUtils.roundMoney((tempFatCon['Fatturato'] ?? 0.0) + amount);
              }
            }
          }
        }
      }
    }
    
    // Deadlines processing (filtered by selected year) - da sottrarre al patrimonio
    double totalDeadlinesPaid = 0.0;
    for (var d in deadlines) {
      String status = (d['status'] ?? '').toString().toUpperCase();
      if (status == 'PAID' || status == 'SALDATO' || status == 'PAGATO') {
        String? dateStr = d['date_from']?.toString();
        if (dateStr == null || dateStr.isEmpty) {
          dateStr = d['date']?.toString();
        }
        if (dateStr != null && dateStr.isNotEmpty) {
          int year = _extractYear(dateStr);
          if (year == selectedYear) {
            double amount = CurrencyUtils.parseCurrency(d['amount']?.toString());
            totalDeadlinesPaid += amount;
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
    double change = ((current - previous) / previous) * 100;
    String prefix = change > 0 ? '+' : '';
    return '$prefix${change.toStringAsFixed(1)}%';
  }
}
