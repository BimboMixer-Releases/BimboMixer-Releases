import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _filteredInvoices getter
new_getter = '''  int _compareInvoiceNumbers(String a, String b) {
    final regex = RegExp(r'^([a-zA-Z]+)?\s*(\d+)\s*(?:/|-)?\s*(\d+)?$');
    final matchA = regex.firstMatch(a.trim());
    final matchB = regex.firstMatch(b.trim());

    if (matchA != null && matchB != null) {
      final yearA = int.tryParse(matchA.group(3) ?? '0') ?? 0;
      final yearB = int.tryParse(matchB.group(3) ?? '0') ?? 0;
      if (yearA != yearB) return yearA.compareTo(yearB);

      final numA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
      final numB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
      if (numA != numB) return numA.compareTo(numB);

      final prefixA = matchA.group(1) ?? '';
      final prefixB = matchB.group(1) ?? '';
      return prefixA.compareTo(prefixB);
    }
    return a.compareTo(b);
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    var filtered = List<Map<String, dynamic>>.from(_invoices);
    
    if (_sortType == InvoiceSortType.number) {
      filtered.sort((a, b) {
        String numA = a['number']?.toString() ?? '';
        String numB = b['number']?.toString() ?? '';
        return _compareInvoiceNumbers(numA, numB);
      });
      if (!_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    } else {
      if (_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    }
    return filtered;
  }'''

content = re.sub(
    r'  List<Map<String, dynamic>> get _filteredInvoices \{.*?return filtered;\s*\}',
    new_getter,
    content,
    flags=re.DOTALL
)

# Replace AppBar actions
old_actions = r'''          actions: \[
            IconButton\(
              icon: Icon\(_sortAscending \? Icons\.arrow_upward : Icons\.arrow_downward, color: Colors\.blueAccent\),
              tooltip: _sortAscending \? 'Ordina Data: Più Recenti' : 'Ordina Data: Meno Recenti',
              onPressed: \(\) \{
                setState\(\(\) \{ _sortAscending = !_sortAscending; \}\);
              \},
            \),'''

new_actions = '''          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Colors.blueAccent),
              tooltip: 'Ordina',
              color: const Color(0xFF16192B),
              onSelected: (val) {
                setState(() {
                  if (val == 'Numero (Crescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = true;
                  } else if (val == 'Numero (Decrescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = false;
                  } else if (val == 'Data Più Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = false; 
                  } else if (val == 'Data Meno Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = true;
                  }
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Numero (Decrescente)', child: Text('Numero (Decrescente)', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'Numero (Crescente)', child: Text('Numero (Crescente)', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'Data Più Recente', child: Text('Data Più Recente', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'Data Meno Recente', child: Text('Data Meno Recente', style: TextStyle(color: Colors.white))),
              ],
            ),'''

content = re.sub(old_actions, new_actions, content, flags=re.DOTALL)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
