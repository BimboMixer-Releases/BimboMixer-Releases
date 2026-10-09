import sys
import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'import ''../utils/sort_utils.dart'';' not in content:
    content = content.replace('import ''package:provider/provider.dart'';', 'import ''package:provider/provider.dart'';\nimport ''../utils/sort_utils.dart'';')

target = r'''    // Ordina per data in base alle preferenze
    final sortedPayments = List<Map<String, dynamic>>.from(_globalRecentPayments)
      ..sort((a, b) {
        final da = a['date']?.toString() ?? '';
        final db = b['date']?.toString() ?? '';
        DateTime? dtA, dtB;
        try {
            final pA = da.split('/');
            if(pA.length==3) dtA = DateTime(int.parse(pA[2]), int.parse(pA[1]), int.parse(pA[0]));
        }catch(_){}
        try {
            final pB = db.split('/');
            if(pB.length==3) dtB = DateTime(int.parse(pB[2]), int.parse(pB[1]), int.parse(pB[0]));
        }catch(_){}
        if(dtA != null && dtB != null) return _sortPaymentsAscending ? dtA.compareTo(dtB) : dtB.compareTo(dtA);
        return _sortPaymentsAscending ? da.compareTo(db) : db.compareTo(da);
      });'''

replacement = r'''    // Ordina in modo fisso dal pi recente al meno recente (descending: true)
    final sortedPayments = List<Map<String, dynamic>>.from(_globalRecentPayments)
      ..sort((a, b) => compareDates(a['date']?.toString(), b['date']?.toString(), descending: true));'''

content = content.replace(target, replacement)

# Do the same for invoices if any
target_inv = r'''            ..._invoices.take(5).map((inv) {'''
replacement_inv = r'''            ...(List<Map<String, dynamic>>.from(_invoices)..sort((a, b) => compareDates(a['date']?.toString(), b['date']?.toString(), descending: true))).take(5).map((inv) {'''
content = content.replace(target_inv, replacement_inv)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
