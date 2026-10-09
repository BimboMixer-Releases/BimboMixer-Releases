with open('lib/screens/deadlines_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import if missing
if 'currency_utils.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/currency_utils.dart';")

# Replace parsing
target = "double.tryParse(amountCtrl.text) ?? 0.0"
replacement = "CurrencyUtils.parseCurrency(amountCtrl.text)"
content = content.replace(target, replacement)

with open('lib/screens/deadlines_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fatto!")