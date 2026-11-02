import 'package:flutter/material.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../utils/date_utils_app.dart';
import '../utils/security_utils.dart';

class CalendarScreen extends StatefulWidget {
  final String role;
  const CalendarScreen({super.key, required this.role});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _magenta = Color(0xFFC040FF);
  static const List<String> _weekdays = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _isBusy = false;

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateUtils.dateOnly(now);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _dbHelper.getCalendarEvents();
      if (!mounted) {
        return;
      }
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showSnack('Errore caricamento eventi: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _showEventDialog([Map<String, dynamic>? event]) async {
    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) {
      return;
    }

    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CalendarEventDialog(
        event: event,
        initialDate: _selectedDate ?? DateTime.now(),
      ),
    );
    if (data == null || !mounted) {
      return;
    }

    try {
      if (event == null) {
        data['created_at'] = DateTime.now().toIso8601String();
        await _dbHelper.insertCalendarEvent(data);
      } else {
        data['id'] = event['id'];
        await _dbHelper.updateCalendarEvent(data);
      }
      await _loadEvents();
    } catch (e) {
      _showSnack('Errore salvataggio evento: $e', Colors.red);
    }
  }

  Future<void> _deleteEvent(dynamic rawId) async {
    final id = rawId?.toString();
    if (id == null || id.isEmpty) {
      return;
    }
    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Elimina'),
        content: const Text('Vuoi davvero eliminare questo evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sì, Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteCalendarEvent(id);
        await _loadEvents();
      } catch (e) {
        _showSnack('Errore eliminazione evento: $e', Colors.red);
      }
    }
  }

  Future<void> _toggleCompleted(Map<String, dynamic> event, bool value) async {
    if (_isBusy) {
      return;
    }
    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final updated = Map<String, dynamic>.from(event);
      updated['is_completed'] = value ? 1 : 0;
      updated['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.updateCalendarEvent(updated);
      await _loadEvents();
    } catch (e) {
      _showSnack('Errore aggiornamento evento: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  // --- CALENDAR LOGIC ---
  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events.where((e) {
      final d = DateUtilsApp.tryParseDate(e['date']?.toString());
      return d != null && DateUtils.isSameDay(d, day);
    }).toList();
  }

  Color _colorFor(Map<String, dynamic> e) {
    return (e['title'] ?? '').toString().length % 2 == 0 ? _cyan : _magenta;
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0F0C1B);

    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Lunedì

    final List<DateTime?> calendarGrid = [];
    for (int i = 1; i < startingWeekday; i++) {
      calendarGrid.add(null);
    }
    for (int i = 1; i <= _daysInMonth; i++) {
      calendarGrid.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    while (calendarGrid.length < 42) {
      calendarGrid.add(null);
    }

    final selectedEvents = _selectedDate != null
        ? _getEventsForDay(_selectedDate!)
        : <Map<String, dynamic>>[];

    final monthLabel = DateFormat('MMMM yyyy', 'it_IT').format(_currentMonth);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Calendario', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  // Evita overflow verticale della griglia su schermi larghi (PC)
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER: Mese e Anno ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                monthLabel.isEmpty
                                    ? monthLabel
                                    : monthLabel[0].toUpperCase() +
                                          monthLabel.substring(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white70,
                              ),
                              onPressed: () => setState(() {
                                _currentMonth = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month - 1,
                                  1,
                                );
                              }),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                              onPressed: () => setState(() {
                                _currentMonth = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month + 1,
                                  1,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                      // --- WEEKDAYS ROW ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: _weekdays
                              .map(
                                (day) => Expanded(
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
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // --- CALENDAR GRID ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: calendarGrid.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childAspectRatio: 0.95,
                              ),
                          itemBuilder: (context, index) =>
                              _buildDayCell(calendarGrid[index]),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- DAILY OVERVIEW PANEL ---
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildDailyPanel(selectedEvents),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventDialog(),
        backgroundColor: _magenta,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDayCell(DateTime? date) {
    if (date == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
      );
    }

    final isSelected =
        _selectedDate != null && DateUtils.isSameDay(date, _selectedDate);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final dayEvents = _getEventsForDay(date);
    final hasEvents = dayEvents.isNotEmpty;

    Color glowColor = Colors.white;
    String eventText = '';
    if (hasEvents) {
      glowColor = _colorFor(dayEvents.first);
      final words = (dayEvents.first['title'] ?? '').toString().split(' ');
      eventText = words.length > 2 ? '${words[0]}\n${words[1]}' : words.join(' ');
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? glowColor.withValues(alpha: 0.8)
                : (isToday
                      ? _cyan.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected && hasEvents
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 6,
              child: Text(
                date.day.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glowColor,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Flexible(
                      child: Text(
                        eventText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyPanel(List<Map<String, dynamic>> selectedEvents) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedDate != null
                ? DateFormat('EEEE d MMMM', 'it_IT').format(_selectedDate!)
                : 'Riepilogo giornaliero',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: selectedEvents.isEmpty
                ? const Text(
                    'Nessun evento.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  )
                : ListView.separated(
                    itemCount: selectedEvents.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final e = selectedEvents[index];
                      final glowColor = _colorFor(e);
                      final completed =
                          e['is_completed'] == 1 || e['is_completed'] == true;
                      final paid = e['is_paid'] == 1 || e['is_paid'] == true;
                      return InkWell(
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
                                  BoxShadow(color: glowColor, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (e['title'] ?? '').toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  decoration: completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (paid)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.euro,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),
                              ),
                            Checkbox(
                              value: completed,
                              onChanged: _isBusy
                                  ? null
                                  : (v) => _toggleCompleted(e, v ?? false),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white30,
                                size: 18,
                              ),
                              tooltip: 'Elimina evento',
                              onPressed: () => _deleteEvent(e['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dialog creazione/modifica evento con controller correttamente disposti.
class _CalendarEventDialog extends StatefulWidget {
  final Map<String, dynamic>? event;
  final DateTime initialDate;

  const _CalendarEventDialog({this.event, required this.initialDate});

  @override
  State<_CalendarEventDialog> createState() => _CalendarEventDialogState();
}

class _CalendarEventDialogState extends State<_CalendarEventDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _dateCtrl;
  late bool _isCompleted;
  late bool _isPaid;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: (e?['title'] ?? '').toString());
    final parsed = DateUtilsApp.tryParseDate(e?['date']?.toString());
    _dateCtrl = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(parsed ?? widget.initialDate),
    );
    _isCompleted = e != null && (e['is_completed'] == 1 || e['is_completed'] == true);
    _isPaid = e != null && (e['is_paid'] == 1 || e['is_paid'] == true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current =
        DateUtilsApp.tryParseDate(_dateCtrl.text) ?? widget.initialDate;
    final date = await GlassDatePicker.show(
      context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() => _dateCtrl.text = DateFormat('dd/MM/yyyy').format(date));
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final date = DateUtilsApp.tryParseDate(_dateCtrl.text);
    if (title.isEmpty || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un titolo e una data valida.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': title,
      'date': DateFormat('dd/MM/yyyy').format(date),
      'is_completed': _isCompleted ? 1 : 0,
      'is_paid': _isPaid ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.event == null;
    return AlertDialog(
      title: Text(isNew ? 'Nuovo Evento' : 'Modifica Evento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titolo Evento'),
            ),
            TextField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Data',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _pickDate,
            ),
            CheckboxListTile(
              title: const Text('Completato'),
              value: _isCompleted,
              onChanged: (v) => setState(() => _isCompleted = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Saldato'),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
