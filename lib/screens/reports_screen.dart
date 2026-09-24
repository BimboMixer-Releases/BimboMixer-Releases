import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSubmitDialog(BuildContext context, String collection, String title) {
    final TextEditingController textCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF22D3EE), width: 1.5),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'La tua Email (Opzionale)',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF22D3EE))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Descrizione...',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF22D3EE))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22D3EE),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (textCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Inserisci una descrizione.')),
                );
                return;
              }
              try {
                await FirebaseFirestore.instance.collection(collection).add({
                  'text': textCtrl.text.trim(),
                  'user_email': emailCtrl.text.trim().isEmpty ? 'Utente Anonimo' : emailCtrl.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Segnalazione inviata con successo!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('INVIA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F111A), Color(0xFF16192B)],
          ),
        ),
        child: Column(
          children: [
            // App Bar Custom
            Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF16192B),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Report & Consigli',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              color: const Color(0xFF16192B),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFB388FF),
                indicatorWeight: 3,
                labelColor: const Color(0xFFB388FF),
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(icon: Icon(Icons.bug_report), text: 'Bug Segnalati'),
                  Tab(icon: Icon(Icons.lightbulb), text: 'Suggerimenti'),
                ],
              ),
            ),
            
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ReportsList(collection: 'bug_reports', iconData: Icons.bug_report, accentColor: Color(0xFFF06292)),
                  _ReportsList(collection: 'suggestions', iconData: Icons.lightbulb_outline, accentColor: Color(0xFFFFD54F)),
                ],
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF16192B),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Riporta Bug Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF06292).withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFFF06292),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFF06292)),
                        ),
                      ),
                      onPressed: () => _showSubmitDialog(context, 'bug_reports', 'Riporta un Bug'),
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Riporta Bug', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    
                    // Suggerimenti Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFFFFD54F),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFFFD54F)),
                        ),
                      ),
                      onPressed: () => _showSubmitDialog(context, 'suggestions', 'Invia Suggerimento'),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Sugg.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  final String collection;
  final IconData iconData;
  final Color accentColor;

  const _ReportsList({
    required this.collection,
    required this.iconData,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: accentColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'Nessun report trovato.',
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                : 'Data sconosciuta';
            
            final email = data['user_email'] ?? 'Utente Anonimo';
            final text = data['text'] ?? '';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: accentColor.withValues(alpha: 0.2),
                  child: Icon(iconData, color: accentColor),
                ),
                title: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
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
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminare questo report?', style: TextStyle(color: Colors.white)),
        content: const Text('Questa azione è irreversibile.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              docRef.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
