import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add SharedPreferences import
content = content.replace('import ''package:flutter/material.dart'';', 'import ''package:flutter/material.dart'';\nimport ''package:shared_preferences/shared_preferences.dart'';')

# 2. Add SharedPreferences logic to initState and onPressed
init_state_target = '''  void initState() {
    super.initState();
    _loadData();'''

init_state_replacement = '''  void initState() {
    super.initState();
    _loadPrefsAndData();
  }

  Future<void> _loadPrefsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortAscending = prefs.getBool('payments_sort_ascending') ?? false;
    });
    _loadData();'''

content = content.replace(init_state_target, init_state_replacement)

on_pressed_target = '''onPressed: () { setState(() { _sortAscending = !_sortAscending; }); }'''

on_pressed_replacement = '''onPressed: () async { 
                                            final newValue = !_sortAscending;
                                            setState(() { _sortAscending = newValue; }); 
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.setBool('payments_sort_ascending', newValue);
                                          }'''

content = content.replace(on_pressed_target, on_pressed_replacement)

# 3. Add try/catch and SnackBar to _downloadSinglePayment
download_target = '''      await PDFReportService.generateAndDownloadReport(
        title: 'Dettaglio Movimento',
        headers: ['Campo', 'Valore'],
        data: [
          ['Data', dt],
          ['Cliente', cliente],
          ['Descrizione', descr],
          ['Importo', imp],
          ['Tipo', tipo],
          ['Metodo', metodo],
        ],
      );'''

download_replacement = '''      try {
        await PDFReportService.generateAndDownloadReport(
          title: 'Dettaglio Movimento',
          headers: ['Campo', 'Valore'],
          data: [
            ['Data', dt],
            ['Cliente', cliente],
            ['Descrizione', descr],
            ['Importo', imp],
            ['Tipo', tipo],
            ['Metodo', metodo],
          ],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generato e scaricato con successo.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore durante il salvataggio del PDF: '), backgroundColor: Colors.red),
          );
        }
      }'''

content = content.replace(download_target, download_replacement)

# 4. Make Search Bar responsive in _buildTopHeaderBar
search_target = '''          // Right side: Search Box + Bell + AXION Brand
          Row(
            children: [
              // Search Box Capsule
              Container(
                width: 240,'''

search_replacement = '''          // Right side: Search Box + Bell + AXION Brand
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Search Box Capsule
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),'''

content = content.replace(search_target, search_replacement)

search_target2 = '''                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
  
              const SizedBox(width: 16),
  
  
            ],
      );'''

search_replacement2 = '''                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );'''

content = content.replace(search_target2, search_replacement2)

# 5. Fix scrolling block issue by using Expanded and removing SingleChildScrollView
# Find the exact LayoutBuilder builder start
scroll_target1 = '''                  return SingleChildScrollView(
                    child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16.0 : 32.0,
                      vertical: 24.0,
                    ),
                    child: Column('''

scroll_replacement1 = '''                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16.0 : 32.0,
                      vertical: 24.0,
                    ),
                    child: Column('''

content = content.replace(scroll_target1, scroll_replacement1)

scroll_target2 = '''                      // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                      SizedBox(
                        height: glassHeight,
                        child: Container('''

scroll_replacement2 = '''                      // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                      Expanded(
                        child: Container('''

content = content.replace(scroll_target2, scroll_replacement2)

# Since we removed SingleChildScrollView at scroll_target1, we must remove one closing parenthesis.
# The layout structure at the end of build method:
end_target = '''                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
),
),
);
}'''

end_replacement = '''                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  ),
),
);
}'''
content = content.replace(end_target, end_replacement)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
