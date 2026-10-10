import re

with open('lib/screens/memo_form_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_return = """    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per il memo')),
      );
      return;
    }"""

good_return = """    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per il memo')),
      );
      setState(() => _isSaving = false);
      return;
    }"""

content = content.replace(bad_return, good_return)

with open('lib/screens/memo_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
