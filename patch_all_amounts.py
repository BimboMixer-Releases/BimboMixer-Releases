import re
import os

files = [
    'lib/screens/invoices_screen.dart',
    'lib/screens/memo_form_screen.dart',
    'lib/screens/payment_form_screen.dart',
    'lib/screens/quotes_screen.dart'
]

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add import if missing
    if 'currency_utils.dart' not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/currency_utils.dart';")
        content = content.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\nimport 'package:contabile_app/utils/currency_utils.dart';")

    # Pattern for double.tryParse(var.replaceAll(',', '.')) ?? 0.0
    # Also handles cases with / without space, and nested replaces
    content = re.sub(r'double\.tryParse\(([^)]+)\.text(?:[^)]*)\)\s*\?\?\s*0\.0', r'CurrencyUtils.parseCurrency(\1.text)', content)
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print("Fatto per tutti i file!")