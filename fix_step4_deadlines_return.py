import re

with open('lib/screens/deadlines_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Trova il blocco catch
pattern = re.compile(r'(catch \(e\) \{\s*if \(mounted\) \{\s*setD\(\(\) => isSaving = false\);\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\(content: Text\(\'Errore salvataggio:[^\)]+\)\)\);\s*\}\s*\})', re.DOTALL)

replacement = r'''\1
                                      return;'''

code = pattern.sub(replacement, code)

with open('lib/screens/deadlines_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
