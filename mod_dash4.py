with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = '''  final Map<String, String> serviceNames;'''
replacement1 = '''  final Map<String, String> serviceNames;
  final bool sortAscending;'''

content = content.replace(target1, replacement1)

target2 = '''    required this.serviceNames,
  });'''
replacement2 = '''    required this.serviceNames,
    this.sortAscending = false,
  });'''

content = content.replace(target2, replacement2)

target3 = '''      builder: (_) => _PieChartFullScreenDialog(
        sortedCats: sortedCats,
        categoryColors: _categoryColors,
        palette: palette,
        title: title,
        payments: _globalRecentPayments,
        invoices: _invoices,
        categoryNames: _categoryNames,
        serviceNames: _serviceNames,
      ),'''

replacement3 = '''      builder: (_) => _PieChartFullScreenDialog(
        sortedCats: sortedCats,
        categoryColors: _categoryColors,
        palette: palette,
        title: title,
        payments: _globalRecentPayments,
        invoices: _invoices,
        categoryNames: _categoryNames,
        serviceNames: _serviceNames,
        sortAscending: _sortPaymentsAscending,
      ),'''

content = content.replace(target3, replacement3)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
