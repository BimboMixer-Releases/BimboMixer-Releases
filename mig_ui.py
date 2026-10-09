# -*- coding: utf-8 -*-
import sys

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('Padding(\n                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),')
if start_idx == -1:
    print('Start not found')
    sys.exit(1)

end_str = '                            // Table Area with Horizontal Scroll for Mobile'
end_idx = content.find(end_str, start_idx)
if end_idx == -1:
    print('End not found')
    sys.exit(1)

target = content[start_idx:end_idx]

replacement = '''Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Riepilogo Movimenti',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildStatusFilterChip('Tutti'),
                                            _buildStatusFilterChip('Saldato'),
                                            _buildStatusFilterChip('In Attesa'),
                                            _buildStatusFilterChip('Entrate'),
                                            _buildStatusFilterChip('Uscite'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      // Three Dots Menu
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 22),
                                        color: const Color(0xFF16192B),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        onSelected: (action) {
                                          if (action == 'export_pdf') {
                                            _exportPdfReport();
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'export_pdf',
                                            child: Text('Esporta PDF (Filtri)', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      PopupMenuButton<String>(
                                        tooltip: 'Ordina',
                                        color: const Color(0xFF16192B),
                                        icon: const Icon(Icons.swap_vert, color: Color(0xFF38BDF8), size: 22),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        onSelected: (v) => setState(() => _sortType = v),
                                        itemBuilder: (ctx) => [
                                          for (final s in ['Data Piu Recente', 'Data Meno Recente', 'Importo Maggiore', 'Importo Minore'])
                                            PopupMenuItem(
                                              value: s,
                                              child: Text(s, style: TextStyle(color: s == _sortType ? const Color(0xFF38BDF8) : Colors.white)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

'''

content = content[:start_idx] + replacement + content[end_idx:]

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done payments screen!')
