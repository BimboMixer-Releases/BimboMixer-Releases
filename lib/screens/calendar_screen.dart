import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/date_utils_app.dart';
import '../utils/security_utils.dart';
import 'package:intl/intl.dart';
import '../providers/app_theme_provider.dart';
import 'package:provider/provider.dart';

class CalendarScreen extends StatefulWidget {
  final String role;
  const CalendarScreen({super.key, required this.role});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _dbHelper.getCalendarEvents();
    setState(() {
      _events = events;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredEvents = List.from(_events);
    } else {
      _filteredEvents = _events.where((e) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> _showEventDialog([Map<String, dynamic>? event]) async {
    bool authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    final isNew = event == null;
    final titleController = TextEditingController(text: isNew ? '' : event['title']);
    final dateController = TextEditingController(text: isNew ? '' : event['date']);
    bool isCompleted = isNew ? false : (event['is_completed'] == 1 || event['is_completed'] == true);
    bool isPaid = isNew ? false : (event['is_paid'] == 1 || event['is_paid'] == true);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              title: Text(isNew ? 'Nuovo Evento' : 'Modifica Evento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Titolo Evento'),
                  ),
                  TextField(
                    controller: dateController,
                    decoration: InputDecoration(labelText: 'Data (YYYY-MM-DD)'),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: Text('Completato'),
                    value: isCompleted,
                    onChanged: (val) => setStateBuilder(() => isCompleted = val ?? false),
                  ),
                  CheckboxListTile(
                    title: Text('Pagato'),
                    value: isPaid,
                    onChanged: (val) => setStateBuilder(() => isPaid = val ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annulla')),
                ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'title': titleController.text,
                      'date': dateController.text,
                      'is_completed': isCompleted ? 1 : 0,
                      'is_paid': isPaid ? 1 : 0,
                    };
                    if (isNew) {
                      await _dbHelper.insertCalendarEvent(data);
                    } else {
                      data['id'] = event['id'];
                      await _dbHelper.updateCalendarEvent(data);
                    }
                    if (mounted) Navigator.pop(ctx);
                    _loadEvents();
                  },
                  child: Text('Salva'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(String id) async {
    bool authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Conferma Elimina'),
        content: Text('Vuoi davvero eliminare questo evento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sì, Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteCalendarEvent(id);
      _loadEvents();
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> event, String field, bool value) async {
    bool authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    final updated = Map<String, dynamic>.from(event);
    updated[field] = value ? 1 : 0;
    await _dbHelper.updateCalendarEvent(updated);
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<AppThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario Eventi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cerca evento...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFilter();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _filteredEvents.isEmpty
                      ? Center(child: Text("Nessun evento trovato."))
                      : ListView.builder(
                          itemCount: _filteredEvents.length,
                          itemBuilder: (context, index) {
                            final event = _filteredEvents[index];
                            bool isCompleted = event['is_completed'] == 1 || event['is_completed'] == true;
                            bool isPaid = event['is_paid'] == 1 || event['is_paid'] == true;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(event['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(DateUtilsApp.formatDbDate(event['date'], themeProvider.dateFormat)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Completato', style: TextStyle(fontSize: 10)),
                                        SizedBox(
                                          height: 24,
                                          child: Checkbox(
                                            value: isCompleted,
                                            onChanged: (v) => _toggleStatus(event, 'is_completed', v ?? false),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 8),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Pagato', style: TextStyle(fontSize: 10)),
                                        SizedBox(
                                          height: 24,
                                          child: Checkbox(
                                            value: isPaid,
                                            onChanged: (v) => _toggleStatus(event, 'is_paid', v ?? false),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showEventDialog(event),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteEvent(event['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventDialog(),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
    );
  }
}


