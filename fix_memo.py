import re

with open('lib/screens/memo_form_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'bool _isSaving = false;' not in content:
    content = content.replace('bool _isUploading = false;', 'bool _isUploading = false;\n  bool _isSaving = false;')

old_save_memo = 'Future<void> _saveMemo() async {\n    final theme = context.read<AppThemeProvider>();'
new_save_memo = '''Future<void> _saveMemo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
    final theme = context.read<AppThemeProvider>();'''
content = content.replace(old_save_memo, new_save_memo)

old_end = '''} catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(\'Errore durante il salvataggio: $e\')),
        );
      }
    }
  }'''
new_end = '''} catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(\'Errore durante il salvataggio: $e\')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }'''
content = content.replace(old_end, new_end)

content = content.replace('onPressed: _isUploading ? null : _saveMemo,', 'onPressed: (_isUploading || _isSaving) ? null : _saveMemo,')

content = content.replace("'title': data['title'],\n              'attachments': data['attachments'],", "'title': data['title'],\n              'description': data['title'],\n              'status': 'PAID',\n              'attachments': data['attachments'],")
content = content.replace("'title': data['title'],\n              'attachments': data['attachments']", "'title': data['title'],\n              'description': data['title'],\n              'status': 'PAID',\n              'attachments': data['attachments']")

content = content.replace("'PAGATO'", "'SALDATO'")
content = content.replace("Nuova programmazione", "Nuovo pagamento")
content = content.replace("Nuovo Memo", "Nuovo pagamento")

with open('lib/screens/memo_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
