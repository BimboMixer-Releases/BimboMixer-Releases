import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

load_old = """    final paymentsLastYear = await _dbHelper.getPayments(
      year: _selectedYear - 1,
    );

    final deadlines = await _dbHelper.getDeadlines();"""

load_new = """    final paymentsLastYear = await _dbHelper.getPayments(
      year: _selectedYear - 1,
    );
    final allPayments = await _dbHelper.getPayments();
    final allInvoices = await _dbHelper.getInvoices();

    final deadlines = await _dbHelper.getDeadlines();"""
content = content.replace(load_old, load_new)

metric_call_old = """    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: payments,
      paymentsLastYear: paymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
    );"""

metric_call_new = """    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: payments,
      paymentsLastYear: paymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
      allPayments: allPayments,
      allInvoices: allInvoices,
    );"""
content = content.replace(metric_call_old, metric_call_new)

metric_call2_old = """    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: paymentsLastYear,
      paymentsLastYear: [],
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );"""

metric_call2_new = """    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: paymentsLastYear,
      paymentsLastYear: [],
      invoices: invoices,
      deadlines: deadlines,
      scheduledPayments: scheduled,
      scheduledPaymentsLastYear: scheduled,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );"""
# Wait, actually we don't need to change metricsLastYear

var_old = """  double _totalIn = 0;
  double _totalOut = 0;
  double _totalInLastYear = 0;
  double _totalOutLastYear = 0;"""

var_new = """  double _totalIn = 0;
  double _totalOut = 0;
  double _totalInLastYear = 0;
  double _totalOutLastYear = 0;
  double _patrimonio = 0;"""
content = content.replace(var_old, var_new)

set_old = """      _totalIn = metrics.totalIn;
      _totalOut = metrics.totalOut;
      _totalInLastYear = metricsLastYear.totalIn;
      _totalOutLastYear = metricsLastYear.totalOut;"""
set_new = """      _totalIn = metrics.totalIn;
      _totalOut = metrics.totalOut;
      _totalInLastYear = metricsLastYear.totalIn;
      _totalOutLastYear = metricsLastYear.totalOut;
      _patrimonio = metrics.patrimonio;"""
content = content.replace(set_old, set_new)

pat_old = """  Widget _buildPatrimonioCard(AppThemeProvider theme) {
    double netto = _totalIn - _totalOut;
    double nettoLastYear = _totalInLastYear - _totalOutLastYear;
    String change = _calculatePercentageChange(netto, nettoLastYear);"""

pat_new = """  Widget _buildPatrimonioCard(AppThemeProvider theme) {
    double netto = _patrimonio;
    double nettoLastYear = _totalInLastYear - _totalOutLastYear; // Historical comparison keeps year net
    String change = _calculatePercentageChange(_totalIn - _totalOut, nettoLastYear); // Change compares year performance, not all-time!"""
content = content.replace(pat_old, pat_new)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
