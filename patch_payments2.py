import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_layout = '''                  child: CustomScrollView(
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

good_layout = '''                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopHeaderBar(),
                            const SizedBox(height: 28),
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
                    ],
                    body:'''

content = content.replace(bad_layout, good_layout)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
