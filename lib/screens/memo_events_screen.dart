import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../utils/date_utils_app.dart';
import '../utils/currency_utils.dart';
import '../widgets/gradient_scaffold.dart';
import 'memo_form_screen.dart';
import 'invoice_summary_screen.dart';

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
        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoFormScreen()));
        if (result == true && mounted) _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final memoEvents = await _dbHelper.getMemoEvents();
    final customers = await _dbHelper.getCustomers();
    final invoices = await _dbHelper.getInvoices();
    if (!mounted) return;
    setState(() {
      _pendingInvoices = invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'Incassata').toList();
      _memoEvents = memoEvents;
      _customers = customers;
      _isLoading = false;
    });
  }

  Future<void> _updateMemoStatus(Map<String, dynamic> memo, String newStatus) async {
    if (_isTransferring) return;
    final theme = context.read<AppThemeProvider>();
    
    if (newStatus != 'SALDATO') {
      setState(() => _isTransferring = true);
      try {
        final updated = Map<String, dynamic>.from(memo);
        updated['memo_status'] = newStatus;
        await _dbHelper.updateMemoEvent(updated);
        await _loadData();
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

    if (!confirm) {
      return;
    }

    setState(() => _isTransferring = true);
    try {
      final type = memo['memo_type'] ?? 'MOVIMENTO';
      final transactionType = memo['transaction_type'] ?? 'ENTRATA';

      if (type == 'MOVIMENTO') {
        final paymentData = <String, dynamic>{
          'type': transactionType == 'ENTRATA' ? 'IN' : 'OUT',
          'amount': memo['amount'],
          'date': memo['date_type'] == 'SINGOLA' ? memo['date'] : memo['date_from'],
          'customer_id': memo['customer_id'],
          'category_id': memo['category_id'],
          'service_id': memo['service_id'],
          'payment_method': memo['payment_method'],
          'notes': memo['notes'],
          'title': memo['title'],
          'description': memo['title'],
          'attachments': memo['attachments'],
          'status': 'PAID',
        };
        await _dbHelper.insertPayment(paymentData);
      } else {
        final invoiceData = <String, dynamic>{
          'id': (memo['invoice_number']?.toString().isNotEmpty == true) ? memo['invoice_number'] : DateTime.now().millisecondsSinceEpoch.toString(),
          'amount': memo['amount'],
          'date': (memo['invoice_date']?.toString().isNotEmpty == true) ? memo['invoice_date'] : DateUtilsApp.toDbDate(DateTime.now().toIso8601String(), theme.dateFormat),
          'status': 'PAID',
          'customer_id': memo['customer_id'],
          'category_id': memo['category_id'],
          'service_id': memo['service_id'],
          'notes': memo['notes'],
          'title': memo['title'],
          'attachments': memo['attachments'],
          'type': transactionType == 'ENTRATA' ? 'IN' : 'OUT',
        };
        await _dbHelper.insertInvoice(invoiceData);
      }

      await _dbHelper.deleteMemoEvent(memo['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pagamento trasferito in ${type == 'MOVIMENTO' ? 'Movimenti' : 'Fatture'}!')),
        );
      }
      await _loadData();
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _deleteMemo(String id) async {
    final theme = context.read<AppThemeProvider>();
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.cardColor,
            title: const Text('Elimina', style: TextStyle(color: Colors.white)),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Elimina', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await _dbHelper.deleteMemoEvent(id);
      _loadData();
    }
  }

  Map<String, dynamic>? _getCustomer(String? id) {
    if (id == null) return null;
    try {
      return _customers.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }

  String _formatMemoDate(Map<String, dynamic> memo, AppThemeProvider theme) {
    if (memo['memo_type'] == 'FATTURA') {
      final fNum = memo['invoice_number']?.toString() ?? 'Non ass.';
      final fDate = DateUtilsApp.formatDbDate(memo['invoice_date']?.toString(), theme.dateFormat);
      return 'Fatt. $fNum del $fDate';
    }
    
    if (memo['date_type'] == 'RANGE') {
      final df = DateUtilsApp.formatDbDate(memo['date_from']?.toString(), theme.dateFormat);
      final dt = DateUtilsApp.formatDbDate(memo['date_to']?.toString(), theme.dateFormat);
      return 'Da $df a $dt';
    }
    
    return DateUtilsApp.formatDbDate(memo['date']?.toString(), theme.dateFormat);
  }

  Widget _buildTopHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Pagamenti Programmati',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoFormScreen()),
              );
              if (result == true) _loadData();
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
    List<DataRow> rows = [];
    
    for (var inv in _pendingInvoices) {
      final customer = _getCustomer(inv['customer_id']?.toString());
      final amount = double.tryParse(inv['amount']?.toString() ?? '0') ?? 0.0;
      final isLate = inv['status'] == 'LATE';
      
      rows.add(DataRow(
        cells: [
          const DataCell(Text('Fattura', style: TextStyle(color: Colors.amberAccent))),
          DataCell(Text('Fattura ${inv['number'] ?? ''} - ${customer?['name'] ?? 'Sconosciuto'}', style: const TextStyle(color: Colors.white))),
          DataCell(Text(CurrencyUtils.formatEuro(amount), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
          DataCell(Text(DateUtilsApp.formatDbDate(inv['date']?.toString(), theme.dateFormat), style: const TextStyle(color: Colors.white70))),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLate ? Colors.redAccent.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isLate ? 'IN RITARDO' : 'IN ATTESA',
                style: TextStyle(color: isLate ? Colors.redAccent : Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          DataCell(
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blueAccent, size: 20),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InvoiceSummaryScreen(invoiceId: inv['id'].toString())),
                );
                if (mounted) _loadData();
              },
            ),
          ),
        ],
      ));
    }

    for (var memo in _memoEvents) {
      final customer = _getCustomer(memo['customer_id']?.toString());
      final isMovement = memo['memo_type'] == 'MOVIMENTO';
      final isEntrata = memo['transaction_type'] != 'USCITA';
      final rawStatus = memo['memo_status'] ?? 'IN ATTESA';
      final status = (rawStatus == 'PAGATO' || rawStatus == 'SALDATO') ? 'SALDATO' : rawStatus;
      final amount = double.tryParse(memo['amount']?.toString() ?? '0.0') ?? 0.0;
      
      rows.add(DataRow(
        cells: [
          DataCell(Text(isMovement ? 'Movimento' : 'Fattura', style: TextStyle(color: isMovement ? Colors.tealAccent : Colors.amberAccent))),
          DataCell(Text(memo['title']?.toString().isNotEmpty == true ? memo['title'].toString() : (customer?['name'] ?? 'Sconosciuto'), style: const TextStyle(color: Colors.white))),
          DataCell(Text(CurrencyUtils.formatEuro(amount), style: TextStyle(color: isEntrata ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold))),
          DataCell(Text(_formatMemoDate(memo, theme), style: const TextStyle(color: Colors.white70))),
          DataCell(
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: status,
                dropdownColor: const Color(0xFF13132B),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                items: ['IN ATTESA', 'SOLLECITARE', 'SALDATO'].map((String val) {
                  Color dotColor = Colors.grey;
                  if (val == 'SALDATO') dotColor = Colors.green;
                  if (val == 'SOLLECITARE') dotColor = Colors.orange;
                  if (val == 'IN ATTESA') dotColor = Colors.blue;
                  
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: dotColor, size: 10),
                        const SizedBox(width: 6),
                        Text(
                          val,
                          style: TextStyle(color: val == 'SALDATO' ? Colors.greenAccent : Colors.white),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isTransferring ? null : (val) {
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
                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemoFormScreen(initialMemo: memo),
                      ),
                    );
                    if (result == true) _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  onPressed: () => _deleteMemo(memo['id']),
                ),
              ],
            ),
          ),
        ],
      ));
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
              const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)))
            else if (_memoEvents.isEmpty && _pendingInvoices.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Nessun pagamento programmato.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _isTransferring && _memoEvents.isNotEmpty ? 
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(child: CircularProgressIndicator()),
                          ) : DataTable(
                          headingTextStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                          dataTextStyle: const TextStyle(color: Colors.white),
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
