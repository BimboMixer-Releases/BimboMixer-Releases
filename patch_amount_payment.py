import re

with open('lib/screens/payment_form_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_init = "_amountController.text = payment.amount.toString();"
new_init = "_amountController.text = CurrencyUtils.formatNumber(payment.amount);"

if old_init in content:
    content = content.replace(old_init, new_init)

with open('lib/screens/payment_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Amount init patched in PaymentFormScreen")