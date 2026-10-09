import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:contabile_app/database/database_helper.dart';

void main() {
  group('Payment ID Generation & Concurrency Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseHelper dbHelper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      DatabaseHelper.setMockFirestore(fakeFirestore);
      dbHelper = DatabaseHelper();
      dbHelper.currentUser = 'test_user';
    });

    test('Initial ID should be A001', () async {
      final id = await dbHelper.insertPayment({'amount': 100});
      expect(id, 'A001');
      final doc = await fakeFirestore.collection('payments').doc('A001').get();
      expect(doc.exists, true);
    });

    test('Should increment properly to A002', () async {
      await dbHelper.insertPayment({'amount': 100}); // A001
      final id2 = await dbHelper.insertPayment({'amount': 200}); // A002
      expect(id2, 'A002');
    });

    test('Should wrap A999 to B001', () async {
      await fakeFirestore.collection('metadata').doc('payment_counter').set({'last_id': 'A999'});
      final id = await dbHelper.insertPayment({'amount': 100});
      expect(id, 'B001');
    });

    test('Should throw error on Z999 limit and preserve data', () async {
      await fakeFirestore.collection('metadata').doc('payment_counter').set({'last_id': 'Z999'});
      expect(() async => await dbHelper.insertPayment({'amount': 100}), throwsException);
      final counter = await fakeFirestore.collection('metadata').doc('payment_counter').get();
      expect(counter.data()?['last_id'], 'Z999');
    });

    test('Sequential inserts should not overwrite', () async {
      final results = <String>[];
      for (int i = 0; i < 50; i++) {
        results.add(await dbHelper.insertPayment({'amount': i}));
      }
      final uniqueIds = results.toSet();
      expect(uniqueIds.length, 50);
      expect(results.contains('A001'), true);
      expect(results.contains('A050'), true);
      final snap = await fakeFirestore.collection('payments').get();
      expect(snap.docs.length, 50);
    });
  });
}