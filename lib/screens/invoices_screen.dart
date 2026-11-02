import 'dart:convert';
import 'dart:io';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/screens/invoice_summary_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../services/attachment_service.dart';
import '../services/pdf_report_service.dart';
import '../utils/calculation_engine.dart';
import '../utils/currency_utils.dart';
import '../utils/date_picker_util.dart';
import '../utils/date_utils_app.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/sort_utils.dart';
import '../utils/url_launcher_util.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_scaffold.dart';

class InvoicesScreen extends StatefulWidget {
  final bool openDialog;
  const InvoicesScreen({super.key, this.openDialog = false});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _togglingIds = <String>{};

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const List<String> _vatCodes = [
    '22% (Ordinaria)',
    '10% (Agevolata)',
    '5% (Super agevolata)',
    '4% (Minima)',
    '0% (Esente)',
    '2.1 (Non soggetta - Art. 15)',
    '2.2 (Non soggetta - Altri casi)',
    'Reverse Charge (Inversione contabile)',
  ];

  String _statusFilter = 'Tutte';
  DateTimeRange? _dateRange;
  String _sortMode = 'Data Piu Recente';

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      if (widget.openDialog && mounted) {
        _showInvoiceDialog();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      if (trimmed.isEmpty) return [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {
          final stripped = trimmed.substring(
            1,
            trimmed.endsWith(']') ? trimmed.length - 1 : trimmed.length,
          );
          return stripped
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
      return trimmed
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  static String _normalizeInvoiceStatus(Map<String, dynamic>? invoice) {
    if (invoice == null) return 'PENDING';
    if (CalculationEngine.isInvoiceSettled(invoice)) return 'PAID';
    final raw = (invoice['status'] ?? '').toString().trim().toUpperCase();
    if (raw == 'LATE' || raw == 'IN RITARDO' || raw == 'DA SOLLECITARE') {
      return 'LATE';
    }
    return 'PENDING';
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final invoices = await _dbHelper.getInvoices();
      final customers = await _dbHelper.getCustomers();

      invoices.sort((a, b) {
        final normA = _normalizeInvoiceStatus(a);
        final normB = _normalizeInvoiceStatus(b);
        final int pA = normA == 'LATE'
            ? 1
            : normA == 'PAID'
                ? 3
                : 2;
        final int pB = normB == 'LATE'
            ? 1
            : normB == 'PAID'
                ? 3
                : 2;

        if (pA != pB) return pA.compareTo(pB);

        final numStrA = a['number']?.toString() ?? '';
        final numStrB = b['number']?.toString() ?? '';
        final matchA = RegExp(r'\d+').firstMatch(numStrA);
        final matchB = RegExp(r'\d+').firstMatch(numStrB);

        final int numA = matchA != null ? int.parse(matchA.group(0)!) : 0;
        final int numB = matchB != null ? int.parse(matchB.group(0)!) : 0;

        return numA.compareTo(numB);
      });

      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento fatture: $e')),
      );
    }
  }

  Future<void> _showInvoiceDialog({
    Map<String, dynamic>? invoice,
    bool isReadOnly = false,
  }) async {
    if (!mounted) return;
    final dateFormat =
        Provider.of<AppThemeProvider>(context, listen: false).dateFormat;

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _InvoiceFormDialog(
        invoice: invoice,
        isReadOnly: isReadOnly,
        customers: _customers,
        vatCodes: _vatCodes,
        dateFormat: dateFormat,
        dbHelper: _dbHelper,
        attachmentService: _attachmentService,
        onAutoPersist: _loadData,
      ),
    );

    if (changed == true && mounted) {
      await _loadData();
    }
  }

