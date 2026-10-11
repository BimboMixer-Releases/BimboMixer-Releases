import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace('List<Map<String, String>> extractedItems = [];', 'List<Map<String, dynamic>> extractedItems = [];')

old_extraction = r'''      // 5. Check for Items / Services
      final lines = text.split('\n');
      for (var l in lines) {
        if (l.contains('â‚¬') ||
            l.toLowerCase().contains('ore') ||
            l.toLowerCase().contains('consulenza') ||
            l.toLowerCase().contains('servizi')) {
          final clean = l.replaceAll(RegExp(r'[^\w\s\(\)\â‚¬\.\,]'), '').trim();
          if (clean.length > 5 &&
              clean.length < 80 &&
              extractedItems.length < 5) {
            extractedItems.add({'name': clean, 'qty': '1'});
          }
        }
      }'''

new_extraction = r'''      // 5. Check for Items / Services and Materials List
      final lines = text.split('\n');
      bool parsingMaterials = false;
      for (var l in lines) {
        final lowerL = l.toLowerCase();
        
        // Start parsing materials if we see the specific header
        if (lowerL.contains('lista materiali allegata')) {
          parsingMaterials = true;
          continue;
        }

        if (parsingMaterials) {
          // Attempt to extract item starting with N°, N., N or just starting with a number
          // For example: "N°8 Barre Led", "N° 4 Accecatori", "N 2 Macchine"
          final match = RegExp(r'N[°º\.\s]*(\d+)\s*(.*)', caseSensitive: false).firstMatch(l.trim());
          if (match != null) {
            String qty = match.group(1)!;
            String name = match.group(2)!.trim();
            if (name.isNotEmpty) {
              extractedItems.add({'name': name, 'qty': qty, 'checked': false});
            }
          }
        } else {
          // Standard generic heuristic (if not in a material list)
          if (l.contains('€') || l.contains('â‚¬') ||
              lowerL.contains('ore') ||
              lowerL.contains('consulenza') ||
              lowerL.contains('servizi')) {
            final clean = l.replaceAll(RegExp(r'[^\w\s\(\)\€\â\‚¬\.\,]'), '').trim();
            if (clean.length > 5 &&
                clean.length < 80 &&
                extractedItems.length < 5) {
              extractedItems.add({'name': clean, 'qty': '1', 'checked': false});
            }
          }
        }
      }'''

code = code.replace(old_extraction, new_extraction)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("patched extraction")
