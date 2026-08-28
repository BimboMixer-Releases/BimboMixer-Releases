import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/models/models.dart';
import 'package:contabile_app/widgets/gradient_scaffold.dart';
import 'package:contabile_app/widgets/glass_container.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:contabile_app/services/attachment_service.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ScheduledPaymentFormScreen extends StatefulWidget {
  final String? paymentId;
  final bool isReadOnly;
  
  const ScheduledPaymentFormScreen({super.key, this.paymentId, this.isReadOnly = false});

  @override
  State<ScheduledPaymentFormScreen> createState() => _ScheduledPaymentFormScreenState();
}

class _ScheduledPaymentFormScreenState extends State<ScheduledPaymentFormScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  String _type = 'IN';
  String _paymentMethod = 'Fattura';
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  
  List<Customer> _customers = [];
  List<Category> _categories = [];
  List<ServiceType> _services = [];
  
  String? _selectedCustomerId;
  String? _selectedCategoryId;
  String? _selectedServiceId;

  List<String> _attachments = [];
  DateTime _selectedDate = DateTime.now();
  final AttachmentService _attachmentService = AttachmentService();
  bool _isUploading = false;

  // Tracks the Firestore ID even for new payments auto-created when adding attachments
  String? _autoSavedPaymentId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final custData = await _dbHelper.getCustomers();
    final catData = await _dbHelper.getCategories();
    final servData = await _dbHelper.getServiceTypes();
    
    setState(() {
      _customers = custData.map((e) => Customer.fromMap(e)).toList();
      _categories = catData.map((e) => Category.fromMap(e)).toList();
      _services = servData.map((e) => ServiceType.fromMap(e)).toList();
    });

    if (widget.paymentId != null) {
      final paymentData = await _dbHelper.getPaymentById(widget.paymentId!);
      if (paymentData != null) {
        final payment = Payment.fromMap(paymentData, widget.paymentId!);
        setState(() {
          _type = payment.type;
          _paymentMethod = payment.paymentMethod ?? 'Fattura';
          _amountController.text = payment.amount.toString();
          try {
            _selectedDate = DateTime.parse(payment.date);
          } catch (_) {}
          _selectedCustomerId = payment.customerId;
          _selectedCategoryId = payment.categoryId;
          _selectedServiceId = payment.serviceId;
          _notesController.text = payment.notes ?? '';
          _titleController.text = payment.title ?? '';
          _clientPhoneController.text = payment.clientPhone ?? '';
          _clientEmailController.text = payment.clientEmail ?? '';
          if (payment.attachments != null && payment.attachments!.isNotEmpty) {
            _attachments = List<String>.from(jsonDecode(payment.attachments!));
          }
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          child: Material(
            type: MaterialType.transparency,
            child: Wrap(
              children: [
                ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.white),
                title: Text('Scatta Foto', style: TextStyle(color: Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _captureAndCompressImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.white),
                title: Text('Scegli da Galleria', style: TextStyle(color: Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _captureAndCompressImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.white),
                title: Text('Scegli PDF', style: TextStyle(color: Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPdfFile();
                },
              ),
            ],
          )),
        );
      },
    );
  }

  Future<void> _captureAndCompressImage(ImageSource source) async {
    try {
      setState(() => _isUploading = true);
      File? file;
      if (source == ImageSource.camera) {
        file = await _attachmentService.pickImageFromCamera(context);
      } else {
        file = await _attachmentService.pickImageFromGallery(context);
      }
      
      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      final url = await _attachmentService.uploadAttachment(file, 'attachments/payments');
      if (url != null) {
        setState(() {
          _attachments.add(url);
        });
        await _persistPaymentWithAttachments();
      }
    } catch (e) {
      debugPrint("Errore fotocamera/upload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  /// Auto-saves payment to Firestore when adding attachments to ensure they're never lost.
  /// For existing payments: updates immediately. For new payments: creates a record first.
  Future<void> _persistPaymentWithAttachments() async {
    final effectiveId = widget.paymentId ?? _autoSavedPaymentId;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    if (effectiveId != null) {
      // Update existing record
      final data = {
        'id': effectiveId,
        'type': _type,
        'amount': amount,
        'date': date,
        'customer_id': _selectedCustomerId,
        'category_id': _selectedCategoryId,
        'service_id': _selectedServiceId,
        'payment_method': _paymentMethod,
        'attachments': jsonEncode(_attachments),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'client_phone': _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
        'client_email': _clientEmailController.text.trim().isEmpty ? null : _clientEmailController.text.trim(),
      };
      await _dbHelper.updateScheduledPayment(data);
    } else {
      // New payment: auto-save to get an ID, then we'll update on final Save
      final data = {
        'type': _type,
        'amount': amount > 0 ? amount : 0.0,
        'date': date,
        'customer_id': _selectedCustomerId,
        'category_id': _selectedCategoryId,
        'service_id': _selectedServiceId,
        'payment_method': _paymentMethod,
        'attachments': jsonEncode(_attachments),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'client_phone': _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
        'client_email': _clientEmailController.text.trim().isEmpty ? null : _clientEmailController.text.trim(),
        'status': 'PAID',
      };
      final newId = await _dbHelper.insertScheduledPayment(data);
      setState(() => _autoSavedPaymentId = newId);
      debugPrint("Auto-saved new payment with id: $newId");
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      setState(() => _isUploading = true);
      final file = await _attachmentService.pickFile(context);
      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      final url = await _attachmentService.uploadAttachment(file, 'attachments/payments');
      if (url != null) {
        setState(() {
          _attachments.add(url);
        });
        await _persistPaymentWithAttachments();
      }
    } catch (e) {
      debugPrint("Errore scelta PDF/upload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire l\'allegato')));
      }
    }
  }

  Future<void> _savePayment() async {
    if (_amountController.text.isEmpty) return;
    
    // Use auto-saved ID if payment was auto-created when adding attachments
    final effectiveId = widget.paymentId ?? _autoSavedPaymentId;
    
    final newPayment = Payment(
      id: effectiveId,
      type: _type,
      amount: double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      customerId: _selectedCustomerId,
      categoryId: _selectedCategoryId,
      serviceId: _selectedServiceId,
      paymentMethod: _paymentMethod,
      attachments: jsonEncode(_attachments),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      clientPhone: _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
      clientEmail: _clientEmailController.text.trim().isEmpty ? null : _clientEmailController.text.trim(),
    );

    try {
      if (effectiveId == null) {
        // Brand new payment, no attachments added yet
        await _dbHelper.insertScheduledPayment(newPayment.toMap());
      } else {
        await _dbHelper.updateScheduledPayment(newPayment.toMap());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deletePayment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text('Elimina', style: TextStyle(color: Colors.black)),
        content: Text('Sei sicuro di voler eliminare questo movimento?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla', style: TextStyle(color: Colors.white.withOpacity(0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Elimina', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deletePayment(widget.paymentId!);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore durante l\'eliminazione: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context);
    final displayDate = DateFormat(theme.dateFormat).format(_selectedDate);

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          widget.paymentId == null
              ? 'Registra Pagamento'
              : widget.isReadOnly
                  ? 'Dettaglio Movimento'
                  : 'Modifica Pagamento',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (widget.paymentId != null && widget.isReadOnly)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.blueAccent),
              tooltip: 'Modifica',
              onPressed: () async {
                final auth = await SecurityUtils.requireAdminAuth(context);
                if (auth && mounted) {
                  final ctx = context;
                  Navigator.pushReplacement(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ScheduledPaymentFormScreen(paymentId: widget.paymentId, isReadOnly: false),
                    ),
                  );
                }
              },
            ),
          if (widget.paymentId != null && !widget.isReadOnly)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deletePayment,
            ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.white)) 
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IgnorePointer(
                ignoring: widget.isReadOnly,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment(value: 'IN', label: Text('Entrata')),
                        ButtonSegment(value: 'OUT', label: Text('Uscita')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _type = newSelection.first;
                          // Reset category if type changes
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      style: TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Importo (es. 100.50)',
                        prefixText: '€ ',
                        prefixStyle: TextStyle(color: Colors.black),
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                      ),
                    ),
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(text: displayDate),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Data',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                            suffixIcon: Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.7)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<String>(
                      selectedItem: _paymentMethod,
                      items: (filter, _) => ['Fattura', 'Contante', 'Bonifico', 'Carta'],
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Cerca metodo...',
                            hintStyle: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Text(
                        selectedItem ?? 'Metodo',
                        style: TextStyle(color: Colors.white),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Metodo',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      onSelected: (String? val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),

              // ALLEGATI MOVED TO THE CENTER
              if (!widget.isReadOnly)
                ElevatedButton.icon(
                  onPressed: _pickAttachment,
                  icon: Icon(Icons.attach_file),
                  label: Text('Allega Foto/PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                ),
              if (_isUploading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                ),
              if (_attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Allegati:', style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      ..._attachments.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String url = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.attachment, color: Colors.blueAccent, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _launchUrl(url),
                                  child: Text(
                                    'Apri Allegato ${idx + 1}',
                                    style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.download, color: Colors.greenAccent, size: 24),
                                tooltip: 'Scarica in locale',
                                onPressed: () => _attachmentService.downloadAttachment(context, url),
                              ),
                              if (!widget.isReadOnly)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.redAccent, size: 24),
                                  onPressed: () {
                                    setState(() {
                                      _attachments.removeAt(idx);
                                    });
                                    if (widget.paymentId != null) {
                                      final newPayment = Payment(
                                        id: widget.paymentId,
                                        type: _type,
                                        amount: double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0,
                                        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                                        customerId: _selectedCustomerId,
                                        categoryId: _selectedCategoryId,
                                        serviceId: _selectedServiceId,
                                        paymentMethod: _paymentMethod,
                                        attachments: jsonEncode(_attachments),
                                        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                                        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
                                        clientPhone: _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
                                        clientEmail: _clientEmailController.text.trim().isEmpty ? null : _clientEmailController.text.trim(),
                                      );
                                      _dbHelper.updateScheduledPayment(newPayment.toMap());
                                    }
                                  },
                                )
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              SizedBox(height: 16),

              IgnorePointer(
                ignoring: widget.isReadOnly,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Titolo (opzionale)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<Customer>(
                      selectedItem: _selectedCustomerId != null ? _customers.firstWhere((c) => c.id == _selectedCustomerId, orElse: () => Customer(id: '', name: '')) : null,
                      items: (filter, _) => _customers,
                      itemAsString: (Customer c) => c.name,
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Cerca cliente...',
                            hintStyle: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Text(
                        selectedItem?.name ?? '',
                        style: TextStyle(color: Colors.white),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Cliente (Opzionale)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      onSelected: (Customer? val) {
                        setState(() {
                          _selectedCustomerId = val?.id;
                          if (val != null) {
                            if (val.phone != null && val.phone!.isNotEmpty) {
                              _clientPhoneController.text = val.phone!;
                            }
                            if (val.email != null && val.email!.isNotEmpty) {
                              _clientEmailController.text = val.email!;
                            }
                          }
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _clientPhoneController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Cellulare Cliente',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _clientEmailController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email Cliente',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<Category>(
                      selectedItem: _selectedCategoryId != null ? _categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => Category(id: '', name: '', type: '')) : null,
                      items: (filter, _) => _categories.where((c) => c.type == _type).toList(),
                      itemAsString: (Category c) => c.name,
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Cerca categoria...',
                            hintStyle: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Text(
                        selectedItem?.name ?? '',
                        style: TextStyle(color: Colors.white),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Categoria (Opzionale)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      onSelected: (Category? val) => setState(() => _selectedCategoryId = val?.id),
                    ),
                    SizedBox(height: 16),
                    DropdownSearch<ServiceType>(
                      selectedItem: _selectedServiceId != null ? _services.firstWhere((s) => s.id == _selectedServiceId, orElse: () => ServiceType(id: '', name: '')) : null,
                      items: (filter, _) => _services,
                      itemAsString: (ServiceType s) => s.name,
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Cerca servizio...',
                            hintStyle: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Text(
                        selectedItem?.name ?? '',
                        style: TextStyle(color: Colors.white),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Servizio (Opzionale)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      onSelected: (ServiceType? val) => setState(() => _selectedServiceId = val?.id),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      style: TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descrizione evento (Opzionale)',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        hintText: 'Es: Matrimonio Rossi, DJ set serata...',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              if (!widget.isReadOnly)
                ElevatedButton(
                  onPressed: _savePayment,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  child: Text('SALVA PAGAMENTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


