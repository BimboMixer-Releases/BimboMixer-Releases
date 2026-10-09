p = 'lib/screens/invoices_screen.dart'
s = open(p, encoding='utf-8', newline='').read()

a = s.index('  @override\r\n  Widget _buildTopHeaderBar()')
b = s.index('  Widget _tableHeader(String title)')

new = r'''  // ---- Filtri / ordinamento ----
  String _statusFilter = 'Tutte';
  Map<String, dynamic>? _dateRange;
  String _sortMode = 'Data Piu Recente';

  List<Map<String, dynamic>> get _filteredInvoices {
    var list = _invoices.where((i) {
      final st = i['status']?.toString();
      if (_statusFilter == 'Da Incassare' && st == 'PAID') return false;
      if (_statusFilter == 'Incassata' && st != 'PAID') return false;
      if (_dateRange != null) {
        final d = i['date']?.toString();
        if (d != null && d.isNotEmpty && !ReportUtils.isDateInRange(d, _dateRange)) return false;
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
    await PdfReportService.generateAndDownloadReport(
      title: 'Report Fatture',
      headers: ['Numero', 'Cliente', 'Data', 'Importo', 'Stato'],
      data: data,
      dateRangeText: _dateRange == null ? 'Tutte le date' : ReportUtils.formatDateRangeText(_dateRange, dateFormat),
      dateFormatString: dateFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final filtered = _filteredInvoices;
    final total = filtered.fold<double>(0.0, (sum, i) => sum + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0));

    return GradientScaffold(
      appBar: AppBar(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    );
  }

  Widget _buildInvoiceRow(Map<String, dynamic> invoice, String dateFormat) {
    final isPaid = invoice['status'] == 'PAID';
    final isLate = invoice['status'] == 'LATE';
    final color = isPaid ? const Color(0xFF10B981) : isLate ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final amountVal = double.tryParse(invoice['amount']?.toString() ?? '0') ?? 0;
    final customer = _getCustomer(invoice['customer_id']?.toString());
    final customerName = customer?['name']?.toString() ?? 'Sconosciuto';
    return Material(
      color: const Color(0xFF13141F).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceSummaryScreen(
                invoiceId: invoice['id'].toString(),
                onEdit: (invoiceData) => _showInvoiceDialog(invoice: invoiceData, isReadOnly: false),
              ),
            ),
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
                    Text(invoice['number']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis,
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
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color, width: 1.2),
                    ),
                    child: Text(isPaid ? 'Incassata' : isLate ? 'In Ritardo' : 'Da Incassare',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF38BDF8), size: 20),
                onPressed: () async {
                  final authorized = await SecurityUtils.requireAdminAuth(context);
                  if (authorized && mounted) _showInvoiceDialog(invoice: invoice, isReadOnly: false);
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

'''.replace('\n', '\r\n')

s = s[:a] + new + s[b:]
s = s.replace("import '../utils/report_utils.dart';",
  "import '../utils/report_utils.dart';\r\nimport '../utils/currency_utils.dart';\r\nimport '../widgets/gradient_scaffold.dart';")
open(p, 'w', encoding='utf-8', newline='').write(s)
print('ok')
