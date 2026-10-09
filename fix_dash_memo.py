import re
# ---------- Dashboard ----------
p = 'lib/screens/dashboard_screen.dart'
s = open(p, encoding='utf-8', newline='').read()
old_count = "int unpaidInvoices = _scheduledPayments.where((p) => p['type'] == 'IN' && p['status'] != 'PAID' && p['status'] != 'Pagato' && p['status'] != 'Incassata').length;"
assert old_count in s
s = s.replace(old_count, "int unpaidInvoices = _invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'Incassata').length;")
old_nav = "              onTap: () {\r\n                Navigator.push(\r\n                  context,\r\n                  MaterialPageRoute(builder: (_) => const InvoicesScreen()),\r\n                );\r\n              },"
assert old_nav in s
s = s.replace(old_nav, "              onTap: () {\r\n                Navigator.push(\r\n                  context,\r\n                  MaterialPageRoute(builder: (_) => const MemoEventsScreen()),\r\n                ).then((_) {\r\n                  if (mounted) _loadDashboardData();\r\n                });\r\n              },")
s = s.replace("import 'package:contabile_app/screens/invoices_screen.dart';", "import 'package:contabile_app/screens/invoices_screen.dart';\r\nimport 'package:contabile_app/screens/memo_events_screen.dart';", 1)
open(p, 'w', encoding='utf-8', newline='').write(s)

# ---------- MemoEventsScreen ----------
p = 'lib/screens/memo_events_screen.dart'
s = open(p, encoding='utf-8', newline='').read()
s = s.replace("import 'memo_form_screen.dart';", "import 'memo_form_screen.dart';\r\nimport 'invoice_summary_screen.dart';", 1)
s = s.replace("  List<Map<String, dynamic>> _customers = [];\r\n  bool _isLoading = true;",
 "  List<Map<String, dynamic>> _customers = [];\r\n  List<Map<String, dynamic>> _pendingInvoices = [];\r\n  bool _isLoading = true;", 1)
s = s.replace("    final customers = await _dbHelper.getCustomers();\r\n    setState(() {\r\n      _memoEvents = memoEvents;",
 "    final customers = await _dbHelper.getCustomers();\r\n    final invoices = await _dbHelper.getInvoices();\r\n    if (!mounted) return;\r\n    setState(() {\r\n      _pendingInvoices = invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'Incassata').toList();\r\n      _memoEvents = memoEvents;", 1)

s = s.replace("          : _memoEvents.isEmpty\r\n          ? Center(", "          : (_memoEvents.isEmpty && _pendingInvoices.isEmpty)\r\n          ? Center(", 1)
s = s.replace("              itemCount: _memoEvents.length,\r\n              itemBuilder: (context, index) {\r\n                final memo = _memoEvents[index];",
 "              itemCount: _pendingInvoices.length + _memoEvents.length,\r\n              itemBuilder: (context, index) {\r\n                if (index < _pendingInvoices.length) {\r\n                  return _buildPendingInvoiceCard(_pendingInvoices[index], theme);\r\n                }\r\n                final memo = _memoEvents[index - _pendingInvoices.length];", 1)

helper = '''  Widget _buildPendingInvoiceCard(Map<String, dynamic> inv, AppThemeProvider theme) {
    final customer = _getCustomer(inv['customer_id']?.toString());
    final amount = double.tryParse(inv['amount']?.toString() ?? '0') ?? 0.0;
    final isLate = inv['status'] == 'LATE';
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoiceSummaryScreen(invoiceId: inv['id'].toString())),
          );
          if (mounted) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.receipt, color: Colors.amberAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FATTURA ${inv['number'] ?? ''}'.trim(),
                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(customer?['name']?.toString() ?? 'Sconosciuto',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(DateUtilsApp.formatDbDate(inv['date']?.toString(), theme.dateFormat),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.circle, size: 10, color: isLate ? Colors.redAccent : Colors.blue),
                      const SizedBox(width: 6),
                      Text(isLate ? 'IN RITARDO' : 'IN ATTESA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              Text(CurrencyUtils.formatEuro(amount),
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

'''.replace('\n', '\r\n')
s = s.replace("  @override\r\n  Widget build(BuildContext context) {", helper + "  @override\r\n  Widget build(BuildContext context) {", 1)
open(p, 'w', encoding='utf-8', newline='').write(s)
print('ok')
