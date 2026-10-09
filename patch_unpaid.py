# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the count
old_code = "int unpaidInvoices = _invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'Incassata').length;"
new_code = "int unpaidInvoices = _scheduledPayments.where((p) => p['type'] == 'IN' && p['status'] != 'PAID' && p['status'] != 'Pagato' && p['status'] != 'Incassata').length;"

content = content.replace(old_code, new_code)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("unpaidInvoices fixed")
