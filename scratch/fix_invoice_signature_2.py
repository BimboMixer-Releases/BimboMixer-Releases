import os
import re

def fix_payment_summary():
    file_path = "lib/screens/payment_summary_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove the bad import
    content = content.replace("import 'package:contabile_app/screens/invoice_form_screen.dart';", "")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

def fix_invoice_summary():
    file_path = "lib/screens/invoice_summary_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    # We will manually replace the file sections.
    # We know my script just failed to match regex.
    new_lines = []
    skip = False
    
    for i, line in enumerate(lines):
        if "import 'package:contabile_app/screens/invoice_form_screen.dart';" in line:
            continue
            
        if "class InvoiceSummaryScreen extends StatefulWidget" in line:
            new_lines.append("class InvoiceSummaryScreen extends StatefulWidget {\n")
            new_lines.append("  final Map<String, dynamic> invoice;\n")
            new_lines.append("  final Function(Map<String, dynamic>) onEdit;\n")
            new_lines.append("  const InvoiceSummaryScreen({super.key, required this.invoice, required this.onEdit});\n")
            skip = True
            continue
            
        if skip and "class _InvoiceSummaryScreenState extends State<InvoiceSummaryScreen>" in line:
            skip = False
            
        if skip:
            continue
            
        if "Future<void> _loadData() async {" in line:
            new_lines.append("  Future<void> _loadData() async {\n")
            new_lines.append("    setState(() => _isLoading = true);\n")
            new_lines.append("    final pData = widget.invoice;\n")
            new_lines.append("    _data = pData;\n")
            new_lines.append("    if (pData != null) {\n")
            skip = True
            continue
            
        if skip and "final custId = pData['customer_id'];" in line:
            new_lines.append(line)
            skip = False
            continue
            
        if skip:
            continue
            
        if "HoverEditButton(" in line:
            new_lines.append(line)
            # Next line has onTap
            new_lines.append("                        onTap: () async {\n")
            new_lines.append("                          bool authorized = await SecurityUtils.requireAdminAuth(context);\n")
            new_lines.append("                          if (!authorized || !context.mounted) return;\n")
            new_lines.append("                          widget.onEdit(widget.invoice);\n")
            new_lines.append("                        },\n")
            skip = True
            continue
            
        if skip and ")," in line and "HoverEditButton" not in line:
            # We skip until we close HoverEditButton
            if i > 0 and "}" in lines[i-1]:
                new_lines.append("                      ),\n")
                skip = False
            continue
            
        if skip:
            continue
            
        new_lines.append(line)

    with open(file_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print("Fixed invoice_summary_screen.dart")

fix_payment_summary()
fix_invoice_summary()
