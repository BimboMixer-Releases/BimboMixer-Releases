# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_1 = '''    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: payments,
      paymentsLastYear: paymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
    );'''

new_1 = '''    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: payments,
      paymentsLastYear: paymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
    );'''

old_2 = '''    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: paymentsLastYear,
      paymentsLastYear: [],
      invoices: invoices,
      deadlines: deadlines,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );'''

new_2 = '''    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: paymentsLastYear,
      paymentsLastYear: [],
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );'''

content = content.replace(old_1, new_1)
content = content.replace(old_2, new_2)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard metrics fixed 2")
