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
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/date_utils_app.dart';
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
  String _statusFilter = 'Tutti'; // Tutti, Saldato, In Attesa, Entrate, Uscite

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
    final payments = await _dbHelper.getPayments();
    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((p) {
      final isIN = p['type'] == 'IN';
      final isPaid = p['status'] == 'PAID' ||
          p['status'] == 'Saldato' ||
          p['status'] == 'Pagato' ||
          (p['status'] == null && isIN);

      if (_statusFilter == 'Saldato' && !isPaid) return false;
      if (_statusFilter == 'In Attesa' && isPaid) return false;
      if (_statusFilter == 'Entrate' && !isIN) return false;
      if (_statusFilter == 'Uscite' && isIN) return false;

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
      MaterialPageRoute(
        builder: (_) => PaymentFormScreen(paymentId: p['id']),
      ),
    );
    _loadPayments();
  }

  Future<void> _toggleStatus(Map<String, dynamic> p) async {
    final auth = await SecurityUtils.requireAdminAuth(context);
    if (!auth || !mounted) return;

    final isIN = p['type'] == 'IN';
    final isPaid = p['status'] == 'PAID' || p['status'] == 'Saldato' || p['status'] == 'Pagato' || (p['status'] == null && isIN);
    final newStatus = isPaid ? 'PENDING' : 'PAID';
    
    try {
      final updatedData = Map<String, dynamic>.from(p);
      updatedData['status'] = newStatus;
      await _dbHelper.updatePayment(updatedData);
      _loadPayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
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
        title: const Text('Elimina Transazione', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Sei sicuro di voler eliminare questo movimento?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899)),
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
        pathOrUrl = pathOrUrl.substring(1, pathOrUrl.length - 1).replaceAll('"', '').trim();
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
          SnackBar(content: Text('Impossibile aprire l\'allegato: $e'), backgroundColor: Colors.red),
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
          const SnackBar(content: Text('Nessun movimento nel periodo selezionato.')),
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
      final dataStr = DateUtilsApp.formatDbDate(p['date']?.toString(), theme.dateFormat);
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

      final importo = '€ ${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}';
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
    final filtered = _filteredPayments;

    return GradientScaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP HEADER BAR: Welcome, User | Search | Notifications | AXION Logo
                    _buildTopHeaderBar(),

                    const SizedBox(height: 28),

                    // 2. PAGE TITLE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Invoices & Transactions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Quick Action Buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 22),
                              tooltip: 'Esporta Report PDF',
                              onPressed: _exportPdfReport,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PaymentFormScreen()),
                                );
                                _loadPayments();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEC4899),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(0xFFEC4899).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              label: const Text('Nuova Fattura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF131728).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.05),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Card Header: Title + Filter Chips + Options
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Transactions Overview',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      _buildStatusFilterChip('Tutti'),
                                      const SizedBox(width: 8),
                                      _buildStatusFilterChip('Saldato'),
                                      const SizedBox(width: 8),
                                      _buildStatusFilterChip('In Attesa'),
                                    ],
                                  ),

                                  // Three Dots Menu
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 22),
                                    color: const Color(0xFF16192B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    onSelected: (action) {
                                      if (action == 'export_pdf') {
                                        _exportPdfReport();
                                      } else if (action == 'new') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const PaymentFormScreen()),
                                        ).then((_) => _loadPayments());
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'export_pdf',
                                        child: Text('Esporta Report PDF', style: TextStyle(color: Colors.white)),
                                      ),
                                      const PopupMenuItem(
                                        value: 'new',
                                        child: Text('Nuovo Movimento', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Table Header Capsule Strip
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [

                                  const Expanded(
                                    flex: 3,
                                    child: Text('Invoice ID', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  const Expanded(
                                    flex: 4,
                                    child: Text('Client Name', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Text('Date', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  const Expanded(
                                    flex: 4,
                                    child: Text('Description', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Text('Amount', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Center(child: Text('Status', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))),
                                  ),
                                  const SizedBox(
                                    width: 100,
                                    child: Center(child: Text('Action', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Table Rows List
                            Expanded(
                              child: filtered.isEmpty
                                  ? const Center(
                                      child: Text('Nessun movimento trovato.', style: TextStyle(color: Colors.white38, fontSize: 14)),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      itemCount: filtered.length,
                                      separatorBuilder: (ctx, i) => Divider(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        height: 1,
                                      ),
                                      itemBuilder: (context, index) {
                                        final p = filtered[index];
                                        final id = p['id']?.toString() ?? '';

                                        final invoiceId = _formatInvoiceId(index);
                                        final clientName = p['customer_name']?.toString().isNotEmpty == true
                                            ? p['customer_name'].toString()
                                            : 'Cliente Generico';
                                        final dateStr = _formatDate(p['date']);
                                        final desc = p['service_name']?.toString().isNotEmpty == true
                                            ? p['service_name'].toString()
                                            : (p['notes']?.toString().isNotEmpty == true ? p['notes'].toString() : (p['payment_method'] ?? 'Prestazione'));
                                        final amountVal = double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
                                        final isIN = p['type'] == 'IN';
                                        final isPaid = p['status'] == 'PAID' ||
                                            p['status'] == 'Saldato' ||
                                            p['status'] == 'Pagato' ||
                                            (p['status'] == null && isIN);

                                        return InkWell(
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PaymentSummaryScreen(paymentId: p['id']),
                                              ),
                                            );
                                            _loadPayments();
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                            child: Row(
                                              children: [
                                                // Invoice ID
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    invoiceId,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),

                                                // Client Name
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    clientName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),

                                                // Date
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    dateStr,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),

                                                // Description
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    desc,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),

                                                // Amount
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    '€ ${amountVal.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),

                                                // Status Neon Badge: Cyan PAID / Magenta PENDING
                                                Expanded(
                                                  flex: 3,
                                                  child: Center(
                                                    child: InkWell(
                                                      onTap: () => _toggleStatus(p),
                                                      borderRadius: BorderRadius.circular(20),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: isPaid
                                                              ? const Color(0xFF22D3EE).withValues(alpha: 0.12)
                                                              : const Color(0xFFEC4899).withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                            color: isPaid
                                                                ? const Color(0xFF22D3EE)
                                                                : const Color(0xFFEC4899),
                                                            width: 1.4,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: (isPaid ? const Color(0xFF22D3EE) : const Color(0xFFEC4899))
                                                                  .withValues(alpha: 0.45),
                                                              blurRadius: 10,
                                                              spreadRadius: 0.5,
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          isPaid ? 'Saldato' : 'In Attesa',
                                                          style: TextStyle(
                                                            color: isPaid ? const Color(0xFF22D3EE) : const Color(0xFFEC4899),
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 1.0,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Action Column: Download Icon & Button
                                                SizedBox(
                                                  width: 100,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      InkWell(
                                                        onTap: () => _openAttachment(p),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: const [
                                                              Icon(Icons.download_rounded, color: Color(0xFF22D3EE), size: 18),
                                                              SizedBox(height: 2),
                                                              Text(
                                                                'Down.',
                                                                style: TextStyle(
                                                                  color: Color(0xFF22D3EE),
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                                        tooltip: 'Modifica',
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () => _editPayment(p),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                                                        hoverColor: Colors.red.withValues(alpha: 0.2),
                                                        tooltip: 'Elimina',
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () => _deletePayment(id),
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Top Header Bar: Welcome text, Search input, notification bell, AXION logo
  Widget _buildTopHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Welcome Text
        RichText(
          text: const TextSpan(
            text: 'Welcome, ',
            style: TextStyle(color: Colors.white60, fontSize: 16),
            children: [
              TextSpan(
                text: 'Eleanor V.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),

        // Right side: Search Box + Bell + AXION Brand
        Row(
          children: [
            // Search Box Capsule
            Container(
              width: 240,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF16192B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38, size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Notification Bell with Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none, color: Colors.white70, size: 20),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEC4899),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 18),

            // AXION Neon Logo
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFFEC4899)],
              ).createShader(bounds),
              child: const Text(
                'AXION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFilterChip(String label) {
    final isSelected = _statusFilter == label;
    Color color = const Color(0xFF38BDF8);
    if (label == 'Saldato') color = const Color(0xFF22D3EE);
    if (label == 'In Attesa') color = const Color(0xFFEC4899);

    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.white.withValues(alpha: 0.1), width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
