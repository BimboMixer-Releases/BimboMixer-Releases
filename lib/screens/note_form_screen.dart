import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/app_theme_provider.dart';
import '../database/database_helper.dart';

class NoteFormScreen extends StatefulWidget {
  final Map<String, dynamic>? note;

  const NoteFormScreen({super.key, this.note});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  String _noteType = 'TEXT'; // 'TEXT' or 'CHECKLIST'
  List<Map<String, dynamic>> _checklistItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!['title'] ?? '';
      _noteType = widget.note!['type'] ?? 'TEXT';
      
      if (_noteType == 'TEXT') {
        _contentController.text = widget.note!['content'] ?? '';
      } else if (_noteType == 'CHECKLIST') {
        try {
          String contentJson = widget.note!['content'] ?? '[]';
          List<dynamic> parsedList = jsonDecode(contentJson);
          _checklistItems = parsedList.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (e) {
          _checklistItems = [];
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String content = '';
    if (_noteType == 'TEXT') {
      content = _contentController.text;
    } else {
      // Pulisci gli elementi vuoti
      _checklistItems.removeWhere((item) => (item['text'] as String).trim().isEmpty);
      content = jsonEncode(_checklistItems);
    }

    final db = DatabaseHelper();
    final data = {
      'title': _titleController.text,
      'type': _noteType,
      'content': content,
      'update_date': DateTime.now().toIso8601String().substring(0, 10),
    };

    try {
      if (widget.note == null) {
        data['creation_date'] = DateTime.now().toIso8601String().substring(0, 10);
        await db.insertNote(data);
      } else {
        data['id'] = widget.note!['id'];
        await db.updateNote(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildChecklistEditor() {
    return Column(
      children: [
        ..._checklistItems.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> item = entry.value;
          return Row(
            children: [
              Checkbox(
                value: item['checked'] ?? false,
                onChanged: (val) {
                  setState(() {
                    item['checked'] = val;
                  });
                },
                activeColor: Colors.blueAccent,
              ),
              Expanded(
                child: TextFormField(
                  initialValue: item['text'],
                  style: TextStyle(
                    color: Colors.white,
                    decoration: (item['checked'] == true) ? TextDecoration.lineThrough : null,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Elemento lista...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    item['text'] = val;
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white.withOpacity(0.54)),
                onPressed: () {
                  setState(() {
                    _checklistItems.removeAt(index);
                  });
                },
              )
            ],
          );
        }),
        SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _checklistItems.add({'text': '', 'checked': false});
            });
          },
          icon: Icon(Icons.add, color: Colors.blueAccent),
          label: Text('Aggiungi voce', style: TextStyle(color: Colors.blueAccent)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.note == null ? 'Nuova Nota' : 'Modifica Nota', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          _isSaving
              ? Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(Icons.check, color: Colors.blueAccent),
                  onPressed: _saveNote,
                )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Titolo',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.borderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Inserisci un titolo' : null,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Text('Tipo: ', style: TextStyle(color: Colors.white.withOpacity(0.54))),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Testo'),
                  selected: _noteType == 'TEXT',
                  onSelected: (val) => setState(() => _noteType = 'TEXT'),
                  selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                  labelStyle: TextStyle(color: _noteType == 'TEXT' ? Colors.blueAccent : Colors.white),
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Lista spunte'),
                  selected: _noteType == 'CHECKLIST',
                  onSelected: (val) => setState(() => _noteType = 'CHECKLIST'),
                  selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                  labelStyle: TextStyle(color: _noteType == 'CHECKLIST' ? Colors.blueAccent : Colors.white),
                ),
              ],
            ),
            SizedBox(height: 24),
            if (_noteType == 'TEXT')
              TextFormField(
                controller: _contentController,
                style: TextStyle(color: Colors.white),
                maxLines: null,
                minLines: 10,
                decoration: InputDecoration(
                  hintText: 'Scrivi qui la tua nota...',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildChecklistEditor(),
              ),
          ],
        ),
      ),
    );
  }
}


