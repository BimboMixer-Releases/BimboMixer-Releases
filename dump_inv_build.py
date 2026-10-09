with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('Widget build(BuildContext context) {')
end = content.find('void _showCustomerSearchDialog', start)
print(content[start:end])
