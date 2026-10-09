# -*- coding: utf-8 -*-
import sys
import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_sort_btn = '''          PopupMenuButton<String>(
            tooltip: 'Ordina',
            color: const Color(0xFF16192B),
            icon: const Icon(Icons.swap_vert, color: Colors.blueAccent, size: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            onSelected: (v) => setState(() => _sortType = v),
            itemBuilder: (ctx) => [
              for (final s in ['Data Piu Recente', 'Data Meno Recente', 'Importo Maggiore', 'Importo Minore'])
                PopupMenuItem(
                  value: s,
                  child: Text(s, style: TextStyle(color: s == _sortType ? Colors.blueAccent : Colors.white)),
                ),
            ],
          ),
          ],'''

content = re.sub(r'IconButton\(\s*icon: Icon\(Icons\.add, color: Colors\.blueAccent\),\s*onPressed: \(\) => _showInvoiceDialog\(\)\)\s*\]\,', new_sort_btn, content)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
