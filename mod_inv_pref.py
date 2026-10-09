with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'package:shared_preferences/shared_preferences.dart' not in content:
    content = content.replace('import ''package:flutter/material.dart'';', 'import ''package:flutter/material.dart'';\nimport ''package:shared_preferences/shared_preferences.dart'';')

target_init = '''  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.openDialog) _showInvoiceDialog();
    });
    _loadData();
  }'''

replacement_init = '''  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.openDialog) _showInvoiceDialog();
    });
    _loadPrefsAndData();
  }

  Future<void> _loadPrefsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final typeIdx = prefs.getInt('invoices_sort_type');
      if (typeIdx != null && typeIdx < InvoiceSortType.values.length) {
        _sortType = InvoiceSortType.values[typeIdx];
      }
      _sortAscending = prefs.getBool('invoices_sort_ascending') ?? true;
    });
    await _loadData();
  }'''

content = content.replace(target_init, replacement_init)

target_menu = '''                setState(() {
                  if (val == 'Numero (Decrescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = false;
                  } else if (val == 'Numero (Crescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = true;
                  } else if (val == 'Data Più Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = false; 
                  } else if (val == 'Data Meno Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = true;
                  }
                });'''

replacement_menu = '''                setState(() {
                  if (val == 'Numero (Decrescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = false;
                  } else if (val == 'Numero (Crescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = true;
                  } else if (val == 'Data Più Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = false; 
                  } else if (val == 'Data Meno Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = true;
                  }
                });
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setInt('invoices_sort_type', _sortType.index);
                  prefs.setBool('invoices_sort_ascending', _sortAscending);
                });'''

content = content.replace(target_menu, replacement_menu)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
