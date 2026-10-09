import sys

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'''  Future<List<Map<String, dynamic>>> getScheduledPayments() async {
    final snapshot = await _db.collection('scheduled_payments').get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) {
      String dateA = a['date'] ?? '';
      String dateB = b['date'] ?? '';
      return dateB.compareTo(dateA);
    });
    return docs;
  }'''

replacement = r'''  Future<List<Map<String, dynamic>>> getScheduledPayments() async {
    final snapshot = await _db.collection('scheduled_payments').get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) {
      return compareDates(a['date']?.toString(), b['date']?.toString(), descending: true);
    });
    return docs;
  }'''

content = content.replace(target, replacement)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
