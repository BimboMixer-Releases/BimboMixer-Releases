# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix computeDashboardMetrics calls
old_metrics1 = '''    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: globalPayments,
      paymentsLastYear: globalPaymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
    );'''

new_metrics1 = '''    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: globalPayments,
      paymentsLastYear: globalPaymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
    );'''

old_metrics2 = '''    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: globalPaymentsLastYear,
      paymentsLastYear: [],
      invoices: invoicesLastYear,
      deadlines: deadlinesLastYear,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );'''

new_metrics2 = '''    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: globalPaymentsLastYear,
      paymentsLastYear: [],
      invoices: invoicesLastYear,
      deadlines: deadlinesLastYear,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: [],
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );'''

content = content.replace(old_metrics1, new_metrics1)
content = content.replace(old_metrics2, new_metrics2)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard metrics fixed")
