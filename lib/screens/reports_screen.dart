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

  void _showSubmitBottomSheet(BuildContext context, String collection, String title) {
    final TextEditingController textCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    String? selectedCategory;

    final categories = collection == 'bug_reports'
        ? ['Interfaccia Utente', 'Errore di Calcolo', 'Crash/Blocco', 'Altro']
        : ['Nuova Funzionalità', 'Miglioramento UI', 'Integrazione', 'Altro'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 32,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        collection == 'bug_reports' ? Icons.bug_report : Icons.lightbulb,
                        color: collection == 'bug_reports' ? const Color(0xFFF06292) : const Color(0xFFFFD54F),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aiutaci a migliorare l\'app descrivendo dettagliatamente il problema o la tua idea.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  // Category Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2D3E),
                        hint: Text(
                          'Seleziona Categoria',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        value: selectedCategory,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        items: categories.map((String cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCategory = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'La tua Email (Opzionale)',
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF22D3EE), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description Field
                  TextField(
                    controller: textCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Descrizione dettagliata...',
                      alignLabelWithHint: true,
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF22D3EE), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: collection == 'bug_reports' ? const Color(0xFFF06292) : const Color(0xFFFFD54F),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (selectedCategory == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Seleziona una categoria.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        if (textCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Inserisci una descrizione.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        
                        try {
                          await FirebaseFirestore.instance.collection(collection).add({
                            'category': selectedCategory,
                            'text': textCtrl.text.trim(),
                            'user_email': emailCtrl.text.trim().isEmpty ? 'Utente Anonimo' : emailCtrl.text.trim(),
                            'timestamp': FieldValue.serverTimestamp(),
                            'status': 'Nuovo', // Added status for professional tracking
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Grazie! Segnalazione inviata con successo.'), 
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
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
                      child: const Text(
                        'INVIA SEGNALAZIONE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }
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
            // Professional App Bar Header
            Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF16192B),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support Center',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Invia report e suggerimenti',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D3E),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: const Color(0xFF383C53),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bug_report, size: 18),
                        SizedBox(width: 8),
                        Text('Bug'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb, size: 18),
                        SizedBox(width: 8),
                        Text('Idee'),
                      ],
                    ),
                  ),
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

            // Floating Action Buttons area (Alternative to bottom bar for a cleaner look)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0F111A),
                    const Color(0xFF0F111A).withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF06292).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFF06292),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: const Color(0xFFF06292).withValues(alpha: 0.5)),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _showSubmitBottomSheet(context, 'bug_reports', 'Segnala un Problema'),
                        icon: const Icon(Icons.bug_report_rounded),
                        label: const Text('Segnala Bug', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFFFD54F),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _showSubmitBottomSheet(context, 'suggestions', 'Nuova Idea'),
                        icon: const Icon(Icons.lightbulb_rounded),
                        label: const Text('Dai Consigli', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text('Errore di connessione: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                ),
                const SizedBox(height: 24),
                Text(
                  collection == 'bug_reports' ? 'Nessun bug segnalato!' : 'Nessun consiglio per ora.',
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa i pulsanti in basso per inviare feedback.',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate())
                : 'Data sconosciuta';
            
            final email = data['user_email'] ?? 'Utente Anonimo';
            final text = data['text'] ?? '';
            final category = data['category'] ?? 'Generale';
            final status = data['status'] ?? 'Nuovo';
            
            // Professional Ticket Card
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onLongPress: () => _showDeleteDialog(context, docs[index].reference),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'Risolto' || status == 'Implementato' 
                                    ? Colors.green.withValues(alpha: 0.15) 
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'Risolto' || status == 'Implementato' 
                                      ? Colors.greenAccent 
                                      : Colors.white60,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, size: 12, color: Colors.white70),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11, 
                                color: Colors.white.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Text('Elimina Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Vuoi davvero eliminare questo report? L\'operazione è irreversibile.', 
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              docRef.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Elimina Definitivamente', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
