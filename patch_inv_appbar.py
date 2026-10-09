import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

appbar_scaffold = '''    return GradientScaffold(
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
              _exportPdfReport(_filteredInvoices, theme.dateFormat, "Tutte le date");
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

content = content.replace('    return GradientScaffold(\n      body: _isLoading', appbar_scaffold)

# Now remove the NestedScrollView structure completely and replace with SingleChildScrollView.
nested_scroll_pattern = r'''                child: NestedScrollView\(
                  headerSliverBuilder: \(context, innerBoxIsScrolled\) => \[
                    SliverToBoxAdapter\(
                      child: Column\(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: \[
.*?
                        \],
                      \),
                    \),
                  \],
                  body: Container\('''

replacement = r'''                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container('''

content = re.sub(nested_scroll_pattern, replacement, content, flags=re.DOTALL)

# Now fix the end braces because we removed NestedScrollView and changed body: Container( to child: Container(
# But wait, body: Container( was closed with ), and then ],),),), ?
# The end of the old build method was:
'''                      ),
                    ),
                  ],
                ),
              ),
            ),
    );'''
# We replaced NestedScrollView -> SingleChildScrollView. We deleted headerSliverBuilder.
# NestedScrollView had ody: Container(.
# SingleChildScrollView has child: Container(.
# The closing braces for NestedScrollView was ), // body Container \n ), // NestedScrollView
# SingleChildScrollView has ), // child Container \n ), // SingleChildScrollView
# The brace count is EXACTLY THE SAME!

# Now remove the Expanded widgets that restrict height
content = re.sub(r'Expanded\(\s*child: InkWell\(', r'InkWell(', content)
content = re.sub(r'Expanded\(\s*child: Container\(', r'Container(', content)
content = re.sub(r'Expanded\(\s*child: filtered\.isEmpty', r'filtered.isEmpty', content)
content = re.sub(r'Expanded\(\s*child: ListView\.builder\(', r'ListView.builder(', content)
content = re.sub(r'ListView\.builder\(\s*itemCount: filtered\.length,', r'ListView.builder(\n                                                      shrinkWrap: true,\n                                                      physics: const NeverScrollableScrollPhysics(),\n                                                      itemCount: filtered.length,', content)

# But wait, we removed multiple Expanded. We must remove their closing braces!
# We removed:
# 1. Expanded around Container(
# 2. Expanded around filtered.isEmpty
# 3. Expanded around ListView.builder(
# 4. Expanded around InkWell( (for the rows!)

# This is too dangerous with regex because we don't know the exact closing braces.
