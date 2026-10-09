# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add getScheduledPayments to _loadDashboardData
old_code = '''    final invoices = await _dbHelper.getInvoices();

    final categories = await _dbHelper.getCategories();'''

new_code = '''    final invoices = await _dbHelper.getInvoices();
    final scheduled = await _dbHelper.getScheduledPayments();

    final categories = await _dbHelper.getCategories();'''

content = content.replace(old_code, new_code)

# Add _scheduledPayments list to state
old_state = '''  List<Map<String, dynamic>> _invoices = [];
  Color? _fiscoWarningColor;'''
new_state = '''  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _scheduledPayments = [];
  Color? _fiscoWarningColor;'''
content = content.replace(old_state, new_state)

# Assign it in setState
old_assign = '''      _invoices = invoices;
      _monthlyNet = metrics.monthlyNet;'''
new_assign = '''      _invoices = invoices;
      _scheduledPayments = scheduled;
      _monthlyNet = metrics.monthlyNet;'''
content = content.replace(old_assign, new_assign)

# And fix the unpaidInvoices count to use _scheduledPayments
old_unpaid = "int unpaidInvoices = _invoices.where((i) => i['status'] != 'PAID').length;"
new_unpaid = "int unpaidInvoices = _scheduledPayments.where((p) => p['type'] == 'IN' && p['status'] != 'PAID' && p['status'] != 'Pagato' && p['status'] != 'Incassata').length;"
content = content.replace(old_unpaid, new_unpaid)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard state fixed")
