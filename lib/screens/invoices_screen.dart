import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/screens/invoice_summary_screen.dart';
import 'memo_form_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/attachment_service.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import '../utils/currency_utils.dart';
import '../widgets/gradient_scaffold.dart';
import '../utils/security_utils.dart';
import '../utils/date_utils_app.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/custom_text_field.dart';
import '../utils/date_picker_util.dart';
import '../utils/url_launcher_util.dart';


class InvoicesScreen extends StatefulWidget {
  final bool openDialog;
  const InvoicesScreen({super.key, this.openDialog = false});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.openDialog) _showInvoiceDialog();
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final invoices = await _dbHelper.getInvoices();
    final customers = await _dbHelper.getCustomers();

    invoices.sort((a, b) {
      // Prioritize status: LATE > PENDING > PAID
      int pA = a['status'] == 'LATE' ? 1 : a['status'] == 'PAID' ? 3 : 2;
      int pB = b['status'] == 'LATE' ? 1 : b['status'] == 'PAID' ? 3 : 2;

      if (pA != pB) return pA.compareTo(pB);

      // Natural sort by number (e.g. "FPR 1/26" before "FPR 10/26")
      String numStrA = a['number']?.toString() ?? '';
      String numStrB = b['number']?.toString() ?? '';
      final matchA = RegExp(r'\d+').firstMatch(numStrA);
      final matchB = RegExp(r'\d+').firstMatch(numStrB);
      
      int numA = matchA != null ? int.parse(matchA.group(0)!) : 0;
      int numB = matchB != null ? int.parse(matchB.group(0)!) : 0;
      
      return numA.compareTo(numB);
    });

    setState(() {
      _invoices = invoices;
      _customers = customers;
      _isLoading = false;
    });
  }



  void _showInvoiceDialog({Map<String, dynamic>? invoice, bool isReadOnly = false}) {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final dateFormat = theme.dateFormat;
    
    final numberCtrl = TextEditingController(text: invoice?['number']?.toString() ?? '');
    final amountCtrl = TextEditingController(text: invoice?['amount']?.toString() ?? '');
    final dateCtrl = TextEditingController(
      text: DateUtilsApp.formatDbDate(invoice?['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first, dateFormat)
    );
    final noteCtrl = TextEditingController(text: invoice?['notes']?.toString() ?? '');
    final eventDateCtrl = TextEditingController(text: DateUtilsApp.formatDbDate(invoice?['event_date']?.toString(), dateFormat));
    final titleCtrl = TextEditingController(text: invoice?['title']?.toString() ?? '');
    final clientPhoneCtrl = TextEditingController(text: invoice?['client_phone']?.toString() ?? '');
    final clientEmailCtrl = TextEditingController(text: invoice?['client_email']?.toString() ?? '');
    final clientVatCtrl = TextEditingController(text: invoice?['client_vat']?.toString() ?? '');
    final clientTaxCodeCtrl = TextEditingController(text: invoice?['client_tax_code']?.toString() ?? '');
    final clientAddressCtrl = TextEditingController(text: invoice?['client_address']?.toString() ?? '');
    final clientCityCtrl = TextEditingController(text: invoice?['client_city']?.toString() ?? '');
    final clientProvinceCtrl = TextEditingController(text: invoice?['client_province']?.toString() ?? '');
    final clientZipCtrl = TextEditingController(text: invoice?['client_zip']?.toString() ?? '');
    final clientSdiCtrl = TextEditingController(text: invoice?['client_sdi']?.toString() ?? '');
    final clientPecCtrl = TextEditingController(text: invoice?['client_pec']?.toString() ?? '');

    String status = invoice?['status']?.toString() ?? 'PENDING';
    String? customerId = invoice?['customer_id']?.toString();
    String? vatCode = invoice?['vat_code']?.toString();

    // Ensure customerId exists in current list
    if (customerId != null && !_customers.any((c) => c['id'].toString() == customerId)) {
      customerId = null;
    }
    // Ensure vatCode exists in current list
    if (vatCode != null && !_vatCodes.contains(vatCode)) {
      vatCode = null;
    }

    List<String> attachments = [];
    if (invoice != null && invoice['attachments'] != null) {
      attachments = List<String>.from(invoice['attachments']);
    }

    bool isUploading = false;
    // Tracks auto-saved invoice ID when user adds attachments before pressing Save
    String? autoSavedInvoiceId;

    // Persists invoice+attachments immediately so photo is never lost
    Future<void> persistInvoiceAttachments(StateSetter setSt) async {
      final effectiveId = invoice?['id']?.toString() ?? autoSavedInvoiceId;
      final data = <String, dynamic>{
        'number': numberCtrl.text,
        'amount': double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'status': status,
        'date': DateUtilsApp.toDbDate(dateCtrl.text, dateFormat),
        'customer_id': customerId,
        'notes': noteCtrl.text,
        'event_date': DateUtilsApp.toDbDate(eventDateCtrl.text, dateFormat),
        'vat_code': vatCode,
        'title': titleCtrl.text,
        'client_phone': clientPhoneCtrl.text,
        'client_email': clientEmailCtrl.text,
        'client_vat': clientVatCtrl.text,
        'client_tax_code': clientTaxCodeCtrl.text,
        'client_address': clientAddressCtrl.text,
        'client_city': clientCityCtrl.text,
        'client_province': clientProvinceCtrl.text,
        'client_zip': clientZipCtrl.text,
        'client_sdi': clientSdiCtrl.text,
        'client_pec': clientPecCtrl.text,
        'attachments': attachments,
      };
      if (effectiveId != null) {
        data['id'] = effectiveId;
        await _dbHelper.updateInvoice(data);
      } else {
        final newId = await _dbHelper.insertInvoice(data);
        autoSavedInvoiceId = newId;
      }
      _loadData();
    }


    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Text(
              invoice == null ? 'Nuova Fattura' : 'Modifica Fattura',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  ignoring: isReadOnly,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(controller: numberCtrl, labelText: 'Numero Fattura (es. FPA 2/26)'),
                      SizedBox(height: 12),
                      CustomTextField(controller: titleCtrl, labelText: 'Titolo (opzionale)'),
                      SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          if (!isReadOnly) DatePickerUtil.selectDate(context, dateCtrl);
                        },
                        child: IgnorePointer(
                          child: CustomTextField(controller: dateCtrl, labelText: 'Data Fattura (gg/mm/aaaa)'),
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownSearch<Map<String, dynamic>>(
                        compareFn: (Map<String, dynamic> a, Map<String, dynamic> b) => a['id'] == b['id'],
                        selectedItem: customerId != null 
                          ? _customers.firstWhere((c) => c['id'].toString() == customerId, orElse: () => {'id': '', 'name': 'Sconosciuto'})
                          : null,
                        items: (filter, _) => _customers,
                        itemAsString: (Map<String, dynamic> c) => c['name'] ?? '',
                        popupProps: PopupProps.menu(menuProps: MenuProps(backgroundColor: Theme.of(context).canvasColor), 
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cerca cliente...',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        dropdownBuilder: (context, selectedItem) => Text(
                          selectedItem?['name'] ?? 'Seleziona Cliente',
                          style: TextStyle(color: Colors.white),
                        ),
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: 'Cliente',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                          ),
                        ),
                        onSelected: isReadOnly ? null : (Map<String, dynamic>? val) {
                          setStateBuilder(() {
                            customerId = val?['id']?.toString();
                            if (val != null) {
                              if (val['phone'] != null) clientPhoneCtrl.text = val['phone'].toString();
                              if (val['email'] != null) clientEmailCtrl.text = val['email'].toString();
                              if (val['vat_number'] != null) clientVatCtrl.text = val['vat_number'].toString();
                              if (val['tax_code'] != null) clientTaxCodeCtrl.text = val['tax_code'].toString();
                              if (val['address_street'] != null) clientAddressCtrl.text = val['address_street'].toString();
                              if (val['address_city'] != null) clientCityCtrl.text = val['address_city'].toString();
                              if (val['address_province'] != null) clientProvinceCtrl.text = val['address_province'].toString();
                              if (val['address_zip'] != null) clientZipCtrl.text = val['address_zip'].toString();
                              if (val['sdi_code'] != null) clientSdiCtrl.text = val['sdi_code'].toString();
                              if (val['pec'] != null) clientPecCtrl.text = val['pec'].toString();
                            }
                          });
                        },
                      ),
                      SizedBox(height: 12),
                      CustomTextField(controller: clientPhoneCtrl, labelText: 'Cellulare Cliente'),
                      SizedBox(height: 12),
                      CustomTextField(controller: clientEmailCtrl, labelText: 'Email Cliente'),
                      SizedBox(height: 12),
                      ExpansionTile(
                        title: Text('Dati Anagrafici Cliente', style: TextStyle(color: Colors.white)),
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white,
                        childrenPadding: EdgeInsets.all(8),
                        children: [
                          TextField(controller: clientVatCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Partita IVA', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)))),
                          SizedBox(height: 8),
                          TextField(controller: clientTaxCodeCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Codice Fiscale', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)))),
                          SizedBox(height: 8),
                          TextField(controller: clientAddressCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Indirizzo', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)))),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(flex: 2, child: TextField(controller: clientCityCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'CittÃ ', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54))))),
                              SizedBox(width: 8),
                              Expanded(flex: 1, child: TextField(controller: clientProvinceCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Provincia', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54))))),
                              SizedBox(width: 8),
                              Expanded(flex: 1, child: TextField(controller: clientZipCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'CAP', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54))))),
                            ],
                          ),
                          SizedBox(height: 8),
                          TextField(controller: clientSdiCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Codice SDI', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)))),
                          SizedBox(height: 8),
                          TextField(controller: clientPecCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'PEC', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)))),
                        ],
                      ),
                      SizedBox(height: 12),
                      CustomTextField(controller: amountCtrl, labelText: '€  Importo', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      SizedBox(height: 16),
                      DropdownSearch<String>(
                        compareFn: (a, b) => a == b,
                        selectedItem: status,
                        items: (filter, _) => ['PENDING', 'PAID', 'LATE'],
                        itemAsString: (String item) {
                          switch(item) {
                            case 'PENDING': return 'Da Incassare';
                            case 'PAID': return 'Incassata';
                            case 'LATE': return 'In Ritardo';
                            default: return item;
                          }
                        },
                        popupProps: PopupProps.menu(menuProps: MenuProps(backgroundColor: Theme.of(context).canvasColor), 
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cerca stato...',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        dropdownBuilder: (context, selectedItem) {
                          String label = selectedItem ?? 'PENDING';
                          switch(selectedItem) {
                            case 'PENDING': label = 'Da Incassare'; break;
                            case 'PAID': label = 'Incassata'; break;
                            case 'LATE': label = 'In Ritardo'; break;
                          }
                          return Text(label, style: TextStyle(color: Colors.white));
                        },
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: 'Stato',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                          ),
                        ),
                        onSelected: isReadOnly ? null : (val) => setStateBuilder(() => status = val ?? 'PENDING'),
                      ),
                      SizedBox(height: 12),
                      DropdownSearch<String>(
                        compareFn: (a, b) => a == b,
                        selectedItem: vatCode,
                        items: (filter, _) => _vatCodes,
                        popupProps: PopupProps.menu(menuProps: MenuProps(backgroundColor: Theme.of(context).canvasColor), 
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cerca codice IVA...',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                        dropdownBuilder: (context, selectedItem) => Text(
                          selectedItem ?? '',
                          style: TextStyle(color: Colors.white),
                        ),
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: 'Codice IVA',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                          ),
                        ),
                        onSelected: isReadOnly ? null : (val) => setStateBuilder(() => vatCode = val),
                      ),
                      SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          if (!isReadOnly) DatePickerUtil.selectDate(context, eventDateCtrl);
                        },
                        child: IgnorePointer(
                          child: CustomTextField(controller: eventDateCtrl, labelText: 'Data Evento (opzionale)'),
                        ),
                      ),
                      SizedBox(height: 12),
                      CustomTextField(controller: noteCtrl, labelText: 'Note Evento', maxLines: 3),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text('Allegati (Foto/File)',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                SizedBox(height: 8),
                if (attachments.isNotEmpty)
                  ...attachments.asMap().entries.map((entry) {
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
                              onTap: () => UrlLauncherUtil.launchCustomUrl(context, url),
                              child: Text(
                                'Allegato ${idx + 1}',
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: isReadOnly ? null : () {
                              setStateBuilder(() {
                                attachments.removeAt(idx);
                              });
                              if (invoice != null) {
                                final data = Map<String, dynamic>.from(invoice);
                                data['attachments'] = attachments;
                                _dbHelper.updateInvoice(data);
                                _loadData();
                              }
                            },
                          )
                        ],
                      ),
                    );
                  }),
                if (isUploading)
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Colors.blueAccent)),
                  ),
                SizedBox(height: 8),
                if (!isReadOnly)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (Platform.isAndroid || Platform.isIOS)
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.white.withValues(alpha: 0.54)),
                          onPressed: () async {
                            final file = await _attachmentService.pickImageFromCamera(context);
                            if (file != null) {
                              setStateBuilder(() => isUploading = true);
                              final url = await _attachmentService.uploadAttachment(
                                  file, 'attachments/invoices');
                              if (url != null) {
                                setStateBuilder(() => attachments.add(url));
                                await persistInvoiceAttachments(setStateBuilder);
                              }
                              setStateBuilder(() => isUploading = false);
                            }
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.image, color: Colors.white.withValues(alpha: 0.54)),
                        onPressed: () async {
                          final file = await _attachmentService.pickFile(context);
                          if (file != null) {
                            setStateBuilder(() => isUploading = true);
                            final url = await _attachmentService.uploadAttachment(
                                file, 'attachments/invoices');
                            if (url != null) {
                              setStateBuilder(() => attachments.add(url));
                              await persistInvoiceAttachments(setStateBuilder);
                            }
                            setStateBuilder(() => isUploading = false);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annulla')),
            if (!isReadOnly)
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        final effectiveId = invoice?['id']?.toString() ?? autoSavedInvoiceId;
                        final data = {
                          'id': effectiveId,
                          'number': numberCtrl.text,
                          'amount': double.tryParse(
                                  amountCtrl.text.replaceAll(',', '.')) ??
                              0.0,
                          'status': status,
                          'date': DateUtilsApp.toDbDate(dateCtrl.text, dateFormat),
                          'customer_id': customerId,
                          'notes': noteCtrl.text,
                          'event_date': DateUtilsApp.toDbDate(eventDateCtrl.text, dateFormat),
                          'vat_code': vatCode,
                          'attachments': attachments,
                        };
                        if (effectiveId == null) {
                          await _dbHelper.insertInvoice(data);
                        } else {
                          await _dbHelper.updateInvoice(data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                      },
                child: Text('Salva'),
              )
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _getCustomer(String? id) {
    if (id == null) return null;
    try {
      return _customers.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }

  // ---- Filtri / ordinamento ----
  String _statusFilter = 'Tutte';
  DateTimeRange? _dateRange;
  String _sortMode = 'Data Piu Recente';

  List<Map<String, dynamic>> get _filteredInvoices {
    var list = _invoices.where((i) {
      final st = i['status']?.toString();
      if (_statusFilter == 'Da Incassare' && st == 'PAID') return false;
      if (_statusFilter == 'Incassata' && st != 'PAID') return false;
      if (_dateRange != null) {
        final d = i['date']?.toString();
        if (d != null && d.isNotEmpty && !ReportUtils.isDateInRange(d, _dateRange!)) return false;
      }
      return true;
    }).toList();
    int numOf(Map<String, dynamic> i) {
      final m = RegExp(r'\d+').firstMatch(i['number']?.toString() ?? '');
      return m != null ? int.parse(m.group(0)!) : 0;
    }
    list.sort((x, y) {
      switch (_sortMode) {
        case 'Numero (Crescente)':
          return numOf(x).compareTo(numOf(y));
        case 'Numero (Decrescente)':
          return numOf(y).compareTo(numOf(x));
        case 'Data Meno Recente':
          return (x['date']?.toString() ?? '').compareTo(y['date']?.toString() ?? '');
        default:
          return (y['date']?.toString() ?? '').compareTo(x['date']?.toString() ?? '');
      }
    });
    return list;
  }

  Future<void> _pickDateFilter() async {
    final range = await ReportUtils.showDateRangeFilterDialog(context);
    if (!mounted || range == null) return;
    setState(() => _dateRange = range);
  }

  Future<void> _exportPdfReport(List<Map<String, dynamic>> items, String dateFormat) async {
    if (items.isEmpty) return;
    final data = items.map<List<String>>((i) {
      final c = _getCustomer(i['customer_id']?.toString());
      final amount = double.tryParse(i['amount']?.toString() ?? '0') ?? 0;
      final st = i['status']?.toString();
      return [
        i['number']?.toString() ?? '-',
        c?['name']?.toString() ?? 'Sconosciuto',
        DateUtilsApp.formatDbDate(i['date']?.toString(), dateFormat),
        CurrencyUtils.formatEuro(amount),
        st == 'PAID' ? 'Incassata' : st == 'LATE' ? 'In Ritardo' : 'Da Incassare',
      ];
    }).toList();
    await PDFReportService.generateAndDownloadReport(
      title: 'Report Fatture',
      headers: ['Numero', 'Cliente', 'Data', 'Importo', 'Stato'],
      data: data,
      dateRangeText: _dateRange == null ? 'Tutte le date' : ReportUtils.formatDateRangeText(_dateRange!, dateFormat),
      dateFormatString: dateFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final filtered = _filteredInvoices;
    final total = filtered.fold<double>(0.0, (sum, i) => sum + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0));

    return GradientScaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
        floating: true,
        snap: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Fatture',
          style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: _dateRange == null ? const Color(0xFF38BDF8) : const Color(0xFFEC4899), size: 22),
            tooltip: 'Filtra per data',
            onPressed: _pickDateFilter,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.white70, size: 20),
              tooltip: 'Rimuovi filtro data',
              onPressed: () => setState(() => _dateRange = null),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Ordina',
            color: const Color(0xFF16192B),
            onSelected: (val) => setState(() => _sortMode = val),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Numero (Decrescente)', child: Text('Numero (Decrescente)', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'Numero (Crescente)', child: Text('Numero (Crescente)', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'Data Piu Recente', child: Text('Data Più Recente', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'Data Meno Recente', child: Text('Data Meno Recente', style: TextStyle(color: Colors.white))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Esporta Report PDF',
            onPressed: () => _exportPdfReport(filtered, theme.dateFormat),
          ),
          const SizedBox(width: 8),
        ],
      ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Tutte', 'Da Incassare', 'Incassata'].map((f) {
                      final sel = _statusFilter == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: sel,
                        onSelected: (_) => setState(() => _statusFilter = f),
                        selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                        backgroundColor: const Color(0xFF16192B),
                        labelStyle: TextStyle(color: sel ? const Color(0xFF38BDF8) : Colors.white70, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${filtered.length} fatture', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                        Text(CurrencyUtils.formatEuro(total), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text('Nessuna fattura trovata', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16))),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildInvoiceRow(filtered[index], theme.dateFormat),
                    ),
                ],
              ),
            ),
                ),
              ],
            ),
    );
  }

  Future<void> _toggleInvoiceStatus(Map<String, dynamic> i) async {
    final isPaid = i['status'] == 'PAID';
    final newStatus = isPaid ? 'PENDING' : 'PAID';

    try {
      final updatedData = Map<String, dynamic>.from(i);
      updatedData['status'] = newStatus;
      await _dbHelper.updateInvoice(updatedData);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: ')));
      }
    }
  }

  Widget _buildInvoiceRow(Map<String, dynamic> invoice, String dateFormat) {
    final isPaid = invoice['status'] == 'PAID';
    final isLate = invoice['status'] == 'LATE';
    final color = isPaid ? const Color(0xFF10B981) : isLate ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final amountVal = double.tryParse(invoice['amount']?.toString() ?? '0') ?? 0;
    
    final invoiceId = invoice['number']?.toString() ?? '-';
    final clientName = _getCustomer(invoice['customer_id']?.toString())?['name'] ?? 'Cliente Generico';
    
    return Material(
      color: const Color(0xFF13141F).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoiceSummaryScreen(invoiceId: invoice['id'])),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fattura ', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(clientName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(DateUtilsApp.formatDbDate(invoice['date']?.toString(), dateFormat), maxLines: 1,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyUtils.formatEuro(amountVal),
                      style: TextStyle(color: const Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _toggleInvoiceStatus(invoice),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 1.2),
                      ),
                      child: Text(isPaid ? 'Saldato' : isLate ? 'In Ritardo' : 'Da Incassare',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 20),
                onPressed: () async {
                  final authorized = await SecurityUtils.requireAdminAuth(context);
                  if (authorized && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MemoFormScreen(initialMemo: invoice, sourceTable: 'invoices'))).then((_) => _loadData());
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEC4899), size: 20),
                onPressed: () async {
                  final authorized = await SecurityUtils.requireAdminAuth(context);
                  if (authorized && mounted) {
                    await _dbHelper.deleteInvoice(invoice['id']);
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerSearchDialog(String? currentId, Function(String) onSelected) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            final filtered = _customers.where((c) {
              final name = c['name']?.toString().toLowerCase() ?? '';
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2C),
              title: Text('Seleziona Cliente', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Cerca per nome...',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.54)),
                      ),
                      onChanged: (val) {
                        setStateBuilder(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return ListTile(
                            title: Text(c['name'] ?? 'Sconosciuto', style: TextStyle(color: Colors.white)),
                            trailing: c['id'].toString() == currentId ? Icon(Icons.check, color: Colors.greenAccent) : null,
                            onTap: () {
                              onSelected(c['id'].toString());
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Chiudi modale ricerca
                        _showAddCustomerQuick(onSelected); // Apri inserimento rapido
                      },
                      icon: Icon(Icons.person_add),
                      label: Text('Aggiungi nuovo cliente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annulla', style: TextStyle(color: Colors.white.withValues(alpha: 0.54))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCustomerQuick(Function(String) onAdded) {
    final nameCtrl = TextEditingController();
    final vatCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Text('Aggiungi Cliente', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ragione Sociale / Nome',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: vatCtrl,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Partita IVA / Codice Fiscale',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: Colors.white.withValues(alpha: 0.54))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final newId = await _dbHelper.insertCustomer({
                  'name': nameCtrl.text.trim(),
                  'vat_number': vatCtrl.text.trim(),
                  'email': '',
                  'phone': '',
                  'address': '',
                });
                await _loadData();
                onAdded(newId.toString());
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              child: Text('Salva'),
            ),
          ],
        );
      },
    );
  }
}





