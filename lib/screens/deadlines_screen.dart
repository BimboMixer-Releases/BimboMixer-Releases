import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/attachment_service.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import 'calendar_screen.dart';
import 'package:pdf/widgets.dart' as pw;

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
                                  style: TextStyle(color: Colors.white.withOpacity(0.54))),
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
                          color: Colors.white.withOpacity(0.7),
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
                            icon: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.54)),
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
                          icon: Icon(Icons.image, color: Colors.white.withOpacity(0.54)),
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
                            style: TextStyle(color: Colors.white.withOpacity(0.54))),
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
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 13),
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
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final dateFormat = theme.dateFormat;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Scadenze',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_calendar, color: Colors.blueAccent),
            tooltip: 'Calendario Eventi',
            onPressed: () {
              // Non serve il controllo di ruolo qui, se vogliamo renderlo disponibile,
              // ma possiamo recuperare il ruolo dal provider se necessario, per ora lo passiamo fisso
              // o verifichiamo la biometria dentro calendar_screen.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen(role: 'admin')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.print, color: Colors.blueAccent),
            tooltip: 'Esporta in PDF',
            onPressed: () async {
              if (_deadlines.isEmpty) return;

              // Richiedi il periodo con il filtro
              final range = await ReportUtils.showDateRangeFilterDialog(context);
              if (range == null) return; // Annullato dall'utente

              // Filtra le scadenze in base al range
              final filteredDeadlines = _deadlines.where((d) {
                final dateFrom = d['date_from'] as String?;
                if (dateFrom == null || dateFrom.isEmpty) return true;
                return ReportUtils.isDateInRange(dateFrom, range);
              }).toList();

              if (filteredDeadlines.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nessuna scadenza nel periodo selezionato.')),
                  );
                }
                return;
              }

              final List<List<String>> data = filteredDeadlines.map<List<String>>((d) {
                final date = _buildDateLabel(d, dateFormat);
                final title = d['title']?.toString() ?? '';
                final amountStr = d['amount']?.toString() ?? '0.0';
                final amount = '${double.tryParse(amountStr)?.toStringAsFixed(2) ?? '0.00'} €';
                final status = d['status'] == 'PAID' ? 'Pagato' : 'Pend.';
                return [title, date, amount, status];
              }).toList();
              
              await PDFReportService.generateAndDownloadReport(
                title: 'Scadenze',
                headers: ['Descrizione', 'Data', 'Importo', 'Stato'],
                data: data,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(50),
                },
                dateRangeText: ReportUtils.formatDateRangeText(range, dateFormat),
                dateFormatString: dateFormat,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.blueAccent),
            onPressed: () => _showDeadlineDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                // Banner totali
                _buildTotalsBanner(theme),
                // Lista scadenze
                Expanded(
                  child: _deadlines.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _deadlines.length,
                          itemBuilder: (context, index) {
                            final d = _deadlines[index];
                            return _buildDeadlineCard(
                                d, theme, dateFormat);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalsBanner(AppThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildTotalChip(
              label: 'Da pagare',
              amount: _totalPending,
              color: Colors.orangeAccent,
              icon: Icons.hourglass_empty,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildTotalChip(
              label: 'Già pagato',
              amount: _totalPaid,
              color: Colors.greenAccent,
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalChip({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8), fontSize: 11)),
                Text(
                  '€ ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineCard(
      Map<String, dynamic> d, AppThemeProvider theme, String dateFormat) {
    final status = _getDeadlineStatus(d);
    final isPaid = status == _DeadlineStatus.paid;
    final isOverdue = status == _DeadlineStatus.overdue;
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final notes = d['notes'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case _DeadlineStatus.paid:
        statusColor = Colors.greenAccent;
        statusLabel = 'Pagato';
        statusIcon = Icons.check_circle;
        break;
      case _DeadlineStatus.overdue:
        statusColor = Colors.redAccent;
        statusLabel = 'Scaduto';
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.orangeAccent;
        statusLabel = 'Da pagare';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : isOverdue
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : theme.borderColor,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDeadlineDialog(deadline: d, isReadOnly: true),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final auth = await SecurityUtils.requireAdminAuth(context);
                        if (auth && mounted) {
                          _togglePaid(d);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Titolo + data
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['title'] ?? 'Scadenza',
                            style: TextStyle(
                              color: isPaid ? Colors.white54 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: isPaid
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: Colors.white38, size: 12),
                              SizedBox(width: 4),
                              Text(
                                _buildDateLabel(d, dateFormat),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.54), fontSize: 12),
                              ),
                            ],
                          ),
                          if (notes.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(notes,
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          if (d['attachments'] != null && (d['attachments'] as List).isNotEmpty) ...[
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.attachment, color: Colors.blueAccent, size: 12),
                                SizedBox(width: 4),
                                Text('${(d['attachments'] as List).length} allegati', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Importo + azioni
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (amount > 0)
                          Text(
                            '€ ${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isPaid ? Colors.greenAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: isPaid
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(
                                  color: statusColor, fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // Azioni rapide
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Aggiungi a calendario
                    TextButton.icon(
                      onPressed: () => _addToCalendar(d),
                      icon: Icon(Icons.event_available,
                          size: 14, color: Colors.blueAccent),
                      label: Text('Aggiungi al Calendario',
                          style: TextStyle(
                              color: Colors.blueAccent, fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    // Toggle pagato
                    TextButton.icon(
                      onPressed: () async {
                        final auth = await SecurityUtils.requireAdminAuth(context);
                        if (auth && mounted) {
                          _togglePaid(d);
                        }
                      },
                      icon: Icon(
                        isPaid ? Icons.undo : Icons.check,
                        size: 14,
                        color: isPaid ? Colors.orangeAccent : Colors.greenAccent,
                      ),
                      label: Text(
                        isPaid ? 'Segna Pendente' : 'Segna Pagato',
                        style: TextStyle(
                          color: isPaid
                              ? Colors.orangeAccent
                              : Colors.greenAccent,
                          fontSize: 11,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    // Modifica
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          color: Colors.blueAccent, size: 18),
                      onPressed: () async {
                        final auth = await SecurityUtils.requireAdminAuth(context);
                        if (auth && mounted) {
                          _showDeadlineDialog(deadline: d, isReadOnly: false);
                        }
                      },
                    ),
                    // Elimina
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      onPressed: () async {
                        final auth = await SecurityUtils.requireAdminAuth(context);
                        if (!auth || !mounted) return;
                        
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E24),
                            title: Text('Elimina Scadenza',
                                style: TextStyle(color: Colors.white)),
                            content: Text(
                                'Sei sicuro di voler eliminare questa scadenza?',
                                style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: Text('Annulla')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: Text('Elimina'),
                              ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available,
              color: Colors.white12, size: 72),
          SizedBox(height: 16),
          Text('Nessuna scadenza inserita',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          SizedBox(height: 8),
          Text('Premi + per aggiungerne una',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

enum _DeadlineStatus { pending, paid, overdue }



