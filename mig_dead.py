import sys

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'''  Future<List<Map<String, dynamic>>> getDeadlines() async {
    final snapshot = await _db.collection('deadlines').orderBy('date').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }'''

replacement = r'''  Future<List<Map<String, dynamic>>> getDeadlines() async {
    final snapshot = await _db.collection('deadlines').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    // Deadlines usually ascending (earliest first)
    docs.sort((a, b) => compareDates(a['date']?.toString(), b['date']?.toString(), descending: false));
    return docs;
  }'''

content = content.replace(target, replacement)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
