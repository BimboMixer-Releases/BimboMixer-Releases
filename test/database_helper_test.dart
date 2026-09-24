import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  group('DatabaseHelper Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseHelper dbHelper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      DatabaseHelper.setMockFirestore(fakeFirestore);
      dbHelper = DatabaseHelper();
      dbHelper.currentUser = 'test_user';
    });

    test('insertUser and getUsers', () async {
      final user = {
        'username': 'admin',
        'password_hash': 'test_password', // Should be hashed by the method
        'role': 'ADMIN',
      };

      final id = await dbHelper.insertUser(user);
      expect(id, isNotEmpty);

      final users = await dbHelper.getUsers();
      expect(users.length, 1);
      expect(users.first['username'], 'admin');
      expect(users.first['role'], 'ADMIN');
      expect(users.first['password_hash'], isNot('test_password')); // Because it should be hashed
    });
  });
}
