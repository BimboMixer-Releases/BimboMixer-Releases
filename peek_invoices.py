def extract_build():
    with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    start = content.find('Widget build(BuildContext context) {')
    end = content.find('void _showCustomerSearchDialog')
    if start != -1 and end != -1:
        print(content[start:end])

extract_build()
