import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I will write a regex to replace everything between Widget build(BuildContext context) { and oid _showCustomerSearchDialog

new_build = '''  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInvoices;

    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Fatture',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Esporta Report PDF',
            onPressed: () {
              final theme = context.read<AppThemeProvider>();
              _exportPdfReport(filtered, theme.dateFormat, "Tutte le date");
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Ordina per',
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
                _loadData();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'Numero (Decrescente)', child: Text('Numero (Decrescente)', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'Numero (Crescente)', child: Text('Numero (Crescente)', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'Data Piu Recente', child: Text('Data Più Recente', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'Data Meno Recente', child: Text('Data Meno Recente', style: TextStyle(color: Colors.white))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3. MAIN GLASS CONTAINER
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16192B).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // TABLE HEADER
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  border: Border(bottom: BorderAction()), // We will replace BorderAction
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Row(
                                  children: [
                                    _buildHeaderCell('Numero', flex: 2),
                                    _buildHeaderCell('Cliente', flex: 3),
                                    _buildHeaderCell('Data', flex: 2),
                                    _buildHeaderCell('Importo', flex: 2, isNumeric: true),
                                    _buildHeaderCell('Stato', flex: 2, isNumeric: true),
                                    _buildHeaderCell('Azioni', flex: 1, isNumeric: true),
                                  ],
                                ),
                              ),

                              // LIST CONTENT
                              filtered.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(40),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Nessuna fattura trovata',
                                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                      itemBuilder: (context, index) {
                                        final invoice = filtered[index];
                                        final isPaid = invoice['status'] == 'Incassata';
                                        
                                        return InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => InvoiceSummaryScreen(invoiceId: invoice['id']),
                                              ),
                                            ).then((_) => _loadData());
                                          },
                                          hoverColor: Colors.white.withOpacity(0.02),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    invoice['number']?.toString() ?? '',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    invoice['customer_name']?.toString() ?? '',
                                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    invoice['date']?.toString() ?? '',
                                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
                                                      "€ " + (invoice['total'] ?? 0.0).toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: (isPaid ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: (isPaid ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        isPaid ? 'Incassata' : 'Da Incassare',
                                                        style: TextStyle(
                                                          color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: PopupMenuButton<String>(
                                                      icon: Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.5), size: 20),
                                                      color: const Color(0xFF16192B),
                                                      onSelected: (val) async {
                                                        if (val == 'edit') {
                                                          _showInvoiceDialog(invoice);
                                                        } else if (val == 'delete') {
                                                          bool? conf = await showDialog<bool>(
                                                            context: context,
                                                            builder: (c) => AlertDialog(
                                                              backgroundColor: const Color(0xFF16192B),
                                                              title: const Text('Conferma', style: TextStyle(color: Colors.white)),
                                                              content: const Text('Eliminare la fattura?', style: TextStyle(color: Colors.white70)),
                                                              actions: [
                                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
                                                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Elimina', style: TextStyle(color: Colors.redAccent))),
                                                              ],
                                                            ),
                                                          );
                                                          if (conf == true) {
                                                            await _dbHelper.deleteInvoice(invoice['id']);
                                                            _loadData();
                                                          }
                                                        }
                                                      },
                                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                                        const PopupMenuItem<String>(value: 'edit', child: Text('Modifica', style: TextStyle(color: Colors.white))),
                                                        const PopupMenuItem<String>(value: 'delete', child: Text('Elimina', style: TextStyle(color: Colors.redAccent))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
'''

new_build = new_build.replace("BorderAction()", "BorderSide(color: Colors.white.withOpacity(0.08))")

start_idx = content.find("  @override\n  Widget build(BuildContext context) {")
if start_idx == -1:
    start_idx = content.find("  Widget build(BuildContext context) {")
end_idx = content.find("  void _showCustomerSearchDialog")
if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + new_build + "\n" + content[end_idx:]
    
    # We must also remove _buildTopHeaderBar which was generated earlier!
    # Let's just find Widget _buildTopHeaderBar() and remove it and its body up to // Helper
    pattern_header = r'  Widget _buildTopHeaderBar\(\) \{.*?(?=  Widget _buildHeaderCell)'
    new_content = re.sub(pattern_header, '', new_content, flags=re.DOTALL)
    
    # Also replace .withOpacity with .withValues(alpha:  to fix deprecation warnings!
    new_content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', new_content)

    with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("INVOICES PATCHED")
