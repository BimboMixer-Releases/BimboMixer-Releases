import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/calculation_engine.dart';
import '../utils/crypto_utils.dart';
import '../utils/date_utils_app.dart';
import '../utils/password_hasher.dart';
import '../utils/sort_utils.dart';

class DatabaseHelper {
  static DatabaseHelper _instance = DatabaseHelper._internal();
  static void setMockInstance(DatabaseHelper mock) {
    _instance = mock;
  }

  FirebaseFirestore? _mockDb;
  FirebaseFirestore get _db => _mockDb ?? FirebaseFirestore.instance;
  FirebaseFirestore get db => _db;

  static void setMockFirestore(FirebaseFirestore mock) {
    _instance._mockDb = mock;
    _instance._paymentsMigrationDone = false;
  }

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Utente attualmente loggato, usato per l'Audit Log e controlli permessi
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
    if (data['password_hash'] != null &&
        !PasswordHasher.isHashed(data['password_hash'].toString())) {
      data['password_hash'] = PasswordHasher.hashPassword(data['password_hash'].toString());
    }
    final docRef = await _db.collection('users').add(data);

    if (currentUser != null && currentUser!.isNotEmpty) {
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
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID utente mancante per updateUser');
    }
    final data = Map<String, dynamic>.from(user)..remove('id');
    if (data['password_hash'] != null &&
        !PasswordHasher.isHashed(data['password_hash'].toString())) {
      data['password_hash'] = PasswordHasher.hashPassword(data['password_hash'].toString());
    }
    await _db.collection('users').doc(id).update(data);