  Map<String, dynamic>? _getCustomer(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in _customers) {
      if (c['id']?.toString() == id) return c;
    }
    return null;
  }

  String _resolveClientName(Map<String, dynamic> invoice) {
    final custId = (invoice['customer_id'] ?? invoice['client_id'])?.toString();
    final fromCust = _getCustomer(custId)?['name']?.toString().trim() ?? '';
    if (fromCust.isNotEmpty) return fromCust;
    final fromInv = invoice['client_name']?.toString().trim() ?? '';
    if (fromInv.isNotEmpty) return fromInv;
    return 'Cliente Generico';
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    final query = _searchQuery.trim().toLowerCase();
    final list = _invoices.where((i) {
      final settled = CalculationEngine.isInvoiceSettled(i);
      if (_statusFilter == 'Da Incassare' && settled) return false;
      if (_statusFilter == 'Incassata' && !settled) return false;
      if (_dateRange != null) {
        final d = i['date']?.toString() ?? '';
        if (!ReportUtils.isDateInRange(d, _dateRange!)) return false;
      }
      if (query.isNotEmpty) {
        final numStr = (i['number'] ?? '').toString().toLowerCase();
        final titleStr = (i['title'] ?? '').toString().toLowerCase();
        final clientStr = _resolveClientName(i).toLowerCase();
        if (!numStr.contains(query) &&
            !titleStr.contains(query) &&
            !clientStr.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    int numOf(Map<String, dynamic> i) {
      final m = RegExp(r'\d+').firstMatch(i['number']?.toString() ?? '');
      return m != null ? int.parse(m.group(0)!) : 0;
    }

    list.sort((x, y) {
      switch (_sortMode) {
        case 'Numero (Crescente)':
          return numOf(x).compareTo(numOf(y));
        case 'Numero (Decrescente)':
          return numOf(y).compareTo(numOf(x));
        case 'Data Meno Recente':
          return compareDates(
            x['date']?.toString(),
            y['date']?.toString(),
            descending: false,
          );
        default:
          return compareDates(
            x['date']?.toString(),
            y['date']?.toString(),
            descending: true,
          );
      }
    });
    return list;
  }

  Future<void> _pickDateFilter() async {
    final range = await ReportUtils.showDateRangeFilterDialog(context);
    if (!mounted || range == null) return;
    setState(() => _dateRange = range);
  }

  Future<void> _exportPdfReport(
    List<Map<String, dynamic>> items,
    String dateFormat,
  ) async {
    if (items.isEmpty) return;
    final data = items.map<List<String>>((i) {
      final amount = CurrencyUtils.parseCurrency(i['amount']?.toString());
      final normSt = _normalizeInvoiceStatus(i);
      return [
        i['number']?.toString() ?? '-',
        _resolveClientName(i),
        DateUtilsApp.formatDbDate(i['date']?.toString(), dateFormat),
        CurrencyUtils.formatEuro(amount),
        normSt == 'PAID'
            ? 'Saldata'
            : normSt == 'LATE'
                ? 'In Ritardo'
                : 'Da Incassare',
      ];
    }).toList();
    await PDFReportService.generateAndDownloadReport(
      title: 'Report Fatture',
      headers: ['Numero', 'Cliente', 'Data', 'Importo', 'Stato'],
      data: data,
      dateRangeText: _dateRange == null
          ? 'Tutte le date'
          : ReportUtils.formatDateRangeText(_dateRange!, dateFormat),
      dateFormatString: dateFormat,
    );
  }

  Future<void> _toggleInvoiceStatus(Map<String, dynamic> invoice) async {
    final docId = invoice['id']?.toString() ?? '';
    if (docId.isEmpty || _togglingIds.contains(docId)) return;

    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    _togglingIds.add(docId);
    final isPaid = CalculationEngine.isInvoiceSettled(invoice);
    final newStatus = isPaid ? 'PENDING' : 'PAID';
    final invoiceId =
        (invoice['number']?.toString().trim().isNotEmpty == true)
            ? invoice['number'].toString().trim()
            : docId;

    try {
      final updatedData = Map<String, dynamic>.from(invoice);
      updatedData['status'] = newStatus;
      await _dbHelper.updateInvoice(updatedData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fattura $invoiceId impostata come ${newStatus == 'PAID' ? 'Saldata' : 'Da Incassare'}',
            ),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      debugPrint('Errore aggiornamento stato fattura $invoiceId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      _togglingIds.remove(docId);
    }
  }

  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final docId = invoice['id']?.toString() ?? '';
    if (docId.isEmpty) return;
    final invoiceId =
        (invoice['number']?.toString().trim().isNotEmpty == true)
            ? invoice['number'].toString().trim()
            : docId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text(
          'Elimina Fattura',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Sei sicuro di voler eliminare definitivamente la Fattura $invoiceId?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    try {
      await _dbHelper.deleteInvoice(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fattura $invoiceId eliminata.')),
        );
        await _loadData();
      }
    } catch (e) {
      debugPrint('Errore eliminazione fattura $invoiceId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore eliminazione: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final filtered = _filteredInvoices;

    // Regola 4: Somma nel totale saldato SOLO le fatture effettivamente saldate
    double settledTotal = 0.0;
    double pendingTotal = 0.0;
    for (final inv in filtered) {
      final amt = CurrencyUtils.parseCurrency(inv['amount']?.toString());
      if (CalculationEngine.isInvoiceSettled(inv)) {
        settledTotal = CurrencyUtils.roundMoney(settledTotal + amt);
      } else {
        pendingTotal = CurrencyUtils.roundMoney(pendingTotal + amt);
      }
    }

    return GradientScaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text(
                    'Fatture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF22D3EE),
                        size: 24,
                      ),
                      tooltip: 'Nuova Fattura',
                      onPressed: () => _showInvoiceDialog(),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.date_range,
                        color: _dateRange == null
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFFEC4899),
                        size: 22,
                      ),
                      tooltip: 'Filtra per data',
                      onPressed: _pickDateFilter,
                    ),
                    if (_dateRange != null)
                      IconButton(
                        icon: const Icon(
                          Icons.filter_alt_off,
                          color: Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'Rimuovi filtro data',
                        onPressed: () => setState(() => _dateRange = null),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.sort,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                      tooltip: 'Ordina',
                      color: const Color(0xFF16192B),
                      onSelected: (val) => setState(() => _sortMode = val),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'Numero (Decrescente)',
                          child: Text(
                            'Numero (Decrescente)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'Numero (Crescente)',
                          child: Text(
                            'Numero (Crescente)',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'Data Piu Recente',
                          child: Text(
                            'Data Più Recente',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'Data Meno Recente',
                          child: Text(
                            'Data Meno Recente',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.print_outlined,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                      tooltip: 'Esporta Report PDF',
                      onPressed: () =>
                          _exportPdfReport(filtered, theme.dateFormat),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF16192B).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.white38,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Cerca numero, titolo o cliente...',
                                    hintStyle: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white38,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Tutte', 'Da Incassare', 'Incassata']
                              .map((f) {
                            final sel = _statusFilter == f;
                            return ChoiceChip(
                              label: Text(f),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = f),
                              selectedColor: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.25),
                              backgroundColor: const Color(0xFF16192B),
                              labelStyle: TextStyle(
                                color: sel
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E293B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text(
                                '${filtered.length} fatture',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Saldate: ${CurrencyUtils.formatEuro(settledTotal)}',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (pendingTotal > 0 ||
                                      _statusFilter == 'Da Incassare')
                                    Text(
                                      'In attesa: ${CurrencyUtils.formatEuro(pendingTotal)}',
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'Nessuna fattura trovata',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _buildInvoiceRow(filtered[index], theme.dateFormat),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInvoiceRow(Map<String, dynamic> invoice, String dateFormat) {
    final normStatus = _normalizeInvoiceStatus(invoice);
    final isPaid = normStatus == 'PAID';
    final isLate = normStatus == 'LATE';
    final isOut =
        (invoice['type'] ?? 'IN').toString().trim().toUpperCase() == 'OUT';
    final color = isPaid
        ? const Color(0xFF10B981)
        : isLate
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final amountVal = CurrencyUtils.parseCurrency(invoice['amount']?.toString());

    final invoiceId =
        (invoice['number']?.toString().trim().isNotEmpty == true)
            ? invoice['number'].toString().trim()
            : (invoice['id']?.toString() ?? '-');
    final clientName = _resolveClientName(invoice);
    final invTitle = invoice['title']?.toString().trim() ?? '';

    return Material(
      color: const Color(0xFF13141F).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceSummaryScreen(
                invoiceId: invoice['id'].toString(),
                onEdit: (invData) {
                  if (mounted) {
                    _showInvoiceDialog(invoice: invData);
                  }
                },
              ),
            ),
          ).then((_) {
            if (mounted) _loadData();
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invTitle.isNotEmpty
                          ? 'Fattura $invoiceId • $invTitle'
                          : 'Fattura $invoiceId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      DateUtilsApp.formatDbDate(
                        invoice['date']?.toString(),
                        dateFormat,
                      ),
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.formatEuro(amountVal),
                    style: TextStyle(
                      color: isOut
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _toggleInvoiceStatus(invoice),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 1.2),
                      ),
                      child: Text(
                        isPaid
                            ? 'Saldato'
                            : isLate
                                ? 'In Ritardo'
                                : 'Da Incassare',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
                tooltip: 'Modifica Fattura',
                onPressed: () async {
                  final authorized =
                      await SecurityUtils.requireAdminAuth(context);
                  if (authorized && mounted) {
                    await _showInvoiceDialog(invoice: invoice);
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
                tooltip: 'Elimina Fattura',
                onPressed: () => _deleteInvoice(invoice),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceFormDialog extends StatefulWidget {
  final Map<String, dynamic>? invoice;
  final bool isReadOnly;
  final List<Map<String, dynamic>> customers;
  final List<String> vatCodes;
  final String dateFormat;
  final DatabaseHelper dbHelper;
  final AttachmentService attachmentService;
  final VoidCallback onAutoPersist;

  const _InvoiceFormDialog({
    required this.invoice,
    required this.isReadOnly,
    required this.customers,
    required this.vatCodes,
    required this.dateFormat,
    required this.dbHelper,
    required this.attachmentService,
    required this.onAutoPersist,
  });

  @override
  State<_InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<_InvoiceFormDialog> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _eventDateCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _clientPhoneCtrl;
  late final TextEditingController _clientEmailCtrl;
  late final TextEditingController _clientVatCtrl;
  late final TextEditingController _clientTaxCodeCtrl;
  late final TextEditingController _clientStreetCtrl;
  late final TextEditingController _clientCityCtrl;
  late final TextEditingController _clientProvinceCtrl;
  late final TextEditingController _clientZipCtrl;
  late final TextEditingController _clientSdiCtrl;
  late final TextEditingController _clientPecCtrl;

  late String _status;
  late String _type;
  String? _customerId;
  String? _vatCode;
  late List<String> _attachments;
  late List<String> _availableVatCodes;

  bool _isUploading = false;
  bool _isSaving = false;
  String? _autoSavedInvoiceId;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;

    _numberCtrl = TextEditingController(
      text: inv?['number']?.toString() ?? '',
    );
    final rawAmt = inv?['amount'];
    _amountCtrl = TextEditingController(
      text: rawAmt != null
          ? CurrencyUtils.formatNumber(
              CurrencyUtils.parseCurrency(rawAmt.toString()),
            )
          : '',
    );
    _dateCtrl = TextEditingController(
      text: DateUtilsApp.formatDbDate(
        inv?['date']?.toString() ??
            DateTime.now().toIso8601String().split('T').first,
        widget.dateFormat,
      ),
    );
    _noteCtrl = TextEditingController(
      text: inv?['notes']?.toString() ?? '',
    );
    _eventDateCtrl = TextEditingController(
      text: DateUtilsApp.formatDbDate(
        inv?['event_date']?.toString(),
        widget.dateFormat,
      ),
    );
    _titleCtrl = TextEditingController(
      text: inv?['title']?.toString() ?? '',
    );
    _clientNameCtrl = TextEditingController(
      text: inv?['client_name']?.toString() ?? '',
    );
    _clientPhoneCtrl = TextEditingController(
      text: inv?['client_phone']?.toString() ?? '',
    );
    _clientEmailCtrl = TextEditingController(
      text: inv?['client_email']?.toString() ?? '',
    );
    _clientVatCtrl = TextEditingController(
      text: inv?['client_vat']?.toString() ?? '',
    );
    _clientTaxCodeCtrl = TextEditingController(
      text: inv?['client_tax_code']?.toString() ?? '',
    );
    _clientStreetCtrl = TextEditingController(
      text: (inv?['client_street'] ?? inv?['client_address'])?.toString() ?? '',
    );
    _clientCityCtrl = TextEditingController(
      text: inv?['client_city']?.toString() ?? '',
    );
    _clientProvinceCtrl = TextEditingController(
      text: inv?['client_province']?.toString() ?? '',
    );
    _clientZipCtrl = TextEditingController(
      text: inv?['client_zip']?.toString() ?? '',
    );
    _clientSdiCtrl = TextEditingController(
      text: inv?['client_sdi']?.toString() ?? '',
    );
    _clientPecCtrl = TextEditingController(
      text: inv?['client_pec']?.toString() ?? '',
    );

    _status = _InvoicesScreenState._normalizeInvoiceStatus(inv);
    _type = (inv?['type'] ?? 'IN').toString().trim().toUpperCase() == 'OUT'
        ? 'OUT'
        : 'IN';
    _customerId = (inv?['customer_id'] ?? inv?['client_id'])?.toString();
    if (_customerId != null &&
        !widget.customers.any((c) => c['id']?.toString() == _customerId)) {
      _customerId = null;
    }

    // Populate clientNameCtrl from selected customer if empty
    if (_clientNameCtrl.text.trim().isEmpty && _customerId != null) {
      for (final c in widget.customers) {
        if (c['id']?.toString() == _customerId) {
          _clientNameCtrl.text = c['name']?.toString() ?? '';
          break;
        }
      }
    }

    _availableVatCodes = List<String>.from(widget.vatCodes);
    final rawVat = inv?['vat_code']?.toString().trim() ?? '';
    if (rawVat.isNotEmpty) {
      if (!_availableVatCodes.contains(rawVat)) {
        _availableVatCodes.insert(0, rawVat);
      }
      _vatCode = rawVat;
    } else {
      _vatCode = null;
    }

    _attachments = _InvoicesScreenState._parseAttachments(inv?['attachments']);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _noteCtrl.dispose();
    _eventDateCtrl.dispose();
    _titleCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientVatCtrl.dispose();
    _clientTaxCodeCtrl.dispose();
    _clientStreetCtrl.dispose();
    _clientCityCtrl.dispose();
    _clientProvinceCtrl.dispose();
    _clientZipCtrl.dispose();
    _clientSdiCtrl.dispose();
    _clientPecCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildInvoicePayload(String? effectiveId) {
    final street = _clientStreetCtrl.text.trim();
    final payload = <String, dynamic>{
      'number': _numberCtrl.text.trim(),
      'title': _titleCtrl.text.trim(),
      'type': _type,
      'amount': CurrencyUtils.parseCurrency(_amountCtrl.text),
      'status': _status,
      'date': DateUtilsApp.toDbDate(_dateCtrl.text, widget.dateFormat),
      'event_date':
          DateUtilsApp.toDbDate(_eventDateCtrl.text, widget.dateFormat),
      'vat_code': _vatCode,
      'customer_id': _customerId,
      'client_name': _clientNameCtrl.text.trim(),
      'client_vat': _clientVatCtrl.text.trim(),
      'client_sdi': _clientSdiCtrl.text.trim(),
      'client_tax_code': _clientTaxCodeCtrl.text.trim(),
      'client_street': street,
      'client_address': street,
      'client_zip': _clientZipCtrl.text.trim(),
      'client_city': _clientCityCtrl.text.trim(),
      'client_province': _clientProvinceCtrl.text.trim(),
      'client_email': _clientEmailCtrl.text.trim(),
      'client_pec': _clientPecCtrl.text.trim(),
      'client_phone': _clientPhoneCtrl.text.trim(),
      'notes': _noteCtrl.text.trim(),
      'attachments': List<String>.from(_attachments),
    };
    if (effectiveId != null && effectiveId.isNotEmpty) {
      payload['id'] = effectiveId;
    }
    return payload;
  }

  Future<void> _persistInvoiceAttachments() async {
    try {
      final effectiveId =
          widget.invoice?['id']?.toString() ?? _autoSavedInvoiceId;
      final data = _buildInvoicePayload(effectiveId);
      if (effectiveId != null && effectiveId.isNotEmpty) {
        await widget.dbHelper.updateInvoice(data);
      } else {
        final newId = await widget.dbHelper.insertInvoice(data);
        _autoSavedInvoiceId = newId;
      }
      widget.onAutoPersist();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio allegato: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadAttachment({required bool fromCamera}) async {
    if (_isUploading || _isSaving) return;
    try {
      final file = fromCamera
          ? await widget.attachmentService.pickImageFromCamera(context)
          : await widget.attachmentService.pickFile(context);
      if (file == null || !mounted) return;

      setState(() => _isUploading = true);
      final url = await widget.attachmentService.uploadAttachment(
        file,
        'attachments/invoices',
      );
      if (!mounted) return;
      if (url != null) {
        setState(() => _attachments.add(url));
        await _persistInvoiceAttachments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento allegato: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openAttachment(String pathOrUrl) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return;
    final isHttp =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    if (!isHttp) {
      final f = File(trimmed);
      if (f.existsSync()) {
        await OpenFilex.open(f.path);
        return;
      }
    }
    await UrlLauncherUtil.launchCustomUrl(context, trimmed);
  }

  Future<void> _save() async {
    if (_isSaving || _isUploading) return;
    setState(() => _isSaving = true);

    try {
      final effectiveId =
          widget.invoice?['id']?.toString() ?? _autoSavedInvoiceId;
      final data = _buildInvoicePayload(effectiveId);

      if (effectiveId == null || effectiveId.isEmpty) {
        await widget.dbHelper.insertInvoice(data);
      } else {
        await widget.dbHelper.updateInvoice(data);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio fattura: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = widget.isReadOnly;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: Text(
        widget.invoice == null ? 'Nuova Fattura' : 'Modifica Fattura',
        style: const TextStyle(color: Colors.white),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IgnorePointer(
                ignoring: isReadOnly || _isSaving,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo Fattura: IN (Attiva) / OUT (Passiva)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _type = 'IN'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _type == 'IN'
                                      ? const Color(0xFF10B981)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'ENTRATA (Attiva)',
                                  style: TextStyle(
                                    color: _type == 'IN'
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _type = 'OUT'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _type == 'OUT'
                                      ? const Color(0xFFEF4444)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'USCITA (Passiva)',
                                  style: TextStyle(
                                    color: _type == 'OUT'
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _numberCtrl,
                      labelText: 'Numero Fattura (es. FPA 2/26)',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _titleCtrl,
                      labelText: 'Titolo (opzionale)',
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        if (!isReadOnly) {
                          DatePickerUtil.selectDate(context, _dateCtrl);
                        }
                      },
                      child: IgnorePointer(
                        child: CustomTextField(
                          controller: _dateCtrl,
                          labelText: 'Data Fattura (gg/mm/aaaa)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<Map<String, dynamic>>(
                      compareFn:
                          (Map<String, dynamic> a, Map<String, dynamic> b) =>
                              a['id']?.toString() == b['id']?.toString(),
                      selectedItem: _customerId != null
                          ? widget.customers.firstWhere(
                              (c) => c['id']?.toString() == _customerId,
                              orElse: () => {
                                'id': '',
                                'name': 'Sconosciuto',
                              },
                            )
                          : null,
                      items: (filter, _) => widget.customers,
                      itemAsString: (Map<String, dynamic> c) =>
                          c['name']?.toString() ?? '',
                      popupProps: PopupProps.menu(
                        menuProps: MenuProps(
                          backgroundColor: Theme.of(context).canvasColor,
                        ),
                        showSearchBox: true,
                        searchFieldProps: const TextFieldProps(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Cerca cliente...',
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Text(
                        selectedItem?['name']?.toString() ??
                            'Seleziona Cliente',
                        style: const TextStyle(color: Colors.white),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Cliente Anagrafica',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.54),
                          ),
                        ),
                      ),
                      onSelected: isReadOnly
                          ? null
                          : (Map<String, dynamic>? val) {
                              setState(() {
                                _customerId = val?['id']?.toString();
                                if (val != null) {
                                  if (val['name'] != null) {
                                    _clientNameCtrl.text =
                                        val['name'].toString();
                                  }
                                  if (val['phone'] != null) {
                                    _clientPhoneCtrl.text =
                                        val['phone'].toString();
                                  }
                                  if (val['email'] != null) {
                                    _clientEmailCtrl.text =
                                        val['email'].toString();
                                  }
                                  if (val['vat_number'] != null) {
                                    _clientVatCtrl.text =
                                        val['vat_number'].toString();
                                  }
                                  if (val['tax_code'] != null) {
                                    _clientTaxCodeCtrl.text =
                                        val['tax_code'].toString();
                                  }
                                  final street =
                                      val['address_street'] ?? val['address'];
                                  if (street != null) {
                                    _clientStreetCtrl.text = street.toString();
                                  }
                                  if (val['address_city'] != null) {
                                    _clientCityCtrl.text =
                                        val['address_city'].toString();
                                  }
                                  if (val['address_province'] != null) {
                                    _clientProvinceCtrl.text =
                                        val['address_province'].toString();
                                  }
                                  if (val['address_zip'] != null) {
                                    _clientZipCtrl.text =
                                        val['address_zip'].toString();
                                  }
                                  if (val['sdi_code'] != null) {
                                    _clientSdiCtrl.text =
                                        val['sdi_code'].toString();
                                  }
                                  if (val['pec'] != null) {
                                    _clientPecCtrl.text = val['pec'].toString();
                                  }
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _clientNameCtrl,
                      labelText: 'Ragione Sociale / Nome Cliente',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _clientPhoneCtrl,
                      labelText: 'Cellulare Cliente',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _clientEmailCtrl,
                      labelText: 'Email Cliente',
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text(
                        'Dati Anagrafici Cliente',
                        style: TextStyle(color: Colors.white),
                      ),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white,
                      childrenPadding: const EdgeInsets.all(8),
                      children: [
                        TextField(
                          controller: _clientVatCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Partita IVA',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _clientTaxCodeCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Codice Fiscale',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _clientStreetCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Indirizzo',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _clientCityCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Città',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.54),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _clientProvinceCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Provincia',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.54),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _clientZipCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'CAP',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.54),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _clientSdiCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Codice SDI',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _clientPecCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'PEC',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _amountCtrl,
                      labelText: '€  Importo',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: _status,
                      items: (filter, _) => const ['PENDING', 'PAID', 'LATE'],
                      itemAsString: (String item) {
                        switch (item) {
                          case 'PENDING':
                            return 'Da Incassare';
                          case 'PAID':
                            return 'Saldata';
                          case 'LATE':
                            return 'In Ritardo';
                          default:
                            return item;
                        }
                      },
                      popupProps: PopupProps.menu(
                        menuProps: MenuProps(
                          backgroundColor: Theme.of(context).canvasColor,
                        ),
                        showSearchBox: true,
                        searchFieldProps: const TextFieldProps(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Cerca stato...',
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) {
                        String label = selectedItem ?? 'PENDING';
                        switch (selectedItem) {
                          case 'PENDING':
                            label = 'Da Incassare';
                            break;
                          case 'PAID':
                            label = 'Saldata';
                            break;
                          case 'LATE':
                            label = 'In Ritardo';
                            break;
                        }
                        return Text(
                          label,
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Stato',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.54),
                          ),
                        ),
                      ),
                      onSelected: isReadOnly
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _status = val);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: _vatCode,
                      items: (filter, _) => _availableVatCodes,
                      popupProps: PopupProps.menu(
                        menuProps: MenuProps(
                          backgroundColor: Theme.of(context).canvasColor,
                        ),
                        showSearchBox: true,
                        searchFieldProps: const TextFieldProps(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Cerca codice IVA...',
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Text(
                        selectedItem ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Codice IVA',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.54),
                          ),
                        ),
                      ),
                      onSelected: isReadOnly
                          ? null
                          : (val) => setState(() => _vatCode = val),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        if (!isReadOnly) {
                          DatePickerUtil.selectDate(context, _eventDateCtrl);
                        }
                      },
                      child: IgnorePointer(
                        child: CustomTextField(
                          controller: _eventDateCtrl,
                          labelText: 'Data Evento (opzionale)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _noteCtrl,
                      labelText: 'Note Evento',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                  final idx = entry.key;
                  final url = entry.value;
                  final fileName = AttachmentService.extractCleanFileName(url);
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
                            onTap: () => _openAttachment(url),
                            child: Text(
                              fileName.isNotEmpty
                                  ? fileName
                                  : 'Allegato ${idx + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          onPressed: (isReadOnly || _isSaving || _isUploading)
                              ? null
                              : () async {
                                  setState(() {
                                    _attachments.removeAt(idx);
                                  });
                                  final effectiveId =
                                      widget.invoice?['id']?.toString() ??
                                          _autoSavedInvoiceId;
                                  if (effectiveId != null &&
                                      effectiveId.isNotEmpty) {
                                    await _persistInvoiceAttachments();
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
              if (!isReadOnly)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (Platform.isAndroid || Platform.isIOS)
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          color: Colors.white.withValues(alpha: 0.54),
                        ),
                        tooltip: 'Scatta Foto',
                        onPressed: (_isUploading || _isSaving)
                            ? null
                            : () => _pickAndUploadAttachment(fromCamera: true),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                      tooltip: 'Allega File',
                      onPressed: (_isUploading || _isSaving)
                          ? null
                          : () => _pickAndUploadAttachment(fromCamera: false),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        if (!isReadOnly)
          ElevatedButton(
            onPressed: (_isUploading || _isSaving) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva'),
          ),
      ],
    );
  }
}
