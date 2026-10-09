import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to change GradientScaffold to include an AppBar.
# Find GradientScaffold(
gradient_scaffold_replacement = '''    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Movimenti',
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
            onPressed: _exportPdfReport,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Filtra per stato',
            color: const Color(0xFF16192B),
            onSelected: (val) {
              setState(() {
                _statusFilter = val;
                _loadPayments();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'Tutti', child: Text('Tutti', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'Saldato', child: Text('Saldato', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'In Attesa', child: Text('In Attesa', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'Entrate', child: Text('Entrate', style: TextStyle(color: Colors.white))),
              const PopupMenuItem<String>(value: 'Uscite', child: Text('Uscite', style: TextStyle(color: Colors.white))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading'''

content = content.replace('    return GradientScaffold(\n      body: _isLoading', gradient_scaffold_replacement)

# Now we must REMOVE the old _buildTopHeaderBar() and the PAGE TITLE block.
# Let's use a regex to match from _buildTopHeaderBar() down to the end of the PAGE TITLE Row.
# The area looks like:
'''                      // 1. TOP HEADER BAR: Welcome, User | Search | Notifications | AXION Logo
                      _buildTopHeaderBar(),

                      const SizedBox(height: 28),

                      // 2. PAGE TITLE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Invoices & Transactions',
...
                        ],
                      ),

                      const SizedBox(height: 22),'''

# We will just write a specific regex to remove everything from "// 1. TOP HEADER BAR" to "// 3. MAIN GLASS CONTAINER"
pattern = r'// 1\. TOP HEADER BAR.*?// 3\. MAIN GLASS CONTAINER'
content = re.sub(pattern, r'// 3. MAIN GLASS CONTAINER', content, flags=re.DOTALL)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Payments screen patched")
