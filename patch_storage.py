import re

# 1. Patch AttachmentService
with open('lib/services/attachment_service.dart', 'r', encoding='utf-8') as f:
    code = f.read()

delete_func = '''
  /// Deletes a file from Firebase Storage given its download URL
  Future<void> deleteAttachment(String url) async {
    if (url.isEmpty || !url.contains('firebasestorage')) return;
    try {
      Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Errore durante l\\'eliminazione dell\\'allegato: \');
    }
  }
'''

# Inserisci deleteAttachment prima di downloadAttachment
code = code.replace(
    "  /// Scarica un allegato e lo salva in locale",
    delete_func + "\n  /// Scarica un allegato e lo salva in locale"
)

with open('lib/services/attachment_service.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# 2. Patch DatabaseHelper
with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    db_code = f.read()

# Add import if missing
if "import '../services/attachment_service.dart';" not in db_code:
    db_code = db_code.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport '../services/attachment_service.dart';\nimport 'dart:convert';")

# Replace deletePayment
payment_delete = '''  Future<void> deletePayment(String id) async {
    try {
      final doc = await _db.collection('payments').doc(id).get();
      if (doc.exists && doc.data() != null) {
         final data = doc.data()!;
         if (data['attachments'] != null && data['attachments'].toString().isNotEmpty) {
            try {
               final List<dynamic> atts = jsonDecode(data['attachments'].toString());
               final _attService = AttachmentService();
               for (var att in atts) {
                  await _attService.deleteAttachment(att.toString());
               }
            } catch (_) {}
         }
      }
    } catch (_) {}
    await _db.collection('payments').doc(id).delete();'''
db_code = re.sub(r'  Future<void> deletePayment\(String id\) async \{\s*await _db\.collection\(\'payments\'\)\.doc\(id\)\.delete\(\);', payment_delete, db_code)

# Replace deleteInvoice
invoice_delete = '''  Future<void> deleteInvoice(String id) async {
    try {
      final doc = await _db.collection('invoices').doc(id).get();
      if (doc.exists && doc.data() != null) {
         final data = doc.data()!;
         if (data['attachments'] != null && data['attachments'] is List) {
            final _attService = AttachmentService();
            for (var att in data['attachments']) {
               await _attService.deleteAttachment(att.toString());
            }
         }
      }
    } catch (_) {}
    await _db.collection('invoices').doc(id).delete();'''
db_code = re.sub(r'  Future<void> deleteInvoice\(String id\) async \{\s*await _db\.collection\(\'invoices\'\)\.doc\(id\)\.delete\(\);', invoice_delete, db_code)

# Replace deleteDeadline
deadline_delete = '''  Future<void> deleteDeadline(String id) async {
    try {
      final doc = await _db.collection('deadlines').doc(id).get();
      if (doc.exists && doc.data() != null) {
         final data = doc.data()!;
         if (data['attachments'] != null && data['attachments'] is List) {
            final _attService = AttachmentService();
            for (var att in data['attachments']) {
               await _attService.deleteAttachment(att.toString());
            }
         }
      }
    } catch (_) {}
    await _db.collection('deadlines').doc(id).delete();'''
db_code = re.sub(r'  Future<void> deleteDeadline\(String id\) async \{\s*await _db\.collection\(\'deadlines\'\)\.doc\(id\)\.delete\(\);', deadline_delete, db_code)

# Replace deleteQuote
quote_delete = '''  Future<void> deleteQuote(String id) async {
    try {
      final doc = await _db.collection('quotes').doc(id).get();
      if (doc.exists && doc.data() != null) {
         final data = doc.data()!;
         if (data['file_url'] != null && data['file_url'].toString().isNotEmpty) {
            final _attService = AttachmentService();
            await _attService.deleteAttachment(data['file_url'].toString());
         }
      }
    } catch (_) {}
    await _db.collection('quotes').doc(id).delete();'''
db_code = re.sub(r'  Future<void> deleteQuote\(String id\) async \{\s*await _db\.collection\(\'quotes\'\)\.doc\(id\)\.delete\(\);', quote_delete, db_code)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(db_code)

