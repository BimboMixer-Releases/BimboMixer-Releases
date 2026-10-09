import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I will replace the outer Column with a CustomScrollView
# We need to find the Expanded that wraps the Container.
old_layout = '''                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. TOP HEADER BAR: Welcome, User | Search | Notifications | AXION Logo
                      _buildTopHeaderBar(),
  
                      const SizedBox(height: 28),
  
                      // 2. PAGE TITLE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Movimenti',
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
                                onPressed: _exportPdfReport,
                              ),
                              
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                      Expanded('''

new_layout = '''                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
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
                                const Text('Movimenti', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 22),
                                      tooltip: 'Esporta Report PDF',
                                      onPressed: _exportPdfReport,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                          ],
                        ),
                      ),
                      // 3. MAIN GLASS CONTAINER
                      SliverFillRemaining(
                        hasScrollBody: true,
                        fillOverscroll: true,'''

content = content.replace(old_layout, new_layout)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
