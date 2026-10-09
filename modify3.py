with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('itemCount: _invoices.length,', 'itemCount: _filteredInvoices.length,')
content = content.replace('final invoice = _invoices[index];', 'final invoice = _filteredInvoices[index];')

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
