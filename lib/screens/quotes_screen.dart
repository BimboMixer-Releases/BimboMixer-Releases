import 'dart:io';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
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

  static const List<String> _quoteStatuses = [
    'Inviato',
    'Accettato',
    'In Revisione',
    'Bozza',
    'Rifiutato',
  ];

  static const List<String> _filterOptions = [
    'Tutti',
    'Accettati',
    'Inviati',
    'In Revisione',
    'Bozza',
    'Rifiutati',
  ];

  List<Map<String, dynamic>> _quotes = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  bool _isBulkUploading = false;
  String _searchQuery = '';
  String _selectedFilter = 'Tutti';
  Map<String, dynamic>? _selectedQuote;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuotes().then((_) {
      if (widget.openDialog && mounted) {
        _showQuoteFormDialog();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _normalizeQuoteStatus(Map<String, dynamic>? q) {
    if (q == null) return 'Inviato';
    final raw = (q['status'] ?? '').toString().trim().toLowerCase();
    if (raw == 'accettato' ||
        raw == 'accettata' ||
        raw == 'accepted' ||
        raw == 'approved') {
      return 'Accettato';
    }
    if (raw == 'rifiutato' ||
        raw == 'rifiutata' ||
        raw == 'rejected' ||
        raw == 'declined') {
      return 'Rifiutato';
    }
    if (raw == 'in revisione' ||
        raw == 'revisione' ||
        raw == 'review' ||
        raw == 'in_review') {
      return 'In Revisione';
    }
    if (raw == 'bozza' || raw == 'draft') {
      return 'Bozza';
    }
    if (raw == 'inviato' ||
        raw == 'inviata' ||
        raw == 'sent' ||
        raw == 'pending') {
      return 'Inviato';
    }
    if (q['accepted'] == true) return 'Accettato';
    if (q['rejected'] == true) return 'Rifiutato';
    return 'Inviato';
  }

  String _resolveQuoteClient(Map<String, dynamic> q) {
    final direct =
        (q['client_name'] ?? q['client'])?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final custId = (q['customer_id'] ?? q['client_id'])?.toString().trim() ?? '';
    if (custId.isNotEmpty) {
      for (final c in _customers) {
        if (c['id']?.toString() == custId) {
          final cName = c['name']?.toString().trim() ?? '';
          if (cName.isNotEmpty) return cName;
        }
      }
    }
    return '-';
  }

  double _resolveQuoteTotal(Map<String, dynamic> q) {
    final raw = q['total_amount'] ?? q['total'];
    return CurrencyUtils.parseCurrency(raw?.toString());
  }

  Future<void> _loadQuotes() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final q = await _dbHelper.getQuotes();
      final c = await _dbHelper.getCustomers();
      if (mounted) {
        setState(() {
          _quotes = q;
          _customers = c;
          if (_quotes.isNotEmpty) {
            if (_selectedQuote != null) {
              try {
                _selectedQuote = _quotes.firstWhere(
                  (item) => item['id'] == _selectedQuote!['id'],
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
      final status = _normalizeQuoteStatus(q);
      if (_selectedFilter != 'Tutti') {
        if (_selectedFilter == 'Accettati' && status != 'Accettato') {
          return false;
        }
        if (_selectedFilter == 'Inviati' && status != 'Inviato') {
          return false;
        }
        if (_selectedFilter == 'In Revisione' && status != 'In Revisione') {
          return false;
        }
        if (_selectedFilter == 'Bozza' && status != 'Bozza') {
          return false;
        }
        if (_selectedFilter == 'Rifiutati' && status != 'Rifiutato') {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final code =
            (q['code'] ?? q['serial_number'] ?? '').toString().toLowerCase();
        final client = _resolveQuoteClient(q).toLowerCase();
        final subject =
            (q['subject'] ?? q['file_name'] ?? '').toString().toLowerCase();
        return code.contains(query) ||
            client.contains(query) ||
            subject.contains(query);
      }
      return true;
    }).toList();
  }

  // --- PDF PARSER UTILITY ---
  static String? _detectSectionCategory(String line) {
    final clean = line
        .replaceAll(RegExp(r'[:\-–•\*#]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    if (clean.isEmpty || clean.length > 45) return null;

    if (RegExp(
      r'^(impianto\s+audio|sezione\s+audio|reparto\s+audio|audio|fonica|amplificazione\s+audio)$',
    ).hasMatch(clean)) {
      return 'Audio';
    }
    if (RegExp(
      r'^(impianto\s+luci|sezione\s+luci|reparto\s+luci|illuminazione|luci|lighting|luci\s+scenografiche)$',
    ).hasMatch(clean)) {
      return 'Luci';
    }
    if (RegExp(
      r'^(impianto\s+video|sezione\s+video|reparto\s+video|video|ledwall|proiezione|regia\s+video)$',
    ).hasMatch(clean)) {
      return 'Video';
    }
    if (RegExp(
      r'^(strutture|struttura|palco|pedane|truss|americane|copertura|rigging|allestimento\s+strutture)$',
    ).hasMatch(clean)) {
      return 'Strutture';
    }
    if (RegExp(
      r'^(effetti\s+speciali|effetti|macchine\s+effetti|sfx)$',
    ).hasMatch(clean)) {
      return 'Effetti';
    }
    if (RegExp(r'^(backline|strumentazione|strumenti)$').hasMatch(clean)) {
      return 'Backline';
    }
    if (RegExp(
      r'^(regia|personale\s+tecnico|personale|assistenza\s+tecnica|servizi\s+tecnici|trasporto\s+e\s+montaggio)$',
    ).hasMatch(clean)) {
      return 'Regia/Servizi';
    }
    return null;
  }

  static bool _isBoilerplateLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.length < 3) return true;
    const skipPrefixes = [
      'bimbomixer',
      'service audio',
      'produzioni teatrali',
      'vetralla',
      'p.iva',
      'partita iva',
      'cod. fisc',
      'codice fiscale',
      'spett.le',
      'gent.le',
      'preventivo',
      'data:',
      'oggetto:',
      'totale',
      'subtotale',
      'imponibile',
      'iva ',
      'iban',
      'banca',
      'condizioni',
      'validit',
      'firma',
      'pagina ',
      'tel.',
      'cell.',
      'email:',
      'pec:',
    ];
    for (final pfx in skipPrefixes) {
      if (lower.startsWith(pfx)) return true;
    }
    if (lower.contains('bimbomixer91@gmail.com') ||
        lower.contains('02494800564')) {
      return true;
    }
    return false;
  }

  static List<Map<String, dynamic>> _extractItemsFromText(String text) {
    final List<Map<String, dynamic>> extractedItems = [];
    final Set<String> seenKeys = <String>{};
    String? currentCategory;

    final equipmentKeywords = RegExp(
      r'\b(audio|casse|diffusor|subwoofer|sub|monitor|spie|mixer|microfon|radiomicrofon|asta|aste|luci|fari|faro|par|testa\s+mobile|teste\s+mobili|beam|wash|spot|strobo|blinder|hazer|fumo|sparkular|laser|dimmer|dmx|video|ledwall|proiettor|schermo|telecamer|regia|struttur|truss|american|elevatori|stativ|palco|pedan|transenn|cavi|cablagg|quadro\s+elettrico|backline|tecnic|fonico|light\s+designer|montaggio|smontaggio|noleggio|allestimento|trasporto|consulenza|servizi|ore)\b',
      caseSensitive: false,
    );

    for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (line.isEmpty) continue;

      final detectedCat = _detectSectionCategory(line);
      if (detectedCat != null) {
        currentCategory = detectedCat;
        continue;
      }

      if (_isBoilerplateLine(line)) continue;

      String candidateDesc = '';
      String qty = '1';
      bool matchedStructure = false;

      // 1. Bullet line: •, -, *, ▪, –, ›
      final bulletMatch =
          RegExp(r'^[\•\-\*\▪\–\›\◦\+]\s*(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        candidateDesc = bulletMatch.group(1)!.trim();
        matchedStructure = true;
      }

      // 2. Leading quantity: "4x Teste mobili", "n. 2 Subwoofer", "2 pz Microfoni"
      if (!matchedStructure) {
        final qtyPrefix = RegExp(
          r'^(?:n\.?\s*|nr\.?\s*)?(\d{1,4})\s*(?:[xX×]|pz\.?|mt\.?|m\.?|gg\.?|ore|h)(?:\s+|\b)(.+)$',
          caseSensitive: false,
        ).firstMatch(line);
        if (qtyPrefix != null) {
          qty = qtyPrefix.group(1)!;
          candidateDesc = qtyPrefix.group(2)!.trim();
          matchedStructure = true;
        }
      }

      // 3. Leading quantity inside bullet: "• 4x Teste mobili"
      if (matchedStructure && qty == '1') {
        final innerQty = RegExp(
          r'^(?:n\.?\s*|nr\.?\s*)?(\d{1,4})\s*(?:[xX×]|pz\.?)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(candidateDesc);
        if (innerQty != null) {
          qty = innerQty.group(1)!;
          candidateDesc = innerQty.group(2)!.trim();
        }
      }

      // 4. Inside a material category section or matching equipment/service keywords
      if (!matchedStructure &&
          line.length >= 4 &&
          line.length <= 130 &&
          (currentCategory != null ||
              equipmentKeywords.hasMatch(line) ||
              line.contains('€'))) {
        candidateDesc = line;
        matchedStructure = true;
      }

      if (!matchedStructure || candidateDesc.isEmpty) continue;

      // Check trailing quantity e.g. "(x4)" or "q.tà 2"
      final trailingQty = RegExp(
        r'(?:\(\s*[xX×]?\s*(\d{1,4})\s*(?:pz\.?)?\s*\)|(?:q\.?t[àa]|pz\.?)\s*:?\s*(\d{1,4}))\s*$',
        caseSensitive: false,
      ).firstMatch(candidateDesc);
      if (trailingQty != null) {
        qty = (trailingQty.group(1) ?? trailingQty.group(2)) ?? qty;
        candidateDesc =
            candidateDesc.substring(0, trailingQty.start).trim();
      }

      // Clean stray control chars while preserving Italian accents and punctuation
      candidateDesc = candidateDesc
          .replaceAll(RegExp(r'[\x00-\x1F]'), '')
          .trim();
      if (candidateDesc.length < 3 || candidateDesc.length > 140) continue;

      final String displayName = (currentCategory != null &&
              !candidateDesc
                  .toLowerCase()
                  .startsWith('[${currentCategory.toLowerCase()}]'))
          ? '[$currentCategory] $candidateDesc'
          : candidateDesc;

      final dedupKey = displayName.toLowerCase();
      if (seenKeys.contains(dedupKey)) continue;
      seenKeys.add(dedupKey);

      extractedItems.add({
        'name': displayName,
        'qty': qty,
        'checked': false,
      });

      if (extractedItems.length >= 120) break;
    }

    return extractedItems;
  }

  Map<String, dynamic> _extractDataFromPdf(File file) {
    final fileName = p.basenameWithoutExtension(file.path);
    String extractedCode = fileName.trim().isNotEmpty
        ? fileName.trim()
        : 'P-${DateFormat('yyyy').format(DateTime.now())}';
    String extractedClient = '';
    String extractedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String extractedSubject = fileName.trim();
    double extractedTotal = 0.0;
    double extractedSubtotal = 0.0;
    double extractedTax = 0.0;
    List<Map<String, dynamic>> extractedItems = [];

    try {
      String text = '';
      if (file.path.toLowerCase().endsWith('.pdf')) {
        try {
          final PdfDocument document =
              PdfDocument(inputBytes: file.readAsBytesSync());
          text = PdfTextExtractor(document).extractText();
          document.dispose();
        } catch (_) {
          text = '';
        }
      } else {
        try {
          text = file.readAsStringSync();
        } catch (_) {
          text = '';
        }
      }

      // 1. Code from filename or PDF text
      final fileNameCodeMatch = RegExp(
        r'^([NnPp]?\s*\d+(?:\s*[\-_\/]\s*\d{2,4})?)',
        caseSensitive: false,
      ).firstMatch(fileName);
      if (fileNameCodeMatch != null &&
          fileNameCodeMatch.group(1)!.trim().isNotEmpty) {
        extractedCode = fileNameCodeMatch.group(1)!.trim();
      } else if (text.isNotEmpty) {
        final codeMatch = RegExp(
          r'(P-\d{4}-\d{2,4}|Preventivo\s*n?\.?\s*([\w\/\-]+))',
          caseSensitive: false,
        ).firstMatch(text);
        if (codeMatch != null) {
          extractedCode = codeMatch.group(0)!.trim();
        }
      }

      if (text.isNotEmpty) {
        // 2. Date
        final dateMatch = RegExp(
          r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})',
        ).firstMatch(text);
        if (dateMatch != null) {
          extractedDate = dateMatch.group(1)!.replaceAll('.', '/').replaceAll('-', '/');
        }

        // 3. Subtotal / Tax / Total parsed strictly with CurrencyUtils.parseCurrency (0.0 if absent)
        final subMatch = RegExp(
          r'(?:Imponibile|Subtotale|Sub-totale)\s*:?\s*(?:€|EUR)?\s*([\d\.\,]+)',
          caseSensitive: false,
        ).allMatches(text);
        if (subMatch.isNotEmpty) {
          extractedSubtotal =
              CurrencyUtils.parseCurrency(subMatch.last.group(1));
        }

        final taxMatch = RegExp(
          r'(?:Totale\s+IVA|Importo\s+IVA|\bIVA\b(?:\s*\d{1,2}\s*%)?)\s*:?\s*(?:€|EUR)?\s*([\d\.\,]+)',
          caseSensitive: false,
        ).allMatches(text);
        if (taxMatch.isNotEmpty) {
          extractedTax = CurrencyUtils.parseCurrency(taxMatch.last.group(1));
        }

        final totalMatches = RegExp(
          r'(?:Totale(?:\s+Preventivo|\s+Complessivo|\s+Generale|\s+Documento|\s+IVA\s+inclusa)?|Total|Importo\s+Totale)\s*:?\s*(?:€|EUR)?\s*([\d\.\,]+)',
          caseSensitive: false,
        ).allMatches(text);
        if (totalMatches.isNotEmpty) {
          extractedTotal =
              CurrencyUtils.parseCurrency(totalMatches.last.group(1));
        }

        if (extractedTotal > 0 && extractedSubtotal == 0.0) {
          extractedSubtotal = extractedTax > 0 && extractedTax <= extractedTotal
              ? CurrencyUtils.roundMoney(extractedTotal - extractedTax)
              : extractedTotal;
        } else if (extractedTotal == 0.0 && extractedSubtotal > 0) {
          extractedTotal =
              CurrencyUtils.roundMoney(extractedSubtotal + extractedTax);
        }

        // 4. Subject
        final subjectMatch = RegExp(
          r'(?:Oggetto|Evento|Manifestazione|Rif\.?)\s*:\s*([^\n\r]+)',
          caseSensitive: false,
        ).firstMatch(text);
        if (subjectMatch != null &&
            subjectMatch.group(1)!.trim().isNotEmpty) {
          extractedSubject = subjectMatch.group(1)!.trim();
        }

        // 5. Client
        final clientMatch = RegExp(
          r'(?:Spett\.le|Gent\.le|Cliente|Committente|Alla\s+c\.a\.\s*di)\s*:?\s*([^\n\r]+)',
          caseSensitive: false,
        ).firstMatch(text);
        if (clientMatch != null && clientMatch.group(1)!.trim().isNotEmpty) {
          extractedClient = clientMatch.group(1)!.trim();
        }

        // 6. Material items (Audio, Luci, Strutture, Video, ecc.)
        extractedItems = _extractItemsFromText(text);
      }

      if (extractedClient.isEmpty) {
        final parts = fileName.split(RegExp(r'[\-_]'));
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          extractedClient = parts[1].trim();
        }
      }

      if (extractedClient.isNotEmpty) {
        final lowerCandidate = extractedClient.toLowerCase();
        for (final c in _customers) {
          final cName = (c['name'] ?? '').toString().trim();
          if (cName.isNotEmpty &&
              lowerCandidate.contains(cName.toLowerCase())) {
            extractedClient = cName;
            break;
          }
        }
      }
    } catch (_) {
      // Keep safe zero/empty defaults without fake values
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
    if (_isBulkUploading) return;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null || result.paths.isEmpty || !mounted) return;

      setState(() => _isBulkUploading = true);
      int successCount = 0;
      int failCount = 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caricamento di ${result.paths.length} file in corso...',
          ),
        ),
      );

      for (final String? path in result.paths) {
        if (path == null || path.trim().isEmpty) continue;
        try {
          final File file = File(path);
          final extracted = _extractDataFromPdf(file);

          String fileUrl = '';
          try {
            fileUrl =
                (await _attachmentService.uploadAttachment(file, 'quotes')) ??
                    '';
          } catch (_) {}

          final code = (extracted['code']?.toString().trim().isNotEmpty == true)
              ? extracted['code'].toString().trim()
              : p.basenameWithoutExtension(file.path);

          // Omit 'serial_number' so DatabaseHelper.insertQuote assigns an atomic sequential serial_number!
          final quoteData = <String, dynamic>{
            'code': code,
            'client_name': extracted['client_name']?.toString() ?? '',
            'date': extracted['date']?.toString() ??
                DateFormat('dd/MM/yyyy').format(DateTime.now()),
            'subject': extracted['subject']?.toString() ?? '',
            'status': 'Inviato',
            'accepted': false,
            'rejected': false,
            'items': extracted['items'] is List ? extracted['items'] : <Map<String, dynamic>>[],
            'subtotal': extracted['subtotal'] ?? 0.0,
            'tax_amount': extracted['tax'] ?? 0.0,
            'total_amount': extracted['total'] ?? 0.0,
            'total': extracted['total'] ?? 0.0,
            'file_name': p.basename(file.path),
            'file_url': fileUrl.isEmpty ? file.path : fileUrl,
            'local_path': file.path,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await _dbHelper.insertQuote(quoteData);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Errore caricamento singolo preventivo in blocco: $e');
        }
      }

      if (successCount > 0) {
        await _loadQuotes();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? 'Caricati $successCount preventivi con successo!'
                  : 'Caricati $successCount preventivi ($failCount non riusciti).',
            ),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
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
    } finally {
      if (mounted) setState(() => _isBulkUploading = false);
    }
  }

  Future<void> _uploadAndCreateQuote() async {
    try {
      final File? file = await _attachmentService.pickFile(context);
      if (file == null) return;

      final extracted = _extractDataFromPdf(file);
      if (!mounted) return;

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
    if (!mounted) return;
    final isEditing = existingQuote != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _QuoteFormDialog(
        initialFile: initialFile,
        initialData: initialData,
        existingQuote: existingQuote,
        nextSuggestedNumber: _quotes.length + 1,
        dbHelper: _dbHelper,
        attachmentService: _attachmentService,
      ),
    );

    if (saved == true && mounted) {
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

  // --- OPEN ORIGINAL PDF ---
  Future<void> _openPdf(Map<String, dynamic> quote) async {
    final localPath = quote['local_path']?.toString().trim() ?? '';
    final fileUrl = quote['file_url']?.toString().trim() ?? '';

    if (localPath.isEmpty && fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun file PDF associato a questo preventivo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // 1. Check local file first
      if (localPath.isNotEmpty &&
          !localPath.startsWith('http://') &&
          !localPath.startsWith('https://')) {
        final localFile = File(localPath);
        if (localFile.existsSync()) {
          await OpenFilex.open(localFile.path);
          return;
        }
      }

      if (fileUrl.isNotEmpty &&
          !fileUrl.startsWith('http://') &&
          !fileUrl.startsWith('https://')) {
        final fallbackLocal = File(fileUrl);
        if (fallbackLocal.existsSync()) {
          await OpenFilex.open(fallbackLocal.path);
          return;
        }
      }

      // 2. Launch URL safely via url_launcher (including Windows, preserving '&' tokens)
      final targetUrl = fileUrl.isNotEmpty ? fileUrl : localPath;
      final uri = Uri.tryParse(targetUrl);
      if (uri != null &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'file')) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }

      throw Exception(' Risorsa non trovata o non apribile');
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

  Future<void> _deleteQuote(String? rawId) async {
    final id = rawId?.trim() ?? '';
    if (id.isEmpty) return;

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

    if (confirm != true || !mounted) return;

    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Autenticazione fallita o annullata. Eliminazione annullata.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await _dbHelper.deleteQuote(id);
      if (mounted) {
        await _loadQuotes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore eliminazione preventivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                    // 1. TOP HEADER
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isMobile = constraints.maxWidth < 600;

                        final Widget title = RichText(
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

                        final Widget searchBar = Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16192B)
                                .withValues(alpha: 0.8),
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

                        final Widget btnBulk = OutlinedButton.icon(
                          onPressed:
                              _isBulkUploading ? null : _bulkUploadQuotes,
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

                        final Widget btnNew = ElevatedButton.icon(
                          onPressed: _uploadAndCreateQuote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22D3EE),
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: const Color(0xFF22D3EE)
                                .withValues(alpha: 0.5),
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

                        final Widget btnGoogleDocs = Tooltip(
                          message: 'Collega a Google Docs',
                          child: InkWell(
                            onTap: () async {
                              final uri = Uri.parse(
                                'https://docs.google.com/document/u/0/',
                              );
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.description,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
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

                    // 2. TABLE OF QUOTES
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF101322).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const double minTableWidth = 850.0;
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
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      PopupMenuButton<String>(
                                                    color: const Color(
                                                      0xFF16192B,
                                                    ),
                                                    offset:
                                                        const Offset(0, 30),
                                                    shape:
                                                        RoundedRectangleBorder(
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
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                                        _filterOptions
                                                            .map(
                                                              (s) =>
                                                                  PopupMenuItem(
                                                                value: s,
                                                                child: Text(
                                                                  s,
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        13,
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
                                          const SizedBox(width: 96),
                                        ],
                                      ),
                                    ),

                                    // Table Content (Single ListView in screen)
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
                                                color: Colors.white.withValues(
                                                  alpha: 0.04,
                                                ),
                                                height: 1,
                                              ),
                                              itemBuilder: (context, index) {
                                                final q = filtered[index];
                                                final isSelected =
                                                    _selectedQuote?['id'] ==
                                                        q['id'];
                                                final code = q['code']
                                                        ?.toString() ??
                                                    q['serial_number']
                                                        ?.toString() ??
                                                    'P-${index + 1}';
                                                final client =
                                                    _resolveQuoteClient(q);
                                                final date =
                                                    q['date']?.toString() ??
                                                        '-';
                                                final subject = q['subject']
                                                        ?.toString() ??
                                                    q['file_name']
                                                        ?.toString() ??
                                                    '-';
                                                final total =
                                                    _resolveQuoteTotal(q);

                                                return InkWell(
                                                  onTap: () {
                                                    setState(
                                                      () => _selectedQuote = q,
                                                    );
                                                    showDialog(
                                                      context: context,
                                                      builder: (dialogCtx) =>
                                                          Dialog(
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        insetPadding:
                                                            const EdgeInsets
                                                                .all(16),
                                                        child: ConstrainedBox(
                                                          constraints:
                                                              BoxConstraints(
                                                            maxWidth: 600,
                                                            maxHeight: MediaQuery
                                                                        .of(
                                                                      dialogCtx,
                                                                    )
                                                                        .size
                                                                        .height *
                                                                    0.88,
                                                          ),
                                                          child:
                                                              SingleChildScrollView(
                                                            child:
                                                                _buildFeaturedQuoteCard(
                                                              q,
                                                              dialogCtx,
                                                            ),
                                                          ),
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
                                                    padding: const EdgeInsets
                                                        .symmetric(
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
                                                                style:
                                                                    const TextStyle(
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
                                                                style:
                                                                    const TextStyle(
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
                                                              CurrencyUtils
                                                                  .formatEuro(
                                                                total,
                                                              ),
                                                              style:
                                                                  const TextStyle(
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
                                                                  q['id']
                                                                      ?.toString(),
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

  // --- DETAIL NEON CARD ---
  Widget _buildFeaturedQuoteCard(
    Map<String, dynamic> quote,
    BuildContext dialogContext,
  ) {
    final status = _normalizeQuoteStatus(quote);

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

    final code = quote['code']?.toString() ??
        quote['serial_number']?.toString() ??
        '-';
    final client = _resolveQuoteClient(quote);
    final date = quote['date']?.toString() ?? '-';
    final subject = quote['subject']?.toString().trim().isNotEmpty == true
        ? quote['subject'].toString()
        : (quote['file_name']?.toString() ?? '-');
    final total = _resolveQuoteTotal(quote);
    final subtotal = quote['subtotal'] != null
        ? CurrencyUtils.parseCurrency(quote['subtotal'].toString())
        : total;
    final tax = quote['tax_amount'] != null
        ? CurrencyUtils.parseCurrency(quote['tax_amount'].toString())
        : CurrencyUtils.roundMoney(
            (total - subtotal) > 0 ? (total - subtotal) : 0.0,
          );

    final List<dynamic> itemsList =
        quote['items'] is List ? List<dynamic>.from(quote['items']) : [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101322).withValues(alpha: 0.96),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Code, Client & Close button
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(dialogContext),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                      CurrencyUtils.formatEuro(total),
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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

          // 3. Items / Materials Box with live checkboxes
          Text(
            'Materiali / Voci (${itemsList.length})',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: itemsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Nessuna voce materiale registrata.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : Column(
                    children: itemsList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final map = entry.value is Map
                          ? Map<String, dynamic>.from(entry.value)
                          : <String, dynamic>{
                              'name': entry.value.toString(),
                              'qty': '1',
                              'checked': false,
                            };

                      return StatefulBuilder(
                        builder: (context, setStateItem) {
                          bool isChecked = map['checked'] == true ||
                              map['checked'] == 'true';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: isChecked,
                                    activeColor: Colors.tealAccent,
                                    onChanged: (val) async {
                                      final newChecked = val ?? false;
                                      setStateItem(() {
                                        map['checked'] = newChecked;
                                        isChecked = newChecked;
                                      });
                                      itemsList[idx] = map;
                                      quote['items'] = itemsList;
                                      if (quote['id'] != null) {
                                        try {
                                          await _dbHelper.updateQuote(quote);
                                        } catch (e) {
                                          debugPrint(
                                            'Errore salvataggio spunta materiale: $e',
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    map['name']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isChecked
                                          ? Colors.white38
                                          : Colors.white70,
                                      fontSize: 12,
                                      decoration: isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                        },
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
                CurrencyUtils.formatEuro(subtotal),
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
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                CurrencyUtils.formatEuro(tax),
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

          // 5. Actions Footer (Visualizza PDF, Modifica, Elimina)
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
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    final authorized =
                        await SecurityUtils.requireAdminAuth(context);
                    if (!authorized || !mounted) return;
                    await _showQuoteFormDialog(existingQuote: quote);
                  },
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
                  Navigator.pop(dialogContext);
                  _deleteQuote(quote['id']?.toString());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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

class _QuoteItemEntry {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  bool checked;
  final Map<String, dynamic> extraFields;

  _QuoteItemEntry({
    required String name,
    required String qty,
    required this.checked,
    Map<String, dynamic>? extra,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty),
        extraFields = extra != null ? Map<String, dynamic>.from(extra) : {};

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      ...extraFields,
      'name': nameCtrl.text.trim(),
      'qty': qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim(),
      'checked': checked,
    };
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _QuoteFormDialog extends StatefulWidget {
  final File? initialFile;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? existingQuote;
  final int nextSuggestedNumber;
  final DatabaseHelper dbHelper;
  final AttachmentService attachmentService;

  const _QuoteFormDialog({
    required this.initialFile,
    required this.initialData,
    required this.existingQuote,
    required this.nextSuggestedNumber,
    required this.dbHelper,
    required this.attachmentService,
  });

  @override
  State<_QuoteFormDialog> createState() => _QuoteFormDialogState();
}

class _QuoteFormDialogState extends State<_QuoteFormDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _subtotalCtrl;
  late final TextEditingController _taxCtrl;
  late String _status;
  final List<_QuoteItemEntry> _items = [];
  bool _isSaving = false;

  bool get _isEditing => widget.existingQuote != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingQuote;
    final init = widget.initialData;

    _codeCtrl = TextEditingController(
      text: existing?['code']?.toString() ??
          init?['code']?.toString() ??
          'N${widget.nextSuggestedNumber}-${DateFormat('yyyy').format(DateTime.now())}',
    );
    _clientCtrl = TextEditingController(
      text: (existing?['client_name'] ??
              existing?['client'] ??
              init?['client_name'] ??
              '')
          .toString(),
    );
    _dateCtrl = TextEditingController(
      text: (existing?['date'] ??
              init?['date'] ??
              DateFormat('dd/MM/yyyy').format(DateTime.now()))
          .toString(),
    );
    _subjectCtrl = TextEditingController(
      text: (existing?['subject'] ?? init?['subject'] ?? '').toString(),
    );

    final rawTotal =
        existing?['total_amount'] ?? existing?['total'] ?? init?['total'] ?? 0;
    final rawSub = existing?['subtotal'] ?? init?['subtotal'] ?? rawTotal;
    final rawTax = existing?['tax_amount'] ?? init?['tax'] ?? 0;

    _totalCtrl = TextEditingController(
      text: CurrencyUtils.formatNumber(
        CurrencyUtils.parseCurrency(rawTotal.toString()),
      ),
    );
    _subtotalCtrl = TextEditingController(
      text: CurrencyUtils.formatNumber(
        CurrencyUtils.parseCurrency(rawSub.toString()),
      ),
    );
    _taxCtrl = TextEditingController(
      text: CurrencyUtils.formatNumber(
        CurrencyUtils.parseCurrency(rawTax.toString()),
      ),
    );

    _status = _QuotesScreenState._normalizeQuoteStatus(existing);

    // Preserve checked state for BOTH existingQuote and initialData!
    final dynamic rawItems = existing?['items'] ?? init?['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      for (final e in rawItems) {
        if (e is Map) {
          final extra = Map<String, dynamic>.from(e)
            ..remove('name')
            ..remove('qty')
            ..remove('checked');
          _items.add(
            _QuoteItemEntry(
              name: e['name']?.toString() ?? '',
              qty: e['qty']?.toString() ?? '1',
              checked: e['checked'] == true || e['checked'] == 'true',
              extra: extra,
            ),
          );
        } else if (e != null) {
          _items.add(
            _QuoteItemEntry(
              name: e.toString(),
              qty: '1',
              checked: false,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _clientCtrl.dispose();
    _dateCtrl.dispose();
    _subjectCtrl.dispose();
    _totalCtrl.dispose();
    _subtotalCtrl.dispose();
    _taxCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final existing = widget.existingQuote;
      String? fileUrl = existing?['file_url']?.toString();
      final String fileName = existing?['file_name']?.toString() ??
          (widget.initialFile != null
              ? p.basename(widget.initialFile!.path)
              : 'preventivo.pdf');

      if (widget.initialFile != null && !_isEditing) {
        try {
          fileUrl = await widget.attachmentService.uploadAttachment(
            widget.initialFile!,
            'quotes',
          );
        } catch (e) {
          debugPrint('Upload allegato preventivo non riuscito (uso locale): $e');
        }
      }

      final parsedSubtotal = CurrencyUtils.parseCurrency(_subtotalCtrl.text);
      final parsedTax = CurrencyUtils.parseCurrency(_taxCtrl.text);
      final parsedTotal = CurrencyUtils.parseCurrency(_totalCtrl.text);

      final serializedItems = _items
          .map((e) => e.toMap())
          .where((m) => (m['name']?.toString().isNotEmpty == true))
          .toList();

      final quoteData = <String, dynamic>{
        ...?existing,
        'code': _codeCtrl.text.trim(),
        'client_name': _clientCtrl.text.trim(),
        'date': _dateCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim(),
        'status': _status,
        'accepted': _status == 'Accettato',
        'rejected': _status == 'Rifiutato',
        'items': serializedItems,
        'subtotal': parsedSubtotal,
        'tax_amount': parsedTax,
        'total_amount': parsedTotal,
        'total': parsedTotal,
        'file_name': fileName,
        'file_url': fileUrl ?? widget.initialFile?.path ?? '',
        'local_path':
            widget.initialFile?.path ?? existing?['local_path'] ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        quoteData['id'] = existing!['id'];
        await widget.dbHelper.updateQuote(quoteData);
      } else {
        // Omit serial_number so DatabaseHelper.insertQuote assigns atomic sequential counter
        quoteData.remove('serial_number');
        quoteData['created_at'] = DateTime.now().toIso8601String();
        await widget.dbHelper.insertQuote(quoteData);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore salvataggio preventivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
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
          enabled: !_isSaving,
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

  @override
  Widget build(BuildContext context) {
    final statusDefinitions = const [
      {'status': 'Inviato', 'color': Colors.blueAccent},
      {'status': 'Accettato', 'color': Colors.greenAccent},
      {'status': 'In Revisione', 'color': Colors.orangeAccent},
      {'status': 'Bozza', 'color': Colors.purpleAccent},
      {'status': 'Rifiutato', 'color': Colors.redAccent},
    ];
    final safeStatus = _QuotesScreenState._quoteStatuses.contains(_status)
        ? _status
        : 'Inviato';

    return Dialog(
      backgroundColor: const Color(0xFF131722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing
                            ? 'Modifica Preventivo'
                            : 'Nuovo Preventivo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context, false),
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
                        _codeCtrl,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField('Data (dd/MM/yyyy)', _dateCtrl),
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
                        _clientCtrl,
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: safeStatus,
                                dropdownColor: const Color(0xFF1E2235),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                isExpanded: true,
                                items: statusDefinitions.map((item) {
                                  final s = item['status'] as String;
                                  final c = item['color'] as Color;
                                  return DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(
                                      s,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: c,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() => _status = val);
                                        }
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
                  _subjectCtrl,
                ),
                const SizedBox(height: 16),

                // Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Materiali / Voci (${_items.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _items.add(
                                  _QuoteItemEntry(
                                    name: '',
                                    qty: '1',
                                    checked: false,
                                  ),
                                );
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
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    key: ObjectKey(item),
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.checked,
                          activeColor: Colors.tealAccent,
                          onChanged: _isSaving
                              ? null
                              : (val) {
                                  setState(() {
                                    item.checked = val ?? false;
                                  });
                                },
                        ),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: item.nameCtrl,
                            enabled: !_isSaving,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Materiale (Audio, Luci, Strutture...)',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: item.qtyCtrl,
                            enabled: !_isSaving,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Q.tà',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    final removed = _items.removeAt(idx);
                                    removed.dispose();
                                  });
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
                        _subtotalCtrl,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'IVA (€)',
                        _taxCtrl,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Totale (€)',
                        _totalCtrl,
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
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context, false),
                      child: const Text(
                        'Annulla',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
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
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isEditing ? 'Salva Modifiche' : 'Crea Preventivo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
