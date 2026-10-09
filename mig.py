import sys

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'''  bool _paymentsMigrationDone = false;

  Future<List<Map<String, dynamic>>> getPayments({int? year, String? startDate, String? endDate}) async {
    Query query = _db.collection('payments');
    
    if (startDate != null && endDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate).where('date', isLessThanOrEqualTo: endDate);
    } else if (year != null) {
      String start = "$year-01-01";
      String end = "${year + 1}-01-01";
      query = query.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
    }
    
    final snapshot = await query.get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    if (!_paymentsMigrationDone) {
      _paymentsMigrationDone = true;
      final oldDocs = docs.where((d) => !RegExp(r'^[A-Z]\d{3}$').hasMatch(d['id'].toString())).toList();
      if (oldDocs.isNotEmpty) {
        oldDocs.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
        for (var p in oldDocs) {
          try {
            await insertPayment(p);
            await deletePayment(p['id']);
          } catch (e) {
            print('Migration error: $e');
          }
        }
        return getPayments(year: year, startDate: startDate, endDate: endDate);
      }
    }'''

replacement = r'''  bool _paymentsMigrationDone = false;
  
  Future<void> _runPaymentsRenumberingMigration() async {
    try {
      final configSnap = await _db.collection('metadata').doc('app_config').get();
      if (configSnap.exists && configSnap.data()?['migration_a001_done'] == true) {
        return;
      }
      
      final snapshot = await _db.collection('payments').get();
      if (snapshot.docs.isEmpty) {
        await _db.collection('metadata').doc('app_config').set({'migration_a001_done': true}, SetOptions(merge: true));
        return;
      }
      
      var docs = snapshot.docs.map((d) {
        final data = d.data();
        data['original_id'] = d.id;
        return data;
      }).toList();
      
      docs.sort((a, b) => compareDates(a['date']?.toString(), b['date']?.toString(), descending: false));
      
      var batch = _db.batch();
      int count = 0;
      
      int number = 1;
      String letter = 'A';
      String lastId = 'A000';
      
      for (var doc in docs) {
        final originalId = doc['original_id'] as String;
        
        if (number > 999) {
           number = 1;
           letter = String.fromCharCode(letter.codeUnitAt(0) + 1);
        }
        final newId = '';
        lastId = newId;
        number++;
        
        final data = Map<String, dynamic>.from(doc)..remove('original_id')..remove('id');
        
        if (originalId != newId) {
          batch.delete(_db.collection('payments').doc(originalId));
        }
        batch.set(_db.collection('payments').doc(newId), data);
        
        count++;
        if (count >= 480) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
      
      final counterRef = _db.collection('metadata').doc('payment_counter');
      batch.set(counterRef, {'last_id': lastId});
      batch.set(_db.collection('metadata').doc('app_config'), {'migration_a001_done': true}, SetOptions(merge: true));
      
      await batch.commit();
      print('Migration A001 completata con successo. Ultimo ID: $lastId');
    } catch (e) {
      print('Errore migrazione A001: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPayments({int? year, String? startDate, String? endDate}) async {
    if (!_paymentsMigrationDone) {
      _paymentsMigrationDone = true;
      await _runPaymentsRenumberingMigration();
    }
  
    Query query = _db.collection('payments');
    
    if (startDate != null && endDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate).where('date', isLessThanOrEqualTo: endDate);
    } else if (year != null) {
      String start = "$year-01-01";
      String end = "${year + 1}-01-01";
      query = query.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
    }
    
    final snapshot = await query.get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();'''

content = content.replace(target, replacement)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
