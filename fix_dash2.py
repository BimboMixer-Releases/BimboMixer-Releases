import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_unpaid = """      int memoUnpaidFatture = _memoEvents.where((m) => m['memo_type']?.toString().toUpperCase() == 'FATTURA' && 
m['memo_status']?.toString().toUpperCase() != 'PAGATO').length;"""
new_unpaid = """      int memoUnpaidFatture = _memoEvents.where((m) => m['memo_type']?.toString().toUpperCase() == 'FATTURA' && m['memo_status']?.toString().toUpperCase() != 'PAGATO' && m['memo_status']?.toString().toUpperCase() != 'SALDATO').length;"""

content = content.replace(old_unpaid, new_unpaid)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
