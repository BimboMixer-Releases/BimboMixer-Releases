import 'package:flutter/material.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
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
  
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _selectedDate = DateTime.now();
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
    final titleController = TextEditingController(
      text: isNew ? '' : event['title'],
    );
    final dateController = TextEditingController(
      text: isNew ? DateFormat('dd/MM/yyyy').format(_selectedDate ?? DateTime.now()) : event['date'],
    );
    bool isCompleted = isNew
        ? false
        : (event['is_completed'] == 1 || event['is_completed'] == true);
    bool isPaid = isNew
        ? false
        : (event['is_paid'] == 1 || event['is_paid'] == true);

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
                    decoration: InputDecoration(labelText: 'Data (YYYY-MM-DD o DD/MM/YYYY)'),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      final date = await GlassDatePicker.show(context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        dateController.text = DateFormat(
                          'dd/MM/yyyy',
                        ).format(date);
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: Text('Completato'),
                    value: isCompleted,
                    onChanged: (v) => setStateBuilder(() => isCompleted = v ?? false),
                  ),
                  CheckboxListTile(
                    title: Text('Pagato'),
                    value: isPaid,
                    onChanged: (v) => setStateBuilder(() => isPaid = v ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final data = {
                      'title': titleController.text,
                      'date': dateController.text,
                      'is_completed': isCompleted ? 1 : 0,
                      'is_paid': isPaid ? 1 : 0,
                      'updated_at': DateTime.now().toIso8601String(),
                    };
                    if (isNew) {
                      data['created_at'] = DateTime.now().toIso8601String();
                      await _dbHelper.insertCalendarEvent(data);
                    } else {
                      data['id'] = event['id'];
                      await _dbHelper.updateCalendarEvent(data);
                    }
                    _loadEvents();
                  },
                  child: Text('Salva'),
                ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No'),
          ),
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

  Future<void> _toggleStatus(
    Map<String, dynamic> event,
    String field,
    bool value,
  ) async {
    bool authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    final updated = Map<String, dynamic>.from(event);
    updated[field] = value ? 1 : 0;
    await _dbHelper.updateCalendarEvent(updated);
    _loadEvents();
  }

  // --- CALENDAR LOGIC ---
  int get _daysInMonth => DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
  
  // Ritorna gli eventi per una determinata data
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _filteredEvents.where((e) {
      try {
        final dStr = e['date'].toString();
        DateTime? d;
        if (dStr.contains('/')) {
           d = DateFormat('dd/MM/yyyy').parse(dStr);
        } else if (dStr.contains('-')) {
           d = DateTime.parse(dStr);
        }
        return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Il colore di sfondo del design
    final Color bgColor = const Color(0xFF0F0C1B);
    
    // Calcoliamo la griglia del calendario
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    int startingWeekday = firstDayOfMonth.weekday; // 1 = Monday
    
    // Lista di date per i bottoni della griglia
    List<DateTime?> calendarGrid = [];
    // Spazi vuoti per i giorni del mese precedente
    for (int i = 1; i < startingWeekday; i++) {
      calendarGrid.add(null);
    }
    // Giorni del mese corrente
    for (int i = 1; i <= _daysInMonth; i++) {
      calendarGrid.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    // Completa l'ultima settimana per avere celle vuote (opzionale per design, 6 file * 7 gg = 42 celle max, in questo design sono esatte 6 file)
    int remainingCells = 42 - calendarGrid.length;
    for (int i = 0; i < remainingCells; i++) {
      calendarGrid.add(null);
    }

    final selectedEvents = _selectedDate != null ? _getEventsForDay(_selectedDate!) : [];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER: Mese e Anno ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white70),
                              onPressed: () {
                                setState(() {
                                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white70),
                              onPressed: () {
                                setState(() {
                                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- WEEKDAYS ROW ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                        return SizedBox(
                          width: MediaQuery.of(context).size.width / 8,
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- CALENDAR GRID ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: calendarGrid.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, index) {
                        final date = calendarGrid[index];
                        if (date == null) {
                          // Cella vuota effetto vetro
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                          );
                        }

                        final isSelected = _selectedDate != null && 
                            date.year == _selectedDate!.year && 
                            date.month == _selectedDate!.month && 
                            date.day == _selectedDate!.day;
                            
                        final dayEvents = _getEventsForDay(date);
                        final hasEvents = dayEvents.isNotEmpty;
                        
                        // Per il design dell'immagine: colori accesi in base a qualcosa (qui usiamo index pari/dispari o ID fittizio per dare varietà)
                        Color glowColor = Colors.transparent;
                        String eventText = "";
                        if (hasEvents) {
                           // Scegliamo cyan o magenta in base alla lunghezza del titolo
                           glowColor = dayEvents.first['title'].toString().length % 2 == 0 
                               ? const Color(0xFF00E5FF) 
                               : const Color(0xFFC040FF);
                           eventText = dayEvents.first['title'].toString();
                           // Limita testo a due parole
                           List<String> words = eventText.split(' ');
                           if (words.length > 2) {
                             eventText = words[0] + '\\n' + words[1];
                           }
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? glowColor.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected && hasEvents
                                  ? [
                                      BoxShadow(
                                        color: glowColor.withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 6,
                                  left: 8,
                                  child: Text(
                                    date.day.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (hasEvents)
                                  Positioned.fill(
                                    top: 18,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: glowColor,
                                            boxShadow: [
                                              BoxShadow(
                                                color: glowColor,
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          eventText.replaceAll('\\n', '\n'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 8,
                                            height: 1.1,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- DAILY OVERVIEW PANEL ---
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Section (Selected Date)
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _selectedDate != null ? DateFormat('E, MMM d').format(_selectedDate!) : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            // Right Section (Events List)
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Daily Overview',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: selectedEvents.isEmpty
                                          ? const Text(
                                              'Nessun evento.',
                                              style: TextStyle(color: Colors.white54, fontSize: 13),
                                            )
                                          : ListView.separated(
                                              itemCount: selectedEvents.length,
                                              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                                              itemBuilder: (context, index) {
                                                final e = selectedEvents[index];
                                                Color glowColor = e['title'].toString().length % 2 == 0 
                                                   ? const Color(0xFF00E5FF) 
                                                   : const Color(0xFFC040FF);
                                                
                                                return GestureDetector(
                                                  onTap: () => _showEventDialog(e),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: glowColor,
                                                          boxShadow: [
                                                            BoxShadow(color: glowColor, blurRadius: 4)
                                                          ]
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          e['title'] ?? '',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 18),
                                                        onPressed: () => _deleteEvent(e['id']),
                                                      )
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventDialog(),
        backgroundColor: const Color(0xFFC040FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
