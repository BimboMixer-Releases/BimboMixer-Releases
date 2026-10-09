import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/utils/password_hasher.dart';

void main() {
  group('Login Auto-Recovery Revert Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseHelper dbHelper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      DatabaseHelper.setMockFirestore(fakeFirestore);
      dbHelper = DatabaseHelper();
    });

    test('Login fallito non forza il successo neanche per bimbomixer', () async {
      // 1. Inserisci utente con hash sbagliato
      await fakeFirestore.collection('users').doc('user123').set({
        'username': 'bimbomixer',
        'password_hash': PasswordHasher.hashPassword('VecchiaPassword'),
      });

      // 2. Chiamiamo verifyCredentials con 'Bimbomixer' come password
      final result = await dbHelper.verifyCredentials('bimbomixer', 'Bimbomixer');

      // 3. Deve fallire (ritornare null) perché l'auto-recovery è stato rimosso
      expect(result, isNull);

      // 4. L'hash nel DB NON deve essere stato modificato (sovrascritto dall'auto-recovery)
      final doc = await fakeFirestore.collection('users').doc('user123').get();
      expect(PasswordHasher.verifyPassword('VecchiaPassword', doc.data()!['password_hash']), isTrue);
    });

    test('Login valido conserva dati e non esegue migrazioni improprie', () async {
      final validHash = PasswordHasher.hashPassword('Bimbomixer');
      await fakeFirestore.collection('users').doc('user123').set({
        'username': 'bimbomixer',
        'password_hash': validHash,
        'role': 'Admin'
      });

      final result = await dbHelper.verifyCredentials('bimbomixer', 'Bimbomixer');
      expect(result, isNotNull);
      expect(result!['role'], 'Admin');

      // Verify hash is unchanged
      final doc = await fakeFirestore.collection('users').doc('user123').get();
      expect(doc.data()!['password_hash'], validHash);
    });
    
    test('Password in chiaro (legacy) viene accettata ma NON causa alcuna migrazione (nessuna scrittura automatica consentita)', () async {
      await fakeFirestore.collection('users').doc('user123').set({
        'username': 'bimbomixer',
        'password': 'PasswordInChiaro',
      });

      final result = await dbHelper.verifyCredentials('bimbomixer', 'PasswordInChiaro');
      expect(result, isNotNull);
      
      // Il vincolo utente vieta modifiche automatiche delle credenziali.
      // Assicuriamoci che NON sia stato scritto un 'password_hash' in automatico.
      final doc = await fakeFirestore.collection('users').doc('user123').get();
      expect(doc.data()!.containsKey('password_hash'), isFalse, reason: 'Non deve scrivere password_hash automaticamente');
      expect(doc.data()!['password'], 'PasswordInChiaro', reason: 'Deve preservare il campo legacy originale');
    });
  });
}
