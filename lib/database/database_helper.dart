import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/password_hasher.dart';
import '../utils/crypto_utils.dart';

class DatabaseHelper {
  static DatabaseHelper _instance = DatabaseHelper._internal();
  static void setMockInstance(DatabaseHelper mock) { _instance = mock; }
  FirebaseFirestore _db = FirebaseFirestore.instance;
  static void setMockFirestore(FirebaseFirestore mock) { _instance._db = mock; }

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Utente attualmente loggato, usato per l'Audit Log
  String? currentUser;

  // --- CRUD USERS ---
  Future<List<Map<String, dynamic>>> getUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<String> insertUser(Map<String, dynamic> user) async {
    final data = Map<String, dynamic>.from(user)..remove('id');
    // Hash della password se non è già hashata
    if (data['password_hash'] != null && !PasswordHasher.isHashed(data['password_hash'])) {
      data['password_hash'] = PasswordHasher.hashPassword(data['password_hash']);
    }
    final docRef = await _db.collection('users').add(data);
    
    if (currentUser != null) {
      await logAuditEvent(
        username: currentUser!,
        eventType: 'CREATE',
        severity: 'HIGH',
        description: 'Creazione nuovo utente: ${data['username']}',
        targetCollection: 'users',
        targetId: docRef.id,
      );
    }
    return docRef.id;
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    final id = user['id'];
    final data = Map<String, dynamic>.from(user)..remove('id');
    // Hash della password se è stata cambiata e non è già hashata
    if (data['password_hash'] != null && !PasswordHasher.isHashed(data['password_hash'])) {
      data['password_hash'] = PasswordHasher.hashPassword(data['password_hash']);
    }
    await _db.collection('users').doc(id).update(data);

    if (currentUser != null) {
      await logAuditEvent(
        username: currentUser!,
        eventType: 'UPDATE',
        severity: 'HIGH',
        description: 'Modifica utente: ${data['username'] ?? id}',
        targetCollection: 'users',
        targetId: id,
      );
    }
  }

  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
    
