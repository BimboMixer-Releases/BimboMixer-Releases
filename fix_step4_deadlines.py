import re

with open('lib/screens/deadlines_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = re.compile(
    r'(if \(deadline == null\) \{\s*await _dbHelper\.insertDeadline\(data\);\s*\} else \{\s*await _dbHelper\.updateDeadline\(data\);\s*\})',
    re.DOTALL
)

replacement = r'''try {
                                      \1
                                      if (mounted) Navigator.pop(ctx);
                                      _loadDeadlines();
                                    } catch (e) {
                                      if (mounted) {
                                        setD(() => isSaving = false);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: ')));
                                      }
                                    }'''

code = pattern.sub(replacement, code)

# Rimuovi i pop e load originali
code = re.sub(r'(\s*if \(mounted\) Navigator\.pop\(ctx\);\s*_loadDeadlines\(\);)', '', code, count=1)

with open('lib/screens/deadlines_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

