# -*- coding: utf-8 -*-
import sys

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to replace the Column inside SafeArea -> Padding with a NestedScrollView.
# Wait, the structure is:
#             : SafeArea(
#                 child: Padding(
#                   padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
#                   child: Column(
#                     crossAxisAlignment: CrossAxisAlignment.start,
#                     children: [

old_layout_start = '''            : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
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


new_layout_start = '''            : SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 24.0),
                      child: Column(
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
                        ],
                      ),
                    ),
                  ),
                ],
                body: Padding(
                  padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 24.0),
                  child: '''

content = content.replace(old_layout_start, new_layout_start)

# Now we need to remove the closing brackets for the old Padding and Column.
# Wait, let's see how it ends.
# The Expanded ends at some point, and then we have:
#                   ],
#                 ),
#               ),
#             ),

old_layout_end = '''                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }'''

new_layout_end = '''                      ),
                ),
              ),
            ),
    );
  }'''

content = content.replace(old_layout_end, new_layout_end)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Payments screen layout fixed for NestedScrollView.")
