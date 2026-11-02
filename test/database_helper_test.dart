import 'package:contabile_app/database/database_helper.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseHelper Comprehensive Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseHelper dbHelper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      DatabaseHelper.setMockFirestore(fakeFirestore);
      dbHelper = DatabaseHelper();
      dbHelper.currentUser = 'test_user';
    });

    tearDown(() {
      dbHelper.currentUser = null;
    });

    test('insertUser and getUsers hashes password', () async {
      final user = {
        'username': 'admin',
        'password_hash': 'test_password',
        'role': 'ADMIN',
      };

      final id = await dbHelper.insertUser(user);
      expect(id, isNotEmpty);

      final users = await dbHelper.getUsers();
      expect(users.length, 1);
      expect(users.first['username'], 'admin');
      expect(users.first['role'], 'ADMIN');
      expect(users.first['password_hash'], isNot('test_password'));
    });

    test('getPayments(year) restituisce correttamente le date italiane dd/MM/yyyy e rinomina migrazione A001', () async {
      await fakeFirestore.collection('payments').doc('legacy_1').set({
        'amount': 500.0,
        'date': '15/03/2026',
        'type': 'IN',
        'payment_method': 'Carta',
        'status': 'PAID',
      });
      await fakeFirestore.collection('payments').doc('legacy_2').set({
        'amount': 250.0,
        'date': '10/11/2025',
        'type': 'OUT',
        'payment_method': 'Contante',
        'status': 'PAID',
      });

      final payments2026 = await dbHelper.getPayments(year: 2026);
      expect(payments2026.length, 1);
      expect(payments2026.first['amount'], 500.0);
      expect(payments2026.first['id'], 'A002'); // legacy_2 (2025) -> A001, legacy_1 (2026) -> A002

      final payments2025 = await dbHelper.getPayments(year: 2025);
      expect(payments2025.length, 1);
      expect(payments2025.first['id'], 'A001');
    });

    test('insertCustomer cifra tax_code e vat_number e getCustomers li decifra e allinea gli alias', () async {
      final id = await dbHelper.insertCustomer({
        'name': 'Rossi Service SRL',
        'vat_number': '01234567890',
        'tax_code': 'RSSMRA80A01H501U',
        'sdi_code': 'ABCDEFG',
        'address_street': 'Via Roma 10',
      });

      final rawSnap = await fakeFirestore.collection('customers').doc(id).get();
      expect(rawSnap.data()!['vat_number'], isNot('01234567890'));
      expect(rawSnap.data()!['tax_code'], isNot('RSSMRA80A01H501U'));
      expect(rawSnap.data()!['fiscal_code'], isNot('RSSMRA80A01H501U'));

      final customers = await dbHelper.getCustomers();
      expect(customers.length, 1);
      expect(customers.first['vat_number'], '01234567890');
      expect(customers.first['tax_code'], 'RSSMRA80A01H501U');
      expect(customers.first['fiscal_code'], 'RSSMRA80A01H501U');
      expect(customers.first['sdi_code'], 'ABCDEFG');
      expect(customers.first['unique_code'], 'ABCDEFG');
      expect(customers.first['address_street'], 'Via Roma 10');
      expect(customers.first['address'], 'Via Roma 10');
    });

    test('settleMemoEventAtomically crea pagamento e rimuove memo atomicamente', () async {
      await fakeFirestore.collection('metadata').doc('app_config').set({
        'migration_a001_done': true,
      });
      final memoId = await dbHelper.insertMemoEvent({
        'title': 'Evento Live Estate',
        'amount': 1200.0,
        'status': 'IN ATTESA',
      });

      final paymentId = await dbHelper.settleMemoEventAtomically(
        memoId: memoId,
        isInvoice: false,
        targetData: {
          'title': 'Evento Live Estate',
          'amount': 1200.0,
          'type': 'IN',
          'date': '20/08/2026',
          'payment_method': 'Bonifico',
          'status': 'PAID',
        },
      );

      expect(paymentId, 'A001');
      final memos = await dbHelper.getMemoEvents();
      expect(memos, isEmpty);
      final payment = await dbHelper.getPaymentById('A001');
      expect(payment, isNotNull);
      expect(payment!['amount'], 1200.0);
    });

    test('insertQuote incrementa atomicamente serial_number', () async {
      await dbHelper.insertQuote({'code': 'P1', 'total': 100.0});
      await dbHelper.insertQuote({'code': 'P2', 'total': 200.0});
      final quotes = await dbHelper.getQuotes();
      expect(quotes.length, 2);
      expect(quotes[0]['serial_number'], 2);
      expect(quotes[1]['serial_number'], 1);
    });
  });
}
