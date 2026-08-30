import 'dart:io';
import 'package:flutter/material.dart';
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

  const MemoFormScreen({super.key, this.initialMemo});

  @override
  State<MemoFormScreen> createState() => _MemoFormScreenState();
}

class _MemoFormScreenState extends State<MemoFormScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();

  bool _isUploading = false;
  List<String> _attachments = [];
  
  // Scelta del tipo di memo
  String _memoType = 'MOVIMENTO'; // O 'FATTURA'
  String _memoStatus = 'IN ATTESA'; // O 'SOLLECITARE', 'PAGATO'
  
  // Dati relazionali
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  
  // Controller Comuni
  String? _customerId;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController(); // Data del movimento o data fattura
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _clientPhoneCtrl = TextEditingController();
  final TextEditingController _clientEmailCtrl = TextEditingController();
  
  // Controller Categorie e Prestazioni per entrambi i tipi
  String? _categoryId;
  String? _serviceId;
  String _paymentMethod = 'Bonifico';
  final TextEditingController _invoiceDateCtrl = TextEditingController();
  
  // Controller Fattura
  final TextEditingController _invoiceNumberCtrl = TextEditingController();
  final TextEditingController _eventDateCtrl = TextEditingController();
  String? _vatCode;
  final List<String> _vatCodes = [
    '22% (Ordinaria)',
    '10% (Agevolata)',
    '5% (Super agevolata)',
    '4% (Minima)',
    '0% (Esente)',
    '2.1 (Non soggetta - Art. 15)',
    '2.2 (Non soggetta - Altri casi)',
    'Reverse Charge (Inversione contabile)'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _initFields();
  }

  void _initFields() {
    if (widget.initialMemo != null) {
      final m = widget.initialMemo!;
      _memoType = m['memo_type'] ?? 'MOVIMENTO';
      _memoStatus = m['memo_status'] ?? 'IN ATTESA';
      
      _customerId = m['customer_id']?.toString();
      _amountCtrl.text = m['amount']?.toString() ?? '';
      _notesCtrl.text = m['notes']?.toString() ?? '';
      _titleCtrl.text = m['title']?.toString() ?? '';
      _clientPhoneCtrl.text = m['client_phone']?.toString() ?? '';
      _clientEmailCtrl.text = m['client_email']?.toString() ?? '';
      _categoryId = m['category_id']?.toString();
      _serviceId = m['service_id']?.toString();
      
      if (m['attachments'] != null) {
        _attachments = List<String>.from(m['attachments']);
      }

      if (_memoType == 'MOVIMENTO') {
        _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString(), 'dd/MM/yyyy'); // Verrà aggiornato in build in base al tema
        _paymentMethod = m['payment_method'] ?? 'Bonifico';
        _invoiceDateCtrl.text = DateUtilsApp.formatDbDate(m['invoice_date']?.toString(), 'dd/MM/yyyy');
      } else {
        _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString(), 'dd/MM/yyyy');
        _invoiceNumberCtrl.text = m['number']?.toString() ?? '';
        _eventDateCtrl.text = DateUtilsApp.formatDbDate(m['event_date']?.toString(), 'dd/MM/yyyy');
        _vatCode = m['vat_code']?.toString();
      }
    } else {
      _dateCtrl.text = DateUtilsApp.formatDbDate(DateTime.now().toIso8601String().split('T').first, 'dd/MM/yyyy');
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
      if (_vatCode != null && !_vatCodes.contains(_vatCode)) {
        _vatCode = null;
      }
    });
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateFormat(theme.dateFormat).parseStrict(controller.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            surface: Color(0xFF1E1E24),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat(theme.dateFormat).format(picked);
      });
    }
  }

  Future<void> _pickAttachment(bool fromCamera) async {
    final file = fromCamera 
      ? await _attachmentService.pickImageFromCamera(context)
      : await _attachmentService.pickFile(context);
      
    if (file != null) {
      setState(() => _isUploading = true);
      final url = await _attachmentService.uploadAttachment(file, 'attachments/memo_events');
      if (url != null) {
        setState(() => _attachments.add(url));
      }
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
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final data = <String, dynamic>{
      'memo_type': _memoType,
      'memo_status': _memoStatus,
      'customer_id': _customerId,
      'amount': double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
      'date': DateUtilsApp.toDbDate(_dateCtrl.text, theme.dateFormat),
      'notes': _notesCtrl.text,
      'title': _titleCtrl.text,
      'client_phone': _clientPhoneCtrl.text,
      'client_email': _clientEmailCtrl.text,
      'category_id': _categoryId,
      'service_id': _serviceId,
      'attachments': _attachments,
    };

    if (_memoType == 'MOVIMENTO') {
      data['payment_method'] = _paymentMethod;
      data['invoice_date'] = DateUtilsApp.toDbDate(_invoiceDateCtrl.text, theme.dateFormat);
    } else {
      data['number'] = _invoiceNumberCtrl.text;
      data['event_date'] = DateUtilsApp.toDbDate(_eventDateCtrl.text, theme.dateFormat);
      data['vat_code'] = _vatCode;
    }

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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.initialMemo == null ? 'Nuovo Memo' : 'Modifica Memo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Colors.blueAccent),
            onPressed: _isUploading ? null : _saveMemo,
          )
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 4,
            color: theme.cardColor,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Toggle Tipo Memo ---
                  if (widget.initialMemo == null)
                    Center(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'MOVIMENTO', label: Text('Movimento')),
                          ButtonSegment(value: 'FATTURA', label: Text('Fattura')),
                        ],
                        selected: {_memoType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _memoType = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.blueAccent.withValues(alpha: 0.3);
                              }
                              return Colors.transparent;
                            },
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.blueAccent;
                              }
                              return Colors.white54;
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        'MEMO $_memoType',
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    
                  SizedBox(height: 24),

                  // --- Campi Comuni ---
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Titolo Memo (opzionale)',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  InkWell(
                    onTap: () => _selectDate(_dateCtrl),
                    child: IgnorePointer(
                      child: TextField(
                        controller: _dateCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _memoType == 'MOVIMENTO' ? 'Data Pagamento' : 'Data Fattura',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  DropdownSearch<Map<String, dynamic>>(
                    selectedItem: _customerId != null 
                      ? _customers.firstWhere((c) => c['id'].toString() == _customerId, orElse: () => {'id': '', 'name': 'Sconosciuto'})
                      : null,
                    items: (filter, _) => _customers,
                    itemAsString: (Map<String, dynamic> c) => c['name'] ?? '',
                    popupProps: PopupProps.menu(menuProps: const MenuProps(backgroundColor: Color(0xFF2A2D34)), 
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Cerca cliente...',
                          hintStyle: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Cliente',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                      ),
                    ),
                    onSelected: (Map<String, dynamic>? val) {
                      setState(() {
                        _customerId = val?['id']?.toString();
                        if (val != null) {
                          if (val['phone'] != null && val['phone'].toString().isNotEmpty) {
                            _clientPhoneCtrl.text = val['phone'].toString();
                          }
                          if (val['email'] != null && val['email'].toString().isNotEmpty) {
                            _clientEmailCtrl.text = val['email'].toString();
                          }
                        }
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  
                  TextField(
                    controller: _clientPhoneCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Cellulare Cliente',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  TextField(
                    controller: _clientEmailCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Cliente',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  DropdownSearch<Map<String, dynamic>>(
                    selectedItem: _categoryId != null 
                      ? _categories.firstWhere((c) => c['id'].toString() == _categoryId, orElse: () => {'id': '', 'name': 'Sconosciuto'})
                      : null,
                    items: (filter, _) => _categories,
                    itemAsString: (Map<String, dynamic> c) => c['name'] ?? '',
                    popupProps: PopupProps.menu(menuProps: const MenuProps(backgroundColor: Color(0xFF2A2D34)), showSearchBox: true),
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Categoria',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                      ),
                    ),
                    onSelected: (Map<String, dynamic>? val) {
                      setState(() => _categoryId = val?['id']?.toString());
                    },
                  ),
                  SizedBox(height: 16),
                  
                  DropdownSearch<Map<String, dynamic>>(
                    selectedItem: _serviceId != null 
                      ? _services.firstWhere((s) => s['id'].toString() == _serviceId, orElse: () => {'id': '', 'name': 'Sconosciuto'})
                      : null,
                    items: (filter, _) => _services,
                    itemAsString: (Map<String, dynamic> s) => s['name'] ?? '',
                    popupProps: PopupProps.menu(menuProps: const MenuProps(backgroundColor: Color(0xFF2A2D34)), showSearchBox: true),
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Tipo Servizio',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                      ),
                    ),
                    onSelected: (Map<String, dynamic>? val) {
                      setState(() => _serviceId = val?['id']?.toString());
                    },
                  ),
                  SizedBox(height: 16),
                  
                  TextField(
                    controller: _amountCtrl,
                    style: TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Importo',
                      prefixText: '€ ',
                      prefixStyle: TextStyle(color: Colors.white),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // --- Campi Specifici Movimento ---
                  if (_memoType == 'MOVIMENTO') ...[
                    DropdownSearch<String>(
                      selectedItem: _paymentMethod,
                      items: (filter, _) => ['Bonifico', 'Contanti', 'Assegno', 'POS', 'Altro'],
                      decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Metodo di Pagamento',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                        ),
                      ),
                      onSelected: (val) => setState(() => _paymentMethod = val ?? 'Bonifico'),
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(_invoiceDateCtrl),
                      child: IgnorePointer(
                        child: TextField(
                          controller: _invoiceDateCtrl,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Data Fattura Relativa (Opzionale)',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // --- Campi Specifici Fattura ---
                  if (_memoType == 'FATTURA') ...[
                    TextField(
                      controller: _invoiceNumberCtrl,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Numero Fattura (es. FPA 2/26)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<String>(
                      selectedItem: _vatCode,
                      items: (filter, _) => _vatCodes,
                      popupProps: PopupProps.menu(menuProps: const MenuProps(backgroundColor: Color(0xFF2A2D34)), showSearchBox: true),
                      decoratorProps: DropDownDecoratorProps(
                        baseStyle: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Codice IVA',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                        ),
                      ),
                      onSelected: (val) => setState(() => _vatCode = val),
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(_eventDateCtrl),
                      child: IgnorePointer(
                        child: TextField(
                          controller: _eventDateCtrl,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Data Evento (opzionale)',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                          ),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 16),
                  TextField(
                    controller: _notesCtrl,
                    style: TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Note Evento',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // --- Allegati ---
                  Text('Allegati (Foto/File)',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 8),
                  if (_attachments.isNotEmpty)
                    ..._attachments.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String url = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attachment, color: Colors.blueAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _launchUrl(url),
                                child: Text(
                                  'Apri Allegato ${idx + 1}',
                                  style: TextStyle(
                                      color: Colors.blueAccent,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.download, color: Colors.greenAccent, size: 20),
                              tooltip: 'Scarica in locale',
                              onPressed: () => _attachmentService.downloadAttachment(context, url),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() {
                                  _attachments.removeAt(idx);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    }),
                  if (_isUploading)
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                    ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (Platform.isAndroid || Platform.isIOS)
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.54)),
                          onPressed: () => _pickAttachment(true),
                        ),
                      IconButton(
                        icon: Icon(Icons.image, color: Colors.white.withOpacity(0.54)),
                        onPressed: () => _pickAttachment(false),
                      ),
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
                      child: Text('Salva Memo', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



