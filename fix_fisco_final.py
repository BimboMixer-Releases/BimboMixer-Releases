p = 'lib/screens/bilancio_fisco_screen.dart'
s = open(p, encoding='utf-8', newline='').read().replace('\r\n', '\n')

s = s.replace("import 'package:lucide_icons_flutter/lucide_icons.dart';",
 "import 'package:lucide_icons_flutter/lucide_icons.dart';\nimport 'package:intl/intl.dart';")

s = s.replace("  double _usciteFisco = 0;\n",
 "  double _usciteFisco = 0;\n  bool _hasError = false;\n\n  /// Rapporto uscite/entrate in %. null = non calcolabile (entrate = 0).\n  double? get _ratioPercent => _entrateFisco > 0 ? (_usciteFisco / _entrateFisco) * 100 : null;\n\n  static String formatRatio(double? percent) {\n    if (percent == null) return 'N/D';\n    return '${NumberFormat('#,##0.##', 'it_IT').format(percent)}%';\n  }\n", 1)

s = s.replace("    setState(() => _isLoading = true);\n    try {",
 "    setState(() {\n      _isLoading = true;\n      _hasError = false;\n    });\n    try {", 1)
s = s.replace("      setState(() {\n        _entrateFisco = entrateF;", "      if (!mounted) return;\n      setState(() {\n        _entrateFisco = entrateF;", 1)
s = s.replace("    } catch (e) {\n      setState(() => _isLoading = false);\n    }",
 "    } catch (e) {\n      if (!mounted) return;\n      setState(() {\n        _hasError = true;\n        _isLoading = false;\n      });\n    }", 1)

a = s.index("    double percent = 0;")
b = s.index("    return GradientScaffold(")
s = s[:a] + """    final ratio = _ratioPercent;
    Color ratioColor = Colors.grey;
    String? message;
    Color messageColor = Colors.white54;
    if (ratio == null) {
      message = _usciteFisco > 0
          ? 'Rapporto non calcolabile: nessuna entrata fiscale.'
          : 'Nessun movimento fiscale: rapporto non calcolabile.';
    } else if (_usciteFisco > _entrateFisco) {
      ratioColor = Colors.redAccent;
      message = 'ATTENZIONE: Uscite superiori alle entrate!';
      messageColor = Colors.redAccent;
    } else if (_usciteFisco > _entrateFisco * 0.8) {
      ratioColor = Colors.orangeAccent;
      message = 'Parita vicina, attenzione alle spese.';
      messageColor = Colors.orangeAccent;
    } else {
      ratioColor = Colors.greenAccent;
      message = 'Bilancio positivo.';
      messageColor = Colors.greenAccent;
    }

""" + s[b:]

s = s.replace("      body: _isLoading\n          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))\n          : SingleChildScrollView(",
"""      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text('Impossibile caricare i dati fiscali.', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadDatiFisco, child: const Text('Riprova')),
                ],
              ),
            )
          : SingleChildScrollView(""", 1)

s = s.replace("                          '%',\n", "                          formatRatio(ratio),\n", 1)
a = s.index("                        if (_usciteFisco > _entrateFisco)\n")
b = s.index("                      ],\n                    ),\n                  ),\n                ],\n              ),\n            ),\n    );")
s = s[:a] + "                        Text(message, textAlign: TextAlign.center, style: TextStyle(color: messageColor, fontSize: 12)),\n" + s[b:]
open(p, 'w', encoding='utf-8', newline='').write(s)
print('ok')
