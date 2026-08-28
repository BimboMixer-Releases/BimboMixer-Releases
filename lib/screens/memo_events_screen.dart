import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../utils/date_utils_app.dart';
import 'memo_form_screen.dart';

class MemoEventsScreen extends StatefulWidget {
  const MemoEventsScreen({super.key});

  @override
  State<MemoEventsScreen> createState() => _MemoEventsScreenState();
}

class _MemoEventsScreenState extends State<MemoEventsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _memoEvents = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final memoEvents = await _dbHelper.getMemoEvents();
    final customers = await _dbHelper.getCustomers();
    setState(() {
      _memoEvents = memoEvents;
      _customers = customers;
      _isLoading = false;
    });
  }

  Future<void> _transferToActual(Map<String, dynamic> memo) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Conferma Trasferimento', style: TextStyle(color: Colors.white)),
        content: Text(
          'Impostando lo stato su "PAGATO", questo memo verrà rimosso da questa lista e inserito in automatico nella sua sezione definitiva (Movimenti o Fatture).\n\nVuoi procedere?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Conferma e Trasferisci', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) {
      // Reload data to revert the visual change if canceled
      _loadData();
      return;
    }

    final type = memo['memo_type'] ?? 'MOVIMENTO';
    
    // Prepare data for the final table by copying properties
    final finalData = Map<String, dynamic>.from(memo);
    finalData.remove('id');
    finalData.remove('memo_type');
    finalData.remove('memo_status');

    if (type == 'MOVIMENTO') {
      // Inserisci in payments
      // Mappiamo i campi al formato atteso da insertPayment (i campi sono già allineati grazie alla form)
      await _dbHelper.insertPayment(finalData);
    } else {
      // Inserisci in invoices
      finalData['status'] = 'PAID'; // Forza lo stato fattura a PAID
      await _dbHelper.insertInvoice(finalData);
    }

    // Elimina il memo
    await _dbHelper.deleteMemoEvent(memo['id']);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Memo trasferito correttamente nei $type!')),
      );
    }
    
    _loadData();
  }

  Future<void> _updateMemoStatus(Map<String, dynamic> memo, String newStatus) async {
    if (newStatus == 'PAGATO') {
      await _transferToActual(memo);
    } else {
      final updated = Map<String, dynamic>.from(memo);
      updated['memo_status'] = newStatus;
      await _dbHelper.updateMemoEvent(updated);
      _loadData();
    }
  }

  Future<void> _deleteMemo(String id) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Conferma', style: TextStyle(color: Colors.white)),
        content: Text('Sei sicuro di voler eliminare questo memo?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Memo pagamenti eventi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _memoEvents.isEmpty
              ? Center(child: Text('Nessun memo presente.', style: TextStyle(color: Colors.white.withOpacity(0.54))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _memoEvents.length,
                  itemBuilder: (context, index) {
                    final memo = _memoEvents[index];
                    final customer = _getCustomer(memo['customer_id']?.toString());
                    final customerName = customer?['name'] ?? 'Nessun cliente';
                    
                    final isMovement = memo['memo_type'] == 'MOVIMENTO';
                    final date = DateUtilsApp.formatDbDate(
                        isMovement ? memo['date']?.toString() : (memo['event_date']?.toString() ?? memo['date']?.toString()), 
                        theme.dateFormat);
                        
                    final status = memo['memo_status'] ?? 'IN ATTESA';
                    
                    return Card(
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MemoFormScreen(initialMemo: memo)),
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
                                    size: 28
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          memo['title']?.toString().isNotEmpty == true 
                                            ? memo['title'].toString().toUpperCase() 
                                            : (isMovement ? 'MEMO MOVIMENTO' : 'MEMO FATTURA'),
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
                                        Text(
                                          'Data: $date',
                                          style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '€ ${memo['amount']?.toString() ?? '0.00'}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownSearch<String>(
                                      selectedItem: status,
                                      items: (filter, _) => ['IN ATTESA', 'SOLLECITARE', 'PAGATO'],
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
                                                fontWeight: FontWeight.bold
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                      decoratorProps: DropDownDecoratorProps(
                                        decoration: InputDecoration(
                                          labelText: 'Stato',
                                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
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
    );
  }
}


