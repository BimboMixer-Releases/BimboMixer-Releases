import re

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We'll replace _generateNextPaymentId and insertPayment.

old_generate = '''  Future<String> _generateNextPaymentId() async {
    try {
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
      
      if (maxId == 'A000') {
        return 'A001';
      }
      
      String letter = maxId.substring(0, 1);
      int number = int.parse(maxId.substring(1));
      
      number++;
      if (number > 999) {
        number = 1;
        int charCode = letter.codeUnitAt(0);
        charCode++;
        letter = String.fromCharCode(charCode);
      }
      
      return '\\';
    } catch (e) {
      return 'A001';
    }
  }'''

old_insert = '''  Future<String> insertPayment(Map<String, dynamic> payment) async {
    final data = Map<String, dynamic>.from(payment)..remove('id');
    final nextId = await _generateNextPaymentId();
    await _db.collection('payments').doc(nextId).set(data);
    return nextId;
  }'''

new_generate_and_insert = '''  Future<String> _generateNextPaymentId() async {
    // This is no longer used for insertion, kept for other internal logic if any
    return 'A001'; 
  }

  Future<void> _initializeCounterIfNeeded() async {
    final counterRef = _db.collection('metadata').doc('payment_counter');
    final counterSnap = await counterRef.get();
    if (counterSnap.exists && counterSnap.data() != null && counterSnap.data()!.containsKey('last_id')) {
      return;
    }
    
    // Compute max from existing payments to initialize counter safely
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
    
    // Assicura che il contatore esista per la transazione
    await _initializeCounterIfNeeded();

    final nextId = await _db.runTransaction((transaction) async {
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
        if (charCode > 90) { // 'Z' is 90
          throw Exception('LIMIT_Z999_REACHED');
        }
        letter = String.fromCharCode(charCode);
      }
      
      final newId = '\\';
      
      // Controllo di non sovrascrivere un record esistente (in caso di modifiche manuali fuori sistema)
      final docRef = _db.collection('payments').doc(newId);
      final docSnap = await transaction.get(docRef);
      if (docSnap.exists) {
        throw Exception('DOCUMENT_ALREADY_EXISTS');
      }
      
      transaction.set(counterRef, {'last_id': newId}, SetOptions(merge: true));
      transaction.set(docRef, data);
      
      return newId;
    });
    
    return nextId;
  }'''

content = content.replace(old_generate, '')
content = content.replace(old_insert, new_generate_and_insert)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)