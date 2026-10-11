import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

old_call = r'''await _dbHelper.updateQuote(quote['id'], {'items': itemsList});'''
new_call = r'''await _dbHelper.updateQuote(quote);'''

code = code.replace(old_call, new_call)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("fixed db update")
