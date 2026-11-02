import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import '../database/database_helper.dart';
import '../utils/security_utils.dart';
import 'note_form_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> notes = [];
    try {
      notes = await _dbHelper.getNotes();
    } catch (e) {
      debugPrint('Errore caricamento note: $e');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _deleteNote(String id) async {
    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          'Elimina nota',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Sei sicuro di voler eliminare questa nota?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annulla',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _dbHelper.deleteNote(id);
        if (!mounted) {
          return;
        }
        await _loadNotes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore eliminazione nota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Note Generali',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _notes.isEmpty
          ? Center(
              child: Text(
                'Nessuna nota presente.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                final noteId = note['id']?.toString();
                final title = note['title']?.toString() ?? 'Senza Titolo';
                final date =
                    (note['update_date'] ?? note['creation_date'] ?? '')
                        .toString();
                final type = note['type']?.toString() ?? 'TEXT';

                return Card(
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.borderColor),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                      child: Icon(
                        type == 'CHECKLIST' ? Icons.checklist : Icons.notes,
                        color: Colors.blueAccent,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: noteId == null
                          ? null
                          : () => _deleteNote(noteId),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteFormScreen(note: note),
                        ),
                      );
                      if (mounted) {
                        await _loadNotes();
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoteFormScreen()),
          );
          if (mounted) {
            await _loadNotes();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
