import re

file_path = "lib/screens/payments_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove the Notification Bell and AXION from _buildHeader
header_pattern = r"            // Notification Bell with Badge.*?// AXION Neon Logo.*?\),\n              \),\n            \),"
# actually, let's just find the start and end and replace with nothing
start_marker = "            // Notification Bell with Badge"
end_marker = "              ),\n            ),"

start_idx = content.find(start_marker)
if start_idx != -1:
    end_idx = content.find(end_marker, start_idx)
    if end_idx != -1:
        end_idx += len(end_marker)
        content = content[:start_idx] + content[end_idx:]

# 2. Add _downloadSinglePayment method
if "_downloadSinglePayment" not in content:
    download_method = """  Future<void> _downloadSinglePayment(Map<String, dynamic> p) async {
    final dt = p['date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date'])) : '';
    final imp = p['amount'] != null ? '€ ${p['amount'].toStringAsFixed(2)}' : '';
    final cliente = p['customer_name'] ?? 'N/D';
    final descr = p['description'] ?? 'N/D';
    final tipo = p['type'] ?? 'N/D';
    final metodo = p['payment_method'] ?? 'N/D';
    
    await PDFReportService.generateAndDownloadReport(
      title: 'Dettaglio Movimento',
      headers: ['Campo', 'Valore'],
      data: [
        ['Data', dt],
        ['Cliente', cliente],
        ['Descrizione', descr],
        ['Importo', imp],
        ['Tipo', tipo],
        ['Metodo', metodo],
      ],
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
    );
  }

"""
    # put it before _openAttachment
    content = content.replace("  Future<void> _openAttachment", download_method + "  Future<void> _openAttachment")
    # if pw is not defined, we need to import it, but wait, `pw` is used in pdf_report_service, not here.
    # So we can't use `pw.FlexColumnWidth` easily without importing `package:pdf/widgets.dart as pw`.
    # Let's remove the columnWidths to keep it simple, or import it.
    
    # Better to just omit columnWidths:
    download_method_fixed = """  Future<void> _downloadSinglePayment(Map<String, dynamic> p) async {
    final dt = p['date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date'])) : '';
    final imp = p['amount'] != null ? '€ ${p['amount'].toStringAsFixed(2)}' : '';
    final cliente = p['customer_name'] ?? 'N/D';
    final descr = p['description'] ?? 'N/D';
    final tipo = p['type'] ?? 'N/D';
    final metodo = p['payment_method'] ?? 'N/D';
    
    await PDFReportService.generateAndDownloadReport(
      title: 'Dettaglio Movimento',
      headers: ['Campo', 'Valore'],
      data: [
        ['Data', dt],
        ['Cliente', cliente],
        ['Descrizione', descr],
        ['Importo', imp],
        ['Tipo', tipo],
        ['Metodo', metodo],
      ],
    );
  }

"""
    content = content.replace(download_method, download_method_fixed)

# 3. Update onTap for the download button
# We have `onTap: () => _openAttachment(p),` inside the list item for the 'Down.' button
# Wait, let's do a precise string replace for the Down button's onTap
# It's inside a padding -> column -> icon(download_rounded)
# Let's replace: 
old_on_tap = """                                                      InkWell(
                                                        onTap: () => _openAttachment(p),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: const [
                                                              Icon(Icons.download_rounded, color: Color(0xFF22D3EE), size: 18),
                                                              SizedBox(height: 2),
                                                              Text(
                                                                'Down.',"""

new_on_tap = """                                                      InkWell(
                                                        onTap: () => _downloadSinglePayment(p),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: const [
                                                              Icon(Icons.download_rounded, color: Color(0xFF22D3EE), size: 18),
                                                              SizedBox(height: 2),
                                                              Text(
                                                                'PDF',"""

content = content.replace(old_on_tap, new_on_tap)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Payments screen updated successfully.")