    if (currentUser != null && currentUser!.isNotEmpty) {
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

    if (currentUser != null && currentUser!.isNotEmpty) {
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
  Future<Map<String, dynamic>?> verifyCredentials(String username, String password) async {
    final users = await getUsers();

    for (final user in users) {
      if (user['username']?.toString().toLowerCase() == username.trim().toLowerCase()) {
        final storedHash =
            user['password_hash']?.toString() ?? user['password']?.toString() ?? '';

        if (PasswordHasher.verifyPassword(password, storedHash)) {
          return user;
        }
        return null;
      }
    }
    return null;
  }

  /// Verifica se l'utente corrente in sessione è un amministratore.
  Future<bool> isCurrentUserAdmin() async {
    final activeUser = currentUser?.trim();
    if (activeUser == null || activeUser.isEmpty) return false;
    try {
      final users = await getUsers();
      for (final u in users) {
        if (u['username']?.toString().toLowerCase() == activeUser.toLowerCase()) {
          return u['role']?.toString().toLowerCase() == 'admin';
        }
      }
    } catch (_) {}
    return false;
  }

  /// Verifica se una password corrisponde a quella di un admin (per SecurityUtils).
  Future<bool> verifyAdminPassword(String password) async {
    final users = await getUsers();
    for (final user in users) {
      if (user['role']?.toString().toLowerCase() == 'admin') {
        final storedHash =
            user['password_hash']?.toString() ?? user['password']?.toString() ?? '';

        if (PasswordHasher.verifyPassword(password, storedHash)) {
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
      'username': username.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'failed',
    });
    return await getRecentFailedAttempts(username);
  }

  /// Conta i tentativi falliti negli ultimi [minutes] minuti senza richiedere indici compositi Firestore.
  Future<int> getRecentFailedAttempts(String username, {int minutes = 5}) async {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    final snapshot = await _db
        .collection('login_attempts')
        .where('username', isEqualTo: username.trim())
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['type'] != 'failed') continue;
      final tsStr = data['timestamp']?.toString() ?? '';
      final ts = DateTime.tryParse(tsStr);
      if (ts != null && ts.isAfter(cutoff)) {
        count++;
      }
    }
    return count;
  }

  /// Pulisce i vecchi tentativi (più di 1 ora).
  Future<void> cleanOldLoginAttempts() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
      final snapshot = await _db
          .collection('login_attempts')
          .where('timestamp', isLessThan: cutoff)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Errore pulizia tentativi login: $e');
    }
  }

  // --- CRUD CUSTOMERS ---
  Map<String, dynamic> _prepareCustomerForWrite(Map<String, dynamic> customer) {
    final data = Map<String, dynamic>.from(customer)..remove('id');

    // Sincronizza chiavi canoniche e legacy prima della cifratura
    final taxCode = (data['tax_code'] ?? data['fiscal_code'])?.toString();
    if (taxCode != null) {
      data['tax_code'] = taxCode;
      data['fiscal_code'] = taxCode;
    }
    final sdiCode = (data['sdi_code'] ?? data['unique_code'])?.toString();
    if (sdiCode != null) {
      data['sdi_code'] = sdiCode;
      data['unique_code'] = sdiCode;
    }
    final addressStreet = (data['address_street'] ?? data['address'])?.toString();
    if (addressStreet != null) {
      data['address_street'] = addressStreet;
      data['address'] = addressStreet;
    }

    // Cifra dati sensibili se non vuoti
    if (data['vat_number'] != null && data['vat_number'].toString().isNotEmpty) {
      data['vat_number'] = CryptoUtils.encryptData(data['vat_number'].toString());
    }
    if (data['fiscal_code'] != null && data['fiscal_code'].toString().isNotEmpty) {
      data['fiscal_code'] = CryptoUtils.encryptData(data['fiscal_code'].toString());
    }
    if (data['tax_code'] != null && data['tax_code'].toString().isNotEmpty) {
      data['tax_code'] = CryptoUtils.encryptData(data['tax_code'].toString());
    }
    return data;
  }

  Map<String, dynamic> _normalizeCustomerFromRead(Map<String, dynamic> raw, String id) {
    final data = Map<String, dynamic>.from(raw);
    data['id'] = id;

    if (data['vat_number'] != null) {
      data['vat_number'] = CryptoUtils.decryptData(data['vat_number'].toString());
    }
    if (data['fiscal_code'] != null) {
      data['fiscal_code'] = CryptoUtils.decryptData(data['fiscal_code'].toString());
    }
    if (data['tax_code'] != null) {
      data['tax_code'] = CryptoUtils.decryptData(data['tax_code'].toString());
    }

    // Allinea alias per compatibilità con tutte le schermate
    final taxCode = (data['tax_code']?.toString().isNotEmpty == true)
        ? data['tax_code']
        : data['fiscal_code'];
    if (taxCode != null) {
      data['tax_code'] = taxCode;
      data['fiscal_code'] = taxCode;
    }

    final sdiCode = (data['sdi_code']?.toString().isNotEmpty == true)
        ? data['sdi_code']
        : data['unique_code'];
    if (sdiCode != null) {
      data['sdi_code'] = sdiCode;
      data['unique_code'] = sdiCode;
    }

    final addressStreet = (data['address_street']?.toString().isNotEmpty == true)
        ? data['address_street']
        : data['address'];
    if (addressStreet != null) {
      data['address_street'] = addressStreet;
      data['address'] = addressStreet;
    }

    return data;
  }

  Future<String> insertCustomer(Map<String, dynamic> customer) async {
    final data = _prepareCustomerForWrite(customer);
    final docRef = await _db.collection('customers').add(data);
    return docRef.id;
  }

  Future<void> updateCustomer(Map<String, dynamic> customer) async {
    final id = customer['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID cliente mancante per updateCustomer');
    }
    final data = _prepareCustomerForWrite(customer);
    await _db.collection('customers').doc(id).update(data);
  }

  Future<void> deleteCustomer(String id) async {
    await _db.collection('customers').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final snapshot = await _db.collection('customers').get();
    final list = snapshot.docs
        .map((doc) => _normalizeCustomerFromRead(doc.data(), doc.id))
        .toList();
    list.sort((a, b) => (a['name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['name'] ?? '').toString().toLowerCase()));
    return list;
  }

  // --- CRUD CATEGORIES ---
  Future<String> insertCategory(Map<String, dynamic> category) async {
    final data = Map<String, dynamic>.from(category)..remove('id');
    final docRef = await _db.collection('categories').add(data);
    return docRef.id;
  }

  Future<void> updateCategory(Map<String, dynamic> category) async {
    final id = category['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID categoria mancante per updateCategory');
    }
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
    final id = service['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID servizio mancante per updateServiceType');
    }
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
  Future<void> _initializeCounterIfNeeded() async {
    final counterRef = _db.collection('metadata').doc('payment_counter');

    final counterSnap = await counterRef.get();
    if (counterSnap.exists &&
        counterSnap.data() != null &&
        counterSnap.data()!.containsKey('last_id')) {
      return;
    }

    final snapshot = await _db.collection('payments').get();
    String maxId = 'A000';
    for (final doc in snapshot.docs) {
      final id = doc.id;
      if (RegExp(r'^[A-Z]\d{3}$').hasMatch(id)) {
        if (id.compareTo(maxId) > 0) {
          maxId = id;
        }
      }
    }

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(counterRef);
      if (!snap.exists || snap.data() == null || !snap.data()!.containsKey('last_id')) {
        transaction.set(counterRef, {'last_id': maxId});
      }
    });
  }

  Map<String, dynamic> _sanitizePaymentForWrite(Map<String, dynamic> payment) {
    return Map<String, dynamic>.from(payment)
      ..remove('id')
      ..remove('_generated_seq')
      ..remove('customer_name')
      ..remove('service_name')
      ..remove('category_name');
  }

  Future<String> insertPayment(Map<String, dynamic> payment) async {
    final data = _sanitizePaymentForWrite(payment);

    await _initializeCounterIfNeeded();

    return await _db.runTransaction((transaction) async {
      final counterRef = _db.collection('metadata').doc('payment_counter');
      final counterSnap = await transaction.get(counterRef);

      String currentId = 'A000';
      if (counterSnap.exists &&
          counterSnap.data() != null &&
          counterSnap.data()!.containsKey('last_id')) {
        currentId = counterSnap.data()!['last_id'] as String;
      }

      if (!RegExp(r'^[A-Z]\d{3}$').hasMatch(currentId)) {
        throw Exception('INVALID_COUNTER_STATE: $currentId');
      }

      String letter = currentId.substring(0, 1);
      int number = int.parse(currentId.substring(1));

      number++;
      if (number > 999) {
        number = 1;
        int charCode = letter.codeUnitAt(0);
        charCode++;
        if (charCode > 90) {
          throw Exception('LIMIT_Z999_REACHED');
        }
        letter = String.fromCharCode(charCode);
      }

      final newId = '$letter${number.toString().padLeft(3, '0')}';

      final docRef = _db.collection('payments').doc(newId);
      final docSnap = await transaction.get(docRef);

      if (docSnap.exists) {
        throw Exception('DOCUMENT_ALREADY_EXISTS');
      }

      transaction.set(counterRef, {'last_id': newId}, SetOptions(merge: true));
      transaction.set(docRef, data);

      return newId;
    });
  }

  Future<void> updatePayment(Map<String, dynamic> payment) async {
    final id = payment['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID pagamento mancante per updatePayment');
    }
    final data = _sanitizePaymentForWrite(payment);
    await _db.collection('payments').doc(id).update(data);
  }

  Future<void> deletePayment(String id) async {
    await _db.collection('payments').doc(id).delete();

    if (currentUser != null && currentUser!.isNotEmpty) {
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

  bool _paymentsMigrationDone = false;

  Future<void> _runPaymentsRenumberingMigration() async {
    try {
      final configSnap = await _db.collection('metadata').doc('app_config').get();
      if (configSnap.exists && configSnap.data()?['migration_a001_done'] == true) {
        return;
      }

      final snapshot = await _db.collection('payments').get();
      if (snapshot.docs.isEmpty) {
        await _db
            .collection('metadata')
            .doc('app_config')
            .set({'migration_a001_done': true}, SetOptions(merge: true));
        return;
      }

      final docs = snapshot.docs.map((d) {
        final data = d.data();
        data['original_id'] = d.id;
        return data;
      }).toList();

      docs.sort((a, b) =>
          compareDates(a['date']?.toString(), b['date']?.toString(), descending: false));

      var batch = _db.batch();
      int count = 0;

      int number = 1;
      String letter = 'A';
      String lastId = 'A000';

      for (final doc in docs) {
        final originalId = doc['original_id'] as String;

        if (number > 999) {
          number = 1;
          final nextCharCode = letter.codeUnitAt(0) + 1;
          if (nextCharCode > 90) {
            throw Exception('LIMIT_Z999_REACHED');
          }
          letter = String.fromCharCode(nextCharCode);
        }
        final newId = '$letter${number.toString().padLeft(3, '0')}';
        lastId = newId;
        number++;

        final data = Map<String, dynamic>.from(doc)
          ..remove('original_id')
          ..remove('id');

        if (originalId != newId) {
          batch.delete(_db.collection('payments').doc(originalId));
        }
        batch.set(_db.collection('payments').doc(newId), data);

        count++;
        if (count >= 450) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }

      final counterRef = _db.collection('metadata').doc('payment_counter');
      batch.set(counterRef, {'last_id': lastId});
      batch.set(
        _db.collection('metadata').doc('app_config'),
        {'migration_a001_done': true},
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint('Migration A001 completata con successo. Ultimo ID: $lastId');
    } catch (e) {
      debugPrint('Errore migrazione A001: $e');
    }
  }

  Future<void> _enrichPayments(List<Map<String, dynamic>> docs) async {
    if (docs.isEmpty) return;
    try {
      final customersSnap = await _db.collection('customers').get();
      final servicesSnap = await _db.collection('service_types').get();
      final categoriesSnap = await _db.collection('categories').get();
      final Map<String, String> customerNames = {
        for (final d in customersSnap.docs) d.id: (d.data()['name'] ?? '').toString()
      };
      final Map<String, String> serviceNames = {
        for (final d in servicesSnap.docs) d.id: (d.data()['name'] ?? '').toString()
      };
      final Map<String, String> categoryNames = {
        for (final d in categoriesSnap.docs) d.id: (d.data()['name'] ?? '').toString()
      };
      for (final doc in docs) {
        final cid = doc['customer_id']?.toString() ?? '';
        final sid = doc['service_id']?.toString() ?? '';
        final catId = doc['category_id']?.toString() ?? '';
        doc['customer_name'] = cid.isNotEmpty ? (customerNames[cid] ?? '') : '';
        doc['service_name'] = sid.isNotEmpty ? (serviceNames[sid] ?? '') : '';
        doc['category_name'] = catId.isNotEmpty ? (categoryNames[catId] ?? '') : '';
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getPayments({
    int? year,
    String? startDate,
    String? endDate,
  }) async {
    if (!_paymentsMigrationDone) {
      _paymentsMigrationDone = true;
      await _runPaymentsRenumberingMigration();
    }

    final snapshot = await _db.collection('payments').get();
    var docs = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return data;
    }).toList();

    // Filtra in memoria per supportare sia formato italiano dd/MM/yyyy sia yyyy-MM-dd
    if (startDate != null && endDate != null) {
      final startDt = DateUtilsApp.tryParseDate(startDate);
      final endDt = DateUtilsApp.tryParseDate(endDate);
      if (startDt != null && endDt != null) {
        final startBound = DateTime(startDt.year, startDt.month, startDt.day);
        final endBound = DateTime(endDt.year, endDt.month, endDt.day, 23, 59, 59);
        docs = docs.where((d) {
          final dt = DateUtilsApp.tryParseDate(d['date']?.toString());
          if (dt == null) return false;
          return !dt.isBefore(startBound) && !dt.isAfter(endBound);
        }).toList();
      }
    } else if (year != null) {
      docs = docs.where((d) {
        return CalculationEngine.extractYear(d['date']?.toString()) == year;
      }).toList();
    }

    // Ordina per data discendente (ultimi inseriti prima)
    docs.sort((a, b) {
      return compareDates(a['date']?.toString(), b['date']?.toString(), descending: true);
    });

    await _enrichPayments(docs);
    return docs;
  }

  Future<List<Map<String, dynamic>>> getPaymentsByCustomer(String customerId) async {
    final snapshot = await _db
        .collection('payments')
        .where('customer_id', isEqualTo: customerId)
        .get();
    final docs = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return data;
    }).toList();

    docs.sort((a, b) =>
        compareDates(a['date']?.toString(), b['date']?.toString(), descending: true));

    await _enrichPayments(docs);
    return docs;
  }

  Future<Map<String, dynamic>?> getPaymentById(String id) async {
    final doc = await _db.collection('payments').doc(id).get();
    if (doc.exists && doc.data() != null) {
      final data = Map<String, dynamic>.from(doc.data()!);
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
    final id = invoice['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID fattura mancante per updateInvoice');
    }
    final data = Map<String, dynamic>.from(invoice)..remove('id');
    await _db.collection('invoices').doc(id).update(data);
  }

  Future<void> deleteInvoice(String id) async {
    await _db.collection('invoices').doc(id).delete();

    if (currentUser != null && currentUser!.isNotEmpty) {
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
    final snapshot = await _db.collection('invoices').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) =>
        compareDates(a['date']?.toString(), b['date']?.toString(), descending: true));
    return docs;
  }

  Future<Map<String, dynamic>?> getInvoiceById(String id) async {
    final doc = await _db.collection('invoices').doc(id).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // --- CRUD DEADLINES ---
  Future<String> insertDeadline(Map<String, dynamic> deadline) async {
    final data = Map<String, dynamic>.from(deadline)..remove('id');
    final docRef = await _db.collection('deadlines').add(data);
    return docRef.id;
  }

  Future<void> updateDeadline(Map<String, dynamic> deadline) async {
    final id = deadline['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID scadenza mancante per updateDeadline');
    }
    final data = Map<String, dynamic>.from(deadline)..remove('id');
    await _db.collection('deadlines').doc(id).update(data);
  }

  Future<void> deleteDeadline(String id) async {
    await _db.collection('deadlines').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getDeadlines() async {
    final snapshot = await _db.collection('deadlines').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) {
      final dateA = (a['date_from']?.toString().isNotEmpty == true)
          ? a['date_from']?.toString()
          : a['date']?.toString();
      final dateB = (b['date_from']?.toString().isNotEmpty == true)
          ? b['date_from']?.toString()
          : b['date']?.toString();
      return compareDates(dateA, dateB, descending: false);
    });
    return docs;
  }

  // --- ACCESS LOGS ---
  Future<void> logAccess(
    String username,
    String role,
    String deviceType, {
    String eventType = 'login_success',
  }) async {
    final now = DateTime.now();

    await _db.collection('access_logs').add({
      'username': username,
      'role': role,
      'device_type': deviceType,
      'timestamp': now.toIso8601String(),
      'event_type': eventType,
    });
  }

  Future<List<Map<String, dynamic>>> getAccessLogs() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final snapshot = await _db
        .collection('access_logs')
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
    final snapshot = await _db
        .collection('audit_log')
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
    final id = event['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID evento calendario mancante');
    }
    final data = Map<String, dynamic>.from(event)..remove('id');
    await _db.collection('calendar_events').doc(id).update(data);
  }

  Future<void> deleteCalendarEvent(String id) async {
    await _db.collection('calendar_events').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getCalendarEvents() async {
    final snapshot = await _db.collection('calendar_events').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) =>
        compareDates(a['date']?.toString(), b['date']?.toString(), descending: false));
    return docs;
  }

  // --- CRUD MEMO EVENTS ---
  Future<String> insertMemoEvent(Map<String, dynamic> memo) async {
    final data = Map<String, dynamic>.from(memo)..remove('id');
    final docRef = await _db.collection('memo_events').add(data);
    return docRef.id;
  }

  Future<void> updateMemoEvent(Map<String, dynamic> memo) async {
    final id = memo['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID memo mancante');
    }
    final data = Map<String, dynamic>.from(memo)..remove('id');
    await _db.collection('memo_events').doc(id).update(data);
  }

  Future<void> deleteMemoEvent(String id) async {
    await _db.collection('memo_events').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getMemoEvents() async {
    final snapshot = await _db.collection('memo_events').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      final dateA = (a['event_date'] ?? a['date'])?.toString();
      final dateB = (b['event_date'] ?? b['date'])?.toString();
      return compareDates(dateA, dateB, descending: true);
    });

    return docs;
  }

  /// Trasferisce un pagamento/fattura programmato in definitivo ed elimina il memo in modo atomico.
  Future<String> settleMemoEventAtomically({
    required String memoId,
    required bool isInvoice,
    required Map<String, dynamic> targetData,
  }) async {
    if (isInvoice) {
      final invData = Map<String, dynamic>.from(targetData)..remove('id');
      final invRef = _db.collection('invoices').doc();
      final memoRef = _db.collection('memo_events').doc(memoId);
      final batch = _db.batch();
      batch.set(invRef, invData);
      batch.delete(memoRef);
      await batch.commit();
      return invRef.id;
    } else {
      final payData = _sanitizePaymentForWrite(targetData);
      await _initializeCounterIfNeeded();

      return await _db.runTransaction((transaction) async {
        final counterRef = _db.collection('metadata').doc('payment_counter');
        final counterSnap = await transaction.get(counterRef);

        String currentId = 'A000';
        if (counterSnap.exists &&
            counterSnap.data() != null &&
            counterSnap.data()!.containsKey('last_id')) {
          currentId = counterSnap.data()!['last_id'] as String;
        }

        if (!RegExp(r'^[A-Z]\d{3}$').hasMatch(currentId)) {
          throw Exception('INVALID_COUNTER_STATE: $currentId');
        }

        String letter = currentId.substring(0, 1);
        int number = int.parse(currentId.substring(1));

        number++;
        if (number > 999) {
          number = 1;
          int charCode = letter.codeUnitAt(0) + 1;
          if (charCode > 90) {
            throw Exception('LIMIT_Z999_REACHED');
          }
          letter = String.fromCharCode(charCode);
        }

        final newId = '$letter${number.toString().padLeft(3, '0')}';
        final docRef = _db.collection('payments').doc(newId);
        final docSnap = await transaction.get(docRef);
        if (docSnap.exists) {
          throw Exception('DOCUMENT_ALREADY_EXISTS');
        }

        final memoRef = _db.collection('memo_events').doc(memoId);
        transaction.set(counterRef, {'last_id': newId}, SetOptions(merge: true));
        transaction.set(docRef, payData);
        transaction.delete(memoRef);
        return newId;
      });
    }
  }

  // --- CRUD NOTE ---
  Future<String> insertNote(Map<String, dynamic> note) async {
    final data = Map<String, dynamic>.from(note)..remove('id');
    final docRef = await _db.collection('notes').add(data);
    return docRef.id;
  }

  Future<void> updateNote(Map<String, dynamic> note) async {
    final id = note['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID nota mancante');
    }
    final data = Map<String, dynamic>.from(note)..remove('id');
    await _db.collection('notes').doc(id).update(data);
  }

  Future<void> deleteNote(String id) async {
    await _db.collection('notes').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final snapshot = await _db.collection('notes').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      final dateA = (a['update_date'] ?? a['creation_date'])?.toString();
      final dateB = (b['update_date'] ?? b['creation_date'])?.toString();
      return compareDates(dateA, dateB, descending: true);
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
    final id = payment['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID pagamento programmato mancante');
    }
    final data = Map<String, dynamic>.from(payment)..remove('id');
    await _db.collection('scheduled_payments').doc(id).update(data);
  }

  Future<void> deleteScheduledPayment(String id) async {
    await _db.collection('scheduled_payments').doc(id).delete();
  }

  Future<Map<String, dynamic>?> getScheduledPaymentById(String id) async {
    final doc = await _db.collection('scheduled_payments').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id;
    return data;
  }

  Future<List<Map<String, dynamic>>> getScheduledPayments() async {
    final snapshot = await _db.collection('scheduled_payments').get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    docs.sort((a, b) =>
        compareDates(a['date']?.toString(), b['date']?.toString(), descending: true));
    return docs;
  }

  // --- CRUD QUOTES (Preventivi) ---
  Future<void> _initializeQuoteCounterIfNeeded() async {
    final counterRef = _db.collection('metadata').doc('quote_counter');
    final counterSnap = await counterRef.get();
    if (counterSnap.exists &&
        counterSnap.data() != null &&
        counterSnap.data()!.containsKey('last_serial')) {
      return;
    }

    final snapshot = await _db.collection('quotes').get();
    int maxSerial = 0;
    for (final doc in snapshot.docs) {
      final s = doc.data()['serial_number'];
      if (s != null) {
        final sInt = int.tryParse(s.toString());
        if (sInt != null && sInt > maxSerial) {
          maxSerial = sInt;
        }
      }
    }

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(counterRef);
      if (!snap.exists ||
          snap.data() == null ||
          !snap.data()!.containsKey('last_serial')) {
        transaction.set(counterRef, {'last_serial': maxSerial});
      }
    });
  }

  Future<String> insertQuote(Map<String, dynamic> quote) async {
    final data = Map<String, dynamic>.from(quote)..remove('id');
    if (data['serial_number'] != null) {
      final docRef = await _db.collection('quotes').add(data);
      return docRef.id;
    }

    await _initializeQuoteCounterIfNeeded();

    return await _db.runTransaction((transaction) async {
      final counterRef = _db.collection('metadata').doc('quote_counter');
      final counterSnap = await transaction.get(counterRef);
      int currentSerial = 0;
      if (counterSnap.exists && counterSnap.data() != null) {
        currentSerial =
            int.tryParse(counterSnap.data()!['last_serial']?.toString() ?? '0') ?? 0;
      }
      final nextSerial = currentSerial + 1;
      data['serial_number'] = nextSerial;

      final docRef = _db.collection('quotes').doc();
      transaction.set(counterRef, {'last_serial': nextSerial}, SetOptions(merge: true));
      transaction.set(docRef, data);
      return docRef.id;
    });
  }

  Future<void> updateQuote(Map<String, dynamic> quote) async {
    final id = quote['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('ID preventivo mancante');
    }
    final data = Map<String, dynamic>.from(quote)..remove('id');
    await _db.collection('quotes').doc(id).update(data);
  }

  Future<void> deleteQuote(String id) async {
    await _db.collection('quotes').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getQuotes() async {
    final snapshot = await _db.collection('quotes').get();
    final docs = snapshot.docs.map((doc) {
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
