# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Change unpaidInvoices calculation
target_calc = "int unpaidInvoices = _invoices.where((p) => p['status'] != 'PAID' && p['status'] != 'Incassata').length;"
new_calc = "int unpaidInvoices = _scheduledPayments.where((p) => p['type'] == 'IN' && p['status'] != 'PAID' && p['status'] != 'Pagato' && p['status'] != 'Incassata').length;"

if target_calc in content:
    content = content.replace(target_calc, new_calc)
else:
    print("Could not find unpaidInvoices calculation")
    sys.exit(1)

# Change navigation
target_nav = '''              _metricCard(
                theme,
                "FATTURE DA INCASSARE",
                '',
                ' fatture in sospeso',
                Icons.receipt,
                Colors.orangeAccent,
                isAmount: false,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen()));
                  _loadDashboardData();
                },
              ),'''

new_nav = '''              _metricCard(
                theme,
                "FATTURE DA INCASSARE",
                '',
                ' fatture in sospeso',
                Icons.receipt,
                Colors.orangeAccent,
                isAmount: false,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduledPaymentsScreen()));
                  _loadDashboardData();
                },
              ),'''

if target_nav in content:
    content = content.replace(target_nav, new_nav)
else:
    print("Could not find navigation. Will try regex or partial replacement.")
    # Partial fallback
    content = content.replace("builder: (_) => const InvoicesScreen()", "builder: (_) => const ScheduledPaymentsScreen()")

# Add import if missing
if "import 'scheduled_payments_screen.dart';" not in content:
    content = content.replace("import 'invoices_screen.dart';", "import 'invoices_screen.dart';\nimport 'scheduled_payments_screen.dart';")

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
