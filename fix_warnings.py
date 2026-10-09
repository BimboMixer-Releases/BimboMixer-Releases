import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Add warning for invoice
code = code.replace(
    "if (wantsMovement) {",
    "if (invoice?['status'] == 'PAID' && status != 'PAID') {\n                              if (mounted) {\n                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ricordati di eliminare il Movimento associato se l\\'avevi creato.', style: TextStyle(color: Colors.orangeAccent))));\n                              }\n                          }\n\n                          if (wantsMovement) {"
)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

with open('lib/screens/deadlines_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Add warning for deadline
code = code.replace(
    "if (wantsMovement) {",
    "if (oldStatus == 'PAID' && newStatus != 'PAID') {\n       if (mounted) {\n         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ricordati di eliminare il Movimento associato se l\\'avevi creato.', style: TextStyle(color: Colors.orangeAccent))));\n       }\n    }\n\n    if (wantsMovement) {"
)

with open('lib/screens/deadlines_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
