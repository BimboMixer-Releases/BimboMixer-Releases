import os

replacements = {
    "double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0": "CurrencyUtils.parseCurrency(amountCtrl.text)",
    "double.tryParse(\n                                  amountCtrl.text.replaceAll(',', '.')) ??\n                              0.0": "CurrencyUtils.parseCurrency(amountCtrl.text)",
    "double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0": "CurrencyUtils.parseCurrency(_amountCtrl.text)",
    "double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0": "CurrencyUtils.parseCurrency(_amountController.text)",
    "double.tryParse(subtotalCtrl.text.replaceAll(',', '.')) ?? 0.0": "CurrencyUtils.parseCurrency(subtotalCtrl.text)",
    "double.tryParse(taxCtrl.text.replaceAll(',', '.')) ?? 0.0": "CurrencyUtils.parseCurrency(taxCtrl.text)",
    "double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? 0.0": "CurrencyUtils.parseCurrency(totalCtrl.text)",
}

files = [
    'lib/screens/invoices_screen.dart',
    'lib/screens/memo_form_screen.dart',
    'lib/screens/payment_form_screen.dart',
    'lib/screens/quotes_screen.dart'
]

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'currency_utils.dart' not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/currency_utils.dart';")
        content = content.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\nimport 'package:contabile_app/utils/currency_utils.dart';")

    # Applica il fallback con multi-line matching
    import re
    content = re.sub(r"double\.tryParse\(\s*amountCtrl\.text\.replaceAll\(',', '\.'\)\s*\)\s*\?\?\s*0\.0", "CurrencyUtils.parseCurrency(amountCtrl.text)", content)

    for old, new in replacements.items():
        content = content.replace(old, new)
        
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print("Fatto 2!")