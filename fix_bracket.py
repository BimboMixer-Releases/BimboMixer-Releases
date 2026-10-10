import re

with open('lib/screens/memo_form_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad = """Future<void> _saveMemo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
    final theme = context.read<AppThemeProvider>();"""

good = """Future<void> _saveMemo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final theme = context.read<AppThemeProvider>();"""

content = content.replace(bad, good)

with open('lib/screens/memo_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
