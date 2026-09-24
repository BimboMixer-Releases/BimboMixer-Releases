import os
import re

def fix_invoice_summary():
    file_path = "lib/screens/invoice_summary_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Remove the import of invoice_form_screen.dart
    content = content.replace("import 'package:contabile_app/screens/invoice_form_screen.dart';", "")

    # 2. Fix the signature of InvoiceSummaryScreen
    old_sig = r"""class InvoiceSummaryScreen extends StatefulWidget \{
  final String invoiceId;

  const InvoiceSummaryScreen\(\{super\.key, required this\.invoiceId\}\);"""
    
    new_sig = """class InvoiceSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final Function(Map<String, dynamic>) onEdit;

  const InvoiceSummaryScreen({super.key, required this.invoice, required this.onEdit});"""
    content = re.sub(old_sig, new_sig, content)

    # 3. Fix _loadData() and _data assignments
    old_load_data = r"""  Future<void> _loadData\(\) async \{
    setState\(\(\) => _isLoading = true\);
    
    final pData = await _dbHelper.getInvoiceById\(widget\.invoiceId\);
    if \(pData != null\) \{
      _data = pData;"""
    
    new_load_data = """  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final pData = widget.invoice;
    _data = pData;
    if (pData != null) {"""
    content = re.sub(old_load_data, new_load_data, content)

    # 4. Fix Edit button logic
    old_edit = r"""                      HoverEditButton\(
                        onTap: \(\) async \{
                          bool authorized = await SecurityUtils\.requireAdminAuth\(context\);
                          if \(\!authorized \|\| \!context\.mounted\) return;
                          await Navigator\.push\(context, MaterialPageRoute\(builder: \(_\) => InvoiceFormScreen\(invoiceId: widget\.invoiceId, isReadOnly: false\)\)\); 
                          _loadData\(\);
                        \},
                      \),"""
    
    new_edit = """                      HoverEditButton(
                        onTap: () async {
                          bool authorized = await SecurityUtils.requireAdminAuth(context);
                          if (!authorized || !context.mounted) return;
                          widget.onEdit(widget.invoice);
                        },
                      ),"""
    content = re.sub(old_edit, new_edit, content)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed invoice_summary_screen.dart")

fix_invoice_summary()
