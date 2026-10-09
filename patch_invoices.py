# -*- coding: utf-8 -*-
with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_start = '''                child: Column(
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
                              onPressed: _exportPdfReport,
                            ),
                            
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                    Expanded('''

good_start = '''                child: NestedScrollView(
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
                              const Text('Fatture', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
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
                  body: Container('''

bad_end = '''                      ),
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
  }'''

good_end = '''                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }'''

if bad_start in content:
    content = content.replace(bad_start, good_start)
    
if bad_end in content:
    content = content.replace(bad_end, good_end)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
