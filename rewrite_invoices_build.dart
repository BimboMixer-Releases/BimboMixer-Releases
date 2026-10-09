import 'dart:io';

void main() {
  final file = File('lib/screens/invoices_screen.dart');
  String content = file.readAsStringSync();

  final buildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {');
  if (buildStart == -1) {
    print('Could not find build method (with @override)');
    // Try without @override just in case
    final altStart = content.indexOf('  Widget build(BuildContext context) {');
    if (altStart == -1) {
      print('Could not find build method');
      return;
    }
  }
  
  // Find the end of build method
  // We know there's `void _showCustomerSearchDialog` after it.
  final endMarker = 'void _showCustomerSearchDialog';
  final endOfBuild = content.indexOf(endMarker);
  
  if (endOfBuild == -1) {
    print('Could not find end of build method');
    return;
  }
  
  // Actually, we want to replace from buildStart to endOfBuild
  // Wait, let's just find `Widget build(BuildContext context) {` using regex and replace everything up to `void _showCustomerSearchDialog`
  
  final newBuildMethod = r'''  Widget _buildTopHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bentornato,',
              style: TextStyle(
                color: const Color(0xFF38BDF8).withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Admin AXION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
              ),
              child: const Icon(Icons.search, color: Colors.white70, size: 20),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
              ),
              child: const Icon(Icons.notifications_none, color: Colors.white70, size: 20),
            ),
            const SizedBox(width: 16),
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('AX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final filtered = _filteredInvoices;

    return GradientScaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP HEADER BAR
                    _buildTopHeaderBar(),

                    const SizedBox(height: 28),

                    // 2. PAGE TITLE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Fatture',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Quick Action Buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 22),
                              tooltip: 'Esporta Report PDF',
                              onPressed: () {
                                _exportPdfReport(
                                  _filteredInvoices,
                                  theme.dateFormat,
                                  "Tutte le date",
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showInvoiceDialog();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEC4899),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(0xFFEC4899).withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              label: const Text('Nuova Fattura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // 3. MAIN GLASS CONTAINER
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF13141F).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.15), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.05), blurRadius: 20, spreadRadius: -5),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Filter / Summary Row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B).withOpacity(0.5),
                                  border: Border(bottom: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.1))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF38BDF8).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.receipt_long, color: Color(0xFF38BDF8), size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${filtered.length} Fatture trovate',
                                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.sort, color: Color(0xFF38BDF8), size: 22),
                                          tooltip: 'Ordina',
                                          color: const Color(0xFF16192B),
                                          onSelected: (val) {
                                            setState(() {
                                              if (val == 'Numero (Decrescente)') {
                                                _sortType = InvoiceSortType.number;
                                                _sortAscending = false;
                                              } else if (val == 'Numero (Crescente)') {
                                                _sortType = InvoiceSortType.number;
                                                _sortAscending = true;
                                              } else if (val == 'Data Piu Recente') {
                                                _sortType = InvoiceSortType.date;
                                                _sortAscending = false;
                                              } else if (val == 'Data Meno Recente') {
                                                _sortType = InvoiceSortType.date;
                                                _sortAscending = true;
                                              }
                                            });
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'Numero (Decrescente)', child: Text('Numero (Decrescente)', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem(value: 'Numero (Crescente)', child: Text('Numero (Crescente)', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem(value: 'Data Piu Recente', child: Text('Data Più Recente', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem(value: 'Data Meno Recente', child: Text('Data Meno Recente', style: TextStyle(color: Colors.white))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.euro_symbol, color: Color(0xFF10B981), size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            CurrencyUtils.formatCurrency(filtered.fold(0.0, (sum, i) {
                                              return sum + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0);
                                            })),
                                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                color: const Color(0xFF0F172A).withOpacity(0.6),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: _tableHeader('NUMERO')),
                                    Expanded(flex: 4, child: _tableHeader('CLIENTE')),
                                    Expanded(flex: 3, child: _tableHeader('DATA')),
                                    Expanded(flex: 3, child: _tableHeader('IMPORTO')),
                                    Expanded(flex: 3, child: _tableHeader('STATO')),
                                    const SizedBox(width: 100, child: Center(child: Text('AZIONI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)))),
                                  ],
                                ),
                              ),

                              // Table Body
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.1)),
                                            const SizedBox(height: 16),
                                            Text('Nessuna fattura trovata', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        itemCount: filtered.length,
                                        separatorBuilder: (context, index) => Divider(color: const Color(0xFF38BDF8).withOpacity(0.05), height: 1),
                                        itemBuilder: (context, index) {
                                          final invoice = filtered[index];
                                          final isPaid = invoice['status'] == 'PAID';
                                          final isLate = invoice['status'] == 'LATE';
                                          
                                          final numFattura = invoice['number']?.toString() ?? '-';
                                          final dataStr = DateUtilsApp.formatDbDate(invoice['date']?.toString(), theme.dateFormat);
                                          final amountVal = double.tryParse(invoice['amount']?.toString() ?? '0') ?? 0;
                                          
                                          final customer = _getCustomer(invoice['customer_id']?.toString());
                                          final customerName = customer?['name'] ?? 'Sconosciuto';
                                          
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

                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => InvoiceSummaryScreen(
                                                      invoiceId: invoice['id'].toString(),
                                                      onEdit: (invoiceData) {
                                                        _showInvoiceDialog(invoice: invoiceData, isReadOnly: false);
                                                      },
                                                    ),
                                                  ),
                                                ).then((_) => _loadData());
                                              },
                                              hoverColor: const Color(0xFF38BDF8).withOpacity(0.05),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                child: Row(
                                                  children: [
                                                    // Numero
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        numFattura,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),

                                                    // Cliente
                                                    Expanded(
                                                      flex: 4,
                                                      child: Tooltip(
                                                        message: customerDetails,
                                                        child: Text(
                                                          customerName,
                                                          style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 13,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                    
                                                    // Data
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        dataStr,
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),

                                                    // Importo
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        CurrencyUtils.formatCurrency(amountVal),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ),

                                                    // Status Neon Badge
                                                    Expanded(
                                                      flex: 3,
                                                      child: Center(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: isPaid
                                                                ? const Color(0xFF10B981).withOpacity(0.12)
                                                                : isLate
                                                                    ? const Color(0xFFEF4444).withOpacity(0.12)
                                                                    : const Color(0xFFF59E0B).withOpacity(0.12),
                                                            borderRadius: BorderRadius.circular(20),
                                                            border: Border.all(
                                                              color: isPaid
                                                                  ? const Color(0xFF10B981)
                                                                  : isLate
                                                                      ? const Color(0xFFEF4444)
                                                                      : const Color(0xFFF59E0B),
                                                              width: 1.4,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: (isPaid
                                                                        ? const Color(0xFF10B981)
                                                                        : isLate
                                                                            ? const Color(0xFFEF4444)
                                                                            : const Color(0xFFF59E0B))
                                                                    .withOpacity(0.45),
                                                                blurRadius: 10,
                                                                spreadRadius: 0.5,
                                                              ),
                                                            ],
                                                          ),
                                                          child: Text(
                                                            isPaid ? 'Incassata' : isLate ? 'In Ritardo' : 'Da Incassare',
                                                            style: TextStyle(
                                                              color: isPaid
                                                                  ? const Color(0xFF10B981)
                                                                  : isLate
                                                                      ? const Color(0xFFEF4444)
                                                                      : const Color(0xFFF59E0B),
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              letterSpacing: 1.0,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),

                                                    // Action Column: Edit/Delete
                                                    SizedBox(
                                                      width: 100,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.edit, color: Color(0xFF38BDF8), size: 20),
                                                            constraints: const BoxConstraints(),
                                                            padding: const EdgeInsets.all(8),
                                                            onPressed: () async {
                                                              final authorized = await SecurityUtils.requireAdminAuth(context);
                                                              if (authorized && mounted) {
                                                                _showInvoiceDialog(invoice: invoice, isReadOnly: false);
                                                              }
                                                            },
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEC4899), size: 20),
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
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tableHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF94A3B8), // Slate 400
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
''';

  final buildStartIndex = content.indexOf('  @override\n  Widget build(BuildContext context) {') != -1 
      ? content.indexOf('  @override\n  Widget build(BuildContext context) {')
      : content.indexOf('  Widget build(BuildContext context) {');
      
  final contentBefore = content.substring(0, buildStartIndex);
  final contentAfter = content.substring(endOfBuild);
  
  final newContent = contentBefore + newBuildMethod + '\n  ' + contentAfter;
  
  file.writeAsStringSync(newContent);
  print('Invoices screen rewrite complete.');
}
