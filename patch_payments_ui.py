import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the text labels
content = content.replace("'Invoices & Transactions'", "'Movimenti'")
content = content.replace("'Transactions Overview'", "'Riepilogo'")
content = content.replace("'Invoice ID'", "'ID'")
content = content.replace("'Client Name'", "'Cliente'")
content = content.replace("'Date'", "'Data'")
content = content.replace("'Description'", "'Descrizione'")
content = content.replace("'Amount'", "'Importo'")
content = content.replace("'Status'", "'Stato'")
content = content.replace("'Action'", "'Azioni'")

# Replace _formatInvoiceId
content = content.replace("final invoiceId = _formatInvoiceId(index);", "final invoiceId = p['document_id']?.toString() ?? p['id']?.toString() ?? '';")

# Add the sort dropdown to the UI near the popup menu
sort_ui = """
                                  Row(
                                    children: [
                                      Theme(
                                        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF16192B)),
                                        child: DropdownButton<String>(
                                          value: _sortType,
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          underline: const SizedBox(),
                                          icon: const Icon(Icons.sort, color: Colors.white54, size: 20),
                                          items: ['Data Piu Recente', 'Data Meno Recente', 'Importo Maggiore', 'Importo Minore']
                                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _sortType = val);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
"""
content = content.replace("PopupMenuButton<String>(", sort_ui, 1)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("UI patched")