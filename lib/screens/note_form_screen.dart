import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import '../database/database_helper.dart';

class _ChecklistEntry {
  final String id;
  bool checked;
  final TextEditingController controller;

  _ChecklistEntry({
    required this.id,
    required this.checked,
    required String text,
  }) : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
  }
}

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
  final List<_ChecklistEntry> _checklistEntries = [];
  int _nextChecklistId = 0;
  bool _isSaving = false;

  String _generateChecklistId() {
    return 'chk_${DateTime.now().microsecondsSinceEpoch}_${_nextChecklistId++}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!['title']?.toString() ?? '';
      _noteType = widget.note!['type']?.toString() ?? 'TEXT';

      if (_noteType == 'TEXT') {
        _contentController.text = widget.note!['content']?.toString() ?? '';
      } else if (_noteType == 'CHECKLIST') {
        try {
          final contentJson = widget.note!['content']?.toString() ?? '[]';
          final decoded = jsonDecode(contentJson);
          if (decoded is List) {
            for (final raw in decoded) {
              if (raw is Map) {
                final map = Map<String, dynamic>.from(raw);
                final existingId = map['id']?.toString();
                _checklistEntries.add(
                  _ChecklistEntry(
                    id: (existingId != null && existingId.isNotEmpty)
                        ? existingId
                        : _generateChecklistId(),
                    checked: map['checked'] == true,
                    text: map['text']?.toString() ?? '',
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Errore decodifica checklist: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (final entry in _checklistEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isSaving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    String content = '';
    if (_noteType == 'TEXT') {
      content = _contentController.text;
    } else {
      final serialized = _checklistEntries
          .where((entry) => entry.controller.text.trim().isNotEmpty)
          .map(
            (entry) => {
              'id': entry.id,
              'text': entry.controller.text.trim(),
              'checked': entry.checked,
            },
          )
          .toList();
      content = jsonEncode(serialized);
    }

    final db = DatabaseHelper();
    final todayIso = DateTime.now().toIso8601String().substring(0, 10);
    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'type': _noteType,
      'content': content,
      'update_date': todayIso,
    };

    try {
      if (widget.note == null) {
        data['creation_date'] = todayIso;
        await db.insertNote(data);
      } else {
        data['id'] = widget.note!['id'];
        await db.updateNote(data);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildChecklistEditor() {
    return Column(
      children: [
        ..._checklistEntries.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final item = mapEntry.value;
          return Row(
            key: ValueKey(item.id),
            children: [
              Checkbox(
                value: item.checked,
                onChanged: (val) {
                  setState(() {
                    item.checked = val ?? false;
                  });
                },
                activeColor: Colors.blueAccent,
              ),
              Expanded(
                child: TextFormField(
                  controller: item.controller,
                  style: TextStyle(
                    color: Colors.white,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Elemento lista...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.white.withValues(alpha: 0.54),
                ),
                onPressed: () {
                  setState(() {
                    final removed = _checklistEntries.removeAt(index);
                    removed.dispose();
                  });
                },
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _checklistEntries.add(
                _ChecklistEntry(
                  id: _generateChecklistId(),
                  checked: false,
                  text: '',
                ),
              );
            });
          },
          icon: const Icon(Icons.add, color: Colors.blueAccent),
          label: const Text(
            'Aggiungi voce',
            style: TextStyle(color: Colors.blueAccent),
          ),
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
        title: Text(
          widget.note == null ? 'Nuova Nota' : 'Modifica Nota',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check, color: Colors.blueAccent),
                  onPressed: _saveNote,
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Titolo',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Inserisci un titolo'
                  : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Tipo: ',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Testo'),
                  selected: _noteType == 'TEXT',
                  onSelected: (val) => setState(() => _noteType = 'TEXT'),
                  selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: _noteType == 'TEXT'
                        ? Colors.blueAccent
                        : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Lista spunte'),
                  selected: _noteType == 'CHECKLIST',
                  onSelected: (val) => setState(() => _noteType = 'CHECKLIST'),
                  selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: _noteType == 'CHECKLIST'
                        ? Colors.blueAccent
                        : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_noteType == 'TEXT')
              TextFormField(
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                minLines: 10,
                decoration: InputDecoration(
                  hintText: 'Scrivi qui la tua nota...',
                  hintStyle: const TextStyle(color: Colors.white38),
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


