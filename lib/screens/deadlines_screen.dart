import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/attachment_service.dart';

class DeadlinesScreen extends StatefulWidget {
  final bool openDialog;
  const DeadlinesScreen({super.key, this.openDialog = false});

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  static const List<String> _categories = [
    'Fiscali',
    'Previdenziali',
    'Aziendali',
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _deadlines = [];
  bool _isLoading = true;
  String _selectedTab = 'Tutte';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.openDialog) {
        _showDeadlineDialog();
      }
    });
    _loadDeadlines();
  }

  static String _resolveDeadlineCategory(Map<String, dynamic> d) {
    final raw = (d['category'] ?? d['deadline_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw.startsWith('previdenz')) return 'Previdenziali';
    if (raw.startsWith('aziend')) return 'Aziendali';
    if (raw.startsWith('fiscal')) return 'Fiscali';

    final title = (d['title'] ?? '').toString().toLowerCase();
    if (title.contains('inps') ||
        title.contains('inail') ||
        title.contains('cassa') ||
        title.contains('contribut')) {
      return 'Previdenziali';
    }
    if (title.contains('affitto') ||
        title.contains('assicuraz') ||
        title.contains('bollett') ||
        title.contains('utenz') ||
        title.contains('fornitor') ||
        title.contains('stipendi')) {
      return 'Aziendali';
    }
    return 'Fiscali';
  }

  static List<String> _parseAttachments(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == '[]') return [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {}
      return [trimmed];
    }
    return [];
  }

  List<Map<String, dynamic>> get _filteredDeadlines {
    if (_selectedTab == 'Tutte') return _deadlines;
    return _deadlines
        .where((d) => _resolveDeadlineCategory(d) == _selectedTab)
        .toList();
  }

  double get _totalPaid => _filteredDeadlines
      .where(CalculationEngine.isDeadlineSettled)
      .fold(
        0.0,
        (sum, d) => sum + CurrencyUtils.parseCurrency(d['amount']?.toString()),
      );

  double get _totalPending => _filteredDeadlines
      .where((d) => !CalculationEngine.isDeadlineSettled(d))
      .fold(
        0.0,
        (sum, d) => sum + CurrencyUtils.parseCurrency(d['amount']?.toString()),
      );

  Future<void> _loadDeadlines() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final deadlines = await _dbHelper.getDeadlines();
      if (!mounted) return;
      setState(() {
        _deadlines = deadlines;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento scadenze: $e')),
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri? url = Uri.tryParse(urlString);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire l\'allegato')),
        );
      }
    }
  }

  String _formatDate(String? rawDate, String dateFormat) {
    if (rawDate == null || rawDate.trim().isEmpty) return '';
    final dt = DateUtilsApp.tryParseDate(rawDate);
    if (dt != null) {
      return DateFormat(dateFormat).format(dt);
    }
    return rawDate;
  }

  _DeadlineStatus _getDeadlineStatus(Map<String, dynamic> d) {
    if (CalculationEngine.isDeadlineSettled(d)) {
      return _DeadlineStatus.paid;
    }
    final rawDate = (d['date_from']?.toString().trim().isNotEmpty == true)
        ? d['date_from']?.toString()
        : d['date']?.toString();
    final dt = DateUtilsApp.tryParseDate(rawDate);
    if (dt != null) {
      final dueDay = DateUtils.dateOnly(dt);
      final today = DateUtils.dateOnly(DateTime.now());
      if (dueDay.isBefore(today)) {
        return _DeadlineStatus.overdue;
      }
    }
    return _DeadlineStatus.pending;
  }

  Future<void> _togglePaid(Map<String, dynamic> d) async {
    final isPaid = CalculationEngine.isDeadlineSettled(d);
    final newStatus = isPaid ? 'PENDING' : 'PAID';
    final updated = Map<String, dynamic>.from(d)..['status'] = newStatus;
    await _dbHelper.updateDeadline(updated);
    if (mounted) {
      _loadDeadlines();
    }
  }

  Future<void> _showDeadlineDialog({
    Map<String, dynamic>? deadline,
    bool isReadOnly = false,
  }) async {
    final defaultCategory =
        _selectedTab != 'Tutte' ? _selectedTab : _categories.first;

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeadlineFormDialog(
        deadline: deadline,
        isReadOnly: isReadOnly,
        defaultCategory: defaultCategory,
        dbHelper: _dbHelper,
        attachmentService: _attachmentService,
        onOpenUrl: _launchUrl,
        onAttachmentsChanged: _loadDeadlines,
      ),
    );

    if (changed == true && mounted) {
      _loadDeadlines();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final parentScaffold = Scaffold.maybeOf(context);
    final hasDrawer = parentScaffold?.hasDrawer == true;
    final canPop = Navigator.canPop(context);
    final filtered = _filteredDeadlines;

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
                  if (hasDrawer)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => parentScaffold?.openDrawer(),
                      ),
                    )
                  else if (canPop)
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
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'Aggiorna scadenze',
                    onPressed: _loadDeadlines,
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
              const SizedBox(height: 16),
              // RIEPILOGO TOTALI
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Prossime Scadenze',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _buildSummaryChip(
                    'Da pagare: ${CurrencyUtils.formatEuro(_totalPending)}',
                    Colors.orangeAccent,
                  ),
                  _buildSummaryChip(
                    'Pagate: ${CurrencyUtils.formatEuro(_totalPaid)}',
                    Colors.greenAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // TIMELINE LIST
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildTimelineItem(filtered[index], index);
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

  Widget _buildSummaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTab(String text) {
    final bool isSelected = _selectedTab == text;
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
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
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

    final rawDate = (d['date_from']?.toString().trim().isNotEmpty == true)
        ? d['date_from']?.toString()
        : d['date']?.toString();
    final dateStr = _formatDate(rawDate, 'dd\nMMM');
    final title = d['title']?.toString() ?? 'Scadenza senza titolo';
    final amount = CurrencyUtils.parseCurrency(d['amount']?.toString());
    final category = _resolveDeadlineCategory(d);
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
                              colors[(index + 1) % colors.length].withValues(
                                alpha: 0.5,
                              ),
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
                            BoxShadow(
                              color: color,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
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
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildNeonBadge(
                        status == _DeadlineStatus.paid
                            ? 'COMPLETATO'
                            : (status == _DeadlineStatus.overdue
                                  ? 'SCADUTO'
                                  : 'IMMINENTE'),
                        color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row 2: Details
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _buildInfoColumn('Categoria', category),
                          _buildInfoColumn(
                            'Stato',
                            statusText,
                            icon: statusIcon,
                            iconColor: statusColor,
                          ),
                          _buildInfoColumn(
                            'Priorità',
                            priority,
                            dotColor: priority == 'ALTA'
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyUtils.formatEuro(amount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _showDeadlineDialog(deadline: d),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white38),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                ),
                                child: const Text(
                                  'Dettagli',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _togglePaid(d),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color.withValues(alpha: 0.8),
                                  shadowColor: color,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                ),
                                child: Text(
                                  status == _DeadlineStatus.paid
                                      ? 'Annulla'
                                      : 'Paga Ora',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor:
                                          Theme.of(ctx).canvasColor,
                                      title: const Text(
                                        'Elimina',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'Vuoi eliminare questa scadenza?',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text(
                                            'ANNULLA',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'ELIMINA',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final id = d['id']?.toString() ?? '';
                                    if (id.isNotEmpty) {
                                      await _dbHelper.deleteDeadline(id);
                                      if (mounted) _loadDeadlines();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildInfoColumn(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    Color? dotColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
            ],
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: color, blurRadius: 4)],
        ),
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
          Text(
            _selectedTab == 'Tutte'
                ? 'Nessuna scadenza inserita'
                : 'Nessuna scadenza nella categoria "$_selectedTab"',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Premi + per aggiungerne una',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DeadlineFormDialog extends StatefulWidget {
  final Map<String, dynamic>? deadline;
  final bool isReadOnly;
  final String defaultCategory;
  final DatabaseHelper dbHelper;
  final AttachmentService attachmentService;
  final Future<void> Function(String url) onOpenUrl;
  final VoidCallback onAttachmentsChanged;

  const _DeadlineFormDialog({
    required this.deadline,
    required this.isReadOnly,
    required this.defaultCategory,
    required this.dbHelper,
    required this.attachmentService,
    required this.onOpenUrl,
    required this.onAttachmentsChanged,
  });

  @override
  State<_DeadlineFormDialog> createState() => _DeadlineFormDialogState();
}

class _DeadlineFormDialogState extends State<_DeadlineFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  late String _status;
  late String _category;
  late List<String> _attachments;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.deadline;
    _titleCtrl = TextEditingController(text: d?['title']?.toString() ?? '');
    final existingAmount = d != null
        ? CurrencyUtils.parseCurrency(d['amount']?.toString())
        : 0.0;
    _amountCtrl = TextEditingController(
      text: d != null && existingAmount > 0
          ? CurrencyUtils.formatNumber(existingAmount)
          : (d?['amount']?.toString() ?? ''),
    );
    _notesCtrl = TextEditingController(text: d?['notes']?.toString() ?? '');

    final rawFrom = (d?['date_from']?.toString().trim().isNotEmpty == true)
        ? d!['date_from'].toString()
        : d?['date']?.toString();
    _dateFrom = DateUtilsApp.tryParseDate(rawFrom);
    _dateTo = DateUtilsApp.tryParseDate(d?['date_to']?.toString());

    _status = d != null && CalculationEngine.isDeadlineSettled(d)
        ? 'PAID'
        : 'PENDING';
    _category = d != null
        ? _DeadlinesScreenState._resolveDeadlineCategory(d)
        : widget.defaultCategory;
    _attachments = _DeadlinesScreenState._parseAttachments(d?['attachments']);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_dateFrom ?? now) : (_dateTo ?? _dateFrom ?? now);
    final picked = await GlassDatePicker.show(
      context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  Future<void> _handleUpload(bool fromCamera) async {
    final file = fromCamera
        ? await widget.attachmentService.pickImageFromCamera(context)
        : await widget.attachmentService.pickFile(context);
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final url = await widget.attachmentService.uploadAttachment(
        file,
        'attachments/deadlines',
      );
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        setState(() => _attachments.add(url));
        if (widget.deadline != null && widget.deadline!['id'] != null) {
          final data = Map<String, dynamic>.from(widget.deadline!);
          data['attachments'] = _attachments;
          await widget.dbHelper.updateDeadline(data);
          widget.onAttachmentsChanged();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving || _isUploading) return;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per la scadenza')),
      );
      return;
    }
    if (_dateFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona la data di scadenza')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isoFrom = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      final isoTo =
          _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null;

      final data = <String, dynamic>{
        if (widget.deadline?['id'] != null) 'id': widget.deadline!['id'],
        'title': _titleCtrl.text.trim(),
        'category': _category,
        'date_from': isoFrom,
        'date_to': isoTo,
        'amount': CurrencyUtils.parseCurrency(_amountCtrl.text),
        'notes': _notesCtrl.text.trim(),
        'status': _status,
        'attachments': _attachments,
        'date': isoFrom,
      };

      if (widget.deadline == null) {
        await widget.dbHelper.insertDeadline(data);
      } else {
        await widget.dbHelper.updateDeadline(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore salvataggio: $e')),
      );
    }
  }

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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.54),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            color: date != null
                ? Colors.blueAccent.withValues(alpha: 0.5)
                : Colors.white24,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.blueAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    display,
                    style: TextStyle(
                      color: date != null ? Colors.white : Colors.white38,
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
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = context.read<AppThemeProvider>().dateFormat;
    final isMobilePlatform =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Dialog(
      backgroundColor: const Color(0xFF1A1A22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  const Icon(Icons.event, color: Colors.orangeAccent),
                  const SizedBox(width: 10),
                  Text(
                    widget.deadline == null
                        ? 'Nuova Scadenza'
                        : 'Modifica Scadenza',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              IgnorePointer(
                ignoring: widget.isReadOnly,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titolo
                    _dialogField(
                      controller: _titleCtrl,
                      label: 'Titolo (es. INPS, IVA trimestrale...)',
                      icon: Icons.label_outline,
                    ),
                    const SizedBox(height: 14),

                    // Categoria / Tipo Scadenza
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      dropdownColor: const Color(0xFF1E1E24),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Categoria Scadenza',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          color: Colors.white38,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      items: _DeadlinesScreenState._categories
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Date da - a
                    Row(
                      children: [
                        Expanded(
                          child: _datePickerField(
                            label: 'Data da',
                            date: _dateFrom,
                            dateFormat: dateFormat,
                            onTap: () => _pickDate(true),
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _datePickerField(
                            label: 'Data a (opz.)',
                            date: _dateTo,
                            dateFormat: dateFormat,
                            onTap: () => _pickDate(false),
                            required: false,
                            onClear: _dateTo != null
                                ? () => setState(() => _dateTo = null)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Importo
                    _dialogField(
                      controller: _amountCtrl,
                      label: 'Importo €',
                      icon: Icons.euro,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Note
                    _dialogField(
                      controller: _notesCtrl,
                      label: 'Note (opzionale)',
                      icon: Icons.notes,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Stato
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            color: Colors.white38,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stato:',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _status,
                            dropdownColor: const Color(0xFF1E1E24),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                value: 'PENDING',
                                child: Text('⏳ Da Pagare'),
                              ),
                              DropdownMenuItem(
                                value: 'PAID',
                                child: Text('✅ Pagato'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _status = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Allegati
              Text(
                'Allegati (Foto/File)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (_attachments.isNotEmpty)
                ..._attachments.asMap().entries.map((entry) {
                  final int idx = entry.key;
                  final String url = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attachment,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => widget.onOpenUrl(url),
                            child: Text(
                              'Allegato ${idx + 1}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: widget.isReadOnly
                              ? null
                              : () async {
                                  setState(() {
                                    _attachments.removeAt(idx);
                                  });
                                  if (widget.deadline != null &&
                                      widget.deadline!['id'] != null) {
                                    final data = Map<String, dynamic>.from(
                                      widget.deadline!,
                                    );
                                    data['attachments'] = _attachments;
                                    await widget.dbHelper.updateDeadline(data);
                                    widget.onAttachmentsChanged();
                                  }
                                },
                        ),
                      ],
                    ),
                  );
                }),
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                ),
              const SizedBox(height: 8),
              if (!widget.isReadOnly)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (isMobilePlatform)
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          color: Colors.white.withValues(alpha: 0.54),
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => _handleUpload(true),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.image,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                      onPressed: _isUploading
                          ? null
                          : () => _handleUpload(false),
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // Azioni
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(
                      'Annulla',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                    ),
                  ),
                  if (!widget.isReadOnly)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Salva'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: (_isUploading || _isSaving) ? null : _save,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DeadlineStatus { pending, paid, overdue }
