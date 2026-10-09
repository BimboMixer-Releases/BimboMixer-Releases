import re

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Trova inizio di _generateNextPaymentId e fine di insertPayment
start_idx = content.find('  Future<String> _generateNextPaymentId() async {')
end_str = '    return nextId;\n  }'
end_idx = content.find(end_str, start_idx) + len(end_str)

if start_idx == -1 or end_idx < len(end_str):
    print("Non trovato!")
    exit(1)

new_code = '''  Future<String> _generateNextPaymentId() async {
    return 'A001';
  }

  Future<void> _initializeCounterIfNeeded() async {
    final counterRef = _db.collection('metadata').doc('payment_counter');
    final counterSnap = await counterRef.get();
    if (counterSnap.exists && counterSnap.data() != null && counterSnap.data()!.containsKey('last_id')) {
      return;
    }
    
    final snapshot = await _db.collection('payments').get();
    String maxId = 'A000';
    for (var doc in snapshot.docs) {
      final id = doc.id;
      if (RegExp(r'^[A-Z]\d{3}$').hasMatch(id)) {
        if (id.compareTo(maxId) > 0) {
          maxId = id;
        }
      }
    }
    
    await counterRef.set({'last_id': maxId}, SetOptions(merge: true));
  }

  Future<String> insertPayment(Map<String, dynamic> payment) async {
    final data = Map<String, dynamic>.from(payment)..remove('id');
    
    await _initializeCounterIfNeeded();

    return await _db.runTransaction((transaction) async {
      final counterRef = _db.collection('metadata').doc('payment_counter');
      final counterSnap = await transaction.get(counterRef);
      
      String currentId = 'A000';
      if (counterSnap.exists && counterSnap.data() != null && counterSnap.data()!.containsKey('last_id')) {
        currentId = counterSnap.data()!['last_id'] as String;
      }
      
      if (!RegExp(r'^[A-Z]\d{3}$').hasMatch(currentId)) {
        currentId = 'A000';
      }
      
      String letter = currentId.substring(0, 1);
      int number = int.parse(currentId.substring(1));
      
      number++;
      if (number > 999) {
        number = 1;
        int charCode = letter.codeUnitAt(0);
        charCode++;
        if (charCode > 90) { // Z is 90
          throw Exception('LIMIT_Z999_REACHED');
        }
        letter = String.fromCharCode(charCode);
      }
      
      final newId = '\\';
      
      final docRef = _db.collection('payments').doc(newId);
      final docSnap = await transaction.get(docRef);
      if (docSnap.exists) {
        throw Exception('DOCUMENT_ALREADY_EXISTS');
      }
      
      transaction.set(counterRef, {'last_id': newId}, SetOptions(merge: true));
      transaction.set(docRef, data);
      
      return newId;
    });
  }'''

content = content[:start_idx] + new_code + content[end_idx:]

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fatto!")