import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'''..._invoices.take(5).map((inv) {'''
replacement = r'''...(List<Map<String, dynamic>>.from(_invoices)..sort((a, b) => compareDates(a['date']?.toString(), b['date']?.toString(), descending: true))).take(5).map((inv) {'''

content = content.replace(target, replacement)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
