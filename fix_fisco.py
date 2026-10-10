import re

with open('lib/screens/bilancio_fisco_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

fisco_logic = """
      double entrateF = 0;
      double usciteF = 0;

      for (var inv in invoices) {
        if (inv['status'] == 'PAID' || inv['status'] == 'Incassata') {
          entrateF += double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
        }
      }

      for (var p in payments) {
        if (p['status'] == 'PAID' || p['status'] == 'Pagato') {
          final method = (p['payment_method']?.toString() ?? '').toLowerCase();
          if (method.contains('carta') || method.contains('credito')) {
            double amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            if (p['type'] == 'IN') entrateF += amt;
            else if (p['type'] == 'OUT') usciteF += amt;
          }
        }
      }
"""

new_fisco_logic = """
      double entrateF = 0;
      double usciteF = 0;
      Set<String> paidInvoiceIds = {};

      for (var inv in invoices) {
        String status = (inv['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'INCASSATA' || status == 'SALDATO') {
          entrateF += double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
          if (inv['id'] != null) {
            paidInvoiceIds.add(inv['id'].toString());
          }
        }
      }

      for (var p in payments) {
        String status = (p['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'SALDATO' || status == 'PAGATO') {
          String? invId = p['invoice_id']?.toString();
          if (invId != null && invId.isNotEmpty && paidInvoiceIds.contains(invId)) {
            continue; // Evita doppio conteggio
          }

          final method = (p['payment_method']?.toString() ?? '').toLowerCase();
          if (method.contains('carta') || method.contains('credito') || method.contains('bancomat')) {
            double amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            if (p['type'] == 'IN') entrateF += amt;
            else if (p['type'] == 'OUT') usciteF += amt;
          }
        }
      }
"""
content = content.replace(fisco_logic.strip(), new_fisco_logic.strip())

with open('lib/screens/bilancio_fisco_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
