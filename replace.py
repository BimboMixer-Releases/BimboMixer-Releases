def replace_between(filename, start_marker, end_marker, new_content):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker, start_idx) + len(end_marker)
    
    if start_idx != -1 and end_idx != -1:
        new_text = content[:start_idx] + new_content + content[end_idx:]
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(new_text)
        print(f"Replaced in {filename}")
    else:
        print(f"Not found in {filename}")

import sys

payments = 'lib/screens/payments_screen.dart'
invoices = 'lib/screens/invoices_screen.dart'

start_marker = "child: NestedScrollView("
end_marker = "body: Container("

new_content = '''child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Column(
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
                      Container('''

replace_between(payments, start_marker, end_marker, new_content)

new_content_inv = new_content.replace('Movimenti', 'Fatture')
replace_between(invoices, start_marker, end_marker, new_content_inv)
