import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_theme_provider.dart';
import '../database/database_helper.dart';
import '../services/attachment_service.dart';
import '../utils/security_utils.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _quotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoading = true);
    try {
      final q = await _dbHelper.getQuotes();
      if (mounted) {
        setState(() {
          _quotes = q;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento preventivi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadQuote() async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    try {
      File? file = await _attachmentService.pickFile(context);
      if (file == null) return;

      setState(() => _isLoading = true);

      // Upload file
      String? url = await _attachmentService.uploadAttachment(file, 'quotes');
      if (url == null) {
        throw Exception("Upload fallito");
      }

      // Compute next serial number
      int nextSerial = 1;
      if (_quotes.isNotEmpty) {
        for (var q in _quotes) {
          int s = int.tryParse(q['serial_number']?.toString() ?? '0') ?? 0;
          if (s >= nextSerial) {
            nextSerial = s + 1;
          }
        }
      }

      await _dbHelper.insertQuote({
        'serial_number': nextSerial,
        'file_name': p.basename(file.path),
        'file_url': url,
        'accepted': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _loadQuotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preventivo caricato con successo!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editSerialNumber(Map<String, dynamic> quote) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    final tc = TextEditingController(text: quote['serial_number']?.toString() ?? '');

    final newSerialStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Modifica Seriale', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: tc,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Numero Seriale',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Annulla', style: TextStyle(color: Colors.white.withOpacity(0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, tc.text),
            child: Text('Salva', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (newSerialStr != null && newSerialStr.isNotEmpty) {
      final newSerial = int.tryParse(newSerialStr);
      if (newSerial != null) {
        await _dbHelper.updateQuote({'id': quote['id'], 'serial_number': newSerial});
        _loadQuotes();
      }
    }
  }

  Future<void> _toggleAccepted(Map<String, dynamic> quote, bool? value) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    await _dbHelper.updateQuote({'id': quote['id'], 'accepted': value ?? false});
    _loadQuotes();
  }

  Future<void> _deleteQuote(String id) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Elimina', style: TextStyle(color: Colors.white)),
        content: Text('Eliminare questo preventivo?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla', style: TextStyle(color: Colors.white.withOpacity(0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Elimina', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteQuote(id);
      _loadQuotes();
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il file.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
            },
          ),
        ),
        title: Text('Preventivi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadQuote,
        backgroundColor: theme.primaryColor,
        child: Icon(Icons.upload_file, color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _quotes.isEmpty
              ? Center(
                  child: Text('Nessun preventivo presente.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _quotes.length,
                  itemBuilder: (context, index) {
                    final quote = _quotes[index];
                    final isAccepted = quote['accepted'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.borderColor),
                      ),
                      child: ListTile(
                        leading: InkWell(
                          onTap: () => _editSerialNumber(quote),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#${quote['serial_number'] ?? '0'}',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        title: InkWell(
                          onTap: () => _openFile(quote['file_url'] ?? ''),
                          child: Text(
                            quote['file_name'] ?? 'Sconosciuto',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isAccepted,
                              onChanged: (val) => _toggleAccepted(quote, val),
                              activeColor: Colors.greenAccent,
                              checkColor: Colors.black,
                            ),
                            Text('Accettato', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteQuote(quote['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}



