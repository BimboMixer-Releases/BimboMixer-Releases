import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

class_level = 0
for i, line in enumerate(lines):
    if 'class _InvoicesScreenState' in line:
        class_level += line.count('{') - line.count('}')
        print(f"Start class at {i+1}")
    elif class_level > 0:
        class_level += line.count('{') - line.count('}')
        if class_level == 0:
            print(f"Class closed at line {i+1}")
            break
