import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/data_import_service.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../widgets/customer_dialog.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  final DataImportService _importService = DataImportService();
  List<Map<String, dynamic>> _parsedData = [];
  bool _isLoading = false;
  
  // Available data in DB
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];

  // Mapped Expenses
  List<ParsedExpense> _mappedExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadDbData();
  }

  Future<void> _loadDbData() async {
    final customers = await DatabaseHelper().getCustomers();
    final categories = await DatabaseHelper().getCategories();
    final services = await DatabaseHelper().getServiceTypes();
    setState(() {
      _customers = customers;
      _categories = categories;
      _services = services;
    });
  }

  Future<void> _pickAndParseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'ods'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        File file = File(result.files.single.path!);
        List<Map<String, dynamic>> data = await _importService.parseFile(file);
        
        setState(() {
          _parsedData = data;
        });
        _mapDataToExpenses();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'importazione: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _promptMissingCustomers() async {
    for (int i = 0; i < _mappedExpenses.length; i++) {
      var exp = _mappedExpenses[i];
      if (exp.customerId == null && exp.customerName.isNotEmpty) {
        // Chiedi conferma
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: Text('Cliente mancante', style: TextStyle(color: Colors.white)),
            content: Text('Il cliente "${exp.customerName}" non esiste in anagrafica. Vuoi crearlo ora?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Salta per ora', style: TextStyle(color: Colors.white.withOpacity(0.54))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: Text('Crea Cliente', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          // Apri il customer_dialog
          bool? created = await showDialog<bool>(
            context: context,
            builder: (ctx) => CustomerDialog(
              initialName: exp.customerName,
              onSave: (newCustomer) async {
                final id = await DatabaseHelper().insertCustomer(newCustomer);
                newCustomer['id'] = id;
                setState(() {
                  _customers.add(newCustomer);
                });
                return id;
              },
            ),
          );

          if (created == true) {
            // Find it in the updated list
            final match = _customers.where((c) => c['name'] == exp.customerName).toList();
            if (match.isNotEmpty) {
              setState(() {
                exp.customerId = match.first['id'];
              });
            }
          }
        }
      }
    }
  }

  void _mapDataToExpenses() {
    _mappedExpenses = _parsedData.map((row) {
      // Find key matching "ENTE" or "nome"
      String eventNameKey = row.keys.firstWhere(
        (k) => k.toLowerCase().contains('ente') || k.toLowerCase().contains('evento') || k.toLowerCase().contains('nome'),
        orElse: () => row.keys.first
      );
      String eventName = row[eventNameKey]?.toString() ?? '';

      // Importo (PREVENTIVO)
      String amountKey = row.keys.firstWhere(
        (k) => k.toLowerCase().contains('preventivo') || k.toLowerCase().contains('import') || k.toLowerCase().contains('total'),
        orElse: () => ''
      );
      double amount = 0.0;
      String? notes;
      
      if (amountKey.isNotEmpty && row[amountKey] != null) {
        String amtStr = row[amountKey].toString().replaceAll('€', '').trim();
        // Check for division like 1300/2
        if (amtStr.contains('/')) {
          var parts = amtStr.split('/');
          if (parts.length == 2) {
            double num1 = double.tryParse(parts[0].replaceAll(',', '.')) ?? 0.0;
            double num2 = double.tryParse(parts[1].replaceAll(',', '.')) ?? 1.0;
            if (num2 != 0) {
              amount = num1 / num2;
              notes = 'Guadagno iniziale: $num1 diviso per ${num2.toInt()} persone';
            }
          }
        } else {
          amount = double.tryParse(amtStr.replaceAll(',', '.')) ?? 0.0;
        }
      }

      // Data (DATA EVENTO)
      String dateKey = row.keys.firstWhere(
        (k) => k.toLowerCase().contains('data evento') || k.toLowerCase().contains('data'),
        orElse: () => ''
      );
      String date = row[dateKey]?.toString() ?? '';

      // Metodo (Fattura / Contante / Ritenuta d'acconto)
      String methodKey = row.keys.firstWhere(
        (k) => k.toLowerCase().contains('metodo di pagamento') || k.toLowerCase().contains('metodo'),
        orElse: () => ''
      );
      String method = 'Contante';
      if (methodKey.isNotEmpty && row[methodKey] != null) {
        String m = row[methodKey].toString().toLowerCase();
        if (m.contains('fattur')) {
          method = 'Fattura';
        } else if (m.contains('ritenuta')) method = "Ritenuta d'acconto";
        else if (m.contains('contant')) method = 'Contanti';
      }

      // Stato (Saldo - ATTESA)
      String statusKey = row.keys.firstWhere(
        (k) => k.toLowerCase().contains('saldo') || k.toLowerCase().contains('stato'),
        orElse: () => ''
      );
      String status = 'PAID';
      if (statusKey.isNotEmpty && row[statusKey] != null) {
        String s = row[statusKey].toString().toLowerCase();
        if (s.contains('attesa')) {
          status = 'PENDING';
        }
      }

      // Try to find matching customer
      String? customerId;
      String customerName = eventName;
      
      var matchedCustomer = _customers.where((c) => c['name'].toString().toLowerCase() == customerName.toLowerCase()).toList();
      if (matchedCustomer.isNotEmpty) {
        customerId = matchedCustomer.first['id'];
      }

      return ParsedExpense(
        eventName: eventName,
        customerName: customerName,
        date: date,
        totalAmount: amount,
        paymentMethod: method,
        status: status,
        notes: notes,
        customerId: customerId,
        rawRowData: row,
      );
    }).toList();

    // After mapping, prompt for missing ones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptMissingCustomers();
    });
  }

  Future<void> _createNewCustomer(ParsedExpense expense, int index) async {
    bool? created = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomerDialog(
        initialName: expense.customerName,
        onSave: (newCustomer) async {
          final id = await DatabaseHelper().insertCustomer(newCustomer);
          newCustomer['id'] = id;
          setState(() {
            _customers.add(newCustomer);
            _mappedExpenses[index].customerId = id;
            _mappedExpenses[index].customerName = newCustomer['name']!;
          });
          return id;
        },
      ),
    );
  }

  Future<void> _saveAllToDatabase() async {
    setState(() => _isLoading = true);
    int saved = 0;
    try {
      for (var exp in _mappedExpenses) {
        // Find default category and service (or you can let the user pick in the UI)
        String? catId = _categories.isNotEmpty ? _categories.first['id'] : null;
        String? servId = _services.isNotEmpty ? _services.first['id'] : null;

        var payment = {
          'type': 'IN', // Guadagno (Entrata)
          'amount': exp.totalAmount,
          'date': DateTime.now().toIso8601String().split('T').first,
          'event_dates': exp.date, // DATA EVENTO mapped to event_dates
          'customer_id': exp.customerId,
          'category_id': catId,
          'service_id': servId,
          'payment_method': exp.paymentMethod,
          'status': exp.status,
          'notes': exp.notes,
        };
        await DatabaseHelper().insertPayment(payment);

        if (exp.paymentMethod.toLowerCase().contains('fattura')) {
          var invoice = {
            'number': '',
            'date': DateTime.now().toIso8601String().split('T').first,
            'customer_id': exp.customerId,
            'amount': exp.totalAmount,
            'status': exp.status,
          };
          await DatabaseHelper().insertInvoice(invoice);
        }

        saved++;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importati $saved movimenti con successo!')),
      );
      Navigator.pop(context, true); // Return to previous screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore salvataggio: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<AppThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Importa Dati (CSV)'),
        actions: [
          if (_mappedExpenses.isNotEmpty)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveAllToDatabase,
              tooltip: 'Salva Tutto',
            )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _mappedExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Nessun dato importato.'),
                      SizedBox(height: 8),
                      Text('Salva il tuo file Excel come CSV e caricalo qui.', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: Icon(Icons.file_open),
                        label: Text('Seleziona File CSV'),
                        onPressed: _pickAndParseFile,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _mappedExpenses.length,
                  itemBuilder: (context, index) {
                    var expense = _mappedExpenses[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Nome Evento',
                                      isDense: true,
                                    ),
                                    controller: TextEditingController(text: expense.eventName)
                                      ..selection = TextSelection.collapsed(offset: expense.eventName.length),
                                    onChanged: (val) => expense.eventName = val,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Importo',
                                      prefixText: '€ ',
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    controller: TextEditingController(text: expense.totalAmount.toString())
                                      ..selection = TextSelection.collapsed(offset: expense.totalAmount.toString().length),
                                    onChanged: (val) => expense.totalAmount = double.tryParse(val) ?? 0.0,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'Cliente',
                                      isDense: true,
                                    ),
                                    initialValue: expense.customerId,
                                    items: [
                                      ..._customers.map((c) {
                                        return DropdownMenuItem<String>(
                                          value: c['id'],
                                          child: Text(c['name']),
                                        );
                                      }),
                                      DropdownMenuItem<String>(
                                        value: 'NEW',
                                        child: Text('+ Crea Nuovo Cliente', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val == 'NEW') {
                                        _createNewCustomer(expense, index);
                                      } else {
                                        setState(() {
                                          expense.customerId = val;
                                          expense.customerName = _customers.firstWhere((c) => c['id'] == val)['name'];
                                        });
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'Metodo',
                                      isDense: true,
                                    ),
                                    initialValue: expense.paymentMethod,
                                    items: ['Contanti', 'Fattura', 'Ritenuta d\'acconto'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (val) => setState(() => expense.paymentMethod = val!),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Stato:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Switch(
                                  value: expense.status == 'PAID',
                                  onChanged: (val) => setState(() => expense.status = val ? 'PAID' : 'PENDING'),
                                  activeThumbColor: Colors.green,
                                ),
                                Text(expense.status == 'PAID' ? 'Pagato' : 'In attesa', style: TextStyle(color: expense.status == 'PAID' ? Colors.green : Colors.orange)),
                              ],
                            ),
                            if (expense.notes != null) ...[
                              SizedBox(height: 8),
                              Text('Note: ${expense.notes}', style: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                            ],
                            SizedBox(height: 8),
                            ExpansionTile(
                              title: Text('Vedi riga originale', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              children: expense.rawRowData.entries.map((e) => 
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${e.key}: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Expanded(child: Text('${e.value}', style: TextStyle(fontSize: 12))),
                                    ],
                                  ),
                                )
                              ).toList(),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class ParsedExpense {
  String eventName;
  String customerName;
  String date; // Represents the mapped event date(s)
  double totalAmount;
  String paymentMethod;
  String status;
  String? notes;
  String? customerId;
  Map<String, dynamic> rawRowData;

  ParsedExpense({
    required this.eventName,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    this.notes,
    this.customerId,
    required this.rawRowData,
  });
}
