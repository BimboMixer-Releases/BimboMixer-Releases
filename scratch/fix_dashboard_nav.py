import re

file_path = "lib/screens/dashboard_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix the navigation from the Dropdown and the Empty State button
content = content.replace("Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceFormScreen()));", "Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen(openDialog: true)));")
content = content.replace("Navigator.push(context, MaterialPageRoute(builder: (_) => const DeadlineFormScreen()));", "Navigator.push(context, MaterialPageRoute(builder: (_) => const DeadlinesScreen(openDialog: true)));")
content = content.replace("Navigator.push(context, MaterialPageRoute(builder: (_) => const QuoteFormScreen()));", "Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotesScreen(openDialog: true)));")

# Also the imports
content = content.replace("import 'package:contabile_app/screens/invoice_form_screen.dart';", "")
content = content.replace("import 'package:contabile_app/screens/deadline_form_screen.dart';", "")
content = content.replace("import 'package:contabile_app/screens/quote_form_screen.dart';", "import 'package:contabile_app/screens/quotes_screen.dart';")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Navigation in Dashboard fixed!")