    if (currentUser != null) {
      await logAuditEvent(
        username: currentUser!,
        eventType: 'DELETE',
        severity: 'CRITICAL',
        description: 'Eliminazione utente',
        targetCollection: 'users',
        targetId: id,
      );
    }
  }

  /// Verifica credenziali: cerca l'utente per username e verifica la password con hash.
  /// Se la password è ancora in chiaro (legacy), la migra automaticamente ad hash.
  /// Ritorna la mappa dell'utente se le credenziali sono valide, null altrimenti.
  Future<Map<String, dynamic>?> verifyCredentials(String username, String password) async {
    final users = await getUsers();
    
    for (var user in users) {
      if (user['username'] == username) {
        // Fallback al vecchio campo 'password' se 'password_hash' non esiste
        final storedHash = user['password_hash']?.toString() ?? user['password']?.toString() ?? '';
        
        if (PasswordHasher.verifyPassword(password, storedHash)) {
          // Se la password era in chiaro, migra a hash
          if (!PasswordHasher.isHashed(storedHash)) {
            try {
              final updateData = {
                'password_hash': PasswordHasher.hashPassword(password),
              };
              await _db.collection('users').doc(user['id']).update(updateData);
            } catch (e) {
              // Non bloccare il login se la migrazione fallisce
              print('Errore migrazione password: $e');
            }
          }
          return user;
        }
        return null; // Username trovato ma password sbagliata
      }
    }
    return null; // Username non trovato
  }

  /// Verifica se una password corrisponde a quella di un admin (per SecurityUtils).
  Future<bool> verifyAdminPassword(String password) async {
    final users = await getUsers();
    for (var user in users) {
      if (user['role']?.toString().toLowerCase() == 'admin') {
        // Fallback al vecchio campo 'password' se 'password_hash' non esiste
        final storedHash = user['password_hash']?.toString() ?? user['password']?.toString() ?? '';
        
        if (PasswordHasher.verifyPassword(password, storedHash)) {
          // Migra se legacy
          if (!PasswordHasher.isHashed(storedHash)) {
            try {
              final updateData = {
                'password_hash': PasswordHasher.hashPassword(password),
              };
              await _db.collection('users').doc(user['id']).update(updateData);
            } catch (e) {
              print('Errore migrazione password admin: $e');
            }
          }
          return true;
        }
      }
    }
    return false;
  }

  // --- RATE LIMITING ---
  /// Registra un tentativo di login fallito. Ritorna il numero di tentativi recenti.
  Future<int> recordFailedLogin(String username) async {
    await _db.collection('login_attempts').add({
      'username': username,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'failed',
    });
    return await getRecentFailedAttempts(username);
  }

  /// Conta i tentativi falliti negli ultimi [minutes] minuti.
  Future<int> getRecentFailedAttempts(String username, {int minutes = 5}) async {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes)).toIso8601String();
    final snapshot = await _db.collection('login_attempts')
        .where('username', isEqualTo: username)
        .where('type', isEqualTo: 'failed')
        .where('timestamp', isGreaterThan: cutoff)
        .get();
    return snapshot.docs.length;
  }

  /// Pulisce i vecchi tentativi (più di 1 ora).
  Future<void> cleanOldLoginAttempts() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
      final snapshot = await _db.collection('login_attempts')
          .where('timestamp', isLessThan: cutoff)
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Errore pulizia tentativi login: $e');
    }
  }

  // --- CRUD CUSTOMERS ---
  Future<String> insertCustomer(Map<String, dynamic> customer) async {
    final data = Map<String, dynamic>.from(customer)..remove('id');
    // Cifra dati sensibili
    if (data['vat_number'] != null) data['vat_number'] = CryptoUtils.encryptData(data['vat_number']);
    if (data['fiscal_code'] != null) data['fiscal_code'] = CryptoUtils.encryptData(data['fiscal_code']);
    
    final docRef = await _db.collection('customers').add(data);
    return docRef.id;
  }

  Future<void> updateCustomer(Map<String, dynamic> customer) async {
    final id = customer['id'];
    final data = Map<String, dynamic>.from(customer)..remove('id');
    // Cifra dati sensibili prima di salvare
    if (data['vat_number'] != null) data['vat_number'] = CryptoUtils.encryptData(data['vat_number']);
    if (data['fiscal_code'] != null) data['fiscal_code'] = CryptoUtils.encryptData(data['fiscal_code']);
    
    await _db.collection('customers').doc(id).update(data);
  }

  Future<void> deleteCustomer(String id) async {
    await _db.collection('customers').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final snapshot = await _db.collection('customers').orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      // Decifra dati sensibili
      if (data['vat_number'] != null) data['vat_number'] = CryptoUtils.decryptData(data['vat_number']);
      if (data['fiscal_code'] != null) data['fiscal_code'] = CryptoUtils.decryptData(data['fiscal_code']);
      return data;
    }).toList();
  }

  // --- CRUD CATEGORIES ---
  Future<String> insertCategory(Map<String, dynamic> category) async {
    final data = Map<String, dynamic>.from(category)..remove('id');
    final docRef = await _db.collection('categories').add(data);
    return docRef.id;
  }

  Future<void> updateCategory(Map<String, dynamic> category) async {
    final id = category['id'];
    final data = Map<String, dynamic>.from(category)..remove('id');
    await _db.collection('categories').doc(id).update(data);
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final snapshot = await _db.collection('categories').orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- CRUD SERVICE TYPES ---
  Future<String> insertServiceType(Map<String, dynamic> service) async {
    final data = Map<String, dynamic>.from(service)..remove('id');
    final docRef = await _db.collection('service_types').add(data);
    return docRef.id;
  }

  Future<void> updateServiceType(Map<String, dynamic> service) async {
    final id = service['id'];
    final data = Map<String, dynamic>.from(service)..remove('id');
    await _db.collection('service_types').doc(id).update(data);
  }

  Future<void> deleteServiceType(String id) async {
    await _db.collection('service_types').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getServiceTypes() async {
    final snapshot = await _db.collection('service_types').orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- CRUD PAYMENTS ---
  Future<String> insertPayment(Map<String, dynamic> payment) async {
    final data = Map<String, dynamic>.from(payment)..remove('id');
    final docRef = await _db.collection('payments').add(data);
    return docRef.id;
  }

  Future<void> updatePayment(Map<String, dynamic> payment) async {
    final id = payment['id'];
    final data = Map<String, dynamic>.from(payment)..remove('id');
    await _db.collection('payments').doc(id).update(data);
  }

  Future<void> deletePayment(String id) async {
    await _db.collection('payments').doc(id).delete();
    
    if (currentUser != null) {
      await logAuditEvent(
        username: currentUser!,
        eventType: 'DELETE',
        severity: 'CRITICAL',
        description: 'Eliminazione pagamento',
        targetCollection: 'payments',
        targetId: id,
      );
    }
  }

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

    // Ordina per data discendente (ultimi inseriti prima)
    docs.sort((a, b) {
      String dateA = a['date'] ?? '';
      String dateB = b['date'] ?? '';
      return dateB.compareTo(dateA);
    });

    // Arricchisce con nome cliente e servizio (join in memoria)
    try {
      final customersSnap = await _db.collection('customers').get();
      final servicesSnap = await _db.collection('service_types').get();
      final Map<String, String> customerNames = {
        for (var d in customersSnap.docs) d.id: (d.data()['name'] ?? '').toString()
      };
      final Map<String, String> serviceNames = {
        for (var d in servicesSnap.docs) d.id: (d.data()['name'] ?? '').toString()
      };
      for (var doc in docs) {
        final cid = doc['customer_id']?.toString() ?? '';
        final sid = doc['service_id']?.toString() ?? '';
        doc['customer_name'] = cid.isNotEmpty ? (customerNames[cid] ?? '') : '';
        doc['service_name'] = sid.isNotEmpty ? (serviceNames[sid] ?? '') : '';
      }
    } catch (_) {}

    return docs;
  }

  Future<List<Map<String, dynamic>>> getPaymentsByCustomer(String customerId) async {
    final snapshot = await _db.collection('payments')
        .where('customer_id', isEqualTo: customerId)
        .get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // Sort in memory to avoid requiring a composite index in Firestore
    docs.sort((a, b) {
      String dateA = a['date'] ?? '';
      String dateB = b['date'] ?? '';
      return dateB.compareTo(dateA); // descending
    });
    
    return docs;
  }

  Future<Map<String, dynamic>?> getPaymentById(String id) async {
    final doc = await _db.collection('payments').doc(id).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // --- CRUD INVOICES ---
  Future<String> insertInvoice(Map<String, dynamic> invoice) async {
    final data = Map<String, dynamic>.from(invoice)..remove('id');
    final docRef = await _db.collection('invoices').add(data);
    return docRef.id;
  }

  Future<void> updateInvoice(Map<String, dynamic> invoice) async {
    final id = invoice['id'];
    final data = Map<String, dynamic>.from(invoice)..remove('id');
    await _db.collection('invoices').doc(id).update(data);
  }

  Future<void> deleteInvoice(String id) async {
    await _db.collection('invoices').doc(id).delete();
    
    if (currentUser != null) {
      await logAuditEvent(
        username: currentUser!,
        eventType: 'DELETE',
        severity: 'CRITICAL',
        description: 'Eliminazione fattura',
        targetCollection: 'invoices',
        targetId: id,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final snapshot = await _db.collection('invoices').orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- CRUD DEADLINES ---
  Future<String> insertDeadline(Map<String, dynamic> deadline) async {
    final data = Map<String, dynamic>.from(deadline)..remove('id');
    final docRef = await _db.collection('deadlines').add(data);
    return docRef.id;
  }

  Future<void> updateDeadline(Map<String, dynamic> deadline) async {
    final id = deadline['id'];
    final data = Map<String, dynamic>.from(deadline)..remove('id');
    await _db.collection('deadlines').doc(id).update(data);
  }

  Future<void> deleteDeadline(String id) async {
    await _db.collection('deadlines').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getDeadlines() async {
    final snapshot = await _db.collection('deadlines').orderBy('date').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- ACCESS LOGS ---
  Future<void> logAccess(String username, String role, String deviceType, {String eventType = 'login_success'}) async {
    final now = DateTime.now();
    
    // Inserisci il nuovo log (append-only: le Firestore rules impediscono modifica/cancellazione)
    await _db.collection('access_logs').add({
      'username': username,
      'role': role,
      'device_type': deviceType,
      'timestamp': now.toIso8601String(),
      'event_type': eventType,
    });
  }

  Future<List<Map<String, dynamic>>> getAccessLogs() async {
    // Filtra solo gli ultimi 7 giorni
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final snapshot = await _db.collection('access_logs')
        .where('timestamp', isGreaterThan: sevenDaysAgo)
        .orderBy('timestamp', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- AUDIT LOG ---
  /// Registra un evento di sicurezza nell'audit log.
  /// Severity: INFO, WARNING, HIGH, CRITICAL
  Future<void> logAuditEvent({
    required String username,
    required String eventType,
    required String severity,
    required String description,
    String? targetId,
    String? targetCollection,
  }) async {
    await _db.collection('audit_log').add({
      'username': username,
      'event_type': eventType,
      'severity': severity,
      'description': description,
      'target_id': targetId,
      'target_collection': targetCollection,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    final snapshot = await _db.collection('audit_log')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- CRUD CALENDAR EVENTS ---
  Future<String> insertCalendarEvent(Map<String, dynamic> event) async {
    final data = Map<String, dynamic>.from(event)..remove('id');
    final docRef = await _db.collection('calendar_events').add(data);
    return docRef.id;
  }

  Future<void> updateCalendarEvent(Map<String, dynamic> event) async {
    final id = event['id'];
    final data = Map<String, dynamic>.from(event)..remove('id');
    await _db.collection('calendar_events').doc(id).update(data);
  }

  Future<void> deleteCalendarEvent(String id) async {
    await _db.collection('calendar_events').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getCalendarEvents() async {
    final snapshot = await _db.collection('calendar_events').orderBy('date').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- CRUD MEMO EVENTS ---
  Future<String> insertMemoEvent(Map<String, dynamic> memo) async {
    final data = Map<String, dynamic>.from(memo)..remove('id');
    final docRef = await _db.collection('memo_events').add(data);
    return docRef.id;
  }

  Future<void> updateMemoEvent(Map<String, dynamic> memo) async {
    final id = memo['id'];
    final data = Map<String, dynamic>.from(memo)..remove('id');
    await _db.collection('memo_events').doc(id).update(data);
  }

  Future<void> deleteMemoEvent(String id) async {
    await _db.collection('memo_events').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getMemoEvents() async {
    final snapshot = await _db.collection('memo_events').get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // Ordinamento in memoria per data evento o data
    docs.sort((a, b) {
      String dateA = a['event_date'] ?? a['date'] ?? '';
      String dateB = b['event_date'] ?? b['date'] ?? '';
      return dateB.compareTo(dateA);
    });
    
    return docs;
  }

  // --- CRUD NOTE ---
  Future<String> insertNote(Map<String, dynamic> note) async {
    final data = Map<String, dynamic>.from(note)..remove('id');
    final docRef = await _db.collection('notes').add(data);
    return docRef.id;
  }

  Future<void> updateNote(Map<String, dynamic> note) async {
    final id = note['id'];
    final data = Map<String, dynamic>.from(note)..remove('id');
    await _db.collection('notes').doc(id).update(data);
  }

  Future<void> deleteNote(String id) async {
    await _db.collection('notes').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final snapshot = await _db.collection('notes').get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // Ordinamento in memoria per update_date
    docs.sort((a, b) {
      String dateA = a['update_date'] ?? a['creation_date'] ?? '';
      String dateB = b['update_date'] ?? b['creation_date'] ?? '';
      return dateB.compareTo(dateA);
    });
    
    return docs;
  }
  // --- CRUD SCHEDULED PAYMENTS ---
  Future<String> insertScheduledPayment(Map<String, dynamic> payment) async {
    final data = Map<String, dynamic>.from(payment)..remove('id');
    final docRef = await _db.collection('scheduled_payments').add(data);
    return docRef.id;
  }

  Future<void> updateScheduledPayment(Map<String, dynamic> payment) async {
    final id = payment['id'];
    final data = Map<String, dynamic>.from(payment)..remove('id');
    await _db.collection('scheduled_payments').doc(id).update(data);
  }

  Future<void> deleteScheduledPayment(String id) async {
    await _db.collection('scheduled_payments').doc(id).delete();
  }

  Future<Map<String, dynamic>?> getScheduledPaymentById(String id) async {
    final doc = await _db.collection('scheduled_payments').doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }

  Future<List<Map<String, dynamic>>> getScheduledPayments() async {
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
  }

  // --- CRUD QUOTES (Preventivi) ---
  Future<String> insertQuote(Map<String, dynamic> quote) async {
    final data = Map<String, dynamic>.from(quote)..remove('id');
    if (data['serial_number'] == null) {
       final allQuotes = await getQuotes();
       int maxSerial = 0;
       for (var q in allQuotes) {
         final s = q['serial_number'];
         if (s != null) {
           final sInt = int.tryParse(s.toString());
           if (sInt != null && sInt > maxSerial) {
             maxSerial = sInt;
           }
         }
       }
       data['serial_number'] = maxSerial + 1;
    }
    final docRef = await _db.collection('quotes').add(data);
    return docRef.id;
  }

  Future<void> updateQuote(Map<String, dynamic> quote) async {
    final id = quote['id'];
    final data = Map<String, dynamic>.from(quote)..remove('id');
    await _db.collection('quotes').doc(id).update(data);
  }

  Future<void> deleteQuote(String id) async {
    await _db.collection('quotes').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getQuotes() async {
    final snapshot = await _db.collection('quotes').get();
    var docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) {
      final sA = int.tryParse(a['serial_number']?.toString() ?? '0') ?? 0;
      final sB = int.tryParse(b['serial_number']?.toString() ?? '0') ?? 0;
      return sB.compareTo(sA);
    });
    return docs;
  }
}


