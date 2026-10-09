import 'dart:io';
import 'package:flutter/material.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/attachment_service.dart';
import '../utils/date_utils_app.dart';
import 'package:url_launcher/url_launcher.dart';

class MemoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialMemo;
  final String? sourceTable;

  const MemoFormScreen({super.key, this.initialMemo, this.sourceTable});

  @override
  State<MemoFormScreen> createState() => _MemoFormScreenState();
}

class _MemoFormScreenState extends State<MemoFormScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();

  bool _isUploading = false;
  List<String> _attachments = [];

  // Tipi principali
  String _memoType = 'MOVIMENTO'; // MOVIMENTO o FATTURA
  String _transactionType = 'ENTRATA'; // ENTRATA o USCITA
  String _dateType = 'SINGOLA'; // SINGOLA o RANGE
  String _memoStatus = 'IN ATTESA'; // IN ATTESA, PAGATO, DA SOLLECITARE

  // Dati relazionali
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];

  // Controllers
  String? _customerId;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController(); // data singola
  final TextEditingController _fromDateCtrl = TextEditingController(); // range da
  final TextEditingController _toDateCtrl = TextEditingController(); // range a
  
  final TextEditingController _invoiceNumberCtrl = TextEditingController();
  final TextEditingController _invoiceDateCtrl = TextEditingController(); // data compilazione
  
  final TextEditingController _clientPhoneCtrl = TextEditingController();
  final TextEditingController _clientEmailCtrl = TextEditingController();
  final TextEditingController _clientVatCtrl = TextEditingController(); // PIVA/CF
  final TextEditingController _clientAddressCtrl = TextEditingController();
  final TextEditingController _clientSdiCtrl = TextEditingController(); // SDI/PEC

  String? _paymentMethod = 'Bonifico';
  String? _categoryId;
  String? _serviceId;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  final List<String> _vatCodes = ['22%', '10%', '4%', '0% (Esente)', '0% (Non Imponibile)'];
  String? _vatCode;

  @override
  void initState() {
    super.initState();
    _loadData();

    if (widget.initialMemo != null) {
      final m = widget.initialMemo!;
      
      if (widget.sourceTable == 'payments') {
        _memoType = 'MOVIMENTO';
        _transactionType = (m['type'] == 'IN') ? 'ENTRATA' : 'USCITA';
        _dateType = 'SINGOLA';
        _memoStatus = (m['status'] == 'PAID' || m['status'] == 'Saldato') ? 'PAGATO' : 'IN ATTESA';
        _titleCtrl.text = m['description']?.toString() ?? '';
        _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString(), 'dd/MM/yyyy');
        _customerId = m['client_id']?.toString();
        _paymentMethod = m['payment_method']?.toString() ?? 'Bonifico';
        _categoryId = m['category_id']?.toString();
        if (m['amount'] != null) {
          _amountCtrl.text = CurrencyUtils.formatNumber(double.tryParse(m['amount'].toString()) ?? 0.0);
        }
        if (m['attachments'] != null && m['attachments'] != '') {
          _attachments = m['attachments'].toString().split(',');
        }
        return; // we can return or skip the rest
      } else if (widget.sourceTable == 'invoices') {
        _memoType = 'FATTURA';
        _transactionType = 'ENTRATA';
        _dateType = 'SINGOLA';
        _memoStatus = (m['status'] == 'PAID' || m['status'] == 'Saldato') ? 'PAGATO' : 'IN ATTESA';
        _titleCtrl.text = m['title']?.toString() ?? '';
        _invoiceNumberCtrl.text = m['number']?.toString() ?? '';
        _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString(), 'dd/MM/yyyy');
        _invoiceDateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString(), 'dd/MM/yyyy');
        _customerId = m['client_id']?.toString();
        _vatCode = m['vat_code']?.toString();
        _notesCtrl.text = m['notes']?.toString() ?? '';
        if (m['amount'] != null) {
          _amountCtrl.text = CurrencyUtils.formatNumber(double.tryParse(m['amount'].toString()) ?? 0.0);
        }
        if (m['attachments'] != null && m['attachments'] != '') {
          _attachments = m['attachments'].toString().split(',');
        }
        return;
      }

      _memoType = m['memo_type'] ?? 'MOVIMENTO';
      _transactionType = m['transaction_type'] ?? 'ENTRATA';
      _dateType = m['date_type'] ?? 'SINGOLA';
      _memoStatus = m['memo_status'] ?? 'IN ATTESA';

      _titleCtrl.text = m['title']?.toString() ?? '';
      
      _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString(), 'dd/MM/yyyy');
      _fromDateCtrl.text = DateUtilsApp.formatDbDate(m['date_from']?.toString(), 'dd/MM/yyyy');
      _toDateCtrl.text = DateUtilsApp.formatDbDate(m['date_to']?.toString(), 'dd/MM/yyyy');
      
      _invoiceNumberCtrl.text = m['invoice_number']?.toString() ?? '';
      _invoiceDateCtrl.text = DateUtilsApp.formatDbDate(m['invoice_date']?.toString(), 'dd/MM/yyyy');

      _customerId = m['customer_id']?.toString();
      _clientPhoneCtrl.text = m['client_phone']?.toString() ?? '';
      _clientEmailCtrl.text = m['client_email']?.toString() ?? '';
      _clientVatCtrl.text = m['client_vat']?.toString() ?? '';
      _clientAddressCtrl.text = m['client_address']?.toString() ?? '';
      _clientSdiCtrl.text = m['client_sdi']?.toString() ?? '';

      _paymentMethod = m['payment_method']?.toString() ?? 'Bonifico';
      _categoryId = m['category_id']?.toString();
      _serviceId = m['service_id']?.toString();
      if (m['amount'] != null) {
          _amountCtrl.text = CurrencyUtils.formatNumber(double.tryParse(m['amount'].toString()) ?? 0.0);
        } else {
          _amountCtrl.text = '';
        }
      _notesCtrl.text = m['notes']?.toString() ?? '';
      _vatCode = m['vat_code']?.toString();

      if (m['attachments'] != null) {
        _attachments = List<String>.from(m['attachments']);
      }
    }
  }

  Future<void> _loadData() async {
    final customers = await _dbHelper.getCustomers();
    final services = await _dbHelper.getServiceTypes();
    final categories = await _dbHelper.getCategories();
    setState(() {
      _customers = customers;
      _services = services;
      _categories = categories;

      if (_customerId != null && !_customers.any((c) => c['id'].toString() == _customerId)) {
        _customerId = null;
      }
      if (_serviceId != null && !_services.any((s) => s['id'].toString() == _serviceId)) {
        _serviceId = null;
      }
      if (_categoryId != null && !_categories.any((c) => c['id'].toString() == _categoryId)) {
        _categoryId = null;
      }
    });
  }

  Future<void> _selectDate(TextEditingController ctrl) async {
    final theme = context.read<AppThemeProvider>();
    DateTime initial = DateTime.now();
    if (ctrl.text.isNotEmpty) {
      try {
        initial = DateFormat(theme.dateFormat).parseStrict(ctrl.text);
      } catch (_) {}
    }
    final picked = await GlassDatePicker.show(context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        ctrl.text = DateFormat(theme.dateFormat).format(picked);
      });
    }
  }

  Future<void> _pickAttachment(bool isCamera) async {
    setState(() => _isUploading = true);
    try {
      File? file;
      if (isCamera) {
         file = await _attachmentService.pickImageFromCamera(context);
      } else {
         if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            file = await _attachmentService.pickFile(context);
         } else {
            file = await _attachmentService.pickImageFromGallery(context);
         }
      }
      
      if (file != null) {
        String? url = await _attachmentService.uploadAttachment(file, 'memos');
        if (url != null) {
          setState(() {
            _attachments.add(url);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'allegato: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _saveMemo() async {
    final theme = context.read<AppThemeProvider>();
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per il memo')),
      );
      return;
    }

    final data = <String, dynamic>{
      'memo_type': _memoType,
      'transaction_type': _transactionType,
      'date_type': _dateType,
      'memo_status': _memoStatus,
      'title': _titleCtrl.text,
      
      'date': DateUtilsApp.toDbDate(_dateCtrl.text, theme.dateFormat),
      'date_from': DateUtilsApp.toDbDate(_fromDateCtrl.text, theme.dateFormat),
      'date_to': DateUtilsApp.toDbDate(_toDateCtrl.text, theme.dateFormat),
      
      'invoice_number': _invoiceNumberCtrl.text,
      'invoice_date': DateUtilsApp.toDbDate(_invoiceDateCtrl.text, theme.dateFormat),
      
      'customer_id': _customerId,
      'client_phone': _clientPhoneCtrl.text,
      'client_email': _clientEmailCtrl.text,
      'client_vat': _clientVatCtrl.text,
      'client_address': _clientAddressCtrl.text,
      'client_sdi': _clientSdiCtrl.text,

      'payment_method': _paymentMethod,
      'category_id': _categoryId,
      'service_id': _serviceId,
      'amount': CurrencyUtils.parseCurrency(_amountCtrl.text),
      'notes': _notesCtrl.text,
      'vat_code': _vatCode,
      'attachments': _attachments,
    };

    try {
      if (widget.sourceTable == 'payments') {
        final paymentData = <String, dynamic>{
          'id': widget.initialMemo!['id'],
          'type': _transactionType == 'ENTRATA' ? 'IN' : 'OUT',
          'amount': data['amount'],
          'date': data['date'],
          'client_id': data['customer_id'],
          'category_id': data['category_id'],
          'payment_method': data['payment_method'],
          'description': data['title'],
          'status': _memoStatus == 'PAGATO' ? 'PAID' : 'PENDING',
          'attachments': data['attachments'] is List ? (data['attachments'] as List).join(',') : data['attachments'],
        };
        await _dbHelper.updatePayment(paymentData);
        if (mounted) Navigator.pop(context, true);
        return;
      } else if (widget.sourceTable == 'invoices') {
        final invoiceData = <String, dynamic>{
          'id': widget.initialMemo!['id'],
          'amount': data['amount'],
          'date': data['date'],
          'status': _memoStatus == 'PAGATO' ? 'PAID' : 'PENDING',
          'client_id': data['customer_id'],
          'category_id': data['category_id'],
          'number': data['invoice_number'],
          'notes': data['notes'],
          'title': data['title'],
          'vat_code': data['vat_code'],
          'attachments': data['attachments'] is List ? (data['attachments'] as List).join(',') : data['attachments'],
        };
        await _dbHelper.updateInvoice(invoiceData);
        if (mounted) Navigator.pop(context, true);
        return;
      }

      if (_memoStatus == 'PAGATO') {
        // TRASFERIMENTO AUTOMATICO
        if (_memoType == 'MOVIMENTO') {
          // Prepara pagamento
          final paymentData = <String, dynamic>{
            'type': _transactionType == 'ENTRATA' ? 'IN' : 'OUT',
            'amount': data['amount'],
            'date': _dateType == 'SINGOLA' ? data['date'] : data['date_from'], // usa date_from se range
            'customer_id': data['customer_id'],
            'category_id': data['category_id'],
            'service_id': data['service_id'],
            'payment_method': data['payment_method'],
            'notes': data['notes'],
            'title': data['title'],
            'attachments': data['attachments'],
          };
          await _dbHelper.insertPayment(paymentData);
        } else {
          // Prepara fattura
          final invoiceData = <String, dynamic>{
            'id': data['invoice_number'].toString().isNotEmpty ? data['invoice_number'] : DateTime.now().millisecondsSinceEpoch.toString(),
            'amount': data['amount'],
            'date': data['invoice_date'].toString().isNotEmpty ? data['invoice_date'] : DateUtilsApp.toDbDate(DateTime.now().toIso8601String(), theme.dateFormat),
            'status': 'PAID', // Invoices uses PAID
            'customer_id': data['customer_id'],
            'category_id': data['category_id'],
            'service_id': data['service_id'],
            'notes': data['notes'],
            'title': data['title'],
            'attachments': data['attachments'],
          };
          // Le fatture sono attualmente sempre trattate come ENTRATE dal calculation engine.
          // In futuro si puo' aggiungere type: OUT alle fatture passive, per ora lo inseriamo:
          invoiceData['type'] = _transactionType == 'ENTRATA' ? 'IN' : 'OUT';
          
          await _dbHelper.insertInvoice(invoiceData);
        }
        
        // Elimina il memo se esisteva (aggiornamento di uno esistente e segnato come pagato)
        if (widget.initialMemo != null) {
          await _dbHelper.deleteMemoEvent(widget.initialMemo!['id']);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Memo PAGATO e trasferito in ${_memoType == 'MOVIMENTO' ? 'Movimenti' : 'Fatture'}!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // SALVATAGGIO NORMALE
        if (widget.initialMemo != null) {
          data['id'] = widget.initialMemo!['id'];
          await _dbHelper.updateMemoEvent(data);
        } else {
          await _dbHelper.insertMemoEvent(data);
        }
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _fromDateCtrl.dispose();
    _toDateCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientVatCtrl.dispose();
    _clientAddressCtrl.dispose();
    _clientSdiCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Widget _buildToggleRow({
    required String option1,
    required String option2,
    required String selected,
    required Function(String) onChanged,
    required Color activeColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option1),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected == option1 ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  option1,
                  style: TextStyle(
                    color: selected == option1 ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option2),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected == option2 ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  option2,
                  style: TextStyle(
                    color: selected == option2 ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
        title: Text(
          widget.initialMemo != null ? 'Modifica Programmazione' : 'Nuova Programmazione',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: theme.backgroundMain,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo Documento
                    Text('TIPO DOCUMENTO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildToggleRow(
                      option1: 'MOVIMENTO',
                      option2: 'FATTURA',
                      selected: _memoType,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _memoType = val),
                    ),
                    SizedBox(height: 16),
                    
                    // Direzione
                    Text('DIREZIONE TRANSAZIONE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildToggleRow(
                      option1: 'ENTRATA',
                      option2: 'USCITA',
                      selected: _transactionType,
                      activeColor: _transactionType == 'ENTRATA' ? Colors.teal : Colors.deepOrangeAccent,
                      onChanged: (val) => setState(() => _transactionType = val),
                    ),
                    SizedBox(height: 16),

                    // Stato
                    Text('STATO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _memoStatus,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white10,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: ['IN ATTESA', 'PAGATO', 'DA SOLLECITARE'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _memoStatus = val!),
                    ),
                    SizedBox(height: 24),

                    // Titolo
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Titolo (visualizzato all\'esterno)',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Data Section
                    if (_memoType == 'MOVIMENTO') ...[
                      Text('TIPO DATA PAGAMENTO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      _buildToggleRow(
                        option1: 'SINGOLA',
                        option2: 'RANGE',
                        selected: _dateType,
                        activeColor: Colors.purpleAccent,
                        onChanged: (val) => setState(() => _dateType = val),
                      ),
                      SizedBox(height: 16),
                      if (_dateType == 'SINGOLA')
                        InkWell(
                          onTap: () => _selectDate(_dateCtrl),
                          child: IgnorePointer(
                            child: TextField(
                              controller: _dateCtrl,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Data Pagamento',
                                labelStyle: TextStyle(color: Colors.white54),
                                icon: Icon(Icons.calendar_today, color: Colors.white54),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(_fromDateCtrl),
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _fromDateCtrl,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Da data',
                                      labelStyle: TextStyle(color: Colors.white54),
                                      icon: Icon(Icons.calendar_today, color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(_toDateCtrl),
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _toDateCtrl,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'A data',
                                      labelStyle: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      // Se FATTURA
                      TextField(
                        controller: _invoiceNumberCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Numero Fattura',
                          labelStyle: TextStyle(color: Colors.white54),
                          icon: Icon(Icons.receipt, color: Colors.white54),
                        ),
                      ),
                      SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(_invoiceDateCtrl),
                        child: IgnorePointer(
                          child: TextField(
                            controller: _invoiceDateCtrl,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Data di compilazione',
                              labelStyle: TextStyle(color: Colors.white54),
                              icon: Icon(Icons.calendar_today, color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 24),

                    // Cliente e Dati
                    Text('DATI CLIENTE / CONTROPARTE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: _customerId != null
                          ? _customers.firstWhere((c) => c['id'].toString() == _customerId, orElse: () => {'id': '', 'name': 'Sconosciuto'})['name']?.toString()
                          : null,
                      items: (filter, _) => _customers.map((c) => c['name']?.toString() ?? '').toList(),
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
                        decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Seleziona Cliente Esistente (Opzionale)',
                          labelStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      onSelected: (String? name) {
                        if (name != null) {
                          final c = _customers.firstWhere((cust) => cust['name'] == name);
                          setState(() {
                            _customerId = c['id']?.toString();
                            _clientPhoneCtrl.text = c['phone']?.toString() ?? _clientPhoneCtrl.text;
                            _clientEmailCtrl.text = c['email']?.toString() ?? _clientEmailCtrl.text;
                            _clientVatCtrl.text = c['vat_number']?.toString() ?? _clientVatCtrl.text;
                            _clientAddressCtrl.text = c['address']?.toString() ?? _clientAddressCtrl.text;
                            _clientSdiCtrl.text = c['sdi_code']?.toString() ?? _clientSdiCtrl.text;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _clientPhoneCtrl,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(labelText: 'Cellulare', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _clientEmailCtrl,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ],
                    ),
                    if (_memoType == 'FATTURA') ...[
                      SizedBox(height: 16),
                      TextField(
                        controller: _clientVatCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(labelText: 'Partita IVA / CF', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _clientAddressCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(labelText: 'Indirizzo Completo', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _clientSdiCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(labelText: 'Codice SDI / PEC', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ],
                    SizedBox(height: 24),

                    // Metodo, Categoria, Servizio
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: _paymentMethod,
                      items: (filter, _) => ['Bonifico', 'Contanti', 'Carta di Credito', 'Assegno', 'Altro'],
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
                        decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Metodo di Pagamento',
                          labelStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      onSelected: (val) => setState(() => _paymentMethod = val),
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: _categoryId != null
                          ? _categories.firstWhere((c) => c['id'].toString() == _categoryId, orElse: () => {'name': ''})['name']?.toString()
                          : null,
                      items: (filter, _) => _categories.map((c) => c['name']?.toString() ?? '').toList(),
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
                        decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          labelStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      onSelected: (name) {
                        final c = _categories.firstWhere((cat) => cat['name'] == name);
                        setState(() => _categoryId = c['id']?.toString());
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: _serviceId != null
                          ? _services.firstWhere((s) => s['id'].toString() == _serviceId, orElse: () => {'name': ''})['name']?.toString()
                          : null,
                      items: (filter, _) => _services.map((s) => s['name']?.toString() ?? '').toList(),
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
                        decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tipo Servizio',
                          labelStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      onSelected: (name) {
                        final s = _services.firstWhere((srv) => srv['name'] == name);
                        setState(() => _serviceId = s['id']?.toString());
                      },
                    ),
                    SizedBox(height: 24),

                    // Importo e Note
                    TextField(
                      controller: _amountCtrl,
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Importo',
                        prefixText: '€ ',
                        prefixStyle: TextStyle(color: Colors.white, fontSize: 24),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _notesCtrl,
                      style: TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Allegati
                    Text('ALLEGATI', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    if (_attachments.isNotEmpty)
                      ..._attachments.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String url = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.attachment, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _launchUrl(url),
                                  child: Text('Allegato ${idx + 1}', style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () => setState(() => _attachments.removeAt(idx)),
                              ),
                            ],
                          ),
                        );
                      }),
                    if (_isUploading) Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (Platform.isAndroid || Platform.isIOS)
                          IconButton(icon: Icon(Icons.camera_alt, color: Colors.white54), onPressed: () => _pickAttachment(true)),
                        IconButton(icon: Icon(Icons.image, color: Colors.white54), onPressed: () => _pickAttachment(false)),
                      ],
                    ),

                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _saveMemo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Salva', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

