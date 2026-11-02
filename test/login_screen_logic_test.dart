import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/utils/password_hasher.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Login Security, Rate Limiting & PasswordHasher Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseHelper dbHelper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      DatabaseHelper.setMockFirestore(fakeFirestore);
      dbHelper = DatabaseHelper();
      dbHelper.currentUser = null;
    });

    tearDown(() {
      dbHelper.currentUser = null;
    });

    test('recordFailedLogin incrementa i tentativi recenti per username', () async {
      expect(await dbHelper.getRecentFailedAttempts('mario'), 0);
      final c1 = await dbHelper.recordFailedLogin('mario');
      final c2 = await dbHelper.recordFailedLogin('mario');
      final other = await dbHelper.getRecentFailedAttempts('luigi');

      expect(c1, 1);
      expect(c2, 2);
      expect(other, 0);
    });

    test('isCurrentUserAdmin distingue correttamente Admin da User', () async {
      await dbHelper.insertUser({
        'username': 'admin_user',
        'password_hash': 'Secret123!',
        'role': 'Admin',
      });
      await dbHelper.insertUser({
        'username': 'standard_user',
        'password_hash': 'UserPass123!',
        'role': 'User',
      });

      dbHelper.currentUser = 'standard_user';
      expect(await dbHelper.isCurrentUserAdmin(), isFalse);

      dbHelper.currentUser = 'admin_user';
      expect(await dbHelper.isCurrentUserAdmin(), isTrue);
    });

    test('PasswordHasher supporta sia password legacy con \$ sia hash SHA-256', () {
      expect(PasswordHasher.verifyPassword('P@ss\$word1', 'P@ss\$word1'), isTrue);
      expect(PasswordHasher.isHashed('P@ss\$word1'), isFalse);

      final hashed = PasswordHasher.hashPassword('P@ss\$word1');
      expect(PasswordHasher.isHashed(hashed), isTrue);
      expect(PasswordHasher.verifyPassword('P@ss\$word1', hashed), isTrue);
      expect(PasswordHasher.verifyPassword('WrongPass', hashed), isFalse);
    });
  });
}
