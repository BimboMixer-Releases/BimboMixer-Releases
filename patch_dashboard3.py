# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to remove the block that was inserted mistakenly inside _selectSlice (or anywhere else)
target = '''      double entrateF = 0;
      double usciteF = 0;
      for (var inv in _invoices) {
        if (inv['status'] == 'PAID' || inv['status'] == 'Incassata') {
          entrateF += double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
        }
      }
      for (var p in _globalRecentPayments) {
        if (p['status'] == 'PAID' || p['status'] == 'Pagato') {
          final method = (p['payment_method']?.toString() ?? '').toLowerCase();
          if (method.contains('carta') || method.contains('credito')) {
            double amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            if (p['type'] == 'IN') entrateF += amt;
            else if (p['type'] == 'OUT') usciteF += amt;
          }
        }
      }
      if (usciteF > entrateF) {
        _fiscoWarningColor = Colors.redAccent;
      } else if (usciteF > entrateF * 0.8) {
        _fiscoWarningColor = Colors.orangeAccent;
      } else if (entrateF > 0) {
        _fiscoWarningColor = Colors.greenAccent;
      } else {
        _fiscoWarningColor = null;
      }

      setState(() {'''

# Find all occurrences
parts = content.split(target)

print(f"Found {len(parts) - 1} occurrences.")

# Reconstruct but only keep the first one (which should be in _loadDashboardData)
# Wait, let's verify where the first one is.
# _loadDashboardData is earlier in the file than _selectSlice.
if len(parts) > 1:
    new_content = parts[0] + target + parts[1]
    for p in parts[2:]:
        new_content += "    setState(() {" + p
    
    with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Fixed extra replacements.")

