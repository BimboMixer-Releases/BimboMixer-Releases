import re

path = 'lib/screens/changelog_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()

new_entry = """  {
    'version': '1.8.51',
    'date': '24 Settembre 2026',
    'changes': [
      'Bugfix: risolto errore di compilazione schermata fatture',
      'Fix: corretto loop infinito negli aggiornamenti',
    ]
  },
"""

c = c.replace('final List<Map<String, dynamic>> _changelog = [\n', 'final List<Map<String, dynamic>> _changelog = [\n' + new_entry)

with open(path, 'w', encoding='utf-8') as f:
    f.write(c)

print("Changelog updated.")
