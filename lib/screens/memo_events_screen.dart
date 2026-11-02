import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/pdf_report_service.dart';
import '../utils/calculation_engine.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils_app.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/sort_utils.dart';
import '../widgets/gradient_scaffold.dart';
import 'invoice_summary_screen.dart';
import 'memo_form_screen.dart';

class MemoEventsScreen extends StatefulWidget {
  final bool openForm;
  const MemoEventsScreen({super.key, this.openForm = false});

  @override
  State<MemoEventsScreen> createState() => _MemoEventsScreenState();
}

class _MemoEventsScreenState extends State<MemoEventsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _memoEvents = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _pendingInvoices = [];

  bool _isLoading = true;
  bool _isTransferring = false;
  String _searchQuery = '';
  String _statusFilter = 'Tutti';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.openForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoFormScreen()),
        );
        if (result == true && mounted) {
          _loadData();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final memoEvents = await _dbHelper.getMemoEvents();
      final customers = await _dbHelper.getCustomers();
      final invoices = await _dbHelper.getInvoices();
      if (!mounted) return;

      final pendingInvoices = invoices
          .where((i) => !CalculationEngine.isInvoiceSettled(i))
          .map((i) => Map<String, dynamic>.from(i))
          .toList();

      setState(() {
        _memoEvents = memoEvents.map((m) => Map<String, dynamic>.from(m)).toList();
        _customers = customers;
        _pendingInvoices = pendingInvoices;
      });
    } catch (e) {
      debugPrint('Errore caricamento pagamenti programmati: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? _getCustomer(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return _customers.firstWhere((c) => c['id'].toString() == id);
    } catch (_) {
      return null;
    }
  }

  String _formatMemoDate(Map<String, dynamic> memo, String dateFormat) {
    final memoType = (memo['memo_type'] ?? 'MOVIMENTO').toString().toUpperCase();
    if (memoType == 'FATTURA') {
      final fNum = (memo['invoice_number'] ?? memo['number'])?.toString() ?? '';
      final rawInvDate = (memo['invoice_date']?.toString().trim().isNotEmpty == true)
          ? memo['invoice_date'].toString()
          : memo['date']?.toString();
      final fDate = DateUtilsApp.formatDbDate(rawInvDate, dateFormat);
      final numDisplay = fNum.isNotEmpty ? fNum : 'Non ass.';
      return fDate.isNotEmpty ? 'Fatt. $numDisplay del $fDate' : 'Fatt. $numDisplay';
    }

    if (memo['date_type'] == 'RANGE') {
      final df = DateUtilsApp.formatDbDate(memo['date_from']?.toString(), dateFormat);
      final dt = DateUtilsApp.formatDbDate(memo['date_to']?.toString(), dateFormat);
      return 'Da $df a $dt';
    }

    return DateUtilsApp.formatDbDate(memo['date']?.toString(), dateFormat);
  }

  /// Lista unificata di tutti gli elementi programmati (memo + fatture pendenti)
  List<Map<String, dynamic>> get _unifiedItems {
    final List<Map<String, dynamic>> items = [];

    // 1. Memo events
    for (final m in _memoEvents) {
      final item = Map<String, dynamic>.from(m);
      item['_item_kind'] = 'MEMO';
      items.add(item);
    }

    // 2. Pending invoices
    for (final inv in _pendingInvoices) {
      final item = Map<String, dynamic>.from(inv);
      item['_item_kind'] = 'PENDING_INVOICE';
      item['title'] = 'Fattura ${inv['number'] ?? ''}'.trim();
      item['memo_type'] = 'FATTURA';
      item['transaction_type'] = (inv['type'] ?? 'IN').toString().toUpperCase() == 'OUT' ? 'USCITA' : 'ENTRATA';
      item['memo_status'] = (inv['status']?.toString().toUpperCase() == 'LATE' ||
              inv['status']?.toString().toUpperCase() == 'DA SOLLECITARE')
          ? 'DA SOLLECITARE'
          : 'IN ATTESA';
      items.add(item);
    }

    // Ordinamento cronologico decrescente
    items.sort((a, b) {
      final dateA = (a['date'] ?? a['invoice_date'] ?? a['date_from'])?.toString();
      final dateB = (b['date'] ?? b['invoice_date'] ?? b['date_from'])?.toString();
      final cmp = compareDates(dateA, dateB, descending: true);
      if (cmp != 0) return cmp;
      final idA = a['id']?.toString() ?? '';
      final idB = b['id']?.toString() ?? '';
      return idB.compareTo(idA);
    });

    return items;
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _unifiedItems.where((item) {
      final status = (item['memo_status'] ?? 'IN ATTESA').toString().toUpperCase();
      final isInvoice = (item['memo_type'] ?? '').toString().toUpperCase() == 'FATTURA';
      final isEntry = (item['transaction_type'] ?? 'ENTRATA').toString().toUpperCase() == 'ENTRATA';

      // Filtro per stato/tipo
      if (_statusFilter == 'In Attesa' && status != 'IN ATTESA') return false;
      if (_statusFilter == 'Da Sollecitare' && status != 'DA SOLLECITARE') return false;
      if (_statusFilter == 'Entrate' && !isEntry) return false;
      if (_statusFilter == 'Uscite' && isEntry) return false;
      if (_statusFilter == 'Fatture' && !isInvoice) return false;
      if (_statusFilter == 'Movimenti' && isInvoice) return false;

      // Filtro per data
      if (_dateRange != null) {
        final dateStr = (item['date'] ?? item['invoice_date'] ?? item['date_from'])?.toString() ?? '';
        if (!ReportUtils.isDateInRange(dateStr, _dateRange!)) {
          return false;
        }
      }

      // Ricerca testuale
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (item['title'] ?? '').toString().toLowerCase();
        final client = (item['client_name'] ?? '').toString().toLowerCase();
        final notes = (item['notes'] ?? '').toString().toLowerCase();
        final amount = (item['amount'] ?? '').toString().toLowerCase();
        final method = (item['payment_method'] ?? '').toString().toLowerCase();

        return title.contains(q) ||
            client.contains(q) ||
            notes.contains(q) ||
            amount.contains(q) ||
            method.contains(q);
      }

      return true;
    }).toList();
  }

  Future<void> _updateMemoStatus(
    Map<String, dynamic> memo,
    String newStatus,
  ) async {
    if (_isTransferring) return;
    final memoId = memo['id']?.toString() ?? '';
    if (memoId.isEmpty) return;

    final normalizedNewStatus = MemoFormScreen.normalizeMemoStatus(newStatus);
    final theme = context.read<AppThemeProvider>();
    final dateFormat = theme.dateFormat;

    if (normalizedNewStatus != 'SALDATO') {
      setState(() => _isTransferring = true);
      try {
        final updated = Map<String, dynamic>.from(memo);
        updated['memo_status'] = normalizedNewStatus;
        await _dbHelper.updateMemoEvent(updated);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore aggiornamento stato: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isTransferring = false);
      }
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Text(
              'Conferma Trasferimento',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Impostando lo stato su "Saldato", questo pagamento verrà rimosso dai pagamenti programmati e inserito in automatico nella sezione corrispondente (Movimenti o Fatture).\n\nVuoi procedere?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annulla', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Conferma Trasferimento', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) {
      return;
    }

    setState(() => _isTransferring = true);
    try {
      final memoType = (memo['memo_type'] ?? 'MOVIMENTO').toString().toUpperCase();
      final isInvoice = memoType == 'FATTURA';
      final transactionType = (memo['transaction_type'] ?? 'ENTRATA').toString().toUpperCase();
      final dirType = transactionType == 'USCITA' ? 'OUT' : 'IN';
      final amount = CurrencyUtils.parseCurrency(memo['amount']?.toString());
      final customerId = (memo['customer_id'] ?? memo['client_id'])?.toString();
      final customerName = _getCustomer(customerId)?['name']?.toString() ??
          (memo['client_name']?.toString() ?? '');
      final attachmentsList = MemoFormScreen.parseAttachments(memo['attachments']);
      final todayDb = DateUtilsApp.toDbDate(
        DateTime.now().toIso8601String(),
        dateFormat,
      );
      final titleText = memo['title']?.toString().trim() ?? '';
      final notesText = memo['notes']?.toString().trim() ?? '';

      final Map<String, dynamic> targetData;
      if (isInvoice) {
        final rawInvDate = (memo['invoice_date']?.toString().trim().isNotEmpty == true)
            ? memo['invoice_date'].toString()
            : (memo['date']?.toString() ?? '');
        final dbInvDate = DateUtilsApp.toDbDate(rawInvDate, dateFormat);
        final finalInvDate = dbInvDate.isNotEmpty ? dbInvDate : todayDb;
        final dbEventDate = DateUtilsApp.toDbDate(memo['date']?.toString(), dateFormat);
        final street = (memo['client_street'] ?? memo['client_address'])?.toString() ?? '';

        targetData = <String, dynamic>{
          'number': (memo['invoice_number'] ?? memo['number'])?.toString().trim() ?? '',
          'title': titleText,
          'type': dirType,
          'amount': amount,
          'date': finalInvDate,
          'event_date': dbEventDate.isNotEmpty ? dbEventDate : finalInvDate,
          'status': 'PAID',
          'vat_code': memo['vat_code']?.toString(),
          'customer_id': customerId,
          'category_id': memo['category_id']?.toString(),
          'service_id': memo['service_id']?.toString(),
          'client_name': customerName,
          'client_phone': memo['client_phone']?.toString() ?? '',
          'client_email': memo['client_email']?.toString() ?? '',
          'client_vat': memo['client_vat']?.toString() ?? '',
          'client_street': street,
          'client_address': street,
          'client_sdi': memo['client_sdi']?.toString() ?? '',
          'notes': notesText,
          'attachments': attachmentsList,
        };
      } else {
        final dateType = (memo['date_type'] ?? 'SINGOLA').toString().toUpperCase();
        final rawPayDate = dateType == 'RANGE'
            ? (memo['date_from']?.toString() ?? '')
            : (memo['date']?.toString() ?? '');
        final dbPayDate = DateUtilsApp.toDbDate(rawPayDate, dateFormat);
        final finalPayDate = dbPayDate.isNotEmpty ? dbPayDate : todayDb;
        final dbDateTo = DateUtilsApp.toDbDate(memo['date_to']?.toString(), dateFormat);

        targetData = <String, dynamic>{
          'type': dirType,
          'amount': amount,
          'date': finalPayDate,
          if (dateType == 'RANGE' && dbDateTo.isNotEmpty) 'date_to': dbDateTo,
          'event_dates': finalPayDate,
          'customer_id': customerId,
          'category_id': memo['category_id']?.toString(),
          'service_id': memo['service_id']?.toString(),
          'payment_method': MemoFormScreen.normalizePaymentMethod(
            memo['payment_method']?.toString(),
          ),
          'notes': notesText,
          'title': titleText,
          'description': titleText,
          'client_phone': memo['client_phone']?.toString() ?? '',
          'client_email': memo['client_email']?.toString() ?? '',
          'attachments': jsonEncode(attachmentsList),
          'status': 'PAID',
        };
      }

      await _dbHelper.settleMemoEventAtomically(
        memoId: memoId,
        isInvoice: isInvoice,
        targetData: targetData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pagamento trasferito in ${isInvoice ? 'Fatture' : 'Movimenti'} con successo!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il trasferimento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _updateInvoiceStatus(Map<String, dynamic> inv) async {
    final invId = inv['id']?.toString();
    if (invId == null || invId.isEmpty) return;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Text('Segna come Saldata', style: TextStyle(color: Colors.white)),
            content: Text(
              'Vuoi segnare la fattura "${inv['number'] ?? ''}" come Saldata? Verrà rimossa dai pagamenti programmati e conteggiata sia su Dashboard che Bilancio Fisco.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annulla', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Conferma Saldo', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    try {
      final updated = Map<String, dynamic>.from(inv);
      updated['status'] = 'PAID';
      await _dbHelper.updateInvoice(updated);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fattura saldata con successo!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteMemo(String memoId) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Conferma Eliminazione', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Vuoi davvero eliminare questo pagamento programmato?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _dbHelper.deleteMemoEvent(memoId);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore eliminazione: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showStatusSelector(Map<String, dynamic> memo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Modifica Stato Pagamento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time_rounded, color: Color(0xFF38BDF8)),
                title: const Text('IN ATTESA', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateMemoStatus(memo, 'IN ATTESA');
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                title: const Text('DA SOLLECITARE', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateMemoStatus(memo, 'DA SOLLECITARE');
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                title: const Text(
                  'SALDATO (Trasferisci)',
                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Rimuove dai programmati e crea movimento/fattura',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateMemoStatus(memo, 'SALDATO');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openSearchDialog() {
    _searchCtrl.text = _searchQuery;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('Cerca Pagamento Programmato', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Titolo, cliente, note, importo...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            onSubmitted: (v) {
              setState(() => _searchQuery = v.trim());
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
                Navigator.pop(ctx);
              },
              child: const Text('Azzera', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _searchQuery = _searchCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Cerca'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdfReport() async {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun elemento da esportare.')),
      );
      return;
    }

    final theme = context.read<AppThemeProvider>();

    final List<List<String>> data = filtered.map<List<String>>((item) {
      final isMemo = item['_item_kind'] == 'MEMO';
      final type = (item['memo_type'] ?? (isMemo ? 'MOVIMENTO' : 'FATTURA')).toString();
      final title = (item['title'] ?? '').toString();
      final custId = (item['customer_id'] ?? item['client_id'])?.toString();
      final customer = _getCustomer(custId);
      final custName = customer?['name']?.toString() ?? (item['client_name']?.toString() ?? 'N/D');
      final dateStr = isMemo
          ? _formatMemoDate(item, theme.dateFormat)
          : DateUtilsApp.formatDbDate(item['date']?.toString(), theme.dateFormat);
      final status = (item['memo_status'] ?? 'IN ATTESA').toString();
      final amountVal = CurrencyUtils.parseCurrency(item['amount']?.toString());
      final isIN = (item['transaction_type'] ?? 'ENTRATA').toString().toUpperCase() == 'ENTRATA';

      return [
        type,
        '$title ($custName)',
        dateStr,
        status,
        CurrencyUtils.formatEuro(isIN ? amountVal : -amountVal),
      ];
    }).toList();

    await PDFReportService.generateAndDownloadReport(
      title: 'Pagamenti Programmati',
      headers: ['Tipo', 'Titolo / Cliente', 'Data / Periodo', 'Stato', 'Importo'],
      data: data,
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(65),
        4: const pw.FixedColumnWidth(60),
      },
      dateRangeText: 'Filtro: $_statusFilter • Generato il ${DateUtilsApp.formatDbDate(DateTime.now().toIso8601String(), theme.dateFormat)}',
      dateFormatString: theme.dateFormat,
      landscape: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final outerScaffold = Scaffold.maybeOf(context);
    final hasShellDrawer = outerScaffold?.hasDrawer ?? false;
    final canPopRoute = Navigator.of(context).canPop();

    final filtered = _filteredItems;

    double totalAmount = 0.0;
    for (final item in filtered) {
      final isIN = (item['transaction_type'] ?? 'ENTRATA').toString().toUpperCase() == 'ENTRATA';
      final amt = CurrencyUtils.parseCurrency(item['amount']?.toString());
      totalAmount += isIN ? amt : -amt;
    }
    totalAmount = CurrencyUtils.roundMoney(totalAmount);

    return GradientScaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: canPopRoute
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      : (hasShellDrawer
                          ? IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => outerScaffold?.openDrawer(),
                            )
                          : null),
                  title: const Text(
                    'Pagamenti Programmati',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF38BDF8),
                        size: 24,
                      ),
                      tooltip: 'Nuovo Pagamento',
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MemoFormScreen()),
                        );
                        if (result == true && mounted) _loadData();
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.print_outlined,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                      tooltip: 'Esporta Report PDF',
                      onPressed: _exportPdfReport,
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
                        // Barra Filtri (Stessa skin di PaymentsScreen)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  'Tutti',
                                  'In Attesa',
                                  'Da Sollecitare',
                                  'Movimenti',
                                  'Fatture',
                                  'Entrate',
                                  'Uscite',
                                ].map((f) {
                                  final sel = _statusFilter == f;
                                  return ChoiceChip(
                                    label: Text(f),
                                    selected: sel,
                                    onSelected: (_) {
                                      setState(() => _statusFilter = f);
                                    },
                                    selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                                    backgroundColor: const Color(0xFF16192B),
                                    labelStyle: TextStyle(
                                      color: sel ? const Color(0xFF38BDF8) : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.search,
                                    color: _searchQuery.isEmpty
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFFEC4899),
                                    size: 22,
                                  ),
                                  tooltip: 'Cerca',
                                  onPressed: _openSearchDialog,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.date_range,
                                    color: _dateRange == null
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFFEC4899),
                                    size: 22,
                                  ),
                                  tooltip: 'Filtra Data',
                                  onPressed: () async {
                                    final picked = await ReportUtils.showDateRangeFilterDialog(context);
                                    if (picked != null && mounted) {
                                      setState(() => _dateRange = picked);
                                    }
                                  },
                                ),
                                if (_dateRange != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    tooltip: 'Rimuovi filtro data',
                                    onPressed: () => setState(() => _dateRange = null),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Banner Capsula Totale
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${filtered.length} programmati (totale da saldare)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyUtils.formatEuro(totalAmount),
                                style: TextStyle(
                                  color: totalAmount >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEC4899),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lista Card (Stessa skin di PaymentsScreen)
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'Nessun pagamento programmato trovato',
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
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _buildItemCard(
                              filtered[index],
                              theme.dateFormat,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String dateFormat) {
    final isPendingInvoice = item['_item_kind'] == 'PENDING_INVOICE';
    final isIN = (item['transaction_type'] ?? 'ENTRATA').toString().toUpperCase() == 'ENTRATA';
    final amountVal = CurrencyUtils.parseCurrency(item['amount']?.toString());
    final memoType = (item['memo_type'] ?? (isPendingInvoice ? 'FATTURA' : 'MOVIMENTO')).toString().toUpperCase();
    final isInvoice = memoType == 'FATTURA';

    final custId = (item['customer_id'] ?? item['client_id'])?.toString();
    final customer = _getCustomer(custId);
    final clientName = customer?['name']?.toString().isNotEmpty == true
        ? customer!['name'].toString()
        : (item['client_name']?.toString().isNotEmpty == true
            ? item['client_name'].toString()
            : 'Cliente Generico');

    final title = (item['title'] ?? (isInvoice ? 'Fattura' : 'Promemoria')).toString();
    final desc = item['notes']?.toString().isNotEmpty == true
        ? item['notes'].toString()
        : (item['payment_method']?.toString() ?? (isInvoice ? 'Emissione Fattura' : 'Prestazione'));

    final dateDisplay = isPendingInvoice
        ? DateUtilsApp.formatDbDate(item['date']?.toString(), dateFormat)
        : _formatMemoDate(item, dateFormat);

    final status = (item['memo_status'] ?? 'IN ATTESA').toString().toUpperCase();
    final isLate = status == 'DA SOLLECITARE' || status == 'LATE';

    final Color badgeColor = isLate ? const Color(0xFFEC4899) : const Color(0xFF38BDF8);

    return Material(
      color: const Color(0xFF13141F).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (isPendingInvoice) {
            final invId = item['id']?.toString() ?? '';
            if (invId.isNotEmpty) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoiceSummaryScreen(invoiceId: invId)),
              );
              if (mounted) _loadData();
            }
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MemoFormScreen(initialMemo: item)),
            );
            if (result == true && mounted) _loadData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isInvoice
                                ? Colors.amber.withValues(alpha: 0.15)
                                : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isInvoice ? Colors.amber : const Color(0xFF38BDF8),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isInvoice ? 'FATTURA' : 'MOVIMENTO',
                            style: TextStyle(
                              color: isInvoice ? Colors.amberAccent : const Color(0xFF38BDF8),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      dateDisplay,
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
                    CurrencyUtils.formatEuro(isIN ? amountVal : -amountVal),
                    style: TextStyle(
                      color: isIN ? const Color(0xFF10B981) : const Color(0xFFEC4899),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _isTransferring
                        ? null
                        : () {
                            if (isPendingInvoice) {
                              _updateInvoiceStatus(item);
                            } else {
                              _showStatusSelector(item);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor, width: 1.2),
                      ),
                      child: Text(
                        isLate ? 'Da Sollecitare' : 'In Attesa',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isPendingInvoice) ...[
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                  tooltip: 'Modifica pagamento programmato',
                  onPressed: _isTransferring
                      ? null
                      : () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MemoFormScreen(initialMemo: item)),
                          );
                          if (result == true && mounted) _loadData();
                        },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFEC4899),
                    size: 20,
                  ),
                  tooltip: 'Elimina pagamento programmato',
                  onPressed: _isTransferring ? null : () => _deleteMemo(item['id']?.toString() ?? ''),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
