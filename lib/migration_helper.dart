import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class MigrationHelper {
  static Future<void> migrate() async {
    List<String> errors = [];
    final dbPath = 'C:\\Users\\Hp\\Documents\\contabile_app\\contabile.db';
    if (!File(dbPath).existsSync()) {
      throw Exception('Database locale (SQLite) non trovato in: $dbPath');
    }
    
    final db = await openDatabase(dbPath);
    final firestore = FirebaseFirestore.instance;

    print('Inizio migrazione Customers...');
    try {
      final customers = await db.query('customers');
      for (var c in customers) {
        final data = Map<String, dynamic>.from(c);
        final id = data.remove('id');
        await firestore.collection('customers').doc(id.toString()).set(data);
      }
    } catch (e) {
      errors.add('Errore customers: $e');
    }

    print('Inizio migrazione Categories...');
    try {
      final categories = await db.query('categories');
      for (var c in categories) {
        final data = Map<String, dynamic>.from(c);
        final id = data.remove('id');
        await firestore.collection('categories').doc(id.toString()).set(data);
      }
    } catch (e) {
      errors.add('Errore categories: $e');
    }

    print('Inizio migrazione Service Types...');
    try {
      final services = await db.query('service_types');
      for (var s in services) {
        final data = Map<String, dynamic>.from(s);
        final id = data.remove('id');
        await firestore.collection('service_types').doc(id.toString()).set(data);
      }
    } catch (e) {
      errors.add('Errore service_types: $e');
    }

    print('Inizio migrazione Payments...');
    try {
      final payments = await db.query('payments');
      for (var p in payments) {
        final data = Map<String, dynamic>.from(p);
        final id = data.remove('id');
        if (data['customerId'] != null) data['customerId'] = data['customerId'].toString();
        if (data['categoryId'] != null) data['categoryId'] = data['categoryId'].toString();
        if (data['serviceId'] != null) data['serviceId'] = data['serviceId'].toString();
        
        await firestore.collection('payments').doc(id.toString()).set(data);
      }
    } catch (e) {
      errors.add('Errore payments: $e');
    }

    print('Inizio migrazione Users...');
    try {
      final users = await db.query('users');
      for (var u in users) {
        final data = Map<String, dynamic>.from(u);
        final id = data.remove('id');
        await firestore.collection('users').doc(id.toString()).set(data);
      }
    } catch (e) {
      errors.add('Errore users: $e');
    }

    if (errors.isNotEmpty) {
      throw Exception('Migrazione completata con errori:\n${errors.join('\n')}');
    }
  }
}
