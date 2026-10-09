import 'dart:io';

void main() {
  var file = File('lib/screens/payments_screen.dart');
  var content = file.readAsStringSync();

  // 1. Add sortType state var
  content = content.replaceFirst(
    "String _statusFilter = 'Tutti';",
    "String _statusFilter = 'Tutti';\n  String _sortType = 'Data Piu Recente';"
  );
  
  // 2. Add SortUtils import
  content = content.replaceFirst(
    "import 'package:contabile_app/providers/app_theme_provider.dart';",
    "import 'package:contabile_app/providers/app_theme_provider.dart';\nimport 'package:contabile_app/utils/sort_utils.dart';"
  );

  // 3. Labels
  content = content.replaceAll("'Invoices & Transactions'", "'Movimenti'");
  content = content.replaceAll("'Transactions Overview'", "'Riepilogo Movimenti'");
  content = content.replaceAll("'Invoice ID'", "'ID'");
  content = content.replaceAll("'Client Name'", "'Cliente'");
  content = content.replaceAll("'Date'", "'Data'");
  content = content.replaceAll("'Description'", "'Descrizione'");
  content = content.replaceAll("'Amount'", "'Importo'");
  content = content.replaceAll("'Status'", "'Stato'");
  content = content.replaceAll("'Action'", "'Azioni'");

  // 4. Fix _formatInvoiceId usages
  content = content.replaceAll(
    "final invoiceId = _formatInvoiceId(index);", 
    "final invoiceId = p['document_id']?.toString() ?? p['id']?.toString() ?? '';"
  );

  // 5. Replace _filteredPayments getter
  var getterRegex = RegExp(r'List<Map<String, dynamic>> get _filteredPayments \{.*?\n  \}', dotAll: true);
  var match = getterRegex.firstMatch(content);
  if (match != null) {
    var newGetter = '''List<Map<String, dynamic>> get _filteredPayments {
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
  }''';
    content = content.replaceRange(match.start, match.end, newGetter);
  }

  // 6. Fix the Row for the PopupMenuButton
  var menuCode = '''
                                  // Three Dots Menu
                                  PopupMenuButton<String>(''';
  
  var newMenuCode = '''
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
                                      PopupMenuButton<String>(''';
  
  content = content.replaceFirst(menuCode, newMenuCode);
  
  // We need to close the Row we just opened, where is it?
  // It's inside the Padding child: Row
  // So we just add ], at the end of the PopupMenuButton.
  // Wait, let's look at the structure:
  // Row( children: [ Expanded(...), PopupMenuButton(...) ] )
  // We want to replace the PopupMenuButton with Row( children: [ DropdownButton, PopupMenuButton ] )
  // So after PopupMenuButton(...) we need to close the Row -> `],)`
  // Wait, I can just replace the end of PopupMenuButton.
  
  var popupEnd = '''                                      const PopupMenuItem(
                                        value: 'new',
                                        child: Text('Nuovo Movimento', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),''';
  var newPopupEnd = '''                                      const PopupMenuItem(
                                        value: 'new',
                                        child: Text('Nuovo Movimento', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                    ],
                                  ),'''; // closes the new Row
                                  
  content = content.replaceFirst(popupEnd, newPopupEnd);

  file.writeAsStringSync(content);
  print("Done payments_screen");
}