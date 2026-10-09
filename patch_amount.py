import re

with open('lib/screens/memo_form_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_init = "_amountCtrl.text = m['amount']?.toString() ?? '';"
new_init = "if (m['amount'] != null) {\n          _amountCtrl.text = CurrencyUtils.formatNumber(double.tryParse(m['amount'].toString()) ?? 0.0);\n        } else {\n          _amountCtrl.text = '';\n        }"

if old_init in content:
    content = content.replace(old_init, new_init)

with open('lib/screens/memo_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Amount init patched")