import re

with open('lib/utils/calculation_engine.dart', 'r', encoding='utf-8') as f:
    content = f.read()

compute_metrics_old = """  static DashboardMetrics computeDashboardMetrics({
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> paymentsLastYear,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> deadlines,
    required List<Map<String, dynamic>> scheduledPayments,
    required List<Map<String, dynamic>> scheduledPaymentsLastYear,
    required Map<String, String> categoryNames,
    required Map<String, String> serviceNames,
    required int selectedYear,
  }) {"""

compute_metrics_new = """  static DashboardMetrics computeDashboardMetrics({
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
  }) {"""

content = content.replace(compute_metrics_old, compute_metrics_new)

# Add all-time patrimonio calculation
calc_vars_old = """    double totalIn = 0.0;
    double totalOut = 0.0;
"""
calc_vars_new = """    double totalIn = 0.0;
    double totalOut = 0.0;
    double globalPatrimonio = 0.0;
    
    // Compute Global Net Worth using allPayments and allInvoices
    Set<String> allPaidInvoiceIds = {};
    if (allPayments != null) {
      for (var p in allPayments) {
        String status = (p['status'] ?? '').toString().toUpperCase();
        if (status == 'PENDING' || status == 'LATE' || status == 'IN ATTESA' || status == 'IN SOSPESO' || status == 'NON PAGATO') continue;
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
"""

content = content.replace(calc_vars_old, calc_vars_new)

return_old = """    return DashboardMetrics(
      totalIn: totalIn,
      totalOut: totalOut,
      patrimonio: 0.0, // not used directly in ui yet
"""

return_new = """    return DashboardMetrics(
      totalIn: totalIn,
      totalOut: totalOut,
      patrimonio: globalPatrimonio,
"""

content = content.replace(return_old, return_new)

with open('lib/utils/calculation_engine.dart', 'w', encoding='utf-8') as f:
    f.write(content)
