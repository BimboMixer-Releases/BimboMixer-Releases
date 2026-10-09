with open('lib/screens/payment_summary_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''    final displayId = 'N. 2026/0' + _data!['id'].toString().padLeft(3, '0');'''
replacement = '''    final displayId = 'ID: ' + (_data!['id']?.toString() ?? '');'''

content = content.replace(target, replacement)

with open('lib/screens/payment_summary_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
