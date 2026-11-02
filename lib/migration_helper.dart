import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'utils/crypto_utils.dart';
import 'utils/password_hasher.dart';

class MigrationHelper {
  static Future<void> migrate() async {
    final List<String> errors = [];
    final docsDir = await getApplicationDocumentsDirectory();
    final candidates = [
      p.join(docsDir.path, 'contabile_app', 'contabile.db'),
      p.join(docsDir.path, 'contabile.db'),
      r'C:\Users\Hp\Documents\contabile_app\contabile.db',
    ];

    String? dbPath;
    for (final path in candidates) {
      if (File(path).existsSync()) {
        dbPath = path;
        break;
      }
    }

    if (dbPath == null) {
      throw Exception('Database locale (SQLite) non trovato in Documenti.');
    }

    final db = await openDatabase(dbPath, readOnly: true);
    final firestore = FirebaseFirestore.instance;

    try {
      debugPrint('Inizio migrazione Customers...');
      try {
        final customers = await db.query('customers');
        for (final c in customers) {
          final data = Map<String, dynamic>.from(c);
          final id = data.remove('id');
          if (data['vat_number'] != null && data['vat_number'].toString().isNotEmpty) {
            data['vat_number'] = CryptoUtils.encryptData(data['vat_number'].toString());
          }
          if (data['fiscal_code'] != null && data['fiscal_code'].toString().isNotEmpty) {
            data['fiscal_code'] = CryptoUtils.encryptData(data['fiscal_code'].toString());
          }
          if (data['tax_code'] != null && data['tax_code'].toString().isNotEmpty) {
            data['tax_code'] = CryptoUtils.encryptData(data['tax_code'].toString());
          }
          await firestore.collection('customers').doc(id.toString()).set(data);
        }
      } catch (e) {
        errors.add('Errore customers: $e');
      }

      debugPrint('Inizio migrazione Categories...');
      try {
        final categories = await db.query('categories');
        for (final c in categories) {
          final data = Map<String, dynamic>.from(c);
          final id = data.remove('id');
          await firestore.collection('categories').doc(id.toString()).set(data);
        }
      } catch (e) {
        errors.add('Errore categories: $e');
      }

      debugPrint('Inizio migrazione Service Types...');
      try {
        final services = await db.query('service_types');
        for (final s in services) {
          final data = Map<String, dynamic>.from(s);
          final id = data.remove('id');
          await firestore.collection('service_types').doc(id.toString()).set(data);
        }
      } catch (e) {
        errors.add('Errore service_types: $e');
      }

      debugPrint('Inizio migrazione Payments...');
      try {
        final payments = await db.query('payments');
        for (final pRow in payments) {
          final data = Map<String, dynamic>.from(pRow);
          final id = data.remove('id');
          if (data.containsKey('customerId')) {
            data['customer_id'] = data.remove('customerId')?.toString();
          } else if (data['customer_id'] != null) {
            data['customer_id'] = data['customer_id'].toString();
          }
          if (data.containsKey('categoryId')) {
            data['category_id'] = data.remove('categoryId')?.toString();
          } else if (data['category_id'] != null) {
            data['category_id'] = data['category_id'].toString();
          }
          if (data.containsKey('serviceId')) {
            data['service_id'] = data.remove('serviceId')?.toString();
          } else if (data['service_id'] != null) {
            data['service_id'] = data['service_id'].toString();
          }
          await firestore.collection('payments').doc(id.toString()).set(data);
        }
      } catch (e) {
        errors.add('Errore payments: $e');
      }

      debugPrint('Inizio migrazione Users...');
      try {
        final users = await db.query('users');
        for (final u in users) {
          final data = Map<String, dynamic>.from(u);
          final id = data.remove('id');
          if (data['password_hash'] != null &&
              !PasswordHasher.isHashed(data['password_hash'].toString())) {
            data['password_hash'] =
                PasswordHasher.hashPassword(data['password_hash'].toString());
          }
          await firestore.collection('users').doc(id.toString()).set(data);
        }
      } catch (e) {
        errors.add('Errore users: $e');
      }
    } finally {
      await db.close();
    }

    if (errors.isNotEmpty) {
      throw Exception('Migrazione completata con errori:\n${errors.join('\n')}');
    }
  }
}
