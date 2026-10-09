import sys
import re

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import if missing
if 'import ''../utils/sort_utils.dart'';' not in content:
    content = content.replace('import ''package:cloud_firestore/cloud_firestore.dart'';', 'import ''package:cloud_firestore/cloud_firestore.dart'';\nimport ''../utils/sort_utils.dart'';')

target1 = r'''    // Ordina per data discendente (ultimi inseriti prima)
    docs.sort((a, b) {
      String dateA = a['date'] ?? '';
      String dateB = b['date'] ?? '';
      return dateB.compareTo(dateA);
    });'''

replacement1 = r'''    // Ordina per data discendente (ultimi inseriti prima)
    docs.sort((a, b) {
      return compareDates(a['date']?.toString(), b['date']?.toString(), descending: true);
    });'''

content = content.replace(target1, replacement1)

target2 = r'''      // Sort in memory to avoid requiring a composite index in Firestore
      docs.sort((a, b) {
        String dateA = a['date'] ?? '';
        String dateB = b['date'] ?? '';
        return dateB.compareTo(dateA); // descending
      });'''

replacement2 = r'''      // Sort in memory to avoid requiring a composite index in Firestore
      docs.sort((a, b) {
        return compareDates(a['date']?.toString(), b['date']?.toString(), descending: true);
      });'''

content = content.replace(target2, replacement2)

target3 = r'''    final docs = snapshot.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      String dateA = a['date'] ?? '';
      String dateB = b['date'] ?? '';
      return dateB.compareTo(dateA);
    });'''

replacement3 = r'''    final docs = snapshot.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      return compareDates(a['date']?.toString(), b['date']?.toString(), descending: true);
    });'''

content = content.replace(target3, replacement3)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
