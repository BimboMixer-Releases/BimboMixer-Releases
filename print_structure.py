import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.strip().startswith('class ') or line.strip().startswith('Widget ') or line.strip().startswith('void ') or line.strip().startswith('Future<'):
        print(f"{i+1}: {line.strip()}")
