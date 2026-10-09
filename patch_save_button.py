import re

with open('lib/screens/payment_form_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Add _isSaving boolean
code = code.replace(
    "bool _isUploading = false;",
    "bool _isUploading = false;\n  bool _isSaving = false;"
)

# Modify _savePayment
save_pattern = re.compile(r'(Future<void> _savePayment\(\) async \{)\s*(if \(_amountController\.text\.isEmpty\) return;)')
replacement = r'''\1
    \2
    if (_isSaving) return;
    setState(() => _isSaving = true);'''
code = save_pattern.sub(replacement, code)

# Modify ElevatedButton
button_pattern = re.compile(r'onPressed:\s*_savePayment,')
button_replacement = r'''onPressed: _isSaving ? null : _savePayment,'''
code = button_pattern.sub(button_replacement, code)

# Modify child text to show loading indicator if _isSaving
text_pattern = re.compile(r"child:\s*Text\(\s*'SALVA PAGAMENTO',\s*style:\s*TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.bold,\s*\),\s*\),")
text_replacement = r'''child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'SALVA PAGAMENTO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),'''
code = text_pattern.sub(text_replacement, code)

with open('lib/screens/payment_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
