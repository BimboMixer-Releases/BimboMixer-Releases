import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import 'payment_form_screen.dart';
import 'payment_summary_screen.dart';
import 'memo_form_screen.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/date_utils_app.dart';
import '../utils/currency_utils.dart';
import '../widgets/gradient_scaffold.dart';
import 'package:pdf/widgets.dart' as pw;

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'Tutti';
  DateTimeRange? _dateRange; // Tutti, Saldato, In Attesa, Entrate, Uscite

  final TextEditingController _searchCtrl = TextEditingController();

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
    setState(() => _isLoading = true);
    final paymentsRaw = await _dbHelper.getPayments();
    
    // Create modifiable copies
    final ascendingList = paymentsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
    
    // Sort oldest to newest to assign sequential IDs
    ascendingList.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
      return da.compareTo(db);
    });
    
    for (int i = 0; i < ascendingList.length; i++) {
      ascendingList[i]['_generated_seq'] = 'A' + (i + 1).toString().padLeft(3, '0');
    }
    
    // Then sort newest to oldest for display
    ascendingList.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    if (mounted) {
      setState(() {
        _payments = ascendingList;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((p) {
      final isIN = p['type'] == 'IN';
      final isPaid =
          p['status'] == 'PAID' ||
          p['status'] == 'Saldato' ||
          p['status'] == 'Pagato' ||
          (p['status'] == null && isIN);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;
      if (_statusFilter == 'Uscite' && isIN) return false;

      if (_dateRange != null) {
        final d = DateTime.tryParse(p['date']?.toString() ?? '');
        if (d != null) {
          final dateOnly = DateTime(d.year, d.month, d.day);
          final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
          if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = (p['id'] ?? '').toString().toLowerCase();
        final client = (p['customer_name'] ?? '').toString().toLowerCase();
        final service = (p['service_name'] ?? '').toString().toLowerCase();
        final notes = (p['notes'] ?? '').toString().toLowerCase();
        final method = (p['payment_method'] ?? '').toString().toLowerCase();
        final amount = (p['amount'] ?? '').toString().toLowerCase();

        return id.contains(q) ||
            client.contains(q) ||
            service.contains(q) ||
            notes.contains(q) ||
            method.contains(q) ||
            amount.contains(q);
      }
      return true;
    }).toList();
  }

  String _formatInvoiceId(int index) {
    return (index + 1).toString().padLeft(3, '0');
  }

  Future<void> _editPayment(Map<String, dynamic> p) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentFormScreen(paymentId: p['id'])),
    );
    _loadPayments();
  }

  Future<void> _toggleStatus(Map<String, dynamic> p) async {
    final isIN = p['type'] == 'IN';
    final isPaid =
        p['status'] == 'PAID' ||
        p['status'] == 'Saldato' ||
        p['status'] == 'Pagato' ||
        (p['status'] == null && isIN);
    final newStatus = isPaid ? 'PENDING' : 'PAID';

    try {
      final updatedData = Map<String, dynamic>.from(p);
      updatedData['status'] = newStatus;
      await _dbHelper.updatePayment(updatedData);
      _loadPayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  String _formatDate(dynamic dateRaw) {
    if (dateRaw == null || dateRaw.toString().isEmpty) return '12 Oct 2023';
    try {
      final d = DateTime.tryParse(dateRaw.toString());
      if (d != null) {
        return DateFormat('dd MMM yyyy').format(d);
      }
    } catch (_) {}
    return dateRaw.toString();
  }

  Future<void> _deletePayment(String id) async {
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
        _loadPayments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _downloadSinglePayment(Map<String, dynamic> p) async {
    final dt = p['date'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date']))
        : '';
    final imp = p['amount'] != null
        ? '€ ${p['amount'].toStringAsFixed(2)}'
        : '';
    final cliente = p['customer_name'] ?? 'N/D';
    final descr = p['description'] ?? 'N/D';
    final tipo = p['type'] ?? 'N/D';
    final metodo = p['payment_method'] ?? 'N/D';

    await PDFReportService.generateAndDownloadReport(
      title: 'Dettaglio Movimento',
      headers: ['Campo', 'Valore'],
      data: [
        ['Data', dt],
        ['Cliente', cliente],
        ['Descrizione', descr],
        ['Importo', imp],
        ['Tipo', tipo],
        ['Metodo', metodo],
      ],
    );
  }

  Future<void> _openAttachment(Map<String, dynamic> payment) async {
    final att = payment['attachments'];
    if (att == null || att.toString() == '[]' || att.toString().isEmpty) {
      // If no attachment, offer to generate invoice summary PDF
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSummaryScreen(paymentId: payment['id']),
        ),
      );
      return;
    }

    try {
      String pathOrUrl = att.toString();
      if (pathOrUrl.startsWith('[') && pathOrUrl.endsWith(']')) {
        pathOrUrl = pathOrUrl
            .substring(1, pathOrUrl.length - 1)
            .replaceAll('"', '')
            .trim();
      }

      final file = File(pathOrUrl);
      if (file.existsSync()) {
        await OpenFilex.open(file.path);
        return;
      }

      final uri = Uri.parse(pathOrUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', pathOrUrl]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire l\'allegato: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportPdfReport() async {
    if (_payments.isEmpty) return;
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final range = await ReportUtils.showDateRangeFilterDialog(context);
    if (range == null) return;

    final filteredPayments = _payments.where((p) {
      final date = p['date'] as String?;
      if (date == null || date.isEmpty) return true;
      return ReportUtils.isDateInRange(date, range);
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
      final notes = p['notes']?.toString() ?? '';
      final List<String> descParts = [];
      if (serviceName.isNotEmpty) descParts.add(serviceName);
      if (notes.isNotEmpty) descParts.add(notes);
      final descrizione = descParts.isNotEmpty ? descParts.join(' - ') : 'N/D';

      final cliente = p['customer_name']?.toString() ?? 'N/D';
      final dataStr = DateUtilsApp.formatDbDate(
        p['date']?.toString(),
        theme.dateFormat,
      );
      final tipo = p['type'] == 'IN' ? 'E' : 'U';

      String metodo = p['payment_method']?.toString() ?? '';
      if (metodo.toLowerCase() == 'bonifico') {
        metodo = 'BON';
      } else if (metodo.toLowerCase() == 'contanti') {
        metodo = 'C/C';
      } else if (metodo.toLowerCase() == 'assegno') {
        metodo = 'ASS';
      } else if (metodo.toLowerCase() == 'pos') {
        metodo = 'POS';
      }

      final importo =
          '€ ${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}';
      final hasAtt = p['attachments'] != null && p['attachments'] != '[]';
      final allegati = hasAtt ? 'S' : 'N';

      return [cliente, descrizione, dataStr, tipo, metodo, importo, allegati];
    }).toList();

    await PDFReportService.generateAndDownloadReport(
      title: 'Invoices & Transactions',
      headers: ['Cliente', 'Descrizione', 'Dt.', 'Tp.', 'Met.', 'Imp.', 'All.'],
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(55),
        3: const pw.FixedColumnWidth(30),
        4: const pw.FixedColumnWidth(40),
        5: const pw.FixedColumnWidth(55),
        6: const pw.FixedColumnWidth(30),
      },
      dateRangeText: ReportUtils.formatDateRangeText(range, theme.dateFormat),
      dateFormatString: theme.dateFormat,
      landscape: true,
      legend: {
        'Dt.': 'Data',
        'Tp.': 'Tipo (E=Entrata, U=Uscita)',
        'Met.': 'Metodo (BON=Bonifico, C/C=Contanti, ASS=Assegno)',
        'Imp.': 'Importo',
        'All.': 'Allegati Presenti (S=Si, N=No)',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final filtered = _filteredPayments;
    final total = filtered.fold<double>(0.0, (sum, p) {
      final isIN = p['type'] == 'IN';
      final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
      return isIN ? sum + amount : sum - amount;
    });

    return GradientScaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text(
                    'Movimenti',
                    style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 22),
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
                                children: ['Tutti', 'Saldato', 'In Attesa', 'Entrate', 'Uscite'].map((f) {
                                  final sel = _statusFilter == f;
                                  return ChoiceChip(
                                    label: Text(f),
                                    selected: sel,
                                    onSelected: (_) {
                                      setState(() {
                                        _statusFilter = f;
                                      });
                                    },
                                    selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                                    backgroundColor: const Color(0xFF16192B),
                                    labelStyle: TextStyle(color: sel ? const Color(0xFF38BDF8) : Colors.white70, fontWeight: FontWeight.bold),
                                  );
                                }).toList(),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.search, color: _searchQuery.isEmpty ? const Color(0xFF38BDF8) : const Color(0xFFEC4899), size: 22),
                                  tooltip: 'Cerca',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) {
                                        String tempQ = _searchQuery;
                                        return AlertDialog(
                                          backgroundColor: const Color(0xFF1E1E2C),
                                          title: const Text('Cerca', style: TextStyle(color: Colors.white)),
                                          content: TextField(
                                            autofocus: true,
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              hintText: 'Cliente, importo, desc...',
                                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                            ),
                                            onChanged: (v) => tempQ = v,
                                            controller: TextEditingController(text: _searchQuery),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() => _searchQuery = '');
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text('Azzera', style: TextStyle(color: Colors.redAccent)),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                setState(() => _searchQuery = tempQ);
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text('Cerca'),
                                            ),
                                          ],
                                        );
                                      }
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.date_range, color: _dateRange == null ? const Color(0xFF38BDF8) : const Color(0xFFEC4899), size: 22),
                                  tooltip: 'Filtra Data',
                                  onPressed: () async {
                                    final picked = await ReportUtils.showDateRangeFilterDialog(context);
                                    if (picked != null) setState(() => _dateRange = picked);
                                  },
                                ),
                                if (_dateRange != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                    tooltip: 'Rimuovi filtro data',
                                    onPressed: () => setState(() => _dateRange = null),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(' movimenti', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                              Text(CurrencyUtils.formatEuro(total), style: TextStyle(color: total >= 0 ? const Color(0xFF10B981) : const Color(0xFFEC4899), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(child: Text('Nessun movimento trovato', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16))),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _buildPaymentRow(filtered[index], theme.dateFormat),
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
    final isIN = p['type'] == 'IN';
    final isPaid = p['status'] == 'PAID' || p['status'] == 'Saldato' || p['status'] == 'Pagato' || (p['status'] == null && isIN);
    final color = isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final amountVal = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
    
    final invoiceId = p['_generated_seq'] ?? 'A000';
    final clientName = p['customer_name']?.toString().isNotEmpty == true ? p['customer_name'].toString() : 'Cliente Generico';
    final desc = p['service_name']?.toString().isNotEmpty == true ? p['service_name'].toString() : (p['notes']?.toString().isNotEmpty == true ? p['notes'].toString() : (p['payment_method'] ?? 'Prestazione'));
    
    return Material(
      color: const Color(0xFF13141F).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PaymentSummaryScreen(paymentId: p['id'])),
          ).then((_) => _loadPayments());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Movimento ', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(clientName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(DateUtilsApp.formatDbDate(p['date']?.toString(), dateFormat), maxLines: 1,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyUtils.formatEuro(isIN ? amountVal : -amountVal),
                      style: TextStyle(color: isIN ? const Color(0xFF10B981) : const Color(0xFFEC4899), fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _toggleStatus(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 1.2),
                      ),
                      child: Text(isPaid ? 'Saldato' : 'In Attesa',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 20),
                onPressed: () async {
                  final auth = await SecurityUtils.requireAdminAuth(context);
                  if (!auth || !mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MemoFormScreen(initialMemo: p, sourceTable: 'payments')),
                  );
                  if (mounted) _loadPayments();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEC4899), size: 20),
                onPressed: () => _deletePayment(p['id']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
