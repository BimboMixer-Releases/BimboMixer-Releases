import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/models/models.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/services/attachment_service.dart';
import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:contabile_app/widgets/glass_container.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
import 'package:contabile_app/widgets/gradient_scaffold.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentFormScreen extends StatefulWidget {
  final String? paymentId;
  final Payment? payment;
  final bool isReadOnly;
  final bool isScheduled;

  const PaymentFormScreen({
    super.key,
    this.paymentId,
    this.payment,
    this.isReadOnly = false,
    this.isScheduled = false,
  });

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  static const List<String> _standardMethods = [
    'Fattura',
    'Carta',
    'Bancomat',
    'Bonifico',
    'Assegno',
    'Contante',
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();

  String _type = 'IN';
  String _paymentMethod = 'Fattura';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  List<Customer> _customers = [];
  List<Category> _categories = [];
  List<ServiceType> _services = [];

  String? _selectedCustomerId;
  String? _selectedCategoryId;
  String? _selectedServiceId;
  String? _invoiceId;
  String? _eventDates;

  List<String> _attachments = [];
  DateTime _selectedDate = DateTime.now();
  DateTime? _dateTo;
  late String _status;

  bool _isUploading = false;
  bool _isSaving = false;
  bool _isLoading = true;

  // Tracks the Firestore ID even for new payments auto-created when adding attachments
  String? _autoSavedPaymentId;

  String? get _initialPaymentId => widget.payment?.id ?? widget.paymentId;

  @override
  void initState() {
    super.initState();
    _status = widget.payment != null
        ? _normalizeStatus(widget.payment!.status)
        : (widget.isScheduled ? 'PENDING' : 'PAID');
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _titleController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  static String _normalizePaymentMethod(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Fattura';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'contanti' || lower == 'contante' || lower == 'c/c') {
      return 'Contante';
    }
    if (lower == 'pos' || lower == 'bancomat') {
      return 'Bancomat';
    }
    if (lower.contains('carta')) {
      return 'Carta';
    }
    if (lower.contains('bonifico') || lower == 'bon') {
      return 'Bonifico';
    }
    if (lower.contains('assegn') || lower == 'ass') {
      return 'Assegno';
    }
    if (lower.contains('fattur')) {
      return 'Fattura';
    }
    for (final method in _standardMethods) {
      if (method.toLowerCase() == lower) return method;
    }
    return 'Fattura';
  }

  static String _normalizeStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'PAID';
    final upper = raw.trim().toUpperCase();
    if (upper == 'PAID' || upper == 'PENDING') return upper;
    if (CalculationEngine.isPaymentSettled({'status': raw})) {
      return 'PAID';
    }
    return 'PENDING';
  }

  static List<String> _parseAttachmentsSafely(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '[]') {
      return [];
    }
    final trimmed = raw.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return [decoded.trim()];
      }
    } catch (_) {
      final inner = (trimmed.startsWith('[') && trimmed.endsWith(']'))
          ? trimmed.substring(1, trimmed.length - 1)
          : trimmed;
      return inner
          .split(',')
          .map((s) => s.replaceAll('"', '').replaceAll("'", '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  void _applyPaymentToFields(Payment p) {
    _type = p.type.trim().toUpperCase() == 'OUT' ? 'OUT' : 'IN';
    _paymentMethod = _normalizePaymentMethod(p.paymentMethod);
    _amountController.text = CurrencyUtils.formatNumber(p.amount);
    _selectedDate = DateUtilsApp.tryParseDate(p.date) ?? DateTime.now();
    if (p.dateTo != null && p.dateTo!.trim().isNotEmpty) {
      _dateTo = DateUtilsApp.tryParseDate(p.dateTo);
    } else {
      _dateTo = null;
    }
    _status = p.status.trim().isEmpty
        ? (widget.isScheduled ? 'PENDING' : 'PAID')
        : p.status.trim();
    _selectedCustomerId = p.customerId;
    _selectedCategoryId = p.categoryId;
    _selectedServiceId = p.serviceId;
    _invoiceId = p.invoiceId;
    _eventDates = p.eventDates;
    _notesController.text = p.notes ?? '';
    _titleController.text = p.title ?? '';
    _clientPhoneController.text = p.clientPhone ?? '';
    _clientEmailController.text = p.clientEmail ?? '';
    _attachments = _parseAttachmentsSafely(p.attachments);
  }

  void _syncDateControllers(String dateFormat) {
    final formattedFrom = DateFormat(dateFormat).format(_selectedDate);
    if (_dateFromController.text != formattedFrom) {
      _dateFromController.text = formattedFrom;
    }
    final formattedTo =
        _dateTo != null ? DateFormat(dateFormat).format(_dateTo!) : '';
    if (_dateToController.text != formattedTo) {
      _dateToController.text = formattedTo;
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _dbHelper.getCustomers(),
        _dbHelper.getCategories(),
        _dbHelper.getServiceTypes(),
      ]);

      if (!mounted) return;

      final custData = results[0];
      final catData = results[1];
      final servData = results[2];

      Payment? loadedPayment = widget.payment;
      final idToFetch = _initialPaymentId;

      if (idToFetch != null && idToFetch.isNotEmpty) {
        final paymentData = widget.isScheduled
            ? await _dbHelper.getScheduledPaymentById(idToFetch)
            : await _dbHelper.getPaymentById(idToFetch);
        if (!mounted) return;
        if (paymentData != null) {
          loadedPayment = Payment.fromMap(paymentData, idToFetch);
        }
      }

      setState(() {
        _customers = custData.map((e) => Customer.fromMap(e)).toList();
        _categories = catData.map((e) => Category.fromMap(e)).toList();
        _services = servData.map((e) => ServiceType.fromMap(e)).toList();
        if (loadedPayment != null) {
          _applyPaymentToFields(loadedPayment);
        }
      });
    } catch (e) {
      debugPrint('Errore caricamento modulo pagamento: $e');
      if (mounted && widget.payment != null) {
        setState(() {
          _applyPaymentToFields(widget.payment!);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Payment _buildPaymentPayload({String? idOverride, double? amountOverride}) {
    final parsedAmount =
        amountOverride ?? CurrencyUtils.parseCurrency(_amountController.text);
    return Payment(
      id: idOverride,
      type: _type,
      amount: parsedAmount,
      date: DateFormat('dd/MM/yyyy').format(_selectedDate),
      customerId: _selectedCustomerId,
      categoryId: _selectedCategoryId,
      serviceId: _selectedServiceId,
      invoiceId: _invoiceId,
      paymentMethod: _paymentMethod,
      attachments: jsonEncode(_attachments),
      status: _status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      eventDates: _eventDates,
      dateTo: _dateTo != null
          ? DateFormat('dd/MM/yyyy').format(_dateTo!)
          : null,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      clientPhone: _clientPhoneController.text.trim().isEmpty
          ? null
          : _clientPhoneController.text.trim(),
      clientEmail: _clientEmailController.text.trim().isEmpty
          ? null
          : _clientEmailController.text.trim(),
    );
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return GlassContainer(
          child: Material(
            type: MaterialType.transparency,
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.white),
                  title: const Text(
                    'Scatta Foto',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _captureAndCompressImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text(
                    'Scegli da Galleria',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _captureAndCompressImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  title: const Text(
                    'Scegli PDF',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickPdfFile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _captureAndCompressImage(ImageSource source) async {
    try {
      if (!mounted) return;
      setState(() => _isUploading = true);
      File? file;
      if (source == ImageSource.camera) {
        file = await _attachmentService.pickImageFromCamera(context);
      } else {
        file = await _attachmentService.pickImageFromGallery(context);
      }

      if (file == null || !mounted) {
        return;
      }

      final url = await _attachmentService.uploadAttachment(
        file,
        'attachments/payments',
      );
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _attachments.add(url);
        });
        await _persistPaymentWithAttachments();
      }
    } catch (e) {
      debugPrint('Errore fotocamera/upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// Auto-saves payment to Firestore when adding attachments to ensure they're never lost.
  Future<void> _persistPaymentWithAttachments() async {
    final effectiveId = _initialPaymentId ?? _autoSavedPaymentId;
    final amount = CurrencyUtils.parseCurrency(_amountController.text);

    if (effectiveId != null && effectiveId.isNotEmpty) {
      final payload = _buildPaymentPayload(
        idOverride: effectiveId,
        amountOverride: amount,
      );
      if (widget.isScheduled) {
        await _dbHelper.updateScheduledPayment(payload.toMap());
      } else {
        await _dbHelper.updatePayment(payload.toMap());
      }
    } else {
      final payload = _buildPaymentPayload(
        amountOverride: amount > 0 ? amount : 0.0,
      );
      final newId = widget.isScheduled
          ? await _dbHelper.insertScheduledPayment(payload.toMap())
          : await _dbHelper.insertPayment(payload.toMap());
      if (mounted) {
        setState(() => _autoSavedPaymentId = newId);
      }
      debugPrint('Auto-saved new payment with id: $newId');
    }
  }

  Future<void> _removeAttachmentAt(int idx) async {
    if (idx < 0 || idx >= _attachments.length) return;
    final urlToRemove = _attachments[idx];
    setState(() {
      _attachments.removeAt(idx);
    });

    await _attachmentService.deleteAttachment(urlToRemove);

    final effectiveId = _initialPaymentId ?? _autoSavedPaymentId;
    if (effectiveId != null && effectiveId.isNotEmpty) {
      try {
        final payload = _buildPaymentPayload(idOverride: effectiveId);
        if (widget.isScheduled) {
          await _dbHelper.updateScheduledPayment(payload.toMap());
        } else {
          await _dbHelper.updatePayment(payload.toMap());
        }
      } catch (e) {
        debugPrint('Errore aggiornamento allegati: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore aggiornamento allegati: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      if (!mounted) return;
      setState(() => _isUploading = true);
      final file = await _attachmentService.pickFile(context);
      if (file == null || !mounted) {
        return;
      }

      final url = await _attachmentService.uploadAttachment(
        file,
        'attachments/payments',
      );
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _attachments.add(url);
        });
        await _persistPaymentWithAttachments();
      }
    } catch (e) {
      debugPrint('Errore scelta PDF/upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openAttachment(String pathOrUrl) async {
    try {
      if (!pathOrUrl.startsWith('http://') &&
          !pathOrUrl.startsWith('https://')) {
        final localFile = File(pathOrUrl);
        if (await localFile.exists()) {
          await OpenFilex.open(localFile.path);
          return;
        }
      }

      final Uri url = Uri.parse(pathOrUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire l\'allegato')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile aprire l\'allegato: $e')),
        );
      }
    }
  }

  Future<void> _savePayment() async {
    if (_isSaving) return;
    final parsedAmount = CurrencyUtils.parseCurrency(_amountController.text);
    if (parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un importo valido maggiore di zero.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final effectiveId = _initialPaymentId ?? _autoSavedPaymentId;
    final newPayment = _buildPaymentPayload(
      idOverride: effectiveId,
      amountOverride: parsedAmount,
    );

    try {
      if (effectiveId == null || effectiveId.isEmpty) {
        if (widget.isScheduled) {
          await _dbHelper.insertScheduledPayment(newPayment.toMap());
        } else {
          await _dbHelper.insertPayment(newPayment.toMap());
        }
      } else {
        if (widget.isScheduled) {
          await _dbHelper.updateScheduledPayment(newPayment.toMap());
        } else {
          await _dbHelper.updatePayment(newPayment.toMap());
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePayment() async {
    final idToDelete = _initialPaymentId ?? _autoSavedPaymentId;
    if (idToDelete == null || idToDelete.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Elimina', style: TextStyle(color: Colors.white)),
        content: Text(
          'Sei sicuro di voler eliminare questo movimento?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annulla',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Elimina',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (widget.isScheduled) {
          await _dbHelper.deleteScheduledPayment(idToDelete);
        } else {
          await _dbHelper.deletePayment(idToDelete);
        }
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante l\'eliminazione: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickDate({bool isFrom = true}) async {
    final initialDate = isFrom ? _selectedDate : (_dateTo ?? _selectedDate);
    final DateTime? picked = await GlassDatePicker.show(
      context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _selectedDate = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context);
    _syncDateControllers(theme.dateFormat);

    final effectiveId = _initialPaymentId;
    final statusItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: 'PENDING',
        child: Text(
          '⏳ Da Pagare',
          style: TextStyle(color: Colors.white),
        ),
      ),
      const DropdownMenuItem(
        value: 'PAID',
        child: Text(
          '✅ Pagato',
          style: TextStyle(color: Colors.white),
        ),
      ),
      if (_status != 'PENDING' && _status != 'PAID')
        DropdownMenuItem(
          value: _status,
          child: Text(
            _status,
            style: const TextStyle(color: Colors.white),
          ),
        ),
    ];

    Customer? selectedCustomer;
    if (_selectedCustomerId != null) {
      for (final c in _customers) {
        if (c.id == _selectedCustomerId) {
          selectedCustomer = c;
          break;
        }
      }
    }

    Category? selectedCategory;
    if (_selectedCategoryId != null) {
      for (final c in _categories) {
        if (c.id == _selectedCategoryId) {
          selectedCategory = c;
          break;
        }
      }
    }

    ServiceType? selectedService;
    if (_selectedServiceId != null) {
      for (final s in _services) {
        if (s.id == _selectedServiceId) {
          selectedService = s;
          break;
        }
      }
    }

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          effectiveId == null
              ? 'Registra Pagamento'
              : widget.isReadOnly
                  ? 'Dettaglio Movimento'
                  : 'Modifica Pagamento',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (effectiveId != null && widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
              tooltip: 'Modifica',
              onPressed: () async {
                final auth = await SecurityUtils.requireAdminAuth(context);
                if (!auth || !context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentFormScreen(
                      paymentId: effectiveId,
                      payment: widget.payment,
                      isReadOnly: false,
                      isScheduled: widget.isScheduled,
                    ),
                  ),
                );
              },
            ),
          if (effectiveId != null && !widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deletePayment,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                              ButtonSegment(
                                value: 'IN',
                                label: Text('Entrata'),
                              ),
                              ButtonSegment(
                                value: 'OUT',
                                label: Text('Uscita'),
                              ),
                            ],
                            selected: {_type},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _type = newSelection.first;
                                _selectedCategoryId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _amountController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Importo (es. 100,50)',
                              prefixText: '€ ',
                              prefixStyle: const TextStyle(color: Colors.white),
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _pickDate(isFrom: true),
                                  child: AbsorbPointer(
                                    child: TextField(
                                      controller: _dateFromController,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Data da',
                                        labelStyle: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        suffixIcon: Icon(
                                          Icons.calendar_today,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _pickDate(isFrom: false),
                                      child: AbsorbPointer(
                                        child: TextField(
                                          controller: _dateToController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Data a (opz.)',
                                            labelStyle: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                            enabledBorder:
                                                UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                              ),
                                            ),
                                            suffixIcon: _dateTo != null
                                                ? const SizedBox(width: 36)
                                                : Icon(
                                                    Icons.calendar_today,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.7),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_dateTo != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.white54,
                                        ),
                                        onPressed: () =>
                                            setState(() => _dateTo = null),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>(_status),
                            initialValue: _status,
                            dropdownColor: Theme.of(context).canvasColor,
                            decoration: InputDecoration(
                              labelText: 'Stato',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            items: statusItems,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _status = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownSearch<String>(
                            compareFn: (a, b) => a == b,
                            selectedItem: _paymentMethod,
                            items: (filter, _) => _standardMethods,
                            popupProps: PopupProps.menu(
                              menuProps: MenuProps(
                                backgroundColor: Theme.of(context).canvasColor,
                              ),
                              showSearchBox: true,
                              searchFieldProps: const TextFieldProps(
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Cerca metodo...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                            dropdownBuilder: (context, selectedItem) => Text(
                              selectedItem ?? 'Metodo',
                              style: const TextStyle(color: Colors.white),
                            ),
                            decoratorProps: DropDownDecoratorProps(
                              decoration: InputDecoration(
                                labelText: 'Metodo',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                            onSelected: (String? val) {
                              if (val != null) {
                                setState(() => _paymentMethod = val);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    if (!widget.isReadOnly)
                      ElevatedButton.icon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Allega Foto/PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    if (_attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allegati:',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._attachments.asMap().entries.map((entry) {
                              final int idx = entry.key;
                              final String url = entry.value;
                              final String cleanName =
                                  AttachmentService.extractCleanFileName(url);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.attachment,
                                      color: Colors.blueAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _openAttachment(url),
                                        child: Text(
                                          cleanName.isNotEmpty
                                              ? cleanName
                                              : 'Apri Allegato ${idx + 1}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (url.startsWith('http://') ||
                                        url.startsWith('https://'))
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download,
                                          color: Colors.greenAccent,
                                          size: 24,
                                        ),
                                        tooltip: 'Scarica in locale',
                                        onPressed: () => _attachmentService
                                            .downloadAttachment(context, url),
                                      ),
                                    if (!widget.isReadOnly)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                          size: 24,
                                        ),
                                        onPressed: () =>
                                            _removeAttachmentAt(idx),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    IgnorePointer(
                      ignoring: widget.isReadOnly,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Titolo (opzionale)',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownSearch<Customer>(
                            compareFn: (Customer a, Customer b) => a.id == b.id,
                            selectedItem: selectedCustomer,
                            items: (filter, _) => _customers,
                            itemAsString: (Customer c) => c.name,
                            popupProps: PopupProps.menu(
                              menuProps: MenuProps(
                                backgroundColor: Theme.of(context).canvasColor,
                              ),
                              showSearchBox: true,
                              searchFieldProps: const TextFieldProps(
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Cerca cliente...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                            dropdownBuilder: (context, selectedItem) => Text(
                              selectedItem?.name ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            decoratorProps: DropDownDecoratorProps(
                              decoration: InputDecoration(
                                labelText: 'Cliente (Opzionale)',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                            onSelected: (Customer? val) {
                              setState(() {
                                _selectedCustomerId = val?.id;
                                if (val != null) {
                                  if (val.phone != null &&
                                      val.phone!.isNotEmpty) {
                                    _clientPhoneController.text = val.phone!;
                                  }
                                  if (val.email != null &&
                                      val.email!.isNotEmpty) {
                                    _clientEmailController.text = val.email!;
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _clientPhoneController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Cellulare Cliente',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _clientEmailController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email Cliente',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownSearch<Category>(
                            compareFn: (Category a, Category b) => a.id == b.id,
                            selectedItem: selectedCategory,
                            items: (filter, _) => _categories
                                .where((c) => c.type == _type)
                                .toList(),
                            itemAsString: (Category c) => c.name,
                            popupProps: PopupProps.menu(
                              menuProps: MenuProps(
                                backgroundColor: Theme.of(context).canvasColor,
                              ),
                              showSearchBox: true,
                              searchFieldProps: const TextFieldProps(
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Cerca categoria...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                            dropdownBuilder: (context, selectedItem) => Text(
                              selectedItem?.name ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            decoratorProps: DropDownDecoratorProps(
                              decoration: InputDecoration(
                                labelText: 'Categoria (Opzionale)',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                            onSelected: (Category? val) =>
                                setState(() => _selectedCategoryId = val?.id),
                          ),
                          const SizedBox(height: 16),
                          DropdownSearch<ServiceType>(
                            compareFn: (ServiceType a, ServiceType b) =>
                                a.id == b.id,
                            selectedItem: selectedService,
                            items: (filter, _) => _services,
                            itemAsString: (ServiceType s) => s.name,
                            popupProps: PopupProps.menu(
                              menuProps: MenuProps(
                                backgroundColor: Theme.of(context).canvasColor,
                              ),
                              showSearchBox: true,
                              searchFieldProps: const TextFieldProps(
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Cerca servizio...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                            dropdownBuilder: (context, selectedItem) => Text(
                              selectedItem?.name ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            decoratorProps: DropDownDecoratorProps(
                              decoration: InputDecoration(
                                labelText: 'Servizio (Opzionale)',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                            onSelected: (ServiceType? val) =>
                                setState(() => _selectedServiceId = val?.id),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _notesController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Descrizione evento (Opzionale)',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              hintText:
                                  'Es: Matrimonio Rossi, DJ set serata...',
                              hintStyle: const TextStyle(color: Colors.white24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!widget.isReadOnly)
                      ElevatedButton(
                        onPressed: _isSaving ? null : _savePayment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SALVA PAGAMENTO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
