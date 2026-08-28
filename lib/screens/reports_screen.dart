import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Report & Consigli (TaxFlow Pro)'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bug_report), text: 'Bug Segnalati'),
              Tab(icon: Icon(Icons.lightbulb), text: 'Suggerimenti'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReportsList(collection: 'bug_reports'),
            _ReportsList(collection: 'suggestions'),
          ],
        ),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  final String collection;

  const _ReportsList({required this.collection, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Nessun report trovato.', style: TextStyle(fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                : 'Data sconosciuta';
            
            final email = data['user_email'] ?? 'Utente Anonimo';
            final text = data['text'] ?? '';
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(text),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Da: $email\nData: $dateStr',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                isThreeLine: true,
                onLongPress: () {
                  _showDeleteDialog(context, docs[index].reference);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, DocumentReference docRef) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare questo report?'),
        content: const Text('Questa azione è irreversibile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              docRef.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
