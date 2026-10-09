import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import for scheduled payments if missing
if "import 'package:contabile_app/screens/scheduled_payments_screen.dart';" not in content:
    content = content.replace("import 'package:contabile_app/screens/invoices_screen.dart';",
                              "import 'package:contabile_app/screens/invoices_screen.dart';\nimport 'package:contabile_app/screens/scheduled_payments_screen.dart';")

# Add _scheduledPayments list
if 'List<Map<String, dynamic>> _scheduledPayments = [];' not in content:
    content = content.replace("List<Map<String, dynamic>> _invoices = [];",
                              "List<Map<String, dynamic>> _invoices = [];\n  List<Map<String, dynamic>> _scheduledPayments = [];")

# Fetch scheduled payments
fetch_old = "final invoices = await _dbHelper.getInvoices();"
fetch_new = "final invoices = await _dbHelper.getInvoices();\n      final scheduled = await _dbHelper.getScheduledPayments();"
if fetch_new not in content:
    content = content.replace(fetch_old, fetch_new)

# Assign to state
assign_old = "_invoices = invoices;"
assign_new = "_invoices = invoices;\n      _scheduledPayments = scheduled;"
if assign_new not in content:
    content = content.replace(assign_old, assign_new)

# Calculate unpaid
calc_old = "int unpaidInvoices = _invoices.where((i) => i['status'] != 'PAID').length;"
calc_new = "int unpaidInvoices = _scheduledPayments.where((p) => p['type'] == 'IN' && p['status'] != 'PAID' && p['status'] != 'Pagato').length;"
if calc_old in content:
    content = content.replace(calc_old, calc_new)

# Update tap
tap_old = "await Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen()));"
tap_new = "await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduledPaymentsScreen()));"
if tap_old in content:
    content = content.replace(tap_old, tap_new)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard updated!")