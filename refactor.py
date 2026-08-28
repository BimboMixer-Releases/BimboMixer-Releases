import os

file_path = 'lib/screens/payment_form_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add isScheduled flag
content = content.replace(
    'final bool isReadOnly;',
    'final bool isReadOnly;\n  final bool isScheduled;'
)
content = content.replace(
    'const PaymentFormScreen({super.key, this.paymentId, this.isReadOnly = false});',
    'const PaymentFormScreen({super.key, this.paymentId, this.isReadOnly = false, this.isScheduled = false});'
)

# Fix title
content = content.replace(
    '''  String get _appBarTitle {
    if (widget.isReadOnly) return 'Dettaglio Pagamento';
    return widget.paymentId == null ? 'Nuovo Pagamento' : 'Modifica Pagamento';
  }''',
    '''  String get _appBarTitle {
    final prefix = widget.isScheduled ? 'Programmato' : 'Pagamento';
    if (widget.isReadOnly) return 'Dettaglio \';
    return widget.paymentId == null ? 'Nuovo \' : 'Modifica \';
  }'''
)

# Fix _loadData reading
content = content.replace(
    'final paymentData = await _dbHelper.getPaymentById(widget.paymentId!);',
    'final paymentData = widget.isScheduled \n          ? await _dbHelper.getScheduledPaymentById(widget.paymentId!)\n          : await _dbHelper.getPaymentById(widget.paymentId!);'
)

# Fix update/insert
content = content.replace(
    'await _dbHelper.updatePayment(data);',
    'if (widget.isScheduled) {\n        await _dbHelper.updateScheduledPayment(data);\n      } else {\n        await _dbHelper.updatePayment(data);\n      }'
)
content = content.replace(
    'final newId = await _dbHelper.insertPayment(data);',
    'final newId = widget.isScheduled \n          ? await _dbHelper.insertScheduledPayment(data) \n          : await _dbHelper.insertPayment(data);'
)
content = content.replace(
    'await _dbHelper.insertPayment(newPayment.toMap());',
    'if (widget.isScheduled) {\n          await _dbHelper.insertScheduledPayment(newPayment.toMap());\n        } else {\n          await _dbHelper.insertPayment(newPayment.toMap());\n        }'
)
content = content.replace(
    'await _dbHelper.updatePayment(newPayment.toMap());',
    'if (widget.isScheduled) {\n          await _dbHelper.updateScheduledPayment(newPayment.toMap());\n        } else {\n          await _dbHelper.updatePayment(newPayment.toMap());\n        }'
)
content = content.replace(
    '_dbHelper.updatePayment(newPayment.toMap());',
    'if (widget.isScheduled) {\n                                        _dbHelper.updateScheduledPayment(newPayment.toMap());\n                                      } else {\n                                        _dbHelper.updatePayment(newPayment.toMap());\n                                      }'
)

# Fix recursive call inside _PaymentFormScreenState
content = content.replace(
    'PaymentFormScreen(paymentId: widget.paymentId, isReadOnly: false)',
    'PaymentFormScreen(paymentId: widget.paymentId, isReadOnly: false, isScheduled: widget.isScheduled)'
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated payment_form_screen.dart")

# Now update scheduled_payments_screen.dart to use PaymentFormScreen
sp_path = 'lib/screens/scheduled_payments_screen.dart'
with open(sp_path, 'r', encoding='utf-8') as f:
    sp_content = f.read()

sp_content = sp_content.replace(
    "import 'package:contabile_app/screens/scheduled_payment_form_screen.dart';",
    "import 'package:contabile_app/screens/payment_form_screen.dart';"
)
sp_content = sp_content.replace(
    'const ScheduledPaymentFormScreen()',
    'const PaymentFormScreen(isScheduled: true)'
)
sp_content = sp_content.replace(
    "ScheduledPaymentFormScreen(paymentId: p['id'])",
    "PaymentFormScreen(paymentId: p['id'], isScheduled: true)"
)

with open(sp_path, 'w', encoding='utf-8') as f:
    f.write(sp_content)

print("Updated scheduled_payments_screen.dart")
