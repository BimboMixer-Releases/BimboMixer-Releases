import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the text labels carefully
content = content.replace("'Invoices & Transactions'", "'Movimenti'")
content = content.replace("'Transactions Overview'", "'Riepilogo'")
content = content.replace("'Invoice ID'", "'ID'")
content = content.replace("'Client Name'", "'Cliente'")
content = content.replace("'Date'", "'Data'")
content = content.replace("'Description'", "'Descrizione'")
content = content.replace("'Amount'", "'Importo'")
content = content.replace("'Status'", "'Stato'")
content = content.replace("'Action'", "'Azioni'")

# Fix ID
content = content.replace("final invoiceId = _formatInvoiceId(index);", "final invoiceId = p['document_id']?.toString() ?? p['id']?.toString() ?? '';")

# Fix _filteredPayments
import re
match = re.search(r'(List<Map<String, dynamic>> get _filteredPayments \{.*?\n  })', content, re.DOTALL)
if match:
    old_getter = match.group(1)
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
  }"""
    content = content.replace(old_getter, new_getter)

# Insert Dropdown in the Header near popup menu
sort_ui = """
                                  Row(
                                    children: [
                                      Theme(
                                        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF16192B)),
                                        child: DropdownButton<String>(
                                          value: _sortType,
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          underline: const SizedBox(),
                                          icon: const Icon(Icons.sort, color: Colors.white54, size: 20),
                                          items: ['Data Piu Recente', 'Data Meno Recente', 'Importo Maggiore', 'Importo Minore']
                                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _sortType = val);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>("""
content = content.replace("PopupMenuButton<String>(", sort_ui, 1)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Safe patched")