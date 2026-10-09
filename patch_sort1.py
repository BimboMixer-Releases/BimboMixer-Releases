import re

# 1. Patch invoices_screen.dart
with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'package:contabile_app/utils/sort_utils.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/sort_utils.dart';")

# Sostituisci il blocco _filteredInvoices
old_block = """  List<Map<String, dynamic>> get _filteredInvoices {
    var filtered = List<Map<String, dynamic>>.from(_invoices);
    
    if (_sortType == InvoiceSortType.number) {
      filtered.sort((a, b) {
        String numA = a['number']?.toString() ?? '';
        String numB = b['number']?.toString() ?? '';
        return _compareInvoiceNumbers(numA, numB);
      });
      if (_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    } else {
      if (_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    }
    return filtered;
  }"""

new_block = """  List<Map<String, dynamic>> get _filteredInvoices {
    var filtered = List<Map<String, dynamic>>.from(_invoices);
    
    if (_sortType == InvoiceSortType.number) {
      filtered.sort((a, b) {
        String numA = a['number']?.toString() ?? '';
        String numB = b['number']?.toString() ?? '';
        return _compareInvoiceNumbers(numA, numB);
      });
      if (_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    } else {
      // Sort by Date
      filtered.sort((a, b) {
        final dA = DateUtilsApp.formatDbDate(a['date']?.toString(), 'dd/MM/yyyy');
        final dB = DateUtilsApp.formatDbDate(b['date']?.toString(), 'dd/MM/yyyy');
        return compareDates(dA, dB, descending: !_sortAscending);
      });
    }
    return filtered;
  }"""

content = content.replace(old_block, new_block)

# Aggiungi filtro se non c'è. "Data Più Recente" esiste già.
with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Patch payments_screen.dart
with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'package:contabile_app/utils/sort_utils.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/sort_utils.dart';")

# Aggiungi _sortType
if 'String _sortType = ' not in content:
    content = content.replace('String _statusFilter = \'Tutti\';', 'String _statusFilter = \'Tutti\';\n  String _sortType = \'Data Piu Recente\';')

old_filter_block = """  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((p) {
      final isIN = p['type'] == 'IN';
      final isPaid = p['status'] == 'PAID' ||
          p['status'] == 'Saldato' ||
          p['status'] == 'Pagato' ||
          (p['status'] == null && isIN);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;

      return true;
    }).toList();
  }"""

new_filter_block = """  List<Map<String, dynamic>> get _filteredPayments {
    var filtered = _payments.where((p) {
      final isIN = p['type'] == 'IN';
      final isPaid = p['status'] == 'PAID' ||
          p['status'] == 'Saldato' ||
          p['status'] == 'Pagato' ||
          (p['status'] == null && isIN);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;

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

if old_filter_block in content:
    content = content.replace(old_filter_block, new_filter_block)
else:
    # try generic regex
    pattern = r'List<Map<String, dynamic>> get _filteredPayments \{.*?\n  \}'
    content = re.sub(pattern, new_filter_block, content, flags=re.DOTALL)


# Aggiungiamo il PopupMenuButton per ordinare in payments_screen.dart
# Troviamo il SearchBar (o simile) o i filtri.
# c'è un Row con _statusFilter
dropdown_pattern = r"""DropdownButtonHideUnderline\(\s*child: DropdownButton<String>\(\s*dropdownColor: const Color\(0xFF2A2A35\),\s*value: _statusFilter,\s*icon: const Icon\(Icons.keyboard_arrow_down, color: Colors.white70\),.*?\),\s*\)"""

# Inseriamo un PopupMenuButton accanto.
new_dropdowns = """Row(
                              children: [
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: const Color(0xFF2A2A35),
                                    value: _statusFilter,
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() => _statusFilter = newValue);
                                      }
                                    },
                                    items: <String>['Tutti', 'Saldato', 'In Attesa', 'Entrate']
                                        .map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.sort, color: Colors.white70),
                                  color: const Color(0xFF2A2A35),
                                  onSelected: (val) {
                                    setState(() => _sortType = val);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'Data Piu Recente', child: Text('Data Più Recente', style: TextStyle(color: Colors.white))),
                                    const PopupMenuItem(value: 'Data Meno Recente', child: Text('Data Meno Recente', style: TextStyle(color: Colors.white))),
                                  ],
                                ),
                              ],
                            )"""

content = re.sub(r'DropdownButtonHideUnderline\(\s*child: DropdownButton<String>\(\s*dropdownColor: const Color\(0xFF2A2A35\),\s*value: _statusFilter,.*?\.toList\(\),\s*\),\s*\)', new_dropdowns, content, flags=re.DOTALL)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fatto 1!")