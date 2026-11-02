import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../utils/calculation_engine.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils_app.dart';
import '../utils/security_utils.dart';
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
  List<Map<String, dynamic>> _memoEvents = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _pendingInvoices = [];
  bool _isLoading = true;
  bool _isTransferring = false;

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
        if (result == true && mounted) _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final memoEvents = await _dbHelper.getMemoEvents();
      final customers = await _dbHelper.getCustomers();
      final invoices = await _dbHelper.getInvoices();
      if (!mounted) return;
      setState(() {
        _pendingInvoices = invoices
            .where((i) => !CalculationEngine.isInvoiceSettled(i))
            .toList();
        _memoEvents = memoEvents;
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento pagamenti programmati: $e')),
      );
    }
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
            backgroundColor: theme.cardColor,
            title: const Text(
              'Conferma Trasferimento',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Impostando lo stato su "Saldato", questo pagamento verrà rimosso da questa lista e inserito in automatico nella sezione corrispondente (Movimenti o Fatture).\n\nVuoi procedere?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'Conferma',
                  style: TextStyle(color: Colors.white),
                ),
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
      final memoType =
          (memo['memo_type'] ?? 'MOVIMENTO').toString().toUpperCase();
      final isInvoice = memoType == 'FATTURA';
      final transactionType =
          (memo['transaction_type'] ?? 'ENTRATA').toString().toUpperCase();
      final dirType = transactionType == 'USCITA' ? 'OUT' : 'IN';
      final amount = CurrencyUtils.parseCurrency(memo['amount']?.toString());
      final customerId = (memo['customer_id'] ?? memo['client_id'])?.toString();
      final customerName =
          _getCustomer(customerId)?['name']?.toString() ??
              (memo['client_name']?.toString() ?? '');
      final attachmentsList =
          MemoFormScreen.parseAttachments(memo['attachments']);
      final todayDb = DateUtilsApp.toDbDate(
        DateTime.now().toIso8601String(),
        dateFormat,
      );
      final titleText = memo['title']?.toString().trim() ?? '';
      final notesText = memo['notes']?.toString().trim() ?? '';

      final Map<String, dynamic> targetData;
      if (isInvoice) {
        final rawInvDate =
            (memo['invoice_date']?.toString().trim().isNotEmpty == true)
                ? memo['invoice_date'].toString()
                : (memo['date']?.toString() ?? '');
        final dbInvDate = DateUtilsApp.toDbDate(rawInvDate, dateFormat);
        final finalInvDate = dbInvDate.isNotEmpty ? dbInvDate : todayDb;
        final dbEventDate =
            DateUtilsApp.toDbDate(memo['date']?.toString(), dateFormat);
        final street =
            (memo['client_street'] ?? memo['client_address'])?.toString() ?? '';

        targetData = <String, dynamic>{
          'number':
              (memo['invoice_number'] ?? memo['number'])?.toString().trim() ??
                  '',
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
        final dateType =
            (memo['date_type'] ?? 'SINGOLA').toString().toUpperCase();
        final rawPayDate = dateType == 'RANGE'
            ? (memo['date_from']?.toString() ?? '')
            : (memo['date']?.toString() ?? '');
        final dbPayDate = DateUtilsApp.toDbDate(rawPayDate, dateFormat);
        final finalPayDate = dbPayDate.isNotEmpty ? dbPayDate : todayDb;
        final dbDateTo =
            DateUtilsApp.toDbDate(memo['date_to']?.toString(), dateFormat);

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
              'Pagamento trasferito in ${isInvoice ? 'Fatture' : 'Movimenti'}!',
            ),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il trasferimento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _deleteMemo(String id) async {
    if (id.isEmpty) return;
    final theme = context.read<AppThemeProvider>();
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.cardColor,
            title:
                const Text('Elimina', style: TextStyle(color: Colors.white)),
            content: Text(
              'Vuoi davvero eliminare questo pagamento programmato?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  'Elimina',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    try {
      await _dbHelper.deleteMemoEvent(id);
      if (mounted) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore eliminazione: $e')),
        );
      }
    }
  }

  Map<String, dynamic>? _getCustomer(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in _customers) {
      if (c['id']?.toString() == id) return c;
    }
    return null;
  }

  String _formatMemoDate(Map<String, dynamic> memo, AppThemeProvider theme) {
    if (memo['memo_type'] == 'FATTURA') {
      final fNum =
          (memo['invoice_number'] ?? memo['number'])?.toString().trim() ?? '';
      final rawInvDate =
          (memo['invoice_date']?.toString().trim().isNotEmpty == true)
              ? memo['invoice_date'].toString()
              : memo['date']?.toString();
      final fDate = DateUtilsApp.formatDbDate(rawInvDate, theme.dateFormat);
      final numDisplay = fNum.isNotEmpty ? fNum : 'Non ass.';
      return fDate.isNotEmpty ? 'Fatt. $numDisplay del $fDate' : 'Fatt. $numDisplay';
    }

    if (memo['date_type'] == 'RANGE') {
      final df = DateUtilsApp.formatDbDate(
        memo['date_from']?.toString(),
        theme.dateFormat,
      );
      final dt = DateUtilsApp.formatDbDate(
        memo['date_to']?.toString(),
        theme.dateFormat,
      );
      return 'Da $df a $dt';
    }

    return DateUtilsApp.formatDbDate(memo['date']?.toString(), theme.dateFormat);
  }

  Widget _buildTopHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
              ],
              const Flexible(
                child: Text(
                  'Pagamenti Programmati',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoFormScreen()),
              );
              if (result == true && mounted) _loadData();
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Nuovo pagamento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildTableRows(AppThemeProvider theme) {
    final List<DataRow> rows = [];

    for (final inv in _pendingInvoices) {
      final custId = (inv['customer_id'] ?? inv['client_id'])?.toString();
      final customer = _getCustomer(custId);
      final custName = customer?['name']?.toString().trim().isNotEmpty == true
          ? customer!['name'].toString()
          : (inv['client_name']?.toString().trim().isNotEmpty == true
              ? inv['client_name'].toString()
              : 'Sconosciuto');
      final amount = CurrencyUtils.parseCurrency(inv['amount']?.toString());
      final rawStatus = (inv['status'] ?? '').toString().trim().toUpperCase();
      final isLate = rawStatus == 'LATE' || rawStatus == 'DA SOLLECITARE';

      rows.add(
        DataRow(
          cells: [
            const DataCell(
              Text('Fattura', style: TextStyle(color: Colors.amberAccent)),
            ),
            DataCell(
              Text(
                'Fattura ${inv['number'] ?? ''} - $custName',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            DataCell(
              Text(
                CurrencyUtils.formatEuro(amount),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataCell(
              Text(
                DateUtilsApp.formatDbDate(
                  inv['date']?.toString(),
                  theme.dateFormat,
                ),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLate
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLate ? 'DA SOLLECITARE' : 'IN ATTESA',
                  style: TextStyle(
                    color: isLate ? Colors.redAccent : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            DataCell(
              IconButton(
                icon: const Icon(
                  Icons.visibility,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceSummaryScreen(
                        invoiceId: inv['id'].toString(),
                        onEdit: (invData) async {
                          if (!mounted) return;
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemoFormScreen(
                                initialMemo: invData,
                                sourceTable: 'invoices',
                              ),
                            ),
                          );
                          if (res == true && mounted) _loadData();
                        },
                      ),
                    ),
                  );
                  if (mounted) _loadData();
                },
              ),
            ),
          ],
        ),
      );
    }

    for (final memo in _memoEvents) {
      final custId = (memo['customer_id'] ?? memo['client_id'])?.toString();
      final customer = _getCustomer(custId);
      final isMovement =
          (memo['memo_type'] ?? 'MOVIMENTO').toString().toUpperCase() ==
              'MOVIMENTO';
      final isEntrata =
          (memo['transaction_type'] ?? 'ENTRATA').toString().toUpperCase() !=
              'USCITA';
      final status = MemoFormScreen.normalizeMemoStatus(
        (memo['memo_status'] ?? memo['status'])?.toString(),
      );
      final amount = CurrencyUtils.parseCurrency(memo['amount']?.toString());
      final memoId = memo['id']?.toString() ?? '';

      rows.add(
        DataRow(
          cells: [
            DataCell(
              Text(
                isMovement ? 'Movimento' : 'Fattura',
                style: TextStyle(
                  color: isMovement ? Colors.tealAccent : Colors.amberAccent,
                ),
              ),
            ),
            DataCell(
              Text(
                memo['title']?.toString().trim().isNotEmpty == true
                    ? memo['title'].toString()
                    : (customer?['name']?.toString() ?? 'Sconosciuto'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            DataCell(
              Text(
                CurrencyUtils.formatEuro(amount),
                style: TextStyle(
                  color: isEntrata ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataCell(
              Text(
                _formatMemoDate(memo, theme),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            DataCell(
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: status,
                  dropdownColor: const Color(0xFF13132B),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  items: MemoFormScreen.memoStatuses.map((String val) {
                    Color dotColor = Colors.grey;
                    if (val == 'SALDATO') dotColor = Colors.green;
                    if (val == 'DA SOLLECITARE') dotColor = Colors.orange;
                    if (val == 'IN ATTESA') dotColor = Colors.blue;

                    return DropdownMenuItem<String>(
                      value: val,
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: dotColor, size: 10),
                          const SizedBox(width: 6),
                          Text(
                            val,
                            style: TextStyle(
                              color: val == 'SALDATO'
                                  ? Colors.greenAccent
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isTransferring
                      ? null
                      : (val) {
                          if (val != null && val != status) {
                            _updateMemoStatus(memo, val);
                          }
                        },
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    onPressed: _isTransferring
                        ? null
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MemoFormScreen(initialMemo: memo),
                              ),
                            );
                            if (result == true && mounted) _loadData();
                          },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed:
                        _isTransferring ? null : () => _deleteMemo(memoId),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeaderBar(),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ),
              )
            else if (_memoEvents.isEmpty && _pendingInvoices.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Nessun pagamento programmato.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _isTransferring && _memoEvents.isNotEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : DataTable(
                                headingTextStyle: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                                dataTextStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Tipo')),
                                  DataColumn(label: Text('Titolo')),
                                  DataColumn(label: Text('Importo')),
                                  DataColumn(label: Text('Data')),
                                  DataColumn(label: Text('Stato')),
                                  DataColumn(label: Text('Azioni')),
                                ],
                                rows: _buildTableRows(theme),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
