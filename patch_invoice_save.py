import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace("bool isUploading = false;", "bool isUploading = false;\n      bool isSaving = false;")

pattern = re.compile(r'onPressed: isUploading\s+\?\s+null\s+:\s+\(\) async \{')
replacement = r'''onPressed: (isUploading || isSaving)
                      ? null
                      : () async {
                          setSt(() => isSaving = true);
'''
code = pattern.sub(replacement, code)

code = code.replace("child: Text('Salva'),", "child: isSaving ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Salva'),")

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

