# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _sortType variable
if "String _sortType = 'Data Piu Recente';" not in content:
    content = content.replace("String _filterStatus = 'Tutte';", "String _filterStatus = 'Tutte';\n  String _sortType = 'Data Piu Recente';")

# Sort the invoices in the getter or builder
old_builder_start = '''                        final filteredList = _invoices.where((i) {
                          if (_filterStatus == 'Tutte') return true;
                          if (_filterStatus == 'Da Incassare') return i['status'] != 'PAID' && i['status'] != 'Pagato' && i['status'] != 'Incassata';
                          if (_filterStatus == 'Incassata') return i['status'] == 'PAID' || i['status'] == 'Pagato' || i['status'] == 'Incassata';
                          return true;
                        }).toList();'''

new_builder_start = '''                        final filteredList = _invoices.where((i) {
                          if (_filterStatus == 'Tutte') return true;
                          if (_filterStatus == 'Da Incassare') return i['status'] != 'PAID' && i['status'] != 'Pagato' && i['status'] != 'Incassata';
                          if (_filterStatus == 'Incassata') return i['status'] == 'PAID' || i['status'] == 'Pagato' || i['status'] == 'Incassata';
                          return true;
                        }).toList();
                        
                        filteredList.sort((a, b) {
                          if (_sortType == 'Data Piu Recente' || _sortType == 'Data Meno Recente') {
                            final da = a['date']?.toString() ?? '';
                            final db = b['date']?.toString() ?? '';
                            return _sortType == 'Data Piu Recente' ? db.compareTo(da) : da.compareTo(db);
                          } else {
                            final aa = double.tryParse(a['amount']?.toString() ?? '0') ?? 0.0;
                            final ab = double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;
                            return _sortType == 'Importo Maggiore' ? ab.compareTo(aa) : aa.compareTo(ab);
                          }
                        });'''

if old_builder_start in content:
    content = content.replace(old_builder_start, new_builder_start)

# Replace the add button with the PopupMenuButton
old_add_btn = '''          IconButton(
              icon: Icon(Icons.add, color: Colors.blueAccent),
              onPressed: () => _showInvoiceDialog())
          ],'''

new_sort_btn = '''          PopupMenuButton<String>(
            tooltip: 'Ordina',
            color: const Color(0xFF16192B),
            icon: const Icon(Icons.swap_vert, color: Colors.blueAccent, size: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            onSelected: (v) => setState(() => _sortType = v),
            itemBuilder: (ctx) => [
              for (final s in ['Data Piu Recente', 'Data Meno Recente', 'Importo Maggiore', 'Importo Minore'])
                PopupMenuItem(
                  value: s,
                  child: Text(s, style: TextStyle(color: s == _sortType ? Colors.blueAccent : Colors.white)),
                ),
            ],
          ),
          ],'''

content = content.replace(old_add_btn, new_sort_btn)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
