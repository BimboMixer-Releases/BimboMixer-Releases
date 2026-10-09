with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'DateTimeRange? _dateRange;' not in content:
    content = content.replace('String _statusFilter = \'Tutti\';', 'String _statusFilter = \'Tutti\';\n  DateTimeRange? _dateRange;')

old_filtered = '''      if (_statusFilter == 'Uscite' && isIN) return false;

      if (_searchQuery.isNotEmpty) {'''

new_filtered = '''      if (_statusFilter == 'Uscite' && isIN) return false;

      if (_dateRange != null) {
        final d = DateTime.tryParse(p['date']?.toString() ?? '');
        if (d != null) {
          final dateOnly = DateTime(d.year, d.month, d.day);
          final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
          if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return false;
        }
      }

      if (_searchQuery.isNotEmpty) {'''

if old_filtered in content:
    content = content.replace(old_filtered, new_filtered)
    print('Replaced _filteredPayments')
else:
    print('Could not find old_filtered')

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
