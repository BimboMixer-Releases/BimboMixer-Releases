import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix broken _filteredPayments block
correct_block = """  List<Map<String, dynamic>> get _filteredPayments {
    var filtered = _payments.where((p) {
      final isIN = p['type'] == 'IN';
      final isPaid = p['status'] == 'PAID' ||
          p['status'] == 'Saldato' ||
          p['status'] == 'Pagato' ||
          (p['status'] == null && isIN);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;
      
      final date = p['date'] as String?;
      if (date != null && date.isNotEmpty && !ReportUtils.isDateInRange(date, range)) return false;

      return true;
    }).toList();

    filtered.sort((a, b) {
      final dA = DateUtilsApp.formatDbDate(a['date']?.toString(), 'dd/MM/yyyy');
      final dB = DateUtilsApp.formatDbDate(b['date']?.toString(), 'dd/MM/yyyy');
      bool descending = _sortType == 'Data Piu Recente';
      return compareDates(dA, dB, descending: descending);
    });

    return filtered;
  }"""

# Remove everything from 'List<Map<String, dynamic>> get _filteredPayments {' up to '@override'
pattern = r'List<Map<String, dynamic>> get _filteredPayments \{.*?@override'
content = re.sub(pattern, correct_block + '\n\n  @override', content, flags=re.DOTALL)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fix payments")