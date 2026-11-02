import 'dart:convert';
import 'dart:io';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/attachment_service.dart';
import '../utils/calculation_engine.dart';
import '../utils/date_utils_app.dart';

class MemoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialMemo;
  final String? sourceTable;

  const MemoFormScreen({super.key, this.initialMemo, this.sourceTable});

  static const List<String> memoStatuses = [
    'IN ATTESA',
    'DA SOLLECITARE',
    'SALDATO',
  ];

  static const List<String> paymentMethods = [
    'Fattura',
    'Carta',
    'Bancomat',
    'Bonifico',
    'Assegno',
    'Contante',
  ];

  static const List<String> defaultVatCodes = [
    '22% (Ordinaria)',
    '10% (Agevolata)',
    '5% (Super agevolata)',
    '4% (Minima)',
    '0% (Esente)',
    '2.1 (Non soggetta - Art. 15)',
    '2.2 (Non soggetta - Altri casi)',
    'Reverse Charge (Inversione contabile)',
  ];

  static String normalizeMemoStatus(String? raw) {
    final s = (raw ?? '').trim().toUpperCase();
    if (s == 'SALDATO' ||
        s == 'SALDATA' ||
        s == 'PAGATO' ||
        s == 'PAGATA' ||
        s == 'PAID' ||
        s == 'INCASSATA' ||
        s == 'INCASSATO') {
      return 'SALDATO';
    }
    if (s == 'DA SOLLECITARE' ||
        s == 'SOLLECITARE' ||
        s == 'LATE' ||
        s == 'IN RITARDO') {
      return 'DA SOLLECITARE';
    }
    return 'IN ATTESA';
  }

  static String normalizePaymentMethod(String? raw) {
    final m = (raw ?? '').trim().toLowerCase();
    if (m.isEmpty) return 'Bonifico';
    if (m.contains('fattur')) return 'Fattura';
    if (m.contains('bancomat') || m.contains('debito')) return 'Bancomat';
    if (m.contains('carta') || m.contains('credit') || m.contains('pos')) {
      return 'Carta';
    }
    if (m.contains('bonifico')) return 'Bonifico';
    if (m.contains('assegn')) return 'Assegno';
    if (m.contains('contant') || m.contains('cash')) return 'Contante';
    return 'Bonifico';
  }

  static List<String> parseAttachments(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {
          final stripped = trimmed.substring(
            1,
            trimmed.endsWith(']') ? trimmed.length - 1 : trimmed.length,
          );
          return stripped
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
      return trimmed
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  State<MemoFormScreen> createState() => _MemoFormScreenState();
}

class _MemoFormScreenState extends State<MemoFormScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();

  bool _isUploading = false;
  bool _isSaving = false;
  List<String> _attachments = [];

  // Tipi principali
  String _memoType = 'MOVIMENTO'; // MOVIMENTO o FATTURA
  String _transactionType = 'ENTRATA'; // ENTRATA o USCITA
  String _dateType = 'SINGOLA'; // SINGOLA o RANGE
  String _memoStatus = 'IN ATTESA'; // IN ATTESA, DA SOLLECITARE, SALDATO

  // Dati relazionali
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];

  // Controllers & Selettori
  String? _customerId;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _fromDateCtrl = TextEditingController();
  final TextEditingController _toDateCtrl = TextEditingController();

  final TextEditingController _invoiceNumberCtrl = TextEditingController();
  final TextEditingController _invoiceDateCtrl = TextEditingController();

  final TextEditingController _clientPhoneCtrl = TextEditingController();
  final TextEditingController _clientEmailCtrl = TextEditingController();
  final TextEditingController _clientVatCtrl = TextEditingController();
  final TextEditingController _clientAddressCtrl = TextEditingController();
  final TextEditingController _clientSdiCtrl = TextEditingController();

  String _paymentMethod = 'Bonifico';
  String? _categoryId;
  String? _serviceId;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  late List<String> _availableVatCodes;
  String? _vatCode;

  @override
  void initState() {
    super.initState();
    _availableVatCodes = List<String>.from(MemoFormScreen.defaultVatCodes);
    _initFromInitialMemo();
    _loadData();
  }

  void _initFromInitialMemo() {
    if (widget.initialMemo == null) return;
    final m = widget.initialMemo!;

    if (widget.sourceTable == 'payments') {
      _memoType = 'MOVIMENTO';
      _transactionType =
          (m['type']?.toString().toUpperCase() == 'OUT') ? 'USCITA' : 'ENTRATA';
      _dateType =
          (m['date_to']?.toString().trim().isNotEmpty == true) ? 'RANGE' : 'SINGOLA';
      _memoStatus = CalculationEngine.isPaymentSettled(m)
          ? 'SALDATO'
          : MemoFormScreen.normalizeMemoStatus(m['status']?.toString());
      _titleCtrl.text =
          (m['title'] ?? m['description'])?.toString() ?? '';
      _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString());
      _fromDateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString());
      _toDateCtrl.text = DateUtilsApp.formatDbDate(m['date_to']?.toString());
      _customerId = (m['customer_id'] ?? m['client_id'])?.toString();
      _paymentMethod =
          MemoFormScreen.normalizePaymentMethod(m['payment_method']?.toString());
      _categoryId = m['category_id']?.toString();
      _serviceId = m['service_id']?.toString();
      _clientPhoneCtrl.text = m['client_phone']?.toString() ?? '';
      _clientEmailCtrl.text = m['client_email']?.toString() ?? '';
      _notesCtrl.text = m['notes']?.toString() ?? '';
      if (m['amount'] != null) {
        _amountCtrl.text = CurrencyUtils.formatNumber(
          CurrencyUtils.parseCurrency(m['amount'].toString()),
        );
      }
      _attachments = MemoFormScreen.parseAttachments(m['attachments']);
      return;
    }

    if (widget.sourceTable == 'invoices') {
      _memoType = 'FATTURA';
      _transactionType =
          (m['type']?.toString().toUpperCase() == 'OUT') ? 'USCITA' : 'ENTRATA';
      _dateType = 'SINGOLA';
      _memoStatus = CalculationEngine.isInvoiceSettled(m)
          ? 'SALDATO'
          : MemoFormScreen.normalizeMemoStatus(m['status']?.toString());
      _titleCtrl.text = m['title']?.toString() ?? '';
      _invoiceNumberCtrl.text = m['number']?.toString() ?? '';
      final rawInvDate =
          (m['invoice_date']?.toString().trim().isNotEmpty == true)
              ? m['invoice_date'].toString()
              : m['date']?.toString();
      _dateCtrl.text = DateUtilsApp.formatDbDate(
        m['event_date']?.toString().trim().isNotEmpty == true
            ? m['event_date'].toString()
            : rawInvDate,
      );
      _invoiceDateCtrl.text = DateUtilsApp.formatDbDate(rawInvDate);
      _customerId = (m['customer_id'] ?? m['client_id'])?.toString();
      _categoryId = m['category_id']?.toString();
      _serviceId = m['service_id']?.toString();
      _clientPhoneCtrl.text = m['client_phone']?.toString() ?? '';
      _clientEmailCtrl.text = m['client_email']?.toString() ?? '';
      _clientVatCtrl.text = m['client_vat']?.toString() ?? '';
      _clientAddressCtrl.text =
          (m['client_street'] ?? m['client_address'])?.toString() ?? '';
      _clientSdiCtrl.text = m['client_sdi']?.toString() ?? '';
      _setVatCode(m['vat_code']?.toString());
      _notesCtrl.text = m['notes']?.toString() ?? '';
      if (m['amount'] != null) {
        _amountCtrl.text = CurrencyUtils.formatNumber(
          CurrencyUtils.parseCurrency(m['amount'].toString()),
        );
      }
      _attachments = MemoFormScreen.parseAttachments(m['attachments']);
      return;
    }

    // Memo programmato standard (memo_events)
    _memoType = (m['memo_type']?.toString().toUpperCase() == 'FATTURA')
        ? 'FATTURA'
        : 'MOVIMENTO';
    _transactionType =
        (m['transaction_type']?.toString().toUpperCase() == 'USCITA')
            ? 'USCITA'
            : 'ENTRATA';
    _dateType =
        (m['date_type']?.toString().toUpperCase() == 'RANGE') ? 'RANGE' : 'SINGOLA';
    _memoStatus = MemoFormScreen.normalizeMemoStatus(
      (m['memo_status'] ?? m['status'])?.toString(),
    );

    _titleCtrl.text = m['title']?.toString() ?? '';

    _dateCtrl.text = DateUtilsApp.formatDbDate(m['date']?.toString());
    _fromDateCtrl.text = DateUtilsApp.formatDbDate(m['date_from']?.toString());
    _toDateCtrl.text = DateUtilsApp.formatDbDate(m['date_to']?.toString());

    _invoiceNumberCtrl.text =
        (m['invoice_number'] ?? m['number'])?.toString() ?? '';
    final rawInvoiceDate =
        (m['invoice_date']?.toString().trim().isNotEmpty == true)
            ? m['invoice_date'].toString()
            : m['date']?.toString();
    _invoiceDateCtrl.text = DateUtilsApp.formatDbDate(rawInvoiceDate);

    _customerId = (m['customer_id'] ?? m['client_id'])?.toString();
    _clientPhoneCtrl.text = m['client_phone']?.toString() ?? '';
    _clientEmailCtrl.text = m['client_email']?.toString() ?? '';
    _clientVatCtrl.text = m['client_vat']?.toString() ?? '';
    _clientAddressCtrl.text =
        (m['client_street'] ?? m['client_address'])?.toString() ?? '';
    _clientSdiCtrl.text = m['client_sdi']?.toString() ?? '';

    _paymentMethod =
        MemoFormScreen.normalizePaymentMethod(m['payment_method']?.toString());
    _categoryId = m['category_id']?.toString();
    _serviceId = m['service_id']?.toString();
    if (m['amount'] != null) {
      _amountCtrl.text = CurrencyUtils.formatNumber(
        CurrencyUtils.parseCurrency(m['amount'].toString()),
      );
    } else {
      _amountCtrl.text = '';
    }
    _notesCtrl.text = m['notes']?.toString() ?? '';
    _setVatCode(m['vat_code']?.toString());
    _attachments = MemoFormScreen.parseAttachments(m['attachments']);
  }

  void _setVatCode(String? rawVat) {
    final trimmed = rawVat?.trim() ?? '';
    if (trimmed.isEmpty) {
      _vatCode = null;
      return;
    }
    if (!_availableVatCodes.contains(trimmed)) {
      _availableVatCodes.insert(0, trimmed);
    }
    _vatCode = trimmed;
  }

  Future<void> _loadData() async {
    try {
      final customers = await _dbHelper.getCustomers();
      final services = await _dbHelper.getServiceTypes();
      final categories = await _dbHelper.getCategories();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _services = services;
        _categories = categories;

        if (_customerId != null &&
            !_customers.any((c) => c['id']?.toString() == _customerId)) {
          _customerId = null;
        }
        if (_serviceId != null &&
            !_services.any((s) => s['id']?.toString() == _serviceId)) {
          _serviceId = null;
        }
        if (_categoryId != null &&
            !_categories.any((c) => c['id']?.toString() == _categoryId)) {
          _categoryId = null;
        }
      });
    } catch (e) {
      debugPrint('Errore caricamento dati relazionali memo: $e');
    }
  }

  Future<void> _selectDate(TextEditingController ctrl) async {
    final theme = context.read<AppThemeProvider>();
    DateTime initial = DateUtilsApp.tryParseDate(ctrl.text) ?? DateTime.now();
    if (initial.isBefore(DateTime(2000))) initial = DateTime(2000);
    if (initial.isAfter(DateTime(2100))) initial = DateTime(2100);

    final picked = await GlassDatePicker.show(
      context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        ctrl.text = DateFormat(theme.dateFormat).format(picked);
      });
    }
  }

  Future<void> _pickAttachment(bool isCamera) async {
    if (_isUploading || _isSaving) return;
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

      if (file != null && mounted) {
        final String? url =
            await _attachmentService.uploadAttachment(file, 'memos');
        if (url != null && mounted) {
          setState(() {
            _attachments.add(url);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'allegato: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openAttachment(String pathOrUrl) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return;
    try {
      final isHttp =
          trimmed.startsWith('http://') || trimmed.startsWith('https://');
      if (!isHttp) {
        final f = File(trimmed);
        if (f.existsSync()) {
          await OpenFilex.open(f.path);
          return;
        }
      }
      final uri = Uri.tryParse(trimmed);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire l\'allegato')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore apertura allegato: $e')),
        );
      }
    }
  }

  String _lookupCustomerName(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final c in _customers) {
      if (c['id']?.toString() == id) {
        return c['name']?.toString() ?? '';
      }
    }
    return '';
  }

  Future<void> _saveMemo() async {
    if (_isSaving || _isUploading) return;

    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un titolo per il memo')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final theme = context.read<AppThemeProvider>();
    final dateFormat = theme.dateFormat;

    final parsedAmount = CurrencyUtils.parseCurrency(_amountCtrl.text);
    final dbSingleDate = DateUtilsApp.toDbDate(_dateCtrl.text, dateFormat);
    final dbFromDate = DateUtilsApp.toDbDate(_fromDateCtrl.text, dateFormat);
    final dbToDate = DateUtilsApp.toDbDate(_toDateCtrl.text, dateFormat);
    final rawInvoiceInput = _invoiceDateCtrl.text.trim().isNotEmpty
        ? _invoiceDateCtrl.text
        : _dateCtrl.text;
    final dbInvoiceDate = DateUtilsApp.toDbDate(rawInvoiceInput, dateFormat);
    final todayDb = DateUtilsApp.toDbDate(
      DateTime.now().toIso8601String(),
      dateFormat,
    );

    final normalizedMethod =
        MemoFormScreen.normalizePaymentMethod(_paymentMethod);
    final normalizedStatus = MemoFormScreen.normalizeMemoStatus(_memoStatus);
    final titleText = _titleCtrl.text.trim();
    final notesText = _notesCtrl.text.trim();
    final invNumber = _invoiceNumberCtrl.text.trim();
    final streetText = _clientAddressCtrl.text.trim();
    final custName = _lookupCustomerName(_customerId);

    final memoPayload = <String, dynamic>{
      'memo_type': _memoType,
      'transaction_type': _transactionType,
      'date_type': _dateType,
      'memo_status': normalizedStatus,
      'title': titleText,
      'date': _memoType == 'FATTURA' ? dbInvoiceDate : dbSingleDate,
      'date_from': dbFromDate,
      'date_to': dbToDate,
      'invoice_number': invNumber,
      'invoice_date': dbInvoiceDate,
      'customer_id': _customerId,
      'client_name': custName,
      'client_phone': _clientPhoneCtrl.text.trim(),
      'client_email': _clientEmailCtrl.text.trim(),
      'client_vat': _clientVatCtrl.text.trim(),
      'client_street': streetText,
      'client_address': streetText,
      'client_sdi': _clientSdiCtrl.text.trim(),
      'payment_method': normalizedMethod,
      'category_id': _categoryId,
      'service_id': _serviceId,
      'amount': parsedAmount,
      'notes': notesText,
      'vat_code': _vatCode,
      'attachments': List<String>.from(_attachments),
    };

    try {
      // Modifica diretta di un record esistente in payments o invoices
      if (widget.sourceTable == 'payments') {
        final effectivePayDate =
            (_dateType == 'RANGE' ? dbFromDate : dbSingleDate);
        final paymentData = <String, dynamic>{
          ...widget.initialMemo!,
          'id': widget.initialMemo!['id'],
          'type': _transactionType == 'USCITA' ? 'OUT' : 'IN',
          'amount': parsedAmount,
          'date': effectivePayDate.isNotEmpty ? effectivePayDate : todayDb,
          if (_dateType == 'RANGE' && dbToDate.isNotEmpty) 'date_to': dbToDate,
          'customer_id': _customerId,
          'category_id': _categoryId,
          'service_id': _serviceId,
          'payment_method': normalizedMethod,
          'title': titleText,
          'description': titleText,
          'notes': notesText,
          'client_phone': _clientPhoneCtrl.text.trim(),
          'client_email': _clientEmailCtrl.text.trim(),
          'status': normalizedStatus == 'SALDATO'
              ? 'PAID'
              : (normalizedStatus == 'DA SOLLECITARE' ? 'LATE' : 'PENDING'),
          'attachments': jsonEncode(_attachments),
        }..remove('client_id');
        await _dbHelper.updatePayment(paymentData);
        if (mounted) Navigator.maybePop(context, true);
        return;
      }

      if (widget.sourceTable == 'invoices') {
        final invoiceData = <String, dynamic>{
          ...widget.initialMemo!,
          'id': widget.initialMemo!['id'],
          'type': _transactionType == 'USCITA' ? 'OUT' : 'IN',
          'amount': parsedAmount,
          'date': dbInvoiceDate.isNotEmpty ? dbInvoiceDate : todayDb,
          'event_date': dbSingleDate,
          'status': normalizedStatus == 'SALDATO'
              ? 'PAID'
              : (normalizedStatus == 'DA SOLLECITARE' ? 'LATE' : 'PENDING'),
          'customer_id': _customerId,
          'category_id': _categoryId,
          'service_id': _serviceId,
          'number': invNumber,
          'notes': notesText,
          'title': titleText,
          'vat_code': _vatCode,
          if (custName.isNotEmpty) 'client_name': custName,
          'client_phone': _clientPhoneCtrl.text.trim(),
          'client_email': _clientEmailCtrl.text.trim(),
          'client_vat': _clientVatCtrl.text.trim(),
          'client_street': streetText,
          'client_address': streetText,
          'client_sdi': _clientSdiCtrl.text.trim(),
          'attachments': List<String>.from(_attachments),
        }..remove('client_id');
        await _dbHelper.updateInvoice(invoiceData);
        if (mounted) Navigator.maybePop(context, true);
        return;
      }

      // Stato SALDATO -> trasferimento atomico in Movimenti o Fatture
      if (normalizedStatus == 'SALDATO') {
        final isInvoice = _memoType == 'FATTURA';
        final Map<String, dynamic> targetData;

        if (isInvoice) {
          final finalInvDate =
              dbInvoiceDate.isNotEmpty ? dbInvoiceDate : todayDb;
          targetData = <String, dynamic>{
            'number': invNumber,
            'title': titleText,
            'type': _transactionType == 'USCITA' ? 'OUT' : 'IN',
            'amount': parsedAmount,
            'date': finalInvDate,
            'event_date': dbSingleDate.isNotEmpty ? dbSingleDate : finalInvDate,
            'status': 'PAID',
            'vat_code': _vatCode,
            'customer_id': _customerId,
            'category_id': _categoryId,
            'service_id': _serviceId,
            'client_name': custName,
            'client_phone': _clientPhoneCtrl.text.trim(),
            'client_email': _clientEmailCtrl.text.trim(),
            'client_vat': _clientVatCtrl.text.trim(),
            'client_street': streetText,
            'client_address': streetText,
            'client_sdi': _clientSdiCtrl.text.trim(),
            'notes': notesText,
            'attachments': List<String>.from(_attachments),
          };
        } else {
          final rawPayDate = _dateType == 'SINGOLA' ? dbSingleDate : dbFromDate;
          final finalPayDate = rawPayDate.isNotEmpty ? rawPayDate : todayDb;
          targetData = <String, dynamic>{
            'type': _transactionType == 'USCITA' ? 'OUT' : 'IN',
            'amount': parsedAmount,
            'date': finalPayDate,
            if (_dateType == 'RANGE' && dbToDate.isNotEmpty)
              'date_to': dbToDate,
            'event_dates': finalPayDate,
            'customer_id': _customerId,
            'category_id': _categoryId,
            'service_id': _serviceId,
            'payment_method': normalizedMethod,
            'notes': notesText,
            'title': titleText,
            'description': titleText,
            'client_phone': _clientPhoneCtrl.text.trim(),
            'client_email': _clientEmailCtrl.text.trim(),
            'attachments': jsonEncode(_attachments),
            'status': 'PAID',
          };
        }

        final existingMemoId = widget.initialMemo?['id']?.toString() ?? '';
        if (existingMemoId.isNotEmpty) {
          await _dbHelper.settleMemoEventAtomically(
            memoId: existingMemoId,
            isInvoice: isInvoice,
            targetData: targetData,
          );
        } else {
          if (isInvoice) {
            await _dbHelper.insertInvoice(targetData);
          } else {
            await _dbHelper.insertPayment(targetData);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pagamento saldato e trasferito in ${isInvoice ? 'Fatture' : 'Movimenti'}!',
              ),
            ),
          );
          await Navigator.maybePop(context, true);
        }
      } else {
        // Salvataggio in memo_events (IN ATTESA o DA SOLLECITARE)
        final existingMemoId = widget.initialMemo?['id']?.toString() ?? '';
        if (existingMemoId.isNotEmpty) {
          memoPayload['id'] = existingMemoId;
          await _dbHelper.updateMemoEvent(memoPayload);
        } else {
          await _dbHelper.insertMemoEvent(memoPayload);
        }
        if (mounted) {
          await Navigator.maybePop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
    final safeStatus = MemoFormScreen.normalizeMemoStatus(_memoStatus);
    final safeMethod = MemoFormScreen.normalizePaymentMethod(_paymentMethod);

    Map<String, dynamic>? selectedCustomer;
    if (_customerId != null) {
      for (final c in _customers) {
        if (c['id']?.toString() == _customerId) {
          selectedCustomer = c;
          break;
        }
      }
    }

    Map<String, dynamic>? selectedCategory;
    if (_categoryId != null) {
      for (final c in _categories) {
        if (c['id']?.toString() == _categoryId) {
          selectedCategory = c;
          break;
        }
      }
    }

    Map<String, dynamic>? selectedService;
    if (_serviceId != null) {
      for (final s in _services) {
        if (s['id']?.toString() == _serviceId) {
          selectedService = s;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.initialMemo != null
              ? 'Modifica Programmazione'
              : 'Nuova Programmazione',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: theme.backgroundMain,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo Documento
                    const Text(
                      'TIPO DOCUMENTO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      option1: 'MOVIMENTO',
                      option2: 'FATTURA',
                      selected: _memoType,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _memoType = val),
                    ),
                    const SizedBox(height: 16),

                    // Direzione
                    const Text(
                      'DIREZIONE TRANSAZIONE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      option1: 'ENTRATA',
                      option2: 'USCITA',
                      selected: _transactionType,
                      activeColor: _transactionType == 'ENTRATA'
                          ? Colors.teal
                          : Colors.deepOrangeAccent,
                      onChanged: (val) =>
                          setState(() => _transactionType = val),
                    ),
                    const SizedBox(height: 16),

                    // Stato
                    const Text(
                      'STATO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: safeStatus,
                      dropdownColor: theme.cardColor,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: MemoFormScreen.memoStatuses
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _memoStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Titolo
                    TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Titolo (visualizzato all\'esterno)',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data Section
                    if (_memoType == 'MOVIMENTO') ...[
                      const Text(
                        'TIPO DATA PAGAMENTO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildToggleRow(
                        option1: 'SINGOLA',
                        option2: 'RANGE',
                        selected: _dateType,
                        activeColor: Colors.purpleAccent,
                        onChanged: (val) => setState(() => _dateType = val),
                      ),
                      const SizedBox(height: 16),
                      if (_dateType == 'SINGOLA')
                        InkWell(
                          onTap: () => _selectDate(_dateCtrl),
                          child: IgnorePointer(
                            child: TextField(
                              controller: _dateCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Data Pagamento',
                                labelStyle: TextStyle(color: Colors.white54),
                                icon: Icon(
                                  Icons.calendar_today,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(_fromDateCtrl),
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _fromDateCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'Da data',
                                      labelStyle:
                                          TextStyle(color: Colors.white54),
                                      icon: Icon(
                                        Icons.calendar_today,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(_toDateCtrl),
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _toDateCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'A data',
                                      labelStyle:
                                          TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ] else ...[
                      // Se FATTURA
                      TextField(
                        controller: _invoiceNumberCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Numero Fattura',
                          labelStyle: TextStyle(color: Colors.white54),
                          icon: Icon(Icons.receipt, color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(_invoiceDateCtrl),
                        child: IgnorePointer(
                          child: TextField(
                            controller: _invoiceDateCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Data Fattura',
                              labelStyle: TextStyle(color: Colors.white54),
                              icon: Icon(
                                Icons.calendar_today,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownSearch<String>(
                        compareFn: (a, b) => a == b,
                        selectedItem: _vatCode,
                        items: (filter, _) => _availableVatCodes,
                        popupProps: const PopupProps.menu(
                          menuProps: MenuProps(
                            backgroundColor: Color(0xFF13132B),
                          ),
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cerca codice IVA...',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        decoratorProps: DropDownDecoratorProps(
                          baseStyle: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Codice IVA',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        onSelected: (val) => setState(() => _vatCode = val),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Cliente e Dati
                    const Text(
                      'DATI CLIENTE / CONTROPARTE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownSearch<Map<String, dynamic>>(
                      compareFn: (a, b) =>
                          a['id']?.toString() == b['id']?.toString(),
                      selectedItem: selectedCustomer,
                      items: (filter, _) => _customers,
                      itemAsString: (c) => c['name']?.toString() ?? '',
                      popupProps: const PopupProps.menu(
                        menuProps:
                            MenuProps(backgroundColor: Color(0xFF13132B)),
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
                        baseStyle: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Seleziona Cliente Esistente (Opzionale)',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      onSelected: (Map<String, dynamic>? c) {
                        setState(() {
                          _customerId = c?['id']?.toString();
                          if (c != null) {
                            if (c['phone'] != null) {
                              _clientPhoneCtrl.text = c['phone'].toString();
                            }
                            if (c['email'] != null) {
                              _clientEmailCtrl.text = c['email'].toString();
                            }
                            if (c['vat_number'] != null) {
                              _clientVatCtrl.text = c['vat_number'].toString();
                            }
                            final addr = c['address_street'] ?? c['address'];
                            if (addr != null) {
                              _clientAddressCtrl.text = addr.toString();
                            }
                            if (c['sdi_code'] != null) {
                              _clientSdiCtrl.text = c['sdi_code'].toString();
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _clientPhoneCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Cellulare',
                              labelStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _clientEmailCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_memoType == 'FATTURA') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _clientVatCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Partita IVA / CF',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _clientAddressCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo Completo',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _clientSdiCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Codice SDI / PEC',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Metodo, Categoria, Servizio
                    DropdownSearch<String>(
                      compareFn: (a, b) => a == b,
                      selectedItem: safeMethod,
                      items: (filter, _) => MemoFormScreen.paymentMethods,
                      popupProps: const PopupProps.menu(
                        menuProps:
                            MenuProps(backgroundColor: Color(0xFF13132B)),
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
                        baseStyle: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Metodo di Pagamento',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      onSelected: (val) {
                        if (val != null) {
                          setState(() => _paymentMethod = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<Map<String, dynamic>>(
                      compareFn: (a, b) =>
                          a['id']?.toString() == b['id']?.toString(),
                      selectedItem: selectedCategory,
                      items: (filter, _) => _categories,
                      itemAsString: (c) => c['name']?.toString() ?? '',
                      popupProps: const PopupProps.menu(
                        menuProps:
                            MenuProps(backgroundColor: Color(0xFF13132B)),
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
                        baseStyle: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      onSelected: (Map<String, dynamic>? cat) {
                        setState(() => _categoryId = cat?['id']?.toString());
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<Map<String, dynamic>>(
                      compareFn: (a, b) =>
                          a['id']?.toString() == b['id']?.toString(),
                      selectedItem: selectedService,
                      items: (filter, _) => _services,
                      itemAsString: (s) => s['name']?.toString() ?? '',
                      popupProps: const PopupProps.menu(
                        menuProps:
                            MenuProps(backgroundColor: Color(0xFF13132B)),
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
                        baseStyle: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tipo Servizio',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      onSelected: (Map<String, dynamic>? srv) {
                        setState(() => _serviceId = srv?['id']?.toString());
                      },
                    ),
                    const SizedBox(height: 24),

                    // Importo e Note
                    TextField(
                      controller: _amountCtrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Importo',
                        prefixText: '€ ',
                        prefixStyle:
                            TextStyle(color: Colors.white, fontSize: 24),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Allegati
                    const Text(
                      'ALLEGATI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_attachments.isNotEmpty)
                      ..._attachments.asMap().entries.map((entry) {
                        final int idx = entry.key;
                        final String url = entry.value;
                        final fileName =
                            AttachmentService.extractCleanFileName(url);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attachment,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _openAttachment(url),
                                  child: Text(
                                    fileName.isNotEmpty
                                        ? fileName
                                        : 'Allegato ${idx + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : () => setState(
                                          () => _attachments.removeAt(idx),
                                        ),
                              ),
                            ],
                          ),
                        );
                      }),
                    if (_isUploading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (Platform.isAndroid || Platform.isIOS)
                          IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white54,
                            ),
                            onPressed: (_isUploading || _isSaving)
                                ? null
                                : () => _pickAttachment(true),
                          ),
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.white54),
                          onPressed: (_isUploading || _isSaving)
                              ? null
                              : () => _pickAttachment(false),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            (_isUploading || _isSaving) ? null : _saveMemo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Salva',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
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
