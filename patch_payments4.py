import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r'child: Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*// 1\. TOP HEADER BAR.*?_buildTopHeaderBar\(\),\s*const SizedBox\(height: 28\),\s*// 2\. PAGE TITLE\s*Row\(\s*mainAxisAlignment: MainAxisAlignment\.spaceBetween,\s*crossAxisAlignment: CrossAxisAlignment\.end,\s*children: \[\s*const Text\(\s*\'Movimenti\'.*?// Quick Action Buttons\s*Row\(\s*children: \[\s*IconButton\(\s*icon: const Icon\(Icons\.print_outlined, color: Color\(0xFF38BDF8\), size: 22\),\s*tooltip: \'Esporta Report PDF\',\s*onPressed: _exportPdfReport,\s*\),\s*\]\,\s*\),\s*\]\,\s*\),\s*const SizedBox\(height: 22\),\s*// 3\. MAIN GLASS CONTAINER: "Transactions Overview"\s*Expanded\('

new_layout = '''child: NestedScrollView(
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
                  body: '''

content = re.sub(pattern, new_layout, content, flags=re.DOTALL)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
