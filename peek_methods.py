import re
with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

methods = re.findall(r'Future<void>\s+([a-zA-Z0-9_]+)\(', content)
methods += re.findall(r'void\s+([a-zA-Z0-9_]+)\(', content)
methods += re.findall(r'String\s+([a-zA-Z0-9_]+)\(', content)
print("Methods in invoices_screen.dart:", set(methods))
