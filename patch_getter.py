import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

getter_start = content.find("List<Map<String, dynamic>> get _filteredPayments {")
getter_end = content.find("  Widget _buildTopHeaderBar() {", getter_start)
if getter_end == -1:
    getter_end = content.find("  @override\n  Widget build(", getter_start)

old_getter = content[getter_start:getter_end]

new_getter = """List<Map<String, dynamic>> get _filteredPayments {
    final list = _payments.where((p) {
      final isIN = p['type'] == 'IN';
      final isPaid = p['status'] == 'PAID' ||
          p['status'] == 'Saldato' ||
          p['status'] == 'Pagato' ||
          (p['status'] == null && isIN);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;
      if (_statusFilter == 'Uscite' && isIN) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = (p['id'] ?? '').toString().toLowerCase();
        final client = (p['customer_name'] ?? '').toString().toLowerCase();
        final service = (p['service_name'] ?? '').toString().toLowerCase();
        final notes = (p['notes'] ?? '').toString().toLowerCase();
        final method = (p['payment_method'] ?? '').toString().toLowerCase();
        final amount = (p['amount'] ?? '').toString().toLowerCase();

        return id.contains(q) ||
            client.contains(q) ||
            service.contains(q) ||
            notes.contains(q) ||
            method.contains(q) ||
            amount.contains(q);
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (_sortType.contains('Data')) {
        int cmp = SortUtils.compareDates(a['date']?.toString(), b['date']?.toString());
        return _sortType == 'Data Piu Recente' ? -cmp : cmp;
      } else {
        double amountA = double.tryParse(a['amount']?.toString() ?? '0') ?? 0.0;
        double amountB = double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;
        return _sortType == 'Importo Maggiore' ? amountB.compareTo(amountA) : amountA.compareTo(amountB);
      }
    });
    return list;
  }

"""

content = content.replace(old_getter, new_getter)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Getter patched")