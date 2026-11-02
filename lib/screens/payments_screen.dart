import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../providers/app_theme_provider.dart';
import '../services/pdf_report_service.dart';
import '../utils/calculation_engine.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils_app.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/sort_utils.dart';
import '../widgets/gradient_scaffold.dart';
import 'payment_form_screen.dart';
import 'payment_summary_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _togglingIds = {};

  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'Tutti';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final paymentsRaw = await _dbHelper.getPayments();
      final ascendingList =
          paymentsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      ascendingList.sort((a, b) {
        final cmp = compareDates(
          a['date']?.toString(),
          b['date']?.toString(),
          descending: false,
        );
        if (cmp != 0) return cmp;
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        return idA.compareTo(idB);
      });

      for (int i = 0; i < ascendingList.length; i++) {
        ascendingList[i]['_generated_seq'] =
            'A${(i + 1).toString().padLeft(3, '0')}';
      }

      ascendingList.sort((a, b) {
        final cmp = compareDates(
          a['date']?.toString(),
          b['date']?.toString(),
          descending: true,
        );
        if (cmp != 0) return cmp;
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        return idB.compareTo(idA);
      });

      if (!mounted) return;
      setState(() {
        _payments = ascendingList;
      });
    } catch (e) {
      debugPrint('Errore caricamento movimenti: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((p) {
      final isIN =
          (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
      final isPaid = CalculationEngine.isPaymentSettled(p);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;
      if (_statusFilter == 'Uscite' && isIN) return false;

      if (_dateRange != null) {
        final dateStr = p['date']?.toString() ?? '';
        if (!ReportUtils.isDateInRange(dateStr, _dateRange!)) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = (p['id'] ?? '').toString().toLowerCase();
        final seq = (p['_generated_seq'] ?? '').toString().toLowerCase();
        final client = (p['customer_name'] ?? '').toString().toLowerCase();
        final service = (p['service_name'] ?? '').toString().toLowerCase();
        final category = (p['category_name'] ?? '').toString().toLowerCase();
        final title = (p['title'] ?? '').toString().toLowerCase();
        final notes = (p['notes'] ?? '').toString().toLowerCase();
        final method = (p['payment_method'] ?? '').toString().toLowerCase();
        final amount = (p['amount'] ?? '').toString().toLowerCase();

        return id.contains(q) ||
            seq.contains(q) ||
            client.contains(q) ||
            service.contains(q) ||
            category.contains(q) ||
            title.contains(q) ||
            notes.contains(q) ||
            method.contains(q) ||
            amount.contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _createNewPayment() async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentFormScreen()),
    );
    if (mounted) {
      await _loadPayments();
    }
  }

  Future<void> _editPayment(Map<String, dynamic> p) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    final paymentModel = Payment.fromMap(p);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentFormScreen(
          paymentId: paymentModel.id,
          payment: paymentModel,
        ),
      ),
    );
    if (mounted) {
      await _loadPayments();
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> p) async {
    final id = p['id']?.toString() ?? '';
    if (id.isEmpty || _togglingIds.contains(id)) return;

    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    if (_togglingIds.contains(id)) return;
    setState(() => _togglingIds.add(id));

    final isPaid = CalculationEngine.isPaymentSettled(p);
    final newStatus = isPaid ? 'PENDING' : 'PAID';

    try {
      final updatedData = Map<String, dynamic>.from(p)
        ..remove('_generated_seq')
        ..remove('customer_name')
        ..remove('service_name')
        ..remove('category_name');
      updatedData['status'] = newStatus;
      await _dbHelper.updatePayment(updatedData);
      if (mounted) {
        await _loadPayments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(id));
      } else {
        _togglingIds.remove(id);
      }
    }
  }

  Future<void> _deletePayment(String? id) async {
    if (id == null || id.isEmpty) return;

    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16192B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text(
          'Elimina Transazione',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Sei sicuro di voler eliminare questo movimento?',
          style: TextStyle(color: Colors.white70),
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
              backgroundColor: const Color(0xFFEC4899),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deletePayment(id);
        if (mounted) {
          await _loadPayments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  static String _abbreviatePaymentMethod(String? raw) {
    final m = (raw ?? '').trim().toLowerCase();
    if (m.isEmpty) return 'N/D';
    if (m.contains('carta')) return 'CAR';
    if (m.contains('bancomat') || m == 'pos') return 'BAN';
    if (m.contains('bonifico') || m == 'bon') return 'BON';
    if (m.contains('assegn') || m == 'ass') return 'ASS';
    if (m.contains('fattur')) return 'FAT';
    if (m.contains('contant') || m == 'c/c') return 'CON';
    return raw!.trim();
  }

  Future<void> _exportPdfReport() async {
    if (_payments.isEmpty) return;
    final theme = Provider.of<AppThemeProvider>(context, listen: false);

    final DateTimeRange? effectiveRange =
        _dateRange ?? await ReportUtils.showDateRangeFilterDialog(context);
    if (effectiveRange == null || !mounted) return;

    final baseFiltered = _filteredPayments;
    final filteredPayments = baseFiltered.where((p) {
      final date = p['date']?.toString() ?? '';
      if (date.trim().isEmpty) return false;
      return ReportUtils.isDateInRange(date, effectiveRange);
    }).toList();

    if (filteredPayments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun movimento nel periodo selezionato.'),
          ),
        );
      }
      return;
    }

    final List<List<String>> data = filteredPayments.map<List<String>>((p) {
      final serviceName = p['service_name']?.toString() ?? '';
      final title = p['title']?.toString() ?? '';
      final notes = p['notes']?.toString() ?? '';
      final List<String> descParts = [];
      if (title.isNotEmpty) descParts.add(title);
      if (serviceName.isNotEmpty) descParts.add(serviceName);
      if (notes.isNotEmpty) descParts.add(notes);
      final descrizione = descParts.isNotEmpty ? descParts.join(' - ') : 'N/D';

      final cliente = (p['customer_name']?.toString().isNotEmpty == true)
          ? p['customer_name'].toString()
          : 'N/D';
      final dataStr = DateUtilsApp.formatDbDate(
        p['date']?.toString(),
        theme.dateFormat,
      );
      final isIN =
          (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
      final tipo = isIN ? 'E' : 'U';
      final stato = CalculationEngine.isPaymentSettled(p) ? 'S' : 'A';
      final metodo = _abbreviatePaymentMethod(p['payment_method']?.toString());
      final importo = CurrencyUtils.formatEuro(
        CurrencyUtils.parseCurrency(p['amount']?.toString()),
      );
      final rawAtt = p['attachments']?.toString().trim() ?? '';
      final hasAtt = rawAtt.isNotEmpty && rawAtt != '[]';
      final allegati = hasAtt ? 'S' : 'N';

      return [
        cliente,
        descrizione,
        dataStr,
        tipo,
        stato,
        metodo,
        importo,
        allegati,
      ];
    }).toList();

    final List<String> subtitleParts = [
      ReportUtils.formatDateRangeText(effectiveRange, theme.dateFormat),
      if (_statusFilter != 'Tutti') 'Filtro: $_statusFilter',
      if (_searchQuery.isNotEmpty) 'Ricerca: "$_searchQuery"',
    ];

    await PDFReportService.generateAndDownloadReport(
      title: 'Riepilogo Movimenti',
      headers: [
        'Cliente',
        'Descrizione',
        'Dt.',
        'Tp.',
        'St.',
        'Met.',
        'Imp.',
        'All.',
      ],
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(55),
        3: const pw.FixedColumnWidth(26),
        4: const pw.FixedColumnWidth(26),
        5: const pw.FixedColumnWidth(38),
        6: const pw.FixedColumnWidth(60),
        7: const pw.FixedColumnWidth(26),
      },
      dateRangeText: subtitleParts.join(' • '),
      dateFormatString: theme.dateFormat,
      landscape: true,
      legend: {
        'Dt.': 'Data',
        'Tp.': 'Tipo (E=Entrata, U=Uscita)',
        'St.': 'Stato (S=Saldato, A=In Attesa)',
        'Met.':
            'Metodo (FAT=Fattura, CAR=Carta, BAN=Bancomat, BON=Bonifico, ASS=Assegno, CON=Contante)',
        'Imp.': 'Importo',
        'All.': 'Allegati Presenti (S=Sì, N=No)',
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
          title: const Text('Cerca', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cliente, importo, desc...',
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
              child: const Text(
                'Azzera',
                style: TextStyle(color: Colors.redAccent),
              ),
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final outerScaffold = Scaffold.maybeOf(context);
    final hasShellDrawer = outerScaffold?.hasDrawer ?? false;
    final canPopRoute = Navigator.of(context).canPop();

    final filtered = _filteredPayments;

    // Regola 4: somma nei totali saldati SOLO i movimenti saldati
    double settledTotal = 0.0;
    for (final p in filtered) {
      if (!CalculationEngine.isPaymentSettled(p)) continue;
      final isIN =
          (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
      final amount = CurrencyUtils.parseCurrency(p['amount']?.toString());
      settledTotal += isIN ? amount : -amount;
    }
    settledTotal = CurrencyUtils.roundMoney(settledTotal);

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
                  leading: canPopRoute
                      ? IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      : (hasShellDrawer
                          ? IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => outerScaffold?.openDrawer(),
                            )
                          : null),
                  title: const Text(
                    'Movimenti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
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
                      tooltip: 'Nuovo Movimento',
                      onPressed: _createNewPayment,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  'Tutti',
                                  'Saldato',
                                  'In Attesa',
                                  'Entrate',
                                  'Uscite',
                                ].map((f) {
                                  final sel = _statusFilter == f;
                                  return ChoiceChip(
                                    label: Text(f),
                                    selected: sel,
                                    onSelected: (_) {
                                      setState(() {
                                        _statusFilter = f;
                                      });
                                    },
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
                                    final picked =
                                        await ReportUtils.showDateRangeFilterDialog(
                                      context,
                                    );
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
                                    onPressed: () =>
                                        setState(() => _dateRange = null),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${filtered.length} movimenti (totale saldati)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyUtils.formatEuro(settledTotal),
                                style: TextStyle(
                                  color: settledTotal >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEC4899),
                                  fontWeight: FontWeight.bold,
                                ),
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
                                'Nessun movimento trovato',
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
                            itemBuilder: (context, index) => _buildPaymentRow(
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

  Widget _buildPaymentRow(Map<String, dynamic> p, String dateFormat) {
    final isIN = (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
    final isPaid = CalculationEngine.isPaymentSettled(p);
    final color = isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final amountVal = CurrencyUtils.parseCurrency(p['amount']?.toString());

    final rawId = p['id']?.toString() ?? '';
    final displayId = RegExp(r'^[A-Z]\d{3}$').hasMatch(rawId)
        ? rawId
        : (p['_generated_seq']?.toString() ??
            (rawId.isNotEmpty ? rawId : 'A000'));
    final isToggling = rawId.isNotEmpty && _togglingIds.contains(rawId);

    final clientName = p['customer_name']?.toString().isNotEmpty == true
        ? p['customer_name'].toString()
        : 'Cliente Generico';
    final desc = p['service_name']?.toString().isNotEmpty == true
        ? p['service_name'].toString()
        : (p['notes']?.toString().isNotEmpty == true
            ? p['notes'].toString()
            : (p['payment_method']?.toString() ?? 'Prestazione'));

    return Material(
      color: const Color(0xFF13141F).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: rawId.isEmpty
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentSummaryScreen(paymentId: rawId),
                  ),
                );
                if (mounted) {
                  await _loadPayments();
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
                    Text(
                      'Movimento $displayId',
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
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateUtilsApp.formatDbDate(
                        p['date']?.toString(),
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
                    CurrencyUtils.formatEuro(isIN ? amountVal : -amountVal),
                    style: TextStyle(
                      color: isIN
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEC4899),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: isToggling ? null : () => _toggleStatus(p),
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
                      child: isToggling
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: color,
                              ),
                            )
                          : Text(
                              isPaid ? 'Saldato' : 'In Attesa',
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
                tooltip: 'Modifica movimento',
                onPressed: () => _editPayment(p),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
                tooltip: 'Elimina movimento',
                onPressed: () => _deletePayment(rawId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
