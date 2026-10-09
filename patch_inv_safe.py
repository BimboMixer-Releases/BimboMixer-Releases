import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace GradientScaffold(body: _isLoading...) with the AppBar version.
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

# 2. Remove _buildTopHeaderBar and the PAGE TITLE Row from the build method layout
pattern = r'// 1\. TOP HEADER.*?// 3\. MAIN GLASS CONTAINER'
content = re.sub(pattern, r'// 3. MAIN GLASS CONTAINER', content, flags=re.DOTALL)

# 3. Fix the Scroll Bug by replacing NestedScrollView with SingleChildScrollView
nested_scroll_pattern = r'''                child: NestedScrollView\(
                  headerSliverBuilder: \(context, innerBoxIsScrolled\) => \[
                    SliverToBoxAdapter\(
                      child: Column\(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: \['''

replacement = r'''                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ['''

content = re.sub(nested_scroll_pattern, replacement, content, flags=re.DOTALL)

# Because we removed NestedScrollView's headerSliverBuilder, we must remove its closing bracket.
# The NestedScrollView body was:
#                       ),
#                     ),
#                   ],
#                   body: Container(

content = content.replace('''                      ),
                    ),
                  ],
                  body: Container(''', '''                      ),
                    Container(''')

# 4. Remove all Expanded around the widgets in the build method.
content = re.sub(r'Expanded\(\s*child: Container\(', r'Container(', content, 1)
content = re.sub(r'Expanded\(\s*child: filtered\.isEmpty', r'filtered.isEmpty', content, 1)
content = re.sub(r'Expanded\(\s*child: ListView\.builder\(', r'ListView.builder(', content, 1)
content = re.sub(r'ListView\.builder\(\s*itemCount: filtered\.length,', r'ListView.builder(\n                                                      shrinkWrap: true,\n                                                      physics: const NeverScrollableScrollPhysics(),\n                                                      itemCount: filtered.length,', content, 1)


with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
