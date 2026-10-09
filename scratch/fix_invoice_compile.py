import re

# Fix invoice_summary_screen.dart
path1 = "lib/screens/invoice_summary_screen.dart"
with open(path1, "r", encoding="utf-8") as f:
    content1 = f.read()

# 1. Remove InvoiceFormScreen import
content1 = re.sub(r"import 'package:contabile_app/screens/invoice_form_screen\.dart';\n", "", content1)

# 2. Add onEdit callback
new_constructor = """class InvoiceSummaryScreen extends StatefulWidget {
  final String invoiceId;
  final Function(Map<String, dynamic>)? onEdit;

  const InvoiceSummaryScreen({super.key, required this.invoiceId, this.onEdit});"""
content1 = re.sub(
    r"class InvoiceSummaryScreen extends StatefulWidget \{.*?const InvoiceSummaryScreen\(\{super\.key, required this\.invoiceId\}\);",
    new_constructor,
    content1,
    flags=re.DOTALL
)

# 3. Replace the HoverEditButton onTap
new_on_tap = """                      HoverEditButton(
                        onTap: () async {
                          bool authorized = await SecurityUtils.requireAdminAuth(context);
                          if (!authorized || !context.mounted || _data == null) return;
                          if (widget.onEdit != null) {
                            widget.onEdit!(_data!);
                          }
                        },
                      ),"""
content1 = re.sub(
    r"HoverEditButton\(\s*onTap: \(\) async \{\s*bool authorized = await SecurityUtils\.requireAdminAuth\(context\);\s*if \(\!authorized \|\| \!context\.mounted\) return;\s*await Navigator\.push\(context, MaterialPageRoute\(builder: \(\_\) => InvoiceFormScreen\(invoiceId: widget\.invoiceId, isReadOnly: false\)\)\);\s*_loadData\(\);\s*\},.*?\},",
    new_on_tap + "\n                      }",
    content1,
    flags=re.DOTALL
)
# Wait, my regex might fail. Let's do a simple replace.
content1 = content1.replace(
    "await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceFormScreen(invoiceId: widget.invoiceId, isReadOnly: false))); \n                          _loadData();",
    "if (widget.onEdit != null) widget.onEdit!(_data!); Navigator.pop(context, true);"
)

with open(path1, "w", encoding="utf-8") as f:
    f.write(content1)

# Fix invoices_screen.dart
path2 = "lib/screens/invoices_screen.dart"
with open(path2, "r", encoding="utf-8") as f:
    content2 = f.read()

content2 = content2.replace(
    """                            builder: (_) => InvoiceSummaryScreen(
                              invoice: invoice,
                              onEdit: (invoiceData) {
                                _showInvoiceDialog(invoice: invoiceData, isReadOnly: false);
                              },
                            ),""",
    """                            builder: (_) => InvoiceSummaryScreen(
                              invoiceId: invoice['id'].toString(),
                              onEdit: (invoiceData) {
                                _showInvoiceDialog(invoice: invoiceData, isReadOnly: false);
                              },
                            ),"""
)

with open(path2, "w", encoding="utf-8") as f:
    f.write(content2)

print("Fixed compile errors.")
