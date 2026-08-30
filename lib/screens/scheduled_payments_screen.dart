import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import 'payment_form_screen.dart';
import 'payment_summary_screen.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/date_utils_app.dart';
import 'package:pdf/widgets.dart' as pw;

class ScheduledPaymentsScreen extends StatefulWidget {
  const ScheduledPaymentsScreen({super.key});

  @override
  State<ScheduledPaymentsScreen> createState() =>
      _ScheduledPaymentsScreenState();
}

class _ScheduledPaymentsScreenState extends State<ScheduledPaymentsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScheduledPayments();
  }

  Future<void> _loadScheduledPayments() async {
    setState(() => _isLoading = true);
    final payments = await _dbHelper.getScheduledPayments();
    setState(() {
      _payments = payments;
      _isLoading = false;
    });
  }

  void _deleteScheduledPayment(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Conferma', style: TextStyle(color: Colors.white)),
        content: Text(
          'Eliminare questo pagamento programmato?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annulla',
              style: TextStyle(color: Colors.white.withOpacity(0.54)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _dbHelper.deleteScheduledPayment(id);
              _loadScheduledPayments();
            },
            child: Text(
              'Elimina',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _markAsPaid(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Conferma Pagamento', style: TextStyle(color: Colors.white)),
        content: Text(
          'Vuoi registrare questo pagamento programmato come pagato?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annulla',
              style: TextStyle(color: Colors.white.withOpacity(0.54)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Update status to 'Pagato'
                final updatedPayment = Map<String, dynamic>.from(payment);
                updatedPayment['status'] = 'Pagato';
                await _dbHelper.updateScheduledPayment(updatedPayment);
                
                // Show success
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pagamento registrato con successo!'), backgroundColor: Colors.green),
                  );
                }
                _loadScheduledPayments();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(
              'Conferma',
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Movimenti', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: Colors.blueAccent),
            tooltip: 'Esporta in PDF',
            onPressed: () async {
              if (_payments.isEmpty) return;
              final range = await ReportUtils.showDateRangeFilterDialog(
                context,
              );
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
                      content: Text(
                        'Nessun movimento nel periodo selezionato.',
                      ),
                    ),
                  );
                }
                return;
              }
              final List<List<String>>
              data = filteredPayments.map<List<String>>((p) {
                final serviceName = p['service_name']?.toString() ?? '';
                final notes = p['notes']?.toString() ?? '';
                final List<String> descParts = [];
                if (serviceName.isNotEmpty) descParts.add(serviceName);
                if (notes.isNotEmpty) descParts.add(notes);
                final descrizione = descParts.isNotEmpty
                    ? descParts.join(' - ')
                    : 'N/D';

                final cliente = p['customer_name']?.toString() ?? 'N/D';
                final dataStr = DateUtilsApp.formatDbDate(
                  p['date']?.toString(),
                  theme.dateFormat,
                );
                final tipo = p['type'] == 'IN' ? 'E' : 'U';

                String metodo = p['payment_method']?.toString() ?? '';
                if (metodo.toLowerCase() == 'bonifico') {
                  metodo = 'BON';
                } else if (metodo.toLowerCase() == 'contanti')
                  metodo = 'C/C';
                else if (metodo.toLowerCase() == 'assegno')
                  metodo = 'ASS';
                else if (metodo.toLowerCase() == 'pos')
                  metodo = 'POS';

                final importo =
                    '${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} €';

                final hasAtt =
                    p['attachments'] != null && p['attachments'] != '[]';
                final allegati = hasAtt ? 'S' : 'N';

                return [
                  cliente,
                  descrizione,
                  dataStr,
                  tipo,
                  metodo,
                  importo,
                  allegati,
                ];
              }).toList();

              await PDFReportService.generateAndDownloadReport(
                title: 'Movimenti',
                headers: [
                  'Cliente',
                  'Descrizione',
                  'Dt.',
                  'Tp.',
                  'Met.',
                  'Imp.',
                  'All.',
                ],
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
                dateRangeText: ReportUtils.formatDateRangeText(
                  range,
                  theme.dateFormat,
                ),
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
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.blueAccent),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentFormScreen(isScheduled: true),
                ),
              );
              _loadScheduledPayments();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _payments.length,
              itemBuilder: (context, index) {
                final p = _payments[index];
                bool isIN = p['type'] == 'IN';

                final customerName = p['customer_name']?.toString() ?? '';
                final serviceName = p['service_name']?.toString() ?? '';
                final notes = p['notes']?.toString() ?? '';

                final List<String> infoLines = [];
                if (customerName.isNotEmpty)
                  infoLines.add('\u{1F464} $customerName');
                if (serviceName.isNotEmpty)
                  infoLines.add('\u{1F3B5} $serviceName');
                if (notes.isNotEmpty) infoLines.add('\u{1F4DD} $notes');
                final subtitleText = infoLines.isNotEmpty
                    ? infoLines.join("  -  ")
                    : '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.borderColor),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PaymentFormScreen(paymentId: p['id'], isScheduled: true),
                          ),
                        );
                        _loadScheduledPayments();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isIN ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIN
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              DateUtilsApp.formatDbDate(
                                p['date']?.toString(),
                                theme.dateFormat,
                              ),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${p['payment_method'] ?? 'Movimento'}${subtitleText.isNotEmpty ? '    $subtitleText' : ''}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            if (p['attachments'] != null &&
                                p['attachments'] != '[]')
                              Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.attachment,
                                  color: Colors.blueAccent,
                                  size: 20,
                                ),
                              ),
                            Text(
                              '${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} €',
                              style: TextStyle(
                                color: isIN
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 12),
                            IconButton(
                              icon: Icon(
                                Icons.check_circle_outline,
                                color: Colors.greenAccent,
                                size: 20,
                              ),
                              tooltip: 'Segna come Pagato',
                              onPressed: () => _markAsPaid(p),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () => _deleteScheduledPayment(p['id']),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}






