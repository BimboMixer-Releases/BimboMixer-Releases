import re

with open('lib/screens/payment_form_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = re.compile(
    r'(if \(effectiveId == null\) \{\s*await _dbHelper\.insertPayment\(data\);\s*\} else \{\s*await _dbHelper\.updatePayment\(data\);\s*\})',
    re.DOTALL
)

replacement = r'''try {
      \1
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: ')));
      }
    }'''

code = pattern.sub(replacement, code)

# Rimuovi il Navigator.pop originale se c'Ã¨, visto che l'ho spostato nel try block
code = re.sub(r'(\s*if \(mounted\) Navigator\.pop\(context,\s*true\);)', '', code, count=1)

with open('lib/screens/payment_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

