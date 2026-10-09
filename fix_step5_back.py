import re

with open('lib/screens/reports_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Trova: if (MediaQuery.of(context).size.width < 600)
# Sostituisci con: if (Navigator.canPop(context))
code = code.replace("if (MediaQuery.of(context).size.width < 600)", "if (Navigator.canPop(context))")

with open('lib/screens/reports_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

