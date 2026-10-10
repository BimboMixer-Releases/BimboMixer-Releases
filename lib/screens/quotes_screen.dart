import '../services/biometric_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:contabile_app/utils/auth_fallback.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../services/attachment_service.dart';
import '../widgets/gradient_scaffold.dart';

class QuotesScreen extends StatefulWidget {
  final bool openDialog;
  const QuotesScreen({super.key, this.openDialog = false});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();

  List<Map<String, dynamic>> _quotes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter =
      'Tutti'; // Tutti, Accettati, Inviati, In Revisione, Bozza
  Map<String, dynamic>? _selectedQuote;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openDialog) _showQuoteFormDialog();
    });
    _loadQuotes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    setState(() => _isLoading = true);
    try {
      final q = await _dbHelper.getQuotes();
      if (mounted) {
        setState(() {
          _quotes = q;
          if (_quotes.isNotEmpty) {
            if (_selectedQuote != null) {
              try {
                _selectedQuote = _quotes.firstWhere(
                  (q) => q['id'] == _selectedQuote!['id'],
                );
              } catch (_) {
                _selectedQuote = _quotes.first;
              }
            } else {
              _selectedQuote = _quotes.first;
            }
          } else {
            _selectedQuote = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento preventivi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredQuotes {
    return _quotes.where((q) {
      // Status filter
      final status =
          (q['status'] ??
                  (q['accepted'] == true
                      ? 'Accettato'
                      : (q['rejected'] == true ? 'Rifiutato' : 'Inviato')))
              .toString();
      if (_selectedFilter != 'Tutti') {
        if (_selectedFilter == 'Accettati' && status != 'Accettato')
          return false;
        if (_selectedFilter == 'Inviati' && status != 'Inviato') return false;
        if (_selectedFilter == 'In Revisione' && status != 'In Revisione')
          return false;
        if (_selectedFilter == 'Bozza' && status != 'Bozza') return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final code = (q['code'] ?? q['serial_number'] ?? '')
            .toString()
            .toLowerCase();
        final client = (q['client_name'] ?? q['client'] ?? '')
            .toString()
            .toLowerCase();
        final subject = (q['subject'] ?? q['file_name'] ?? '')
            .toString()
            .toLowerCase();
        return code.contains(query) ||
            client.contains(query) ||
            subject.contains(query);
      }
      return true;
    }).toList();
  }

  // --- PDF PARSER UTILITY ---
  Map<String, dynamic> _extractDataFromPdf(File file) {
    final fileName = p.basenameWithoutExtension(file.path);
    String extractedCode =
        'P-${DateFormat('yyyy').format(DateTime.now())}-${(_quotes.length + 1).toString().padLeft(2, '0')}';
    String extractedClient = 'Cliente';
    String extractedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String extractedSubject = 'Prestazioni e Servizi';
    double extractedTotal = 0.0;
    double extractedSubtotal = 0.0;
    double extractedTax = 0.0;
    List<Map<String, String>> extractedItems = [];

    // Try reading raw text from PDF file to find patterns
    try {
      final bytes = file.readAsBytesSync();
      final text = String.fromCharCodes(bytes);

      // 1. Check for Code (es. P-2023-08 o Preventivo N. 12)
      final codeMatch = RegExp(
        r'(P-\d{4}-\d{2,4}|Preventivo\s*n?\.?\s*(\d+))',
        caseSensitive: false,
      ).firstMatch(text);
      if (codeMatch != null) {
        extractedCode = codeMatch.group(0)!;
      }

      // 2. Check for Date
      final dateMatch = RegExp(
        r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})',
      ).firstMatch(text);
      if (dateMatch != null) {
        extractedDate = dateMatch.group(1)!;
      }

      // 3. Check for Total (€ 1.200,00 o Totale: 1200)
      final totalMatch = RegExp(
        r'(?:Totale|Total|Importo|EUR|€)\s*:?\s*([\d\.\,]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (totalMatch != null) {
        final numStr = totalMatch
            .group(1)!
            .replaceAll('.', '')
            .replaceAll(',', '.');
        extractedTotal = double.tryParse(numStr) ?? 0.0;
        extractedSubtotal = extractedTotal; // IVA di default 0%
        extractedTax = extractedTotal - extractedSubtotal;
      }

      // 4. Check for Client
      final clientMatch = RegExp(
        r'(?:Spett\.le|Cliente|Client|A:)\s*:?\s*([A-Za-z0-9\s\.\,\-]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (clientMatch != null && clientMatch.group(1)!.trim().isNotEmpty) {
        extractedClient = clientMatch.group(1)!.trim();
      } else {
        // Use filename if it contains a name
        final parts = fileName.split(RegExp(r'[\-_]'));
        if (parts.length > 1) {
          extractedClient = parts[1].trim();
        }
      }

      // 5. Check for Items / Services
      final lines = text.split('\n');
      for (var l in lines) {
        if (l.contains('€') ||
            l.toLowerCase().contains('ore') ||
            l.toLowerCase().contains('consulenza') ||
            l.toLowerCase().contains('servizi')) {
          final clean = l.replaceAll(RegExp(r'[^\w\s\(\)\€\.\,]'), '').trim();
          if (clean.length > 5 &&
              clean.length < 80 &&
              extractedItems.length < 5) {
            extractedItems.add({'name': clean, 'qty': '1'});
          }
        }
      }
    } catch (_) {
      // Fallback to defaults
    }

    if (extractedItems.isEmpty) {
      extractedItems = [
        {'name': 'Consulenza e Prestazioni', 'qty': '1'},
        {'name': 'Servizi Professionali', 'qty': '1'},
      ];
    }

    if (extractedTotal <= 0) {
      extractedTotal = 1500.0;
      extractedSubtotal = 1500.0;
      extractedTax = 0.0;
    }

    return {
      'code': extractedCode,
      'client_name': extractedClient,
      'date': extractedDate,
      'subject': extractedSubject,
      'total': extractedTotal,
      'subtotal': extractedSubtotal,
      'tax': extractedTax,
      'items': extractedItems,
    };
  }

  Future<void> _bulkUploadQuotes() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null || result.paths.isEmpty) return;

      int successCount = 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caricamento di ${result.paths.length} file in corso...',
          ),
        ),
      );

      for (String? path in result.paths) {
        if (path == null) continue;
        File file = File(path);

        final extracted = _extractDataFromPdf(file);

        String fileUrl = '';
        try {
          fileUrl =
              (await _attachmentService.uploadAttachment(file, 'quotes')) ?? '';
        } catch (_) {}

        final code =
            extracted['code']?.toString() ??
            'N${_quotes.length + 1}-${DateFormat('yyyy').format(DateTime.now())}';

        final quoteData = {
          'code': code,
          'serial_number': code,
          'client_name': extracted['client_name']?.toString() ?? '',
          'date':
              extracted['date']?.toString() ??
              DateFormat('dd/MM/yyyy').format(DateTime.now()),
          'subject': extracted['subject']?.toString() ?? 'Consulenza e Servizi',
          'status': 'Inviato',
          'accepted': false,
          'rejected': false,
          'items':
              extracted['items'] ??
              [
                {'name': 'Servizio Principale', 'qty': '1'},
              ],
          'subtotal': extracted['subtotal'] ?? 0.0,
          'tax_amount': extracted['tax'] ?? 0.0,
          'total_amount': extracted['total'] ?? 0.0,
          'file_name': p.basename(file.path),
          'file_url': fileUrl.isEmpty ? file.path : fileUrl,
          'local_path': file.path,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _dbHelper.insertQuote(quoteData);
        successCount++;
        await _loadQuotes();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount preventivi caricati in blocco!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il caricamento in blocco: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndCreateQuote() async {
    try {
      File? file = await _attachmentService.pickFile(context);
      if (file == null) return;

      final extracted = _extractDataFromPdf(file);

      if (!mounted) return;

      // Show Confirmation & Editing Dialog
      await _showQuoteFormDialog(initialFile: file, initialData: extracted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showQuoteFormDialog({
    File? initialFile,
    Map<String, dynamic>? initialData,
    Map<String, dynamic>? existingQuote,
  }) async {
    final isEditing = existingQuote != null;

    final codeCtrl = TextEditingController(
      text:
          existingQuote?['code']?.toString() ??
          initialData?['code']?.toString() ??
          'N${_quotes.length + 1}-${DateFormat('yyyy').format(DateTime.now())}',
    );
    final clientCtrl = TextEditingController(
      text: existingQuote?['client_name'] ?? initialData?['client_name'] ?? '',
    );
    final dateCtrl = TextEditingController(
      text:
          existingQuote?['date'] ??
          initialData?['date'] ??
          DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    final subjectCtrl = TextEditingController(
      text:
          existingQuote?['subject'] ??
          initialData?['subject'] ??
          'Consulenza e Servizi',
    );
    final totalCtrl = TextEditingController(
      text: (existingQuote?['total_amount'] ?? initialData?['total'] ?? '0.00')
          .toString(),
    );
    final subtotalCtrl = TextEditingController(
      text: (existingQuote?['subtotal'] ?? initialData?['subtotal'] ?? '0.00')
          .toString(),
    );
    final taxCtrl = TextEditingController(
      text: (existingQuote?['tax_amount'] ?? initialData?['tax'] ?? '0.00')
          .toString(),
    );
    String status = existingQuote?['status'] ?? 'Inviato';

    List<Map<String, String>> items = [];
    if (existingQuote?['items'] is List) {
      items = (existingQuote!['items'] as List).map((e) {
        if (e is Map) {
          return {
            'name': e['name']?.toString() ?? '',
            'qty': e['qty']?.toString() ?? '1',
          };
        }
        return <String, String>{};
      }).toList();
    } else if (initialData?['items'] is List) {
      items = List<Map<String, String>>.from(initialData!['items']);
    } else {
      items = [
        {'name': 'Servizio Principale', 'qty': '1'},
      ];
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF131722),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing
                              ? 'Modifica Preventivo'
                              : 'Nuovo Preventivo da PDF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),

                    // Row 1: Code & Date
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Codice Preventivo (es. N1-2026)',
                            codeCtrl,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField('Data (dd/MM/yyyy)', dateCtrl),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Client & Status
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            'Nome Cliente / Azienda',
                            clientCtrl,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stato',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: status,
                                    dropdownColor: const Color(0xFF1E2235),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    isExpanded: true,
                                    items:
                                        [
                                          {
                                            'status': 'Inviato',
                                            'color': Colors.blueAccent,
                                          },
                                          {
                                            'status': 'Accettato',
                                            'color': Colors.greenAccent,
                                          },
                                          {
                                            'status': 'In Revisione',
                                            'color': Colors.orangeAccent,
                                          },
                                          {
                                            'status': 'Bozza',
                                            'color': Colors.purpleAccent,
                                          },
                                          {
                                            'status': 'Rifiutato',
                                            'color': Colors.redAccent,
                                          },
                                        ].map((item) {
                                          final s = item['status'] as String;
                                          final c = item['color'] as Color;
                                          return DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                              s,
                                              style: TextStyle(
                                                color: c,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (val) {
                                      if (val != null)
                                        setDialogState(() => status = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Subject
                    _buildTextField(
                      'Oggetto / Descrizione sintetica',
                      subjectCtrl,
                    ),
                    const SizedBox(height: 16),

                    // Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voci / Items',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              items.add({'name': 'Nuova voce', 'qty': '1'});
                            });
                          },
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Color(0xFF38BDF8),
                          ),
                          label: const Text(
                            'Aggiungi voce',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Items List
                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Padding(
                        key: ObjectKey(item),
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: item['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Descrizione item...',
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (v) => item['name'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: item['qty'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Q.tà/Ore',
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (v) => item['qty'] = v,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () {
                                setDialogState(() => items.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // Totals Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Subtotale (€)',
                            subtotalCtrl,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'IVA (€)',
                            taxCtrl,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Totale (€)',
                            totalCtrl,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            'Annulla',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            isEditing ? 'Salva Modifiche' : 'Crea Preventivo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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

    if (saved == true) {
      String? fileUrl = existingQuote?['file_url'];
      String fileName =
          existingQuote?['file_name'] ??
          (initialFile != null
              ? p.basename(initialFile.path)
              : 'preventivo.pdf');

      if (initialFile != null && !isEditing) {
        fileUrl = await _attachmentService.uploadAttachment(
          initialFile,
          'quotes',
        );
      }

      final quoteData = {
        'code': codeCtrl.text.trim(),
        'serial_number': codeCtrl.text.trim(),
        'client_name': clientCtrl.text.trim(),
        'date': dateCtrl.text.trim(),
        'subject': subjectCtrl.text.trim(),
        'status': status,
        'accepted': status == 'Accettato',
        'rejected': status == 'Rifiutato',
        'items': items,
        'subtotal':
            CurrencyUtils.parseCurrency(subtotalCtrl.text),
        'tax_amount': CurrencyUtils.parseCurrency(taxCtrl.text),
        'total_amount':
            CurrencyUtils.parseCurrency(totalCtrl.text),
        'file_name': fileName,
        'file_url': fileUrl ?? initialFile?.path ?? '',
        'local_path': initialFile?.path ?? existingQuote?['local_path'] ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isEditing) {
        await _dbHelper.updateQuote({'id': existingQuote['id'], ...quoteData});
      } else {
        quoteData['created_at'] = DateTime.now().toIso8601String();
        await _dbHelper.insertQuote(quoteData);
      }

      await _loadQuotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Preventivo modificato!'
                  : 'Preventivo salvato con successo!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // --- OPEN ORIGINAL PDF ---
  Future<void> _openPdf(Map<String, dynamic> quote) async {
    final pathOrUrl = quote['local_path'] ?? quote['file_url'];
    if (pathOrUrl == null || pathOrUrl.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun file PDF associato a questo preventivo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final file = File(pathOrUrl.toString());
      if (file.existsSync()) {
        await OpenFilex.open(file.path);
        return;
      }

      // If URL or fallback
      final uri = Uri.parse(pathOrUrl.toString());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', pathOrUrl.toString()]);
      } else {
        throw Exception("File non apribile");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il file PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteQuote(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          'Elimina Preventivo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Sei sicuro di voler eliminare questo preventivo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white54),
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
      final bioService = BiometricService();
      bool isAuth = false;
      if (await bioService.isBiometricAvailable()) {
        isAuth = await bioService.authenticate(reason: 'Autenticati per eliminare il preventivo');
      }
      if (!isAuth && mounted) {
        isAuth = await promptForPasswordFallback(context);
      }
      if (!isAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticazione fallita o annullata. Eliminazione annullata.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      await _dbHelper.deleteQuote(id);
      await _loadQuotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuotes;

    return GradientScaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP HEADER: Title with Count, Search Bar & "+ Nuovo Preventivo" Button
                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isMobile = constraints.maxWidth < 600;

                        Widget title = RichText(
                          text: TextSpan(
                            text: 'Preventivi e Stime ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            children: [
                              TextSpan(
                                text: '(${_quotes.length})',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );

                        Widget searchBar = Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF16192B,
                            ).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.white38,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Ricerca preventivo, cliente, oggetto...',
                                    hintStyle: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: (val) =>
                                      setState(() => _searchQuery = val),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white38,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                            ],
                          ),
                        );

                        Widget btnBulk = OutlinedButton.icon(
                          onPressed: _bulkUploadQuotes,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF22D3EE),
                            side: const BorderSide(color: Color(0xFF22D3EE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.drive_folder_upload, size: 16),
                          label: const Text(
                            'Carica in Blocco',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );

                        Widget btnNew = ElevatedButton.icon(
                          onPressed: _uploadAndCreateQuote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22D3EE),
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: const Color(
                              0xFF22D3EE,
                            ).withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'Nuovo Preventivo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        );

                        Widget btnGoogleDocs = Tooltip(
                          message: 'Collega a Google Docs',
                          child: InkWell(
                            onTap: () async {
                              final uri = Uri.parse('https://docs.google.com/document/u/0/');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/512px-Google_%22G%22_Logo.svg.png',
                                    height: 16,
                                    width: 16,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.description, size: 16, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Google Docs',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              title,
                              const SizedBox(height: 12),
                              searchBar,
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                children: [btnGoogleDocs, btnBulk, btnNew],
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              title,
                              const SizedBox(width: 24),
                              Expanded(child: searchBar),
                              const SizedBox(width: 16),
                              btnGoogleDocs,
                              const SizedBox(width: 12),
                              btnBulk,
                              const SizedBox(width: 12),
                              btnNew,
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20),



                    // 3. BOTTOM SECTION: Table of Quotes with Status Filter Header
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF101322).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double minTableWidth = 850.0;
                            final double actualWidth =
                                constraints.maxWidth > minTableWidth
                                ? constraints.maxWidth
                                : minTableWidth;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: actualWidth,
                                child: Column(
                                  children: [
                                    // Table Header Row with Dropdown filter
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.03,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Filter Dropdown
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: PopupMenuButton<String>(
                                                    color: const Color(
                                                      0xFF16192B,
                                                    ),
                                                    offset: const Offset(0, 30),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Colors.white12,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Preventivi ($_selectedFilter)',
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      const Icon(
                                                        Icons
                                                            .keyboard_arrow_down,
                                                        color: Colors.white70,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                                  onSelected: (v) => setState(
                                                    () => _selectedFilter = v,
                                                  ),
                                                  itemBuilder: (ctx) =>
                                                      [
                                                            'Tutti',
                                                            'Accettati',
                                                            'Inviati',
                                                            'In Revisione',
                                                            'Bozza',
                                                          ]
                                                          .map(
                                                            (
                                                              s,
                                                            ) => PopupMenuItem(
                                                              value: s,
                                                              child: Text(
                                                                s,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Data',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Oggetto',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'Totale',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 80,
                                          ), // For action buttons
                                        ],
                                      ),
                                    ),

                                    // Table Content
                                    Expanded(
                                      child: filtered.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Nessun preventivo trovato.',
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              itemCount: filtered.length,
                                              separatorBuilder: (ctx, i) =>
                                                  Divider(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.04,
                                                        ),
                                                    height: 1,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final q = filtered[index];
                                                final isSelected =
                                                    _selectedQuote?['id'] ==
                                                    q['id'];
                                                final code =
                                                    q['code']?.toString() ??
                                                    q['serial_number']
                                                        ?.toString() ??
                                                    'P-${index + 1}';
                                                final client =
                                                    q['client_name']
                                                        ?.toString() ??
                                                    'Cliente';
                                                final date =
                                                    q['date']?.toString() ??
                                                    '-';
                                                final subject =
                                                    q['subject']?.toString() ??
                                                    q['file_name']
                                                        ?.toString() ??
                                                    '-';
                                                final total =
                                                    double.tryParse(
                                                      q['total_amount']
                                                              ?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0.0;

                                                return InkWell(
                                                  onTap: () {
                                                    setState(() => _selectedQuote = q);
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => Dialog(
                                                        backgroundColor: Colors.transparent,
                                                        insetPadding: const EdgeInsets.all(16),
                                                        child: ConstrainedBox(
                                                          constraints: const BoxConstraints(maxWidth: 600),
                                                          child: _buildFeaturedQuoteCard(q, 0),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    color: isSelected
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.05,
                                                              )
                                                        : Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                code,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              Text(
                                                                'Client: $client',
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize: 11,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            date,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            subject,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 13,
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Align(
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: Text(
                                                              '€ ${total.toStringAsFixed(2)}',
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 96,
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .end,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .picture_as_pdf,
                                                                  color: Color(
                                                                    0xFF38BDF8,
                                                                  ),
                                                                  size: 18,
                                                                ),
                                                                tooltip:
                                                                    'Apri PDF originale',
                                                                onPressed: () =>
                                                                    _openPdf(q),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .delete_outline,
                                                                  color: Colors
                                                                      .redAccent,
                                                                  size: 18,
                                                                ),
                                                                tooltip:
                                                                    'Elimina',
                                                                onPressed: () =>
                                                                    _deleteQuote(
                                                                      q['id'],
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- TOP FEATURED NEON CARD ---
  Widget _buildFeaturedQuoteCard(Map<String, dynamic> quote, int index) {
    final status =
        quote['status']?.toString() ??
        (quote['accepted'] == true ? 'Accettato' : 'Inviato');

    Color neonColor;
    switch (status) {
      case 'Accettato':
        neonColor = Colors.greenAccent;
        break;
      case 'In Revisione':
        neonColor = Colors.orangeAccent;
        break;
      case 'Bozza':
        neonColor = Colors.purpleAccent;
        break;
      case 'Rifiutato':
        neonColor = Colors.redAccent;
        break;
      case 'Inviato':
      default:
        neonColor = Colors.blueAccent;
        break;
    }

    final code =
        quote['code']?.toString() ??
        quote['serial_number']?.toString() ??
        'P-2023-08';
    final client = quote['client_name']?.toString() ?? 'Tech Solutions Inc.';
    final date = quote['date']?.toString() ?? '24/10/2023';
    final subject =
        quote['subject']?.toString() ??
        quote['file_name']?.toString() ??
        'Servizi Contabili & Consulenza Fiscale';
    final total =
        double.tryParse(quote['total_amount']?.toString() ?? '0') ?? 6850.0;
    final subtotal =
        double.tryParse(quote['subtotal']?.toString() ?? '0') ?? total;
    final tax =
        double.tryParse(quote['tax_amount']?.toString() ?? '0') ??
        (total - subtotal);

    List itemsList = quote['items'] is List
        ? (quote['items'] as List)
        : [
            {'name': 'Consulenza Fiscale', 'qty': '20h'},
            {'name': 'Contabilità Trimestrale', 'qty': '20h'},
            {'name': 'Dichiarazione IVA', 'qty': '20h'},
          ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101322).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neonColor.withValues(alpha: 0.8), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: neonColor.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Code, Status Pill, Client
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client: $client',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Metadata: Data, Oggetto, Totale & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildMetaRow('Data', date),
                    const SizedBox(height: 6),
                    _buildMetaRow('Oggetto', subject),
                    const SizedBox(height: 6),
                    _buildMetaRow(
                      'Totale',
                      '€ ${total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status Stamp Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: neonColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: neonColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: neonColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: neonColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      status == 'Accettato'
                          ? Icons.check_circle
                          : (status == 'Rifiutato'
                                ? Icons.cancel
                                : Icons.arrow_forward),
                      size: 14,
                      color: neonColor,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Items Box
          const Text(
            'Items',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: itemsList.take(3).map((item) {
                final map = item is Map
                    ? item
                    : {'name': item.toString(), 'qty': '1'};
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          map['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        map['qty']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Subtotal & IVA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotale',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '€ ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IVA (${subtotal > 0 ? (tax / subtotal * 100).toStringAsFixed(0) : 0}%)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '€ ${tax.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // 5. Actions Footer (Visualizza PDF, Modifica, Cronologia)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _openPdf(quote),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Color(0xFF38BDF8),
                  ),
                  label: const Text(
                    'Visualizza PDF',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () => _showQuoteFormDialog(existingQuote: quote),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Modifica', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteQuote(quote['id']);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  minimumSize: Size.zero,
                ),
                child: const Icon(Icons.delete_outline, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}




