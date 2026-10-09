import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:contabile_app/screens/memo_form_screen.dart';" not in content:
    content = content.replace("import 'package:contabile_app/screens/scheduled_payments_screen.dart';",
                              "import 'package:contabile_app/screens/scheduled_payments_screen.dart';\nimport 'package:contabile_app/screens/memo_form_screen.dart';")

old_push = "await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentFormScreen(isScheduled: true)));"
new_push = "await Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoFormScreen()));"

content = content.replace(old_push, new_push)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Dashboard patched!")