import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/attachment_service.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _deadlines = [];
  bool _isLoading = true;
  String _selectedTab = 'Tutte';

  @override
  void initState() {
    super.initState();
    _loadDeadlines();
  }

  Future<void> _loadDeadlines() async {
    setState(() => _isLoading = true);
    final deadlines = await _dbHelper.getDeadlines();
    setState(() {
      _deadlines = deadlines;
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire l\'allegato')));
      }
    }
  }

  // ─── Calcoli totali ────────────────────────────────────────────────────────

  double get _totalPaid => _deadlines
      .where((d) => d['status'] == 'PAID')
      .fold(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));

  double get _totalPending => _deadlines
      .where((d) => d['status'] == 'PENDING')
      .fold(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));

  // ─── Formattazione data ────────────────────────────────────────────────────

  String _formatDate(String? isoDate, String dateFormat) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat(dateFormat).format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _buildDateLabel(Map<String, dynamic> d, String dateFormat) {
    final from = _formatDate(d['date_from'] as String?, dateFormat);
    final to = _formatDate(d['date_to'] as String?, dateFormat);
    if (to.isEmpty || to == from) return from;
    return '$from → $to';
  }

  // ─── Badge stato ──────────────────────────────────────────────────────────

  _DeadlineStatus _getDeadlineStatus(Map<String, dynamic> d) {
    if (d['status'] == 'PAID') return _DeadlineStatus.paid;
    final dateStr = d['date_from'] as String?;
    if (dateStr != null) {
      try {
        final dt = DateTime.parse(dateStr);
        if (dt.isBefore(DateTime.now())) return _DeadlineStatus.overdue;
      } catch (_) {}
    }
    return _DeadlineStatus.pending;
  }

  // ─── Toggle pagamento rapido ───────────────────────────────────────────────

  Future<void> _togglePaid(Map<String, dynamic> d) async {
    final newStatus = d['status'] == 'PAID' ? 'PENDING' : 'PAID';
    final updated = Map<String, dynamic>.from(d)..['status'] = newStatus;
    await _dbHelper.updateDeadline(updated);
    _loadDeadlines();
  }

  // ─── Aggiungi a Google Calendar ───────────────────────────────────────────

  void _addToCalendar(Map<String, dynamic> d) {
    final title = d['title'] as String? ?? 'Scadenza';
    final notes = d['notes'] as String? ?? '';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final description =
        '${notes.isNotEmpty ? '$notes\n' : ''}Importo: €${amount.toStringAsFixed(2)}';

    DateTime startDate;
    DateTime endDate;
    try {
      startDate = DateTime.parse(d['date_from'] as String? ?? '');
    } catch (_) {
      startDate = DateTime.now();
    }
    final dateToStr = d['date_to'] as String?;
    if (dateToStr != null && dateToStr.isNotEmpty) {
      try {
        endDate = DateTime.parse(dateToStr);
      } catch (_) {
        endDate = startDate;
      }
    } else {
      endDate = startDate;
    }

    final event = Event(
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      allDay: true,
    );

    Add2Calendar.addEvent2Cal(event);
  }

  // ─── Dialog nuova/modifica scadenza ──────────────────────────────────────

  void _showDeadlineDialog({Map<String, dynamic>? deadline, bool isReadOnly = false}) {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final dateFormat = theme.dateFormat;

    final titleCtrl =
        TextEditingController(text: deadline?['title']?.toString() ?? '');
    final amountCtrl =
        TextEditingController(text: deadline?['amount']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: deadline?['notes']?.toString() ?? '');

    DateTime? dateFrom;
    DateTime? dateTo;

    // Leggi le date esistenti
    try {
      final df = deadline?['date_from'] as String?;
      if (df != null && df.isNotEmpty) dateFrom = DateTime.parse(df);
    } catch (_) {}
    try {
      final dt = deadline?['date_to'] as String?;
      if (dt != null && dt.isNotEmpty) dateTo = DateTime.parse(dt);
    } catch (_) {}

    String status = deadline?['status']?.toString() ?? 'PENDING';

    List<String> attachments = [];
    if (deadline != null && deadline['attachments'] != null) {
      attachments = List<String>.from(deadline['attachments']);
    }
    bool isUploading = false;

    Future<void> pickDate(
        StateSetter setD, bool isFrom) async {
      final now = DateTime.now();
      final initial = isFrom ? (dateFrom ?? now) : (dateTo ?? dateFrom ?? now);
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF1E1E24),
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        setD(() {
          if (isFrom) {
            dateFrom = picked;
          } else {
            dateTo = picked;
          }
        });
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => Dialog(
          backgroundColor: const Color(0xFF1A1A22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intestazione
                  Row(
                    children: [
                      Icon(Icons.event, color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Text(
                        deadline == null
                            ? 'Nuova Scadenza'
                            : 'Modifica Scadenza',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  IgnorePointer(
                    ignoring: isReadOnly,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titolo
                        _dialogField(
                          controller: titleCtrl,
                          label: 'Titolo (es. INPS, IVA trimestrale...)',
                          icon: Icons.label_outline,
                        ),
                        SizedBox(height: 14),

                        // Date da - a
                        Row(
                          children: [
                            Expanded(
                              child: _datePickerField(
                                label: 'Data da',
                                date: dateFrom,
                                dateFormat: dateFormat,
                                onTap: () => pickDate(setD, true),
                                required: true,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _datePickerField(
                                label: 'Data a (opz.)',
                                date: dateTo,
                                dateFormat: dateFormat,
                                onTap: () => pickDate(setD, false),
                                required: false,
                                onClear: dateTo != null
                                    ? () => setD(() => dateTo = null)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),

                        // Importo
                        _dialogField(
                          controller: amountCtrl,
                          label: 'Importo €',
                          icon: Icons.euro,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                        SizedBox(height: 14),

                        // Note
                        _dialogField(
                          controller: notesCtrl,
                          label: 'Note (opzionale)',
                          icon: Icons.notes,
                          maxLines: 2,
                        ),
                        SizedBox(height: 16),

                        // Stato
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined,
                                  color: Colors.white38, size: 18),
                              SizedBox(width: 8),
                              Text('Stato:',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.54))),
                              SizedBox(width: 12),
                              DropdownButton<String>(
                                value: status,
                                dropdownColor: const Color(0xFF1E1E24),
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                                underline: SizedBox(),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'PENDING',
                                      child: Text('⏳ Da Pagare')),
                                  DropdownMenuItem(
                                      value: 'PAID',
                                      child: Text('✅ Pagato')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setD(() => status = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Allegati
                  Text('Allegati (Foto/File)',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(height: 8),
                  if (attachments.isNotEmpty)
                    ...attachments.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String url = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attachment, color: Colors.blueAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _launchUrl(url),
                                child: Text(
                                  'Allegato ${idx + 1}',
                                  style: TextStyle(
                                      color: Colors.blueAccent,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: isReadOnly ? null : () {
                                setD(() {
                                  attachments.removeAt(idx);
                                });
                                if (deadline != null) {
                                  final data = Map<String, dynamic>.from(deadline);
                                  data['attachments'] = attachments;
                                  _dbHelper.updateDeadline(data);
                                  _loadDeadlines();
                                }
                              },
                            )
                          ],
                        ),
                      );
                    }),
                  if (isUploading)
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent)),
                    ),
                  SizedBox(height: 8),
                  if (!isReadOnly)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (Platform.isAndroid || Platform.isIOS)
                          IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.white.withValues(alpha: 0.54)),
                            onPressed: () async {
                              final file = await _attachmentService.pickImageFromCamera(context);
                              if (file != null) {
                                setD(() => isUploading = true);
                                final url = await _attachmentService.uploadAttachment(
                                    file, 'attachments/deadlines');
                                if (url != null) {
                                  setD(() => attachments.add(url));
                                  if (deadline != null) {
                                    final data = Map<String, dynamic>.from(deadline);
                                    data['attachments'] = attachments;
                                    _dbHelper.updateDeadline(data);
                                    _loadDeadlines();
                                  }
                                }
                                setD(() => isUploading = false);
                              }
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.image, color: Colors.white.withValues(alpha: 0.54)),
                          onPressed: () async {
                            final file = await _attachmentService.pickFile(context);
                            if (file != null) {
                              setD(() => isUploading = true);
                              final url = await _attachmentService.uploadAttachment(
                                  file, 'attachments/deadlines');
                              if (url != null) {
                                setD(() => attachments.add(url));
                                if (deadline != null) {
                                  final data = Map<String, dynamic>.from(deadline);
                                  data['attachments'] = attachments;
                                  _dbHelper.updateDeadline(data);
                                  _loadDeadlines();
                                }
                              }
                              setD(() => isUploading = false);
                            }
                          },
                        ),
                      ],
                    ),

                  SizedBox(height: 24),

                  // Azioni
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Annulla',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.54))),
                      ),
                      if (!isReadOnly)
                        ElevatedButton.icon(
                          icon: Icon(Icons.save, size: 18),
                          label: Text('Salva'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isUploading ? null : () async {
                            if (titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Inserisci un titolo per la scadenza')),
                              );
                              return;
                            }
                            if (dateFrom == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Seleziona la data di scadenza')),
                              );
                              return;
                            }

                            final data = {
                              'id': deadline?['id'],
                              'title': titleCtrl.text.trim(),
                              'date_from': dateFrom!
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              'date_to': dateTo?.toIso8601String()
                                      .split('T')
                                      .first,
                              'amount':
                                  double.tryParse(amountCtrl.text) ?? 0.0,
                              'notes': notesCtrl.text.trim(),
                              'status': status,
                              'attachments': attachments,
                              // Mantieni date legacy per compatibilità
                              'date': dateFrom!
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                            };

                            if (deadline == null) {
                              await _dbHelper.insertDeadline(data);
                            } else {
                              await _dbHelper.updateDeadline(data);
                            }
                            if (mounted) Navigator.pop(ctx);
                            _loadDeadlines();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Widget helpers dialogo ───────────────────────────────────────────────

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _datePickerField({
    required String label,
    required DateTime? date,
    required String dateFormat,
    required VoidCallback onTap,
    required bool required,
    VoidCallback? onClear,
  }) {
    final display = date != null
        ? DateFormat(dateFormat).format(date)
        : (required ? 'Seleziona ▼' : 'Nessuna ▼');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.white24,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(color: Colors.white38, fontSize: 11)),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: Colors.blueAccent, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    display,
                    style: TextStyle(
                      color:
                          date != null ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: date != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close,
                        color: Colors.white38, size: 14),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  if (Navigator.canPop(context))
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  const Expanded(
                    child: Text(
                      'AGENDA E SCADENZE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [Shadow(color: Colors.white54, blurRadius: 10)],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.list, color: Colors.white54),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white54),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // TABS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTab('Tutte'),
                    _buildTab('Fiscali'),
                    _buildTab('Previdenziali'),
                    _buildTab('Aziendali'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // SUBTITLE
              const Text(
                'Prossime Scadenze',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              // TIMELINE LIST
              Expanded(
                child: _deadlines.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _deadlines.length,
                        itemBuilder: (context, index) {
                          return _buildTimelineItem(_deadlines[index], index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE324FF),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showDeadlineDialog(),
      ),
    );
  }

  Widget _buildTab(String text) {
    bool isSelected = _selectedTab == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = text;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> d, int index) {
    final colors = [
      const Color(0xFFFF2A6D), // Neon Pink
      const Color(0xFF05D9E8), // Neon Cyan
      const Color(0xFF01FFE5), // Neon Green
      const Color(0xFF2588FF), // Neon Blue
    ];
    final color = colors[index % colors.length];

    final dateStr = _formatDate(d['date_from'] as String?, 'dd\nMMM');
    final title = d['title'] ?? 'Scadenza senza titolo';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final customer = d['customer_name']?.toString() ?? 'Nessun cliente';
    final priority = (d['priority']?.toString() ?? 'Media').toUpperCase();
    
    final status = _getDeadlineStatus(d);
    String statusText = 'In Sospeso';
    IconData statusIcon = Icons.info_outline;
    Color statusColor = Colors.orange;
    
    if (status == _DeadlineStatus.paid) {
      statusText = 'Pagato';
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green;
    } else if (status == _DeadlineStatus.overdue) {
      statusText = 'Scaduto';
      statusIcon = Icons.error_outline;
      statusColor = Colors.red;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Date & Line
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Text(
                  dateStr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    height: 1.2,
                    shadows: [Shadow(color: color, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color,
                              colors[(index + 1) % colors.length].withValues(alpha: 0.5)
                            ],
                          ),
                          boxShadow: [BoxShadow(color: color, blurRadius: 4)],
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: color, blurRadius: 8, spreadRadius: 2)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: -5)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Title and Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildNeonBadge(status == _DeadlineStatus.paid ? 'COMPLETATO' : (status == _DeadlineStatus.overdue ? 'SCADUTO' : 'IMMINENTE'), color),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row 2: Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn('Cliente', customer),
                            _buildInfoColumn('Stato', statusText, icon: statusIcon, iconColor: statusColor),
                            _buildInfoColumn('Priorità', priority, dotColor: priority == 'ALTA' ? Colors.red : Colors.orange),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '€ ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _showDeadlineDialog(deadline: d),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  ),
                                  child: const Text('Dettagli', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ),
                                ElevatedButton(
                                  onPressed: () => _togglePaid(d),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color.withValues(alpha: 0.8),
                                    shadowColor: color,
                                    elevation: 8,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  ),
                                  child: Text(status == _DeadlineStatus.paid ? 'Annulla' : 'Paga Ora', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Theme.of(context).canvasColor,
                                        title: const Text('Elimina', style: TextStyle(color: Colors.white)),
                                        content: const Text('Vuoi eliminare questa scadenza?', style: TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULLA', style: TextStyle(color: Colors.white54))),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINA', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _dbHelper.deleteDeadline(d['id']);
                                      _loadDeadlines();
                                    }
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {IconData? icon, Color? iconColor, Color? dotColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
            ],
            if (dotColor != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
    );
  }

  Widget _buildNeonBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: color, blurRadius: 4)]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, color: Colors.white12, size: 72),
          const SizedBox(height: 16),
          const Text('Nessuna scadenza inserita', style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Premi + per aggiungerne una', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

enum _DeadlineStatus { pending, paid, overdue }
