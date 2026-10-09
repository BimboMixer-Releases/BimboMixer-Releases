import re

with open('rewrite_invoices_build.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. We replace GradientScaffold(\n        body: _isLoading with GradientScaffold(\n        appBar: AppBar( ... ),\n        body: _isLoading
app_bar_str = '''    return GradientScaffold(
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
              // Get theme using Provider or ignore if not available
              _exportPdfReport(_filteredInvoices, 'dd/MM/yyyy', "Tutte le date");
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
      body: _isLoading'''

content = content.replace('    return GradientScaffold(\n        body: _isLoading', app_bar_str)

# 2. We remove NestedScrollView completely, replacing it with SingleChildScrollView.
# And we remove the 3 Expanded widgets.
# Let's extract the new build string and rewrite it exactly as we want.

