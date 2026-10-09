import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = re.compile(
    r'(if \(effectiveId == null\) \{\s*final newId = await _dbHelper\.insertInvoice\(data\);\s*data\[\'id\'\] = newId; // capture new ID for movement link\s*\} else \{\s*await _dbHelper\.updateInvoice\(data\);\s*\})',
    re.DOTALL
)

replacement = r'''try {
                            \1
                          } catch (e) {
                            if (mounted) {
                              setSt(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio fattura: ')));
                            }
                            return;
                          }'''

code = pattern.sub(replacement, code)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
