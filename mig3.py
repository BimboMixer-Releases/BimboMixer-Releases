import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = r'''  InvoiceSortType _sortType = InvoiceSortType.number;
  bool _sortAscending = true;'''

replacement1 = r'''  InvoiceSortType _sortType = InvoiceSortType.date;
  bool _sortAscending = false;'''

content = content.replace(target1, replacement1)

target2 = r'''    _sortAscending = prefs.getBool('invoices_sort_ascending') ?? true;'''

replacement2 = r'''    _sortAscending = prefs.getBool('invoices_sort_ascending') ?? false;'''

content = content.replace(target2, replacement2)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
