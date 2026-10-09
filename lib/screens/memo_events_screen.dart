import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../utils/date_utils_app.dart';
import '../utils/currency_utils.dart';
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
    final theme = context.read<AppThemeProvider>();
    
    if (newStatus != 'PAGATO') {
      final updated = Map<String, dynamic>.from(memo);
      updated['memo_status'] = newStatus;
      await _dbHelper.updateMemoEvent(updated);
      _loadData();
      return;
    }

    // Conferma prima di trasferire
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(
              'Conferma Trasferimento',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Impostando lo stato su "PAGATO", questo pagamento verrÃ  rimosso da questa lista e inserito in automatico nella sezione corrispondente (Movimenti o Fatture).\n\nVuoi procedere?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  'Conferma',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) {
      _loadData();
      return;
    }

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
        'attachments': memo['attachments'],
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
    _loadData();
  }

  Future<void> _deleteMemo(String id) async {
    final theme = context.read<AppThemeProvider>();
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text('Elimina', style: TextStyle(color: Colors.white)),
            content: Text(
              'Vuoi davvero eliminare questo pagamento programmato?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: Text('Elimina', style: TextStyle(color: Colors.white)),
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
    
    // Singola
    return DateUtilsApp.formatDbDate(memo['date']?.toString(), theme.dateFormat);
  }

  Widget _buildPendingInvoiceCard(Map<String, dynamic> inv, AppThemeProvider theme) {
    final customer = _getCustomer(inv['customer_id']?.toString());
    final amount = double.tryParse(inv['amount']?.toString() ?? '0') ?? 0.0;
    final isLate = inv['status'] == 'LATE';
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoiceSummaryScreen(invoiceId: inv['id'].toString())),
          );
          if (mounted) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.receipt, color: Colors.amberAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FATTURA ${inv['number'] ?? ''}'.trim(),
                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(customer?['name']?.toString() ?? 'Sconosciuto',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(DateUtilsApp.formatDbDate(inv['date']?.toString(), theme.dateFormat),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.circle, size: 10, color: isLate ? Colors.redAccent : Colors.blue),
                      const SizedBox(width: 6),
                      Text(isLate ? 'IN RITARDO' : 'IN ATTESA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              Text(CurrencyUtils.formatEuro(amount),
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Pagamenti programmati',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.blueAccent),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoFormScreen()),
              );
              if (result == true) _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : (_memoEvents.isEmpty && _pendingInvoices.isEmpty)
          ? Center(
              child: Text(
                'Nessun pagamento programmato.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: theme.cardColor.withValues(alpha: 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt, color: Colors.orangeAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Fatture: ${_pendingInvoices.length + _memoEvents.where((m) => m['memo_type']?.toString().toUpperCase() == 'FATTURA').length}",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 24, color: Colors.white24),
                      Row(
                        children: [
                          Icon(Icons.payment, color: Colors.tealAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Movimenti: ${_memoEvents.where((m) => m['memo_type']?.toString().toUpperCase() == 'MOVIMENTO').length}",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingInvoices.length + _memoEvents.length,
                    itemBuilder: (context, index) {
                if (index < _pendingInvoices.length) {
                  return _buildPendingInvoiceCard(_pendingInvoices[index], theme);
                }
                final memo = _memoEvents[index - _pendingInvoices.length];
                final customer = _getCustomer(memo['customer_id']?.toString());
                final customerName = customer?['name'] ?? 'Sconosciuto';

                final isMovement = memo['memo_type'] == 'MOVIMENTO';
                final isEntrata = memo['transaction_type'] != 'USCITA';
                final status = memo['memo_status'] ?? 'IN ATTESA';

                return Card(
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemoFormScreen(initialMemo: memo),
                        ),
                      );
                      if (result == true) _loadData();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isMovement ? Icons.payment : Icons.receipt,
                                color: isMovement ? Colors.tealAccent : Colors.amberAccent,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      memo['title']?.toString().isNotEmpty == true
                                          ? memo['title'].toString().toUpperCase()
                                          : (isMovement ? 'MOVIMENTO' : 'FATTURA'),
                                      style: TextStyle(
                                        color: isMovement ? Colors.tealAccent : Colors.amberAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      customerName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${_formatMemoDate(memo, theme)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyUtils.formatEuro(double.tryParse(memo['amount']?.toString() ?? '0.0') ?? 0.0),
                                    style: TextStyle(
                                      color: isEntrata ? Colors.greenAccent : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Icon(
                                    isEntrata ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isEntrata ? Colors.greenAccent : Colors.redAccent,
                                    size: 16,
                                  )
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownSearch<String>(
                                  compareFn: (a, b) => a == b,
                                  selectedItem: status,
                                  items: (filter, _) => [
                                    'IN ATTESA',
                                    'SOLLECITARE',
                                    'PAGATO',
                                  ],
                                  popupProps: PopupProps.menu(
                                      menuProps: MenuProps(backgroundColor: Color(0xFF13132B)),
                                      showSearchBox: true,
                                      searchFieldProps: TextFieldProps(
                                        style: TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Cerca...',
                                          hintStyle: TextStyle(color: Colors.white54),
                                        ),
                                      ),
                                    ),
                                    dropdownBuilder: (context, selectedItem) {
                                    Color dotColor = Colors.grey;
                                    if (selectedItem == 'PAGATO') dotColor = Colors.green;
                                    if (selectedItem == 'SOLLECITARE') dotColor = Colors.orange;
                                    if (selectedItem == 'IN ATTESA') dotColor = Colors.blue;

                                    return Row(
                                      children: [
                                        Icon(Icons.circle, color: dotColor, size: 12),
                                        SizedBox(width: 8),
                                        Text(
                                          selectedItem ?? '',
                                          style: TextStyle(
                                            color: selectedItem == 'PAGATO' ? Colors.greenAccent : Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  decoratorProps: DropDownDecoratorProps(
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  onSelected: (val) {
                                    if (val != null && val != status) {
                                      _updateMemoStatus(memo, val);
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteMemo(memo['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
