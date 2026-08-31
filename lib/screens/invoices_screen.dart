import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/screens/invoice_summary_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/attachment_service.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import '../utils/security_utils.dart';
import '../utils/date_utils_app.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final dateFormat = theme.dateFormat;
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateFormat(dateFormat).parseStrict(controller.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E24),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat(dateFormat).format(picked);
    }
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
                      TextField(
                        controller: numberCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                            labelText: 'Numero Fattura (es. FPA 2/26)',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                            labelText: 'Titolo (opzionale)',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                      ),
                      SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          if (!isReadOnly) _selectDate(context, dateCtrl);
                        },
                        child: IgnorePointer(
                          child: TextField(
                            controller: dateCtrl,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                labelText: 'Data Fattura (gg/mm/aaaa)',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownSearch<Map<String, dynamic>>(
                        selectedItem: customerId != null 
                          ? _customers.firstWhere((c) => c['id'].toString() == customerId, orElse: () => {'id': '', 'name': 'Sconosciuto'})
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
                        dropdownBuilder: (context, selectedItem) => Text(
                          selectedItem?['name'] ?? 'Seleziona Cliente',
                          style: TextStyle(color: Colors.white),
                        ),
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: 'Cliente',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
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
                      TextField(
                        controller: clientPhoneCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                            labelText: 'Cellulare Cliente',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: clientEmailCtrl,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                            labelText: 'Email Cliente',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                      ),
                      SizedBox(height: 12),
                      ExpansionTile(
                        title: Text('Dati Anagrafici Cliente', style: TextStyle(color: Colors.white)),
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white,
                        childrenPadding: EdgeInsets.all(8),
                        children: [
                          TextField(controller: clientVatCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Partita IVA', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)))),
                          SizedBox(height: 8),
                          TextField(controller: clientTaxCodeCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Codice Fiscale', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)))),
                          SizedBox(height: 8),
                          TextField(controller: clientAddressCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Indirizzo', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)))),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(flex: 2, child: TextField(controller: clientCityCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Città', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))))),
                              SizedBox(width: 8),
                              Expanded(flex: 1, child: TextField(controller: clientProvinceCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Provincia', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))))),
                              SizedBox(width: 8),
                              Expanded(flex: 1, child: TextField(controller: clientZipCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'CAP', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))))),
                            ],
                          ),
                          SizedBox(height: 8),
                          TextField(controller: clientSdiCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Codice SDI', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)))),
                          SizedBox(height: 8),
                          TextField(controller: clientPecCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'PEC', labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)))),
                        ],
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        style: TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                            labelText: 'Importo',
                            prefixText: '€ ',
                            prefixStyle: TextStyle(color: Colors.white),
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                      ),
                      SizedBox(height: 16),
                      DropdownSearch<String>(
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
                        popupProps: PopupProps.menu(menuProps: const MenuProps(backgroundColor: Color(0xFF2A2D34)), 
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Cerca stato...',
                              hintStyle: TextStyle(color: Colors.black54),
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
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                          ),
                        ),
                        onSelected: isReadOnly ? null : (val) => setStateBuilder(() => status = val ?? 'PENDING'),
                      ),
                      SizedBox(height: 12),
                      DropdownSearch<String>(
                        selectedItem: vatCode,
                        items: (filter, _) => _vatCodes,
                        popupProps: PopupProps.menu(menuProps: const MenuProps(backgroundColor: Color(0xFF2A2D34)), 
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Cerca codice IVA...',
                              hintStyle: TextStyle(color: Colors.black54),
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
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                          ),
                        ),
                        onSelected: isReadOnly ? null : (val) => setStateBuilder(() => vatCode = val),
                      ),
                      SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          if (!isReadOnly) _selectDate(context, eventDateCtrl);
                        },
                        child: IgnorePointer(
                          child: TextField(
                            controller: eventDateCtrl,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                                labelText: 'Data Evento (opzionale)',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        style: TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: 'Note Evento',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.54))),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text('Allegati (Foto/File)',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
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
                              onTap: () => _launchUrl(url),
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
                          icon: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.54)),
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
                        icon: Icon(Icons.image, color: Colors.white.withOpacity(0.54)),
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
            },
          ),
        ),
        title: Text('Fatture', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: Colors.blueAccent),
            tooltip: 'Esporta in PDF',
            onPressed: () async {
              if (_invoices.isEmpty) return;

              final range = await ReportUtils.showDateRangeFilterDialog(context);
              if (range == null) return;

              final filteredInvoices = _invoices.where((i) {
                final date = i['date'] as String?;
                if (date == null || date.isEmpty) return true;
                return ReportUtils.isDateInRange(date, range);
              }).toList();

              if (filteredInvoices.isEmpty) {
                if (mounted) {
                  final snackCtx = context;
                  ScaffoldMessenger.of(snackCtx).showSnackBar(
                    const SnackBar(content: Text('Nessuna fattura nel periodo selezionato.')),
                  );
                }
                return;
              }

              final List<List<String>> data = filteredInvoices.map<List<String>>((i) {
                final date = DateUtilsApp.formatDbDate(i['date']?.toString(), theme.dateFormat);
                final num = i['number']?.toString() ?? '-';
                final amount = '${double.tryParse(i['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} €';
                final status = i['status'] == 'PAID' ? 'INC' : i['status'] == 'LATE' ? 'RIT' : 'DA_INC';
                
                final customer = _getCustomer(i['customer_id']?.toString());
                final customerName = customer?['name'] ?? 'Sconosciuto';
                
                return [customerName, num, date, amount, status];
              }).toList();
              
              await PDFReportService.generateAndDownloadReport(
                title: 'Fatture',
                headers: ['Cliente', 'Descrizione (Num.)', 'Dt.', 'Imp.', 'St.'],
                data: data,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FixedColumnWidth(55),
                  3: const pw.FixedColumnWidth(55),
                  4: const pw.FixedColumnWidth(45),
                },
                dateRangeText: ReportUtils.formatDateRangeText(range, theme.dateFormat),
                dateFormatString: theme.dateFormat,
                landscape: true,
                legend: {
                  'Dt.': 'Data',
                  'Imp.': 'Importo',
                  'St.': 'Stato (INC=Incassata, RIT=In Ritardo, DA_INC=Da Incassare)',
                }
              );
            },
          ),
          IconButton(
              icon: Icon(Icons.add, color: Colors.blueAccent),
              onPressed: () => _showInvoiceDialog())
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _invoices.length,
              itemBuilder: (context, index) {
                final invoice = _invoices[index];
                List<String> attachments = [];
                if (invoice['attachments'] != null) {
                  attachments = List<String>.from(invoice['attachments']);
                }

                final customer = _getCustomer(invoice['customer_id']?.toString());
                final customerName = customer?['name'] ?? 'Cliente Sconosciuto';
                // Costruisci stringa contatti estesa
                List<String> contattiList = [];
                if (customer?['email']?.toString().isNotEmpty == true) contattiList.add("Email: ${customer!['email']}");
                if (customer?['pec']?.toString().isNotEmpty == true) contattiList.add("PEC: ${customer!['pec']}");
                if (customer?['phone']?.toString().isNotEmpty == true) contattiList.add("Tel: ${customer!['phone']}");
                if (customer?['contacts']?.toString().isNotEmpty == true && contattiList.isEmpty) contattiList.add(customer!['contacts']);
                
                final customerContacts = contattiList.isNotEmpty ? contattiList.join(" | ") : 'N/D';
                
                String pivaCf = "";
                if (customer?['vat_number']?.toString().isNotEmpty == true) pivaCf += "P.IVA: ${customer!['vat_number']} ";
                if (customer?['tax_code']?.toString().isNotEmpty == true) pivaCf += "C.F.: ${customer!['tax_code']} ";
                if (pivaCf.isEmpty) pivaCf = "N/D";
                
                final customerDetails = "$pivaCf\nContatti: $customerContacts";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.borderColor),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceSummaryScreen(
                              invoice: invoice,
                              onEdit: (invoiceData) {
                                _showInvoiceDialog(invoice: invoiceData, isReadOnly: false);
                              },
                            ),
                          ),
                        ).then((_) => _loadData());
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
                                Icon(Icons.receipt, color: Colors.blueAccent, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fattura ${invoice['number'] ?? '-'}',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      if (customer != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Tooltip(
                                            message: customerDetails,
                                            padding: const EdgeInsets.all(12),
                                            textStyle: TextStyle(color: Colors.white, fontSize: 13),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2C2C34),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person, color: Colors.white.withOpacity(0.7), size: 14),
                                                SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    customerName,
                                                    style: TextStyle(
                                                      color: Colors.blueAccent,
                                                      fontWeight: FontWeight.w600,
                                                      decoration: TextDecoration.underline,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('€ ${invoice['amount'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: invoice['status'] == 'PAID'
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : invoice['status'] == 'LATE'
                                            ? Colors.red.withValues(alpha: 0.2)
                                            : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: invoice['status'] == 'PAID'
                                          ? Colors.green
                                          : invoice['status'] == 'LATE'
                                              ? Colors.red
                                              : Colors.orange,
                                    ),
                                  ),
                                  child: Text(
                                    invoice['status'] == 'PAID'
                                        ? 'Incassata'
                                        : invoice['status'] == 'LATE'
                                            ? 'In Ritardo'
                                            : 'Da Incassare',
                                    style: TextStyle(
                                      color: invoice['status'] == 'PAID'
                                          ? Colors.greenAccent
                                          : invoice['status'] == 'LATE'
                                              ? Colors.redAccent
                                              : Colors.orangeAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text('Data: ${DateUtilsApp.formatDbDate(invoice['date']?.toString(), theme.dateFormat)}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 13)),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (invoice['notes'] != null && invoice['notes'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Note: ${invoice['notes']}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                              ),
                            if (invoice['event_date'] != null && invoice['event_date'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Evento: ${DateUtilsApp.formatDbDate(invoice['event_date']?.toString(), theme.dateFormat)}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                              ),
                            if (invoice['vat_code'] != null && invoice['vat_code'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('IVA: ${invoice['vat_code']}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                              ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (attachments.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(right: 12.0),
                                    child: Icon(Icons.attachment, color: Colors.white.withOpacity(0.54), size: 20),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                  onPressed: () async {
                                    final authorized = await SecurityUtils.requireAdminAuth(context);
                                    if (authorized && mounted) {
                                      _showInvoiceDialog(invoice: invoice, isReadOnly: false);
                                    }
                                  },
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
              title: Text('Seleziona Cliente', style: TextStyle(color: Colors.black)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Cerca per nome...',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.54)),
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
                  child: Text('Annulla', style: TextStyle(color: Colors.white.withOpacity(0.54))),
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
          title: Text('Aggiungi Cliente', style: TextStyle(color: Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ragione Sociale / Nome',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: vatCtrl,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Partita IVA / Codice Fiscale',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annulla', style: TextStyle(color: Colors.white.withOpacity(0.54))),
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





