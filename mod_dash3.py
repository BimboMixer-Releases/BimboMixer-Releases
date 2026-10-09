with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''class _PieChartFullScreenDialog extends StatefulWidget {
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> invoices;
  final String chartFilter;'''

replacement = '''class _PieChartFullScreenDialog extends StatefulWidget {
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> invoices;
  final String chartFilter;
  final bool sortAscending;'''

content = content.replace(target, replacement)

target2 = '''  const _PieChartFullScreenDialog({
    Key? key,
    required this.payments,
    required this.invoices,
    required this.chartFilter,
  }) : super(key: key);'''

replacement2 = '''  const _PieChartFullScreenDialog({
    super.key,
    required this.payments,
    required this.invoices,
    required this.chartFilter,
    required this.sortAscending,
  });'''

content = content.replace(target2, replacement2)

target3 = '''      return _sortPaymentsAscending ? da.compareTo(db) : db.compareTo(da);'''
replacement3 = '''      return widget.sortAscending ? da.compareTo(db) : db.compareTo(da);'''

content = content.replace(target3, replacement3)

target4 = '''                    builder: (ctx) => _PieChartFullScreenDialog(
                      payments: _globalRecentPayments,
                      invoices: _invoices,
                      chartFilter: _chartFilter,
                    ),'''
replacement4 = '''                    builder: (ctx) => _PieChartFullScreenDialog(
                      payments: _globalRecentPayments,
                      invoices: _invoices,
                      chartFilter: _chartFilter,
                      sortAscending: _sortPaymentsAscending,
                    ),'''

content = content.replace(target4, replacement4)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
