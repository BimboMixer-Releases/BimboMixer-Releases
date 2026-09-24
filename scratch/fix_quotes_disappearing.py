import os

file_path = "lib/screens/quotes_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix stale _selectedQuote in _loadQuotes
old_load = """          if (_quotes.isNotEmpty && _selectedQuote == null) {
            _selectedQuote = _quotes.first;
          }"""

new_load = """          if (_quotes.isNotEmpty) {
            if (_selectedQuote != null) {
              try {
                _selectedQuote = _quotes.firstWhere((q) => q['id'] == _selectedQuote!['id']);
              } catch (_) {
                _selectedQuote = _quotes.first;
              }
            } else {
              _selectedQuote = _quotes.first;
            }
          } else {
            _selectedQuote = null;
          }"""

if old_load in content:
    content = content.replace(old_load, new_load)

# Fix items parsing in _showQuoteFormDialog so it doesn't crash on int 'qty'
old_items = """    if (existingQuote?['items'] is List) {
      items = (existingQuote!['items'] as List).map((e) => Map<String, String>.from(e as Map)).toList();
    }"""

new_items = """    if (existingQuote?['items'] is List) {
      items = (existingQuote!['items'] as List).map((e) {
        if (e is Map) {
          return {
            'name': e['name']?.toString() ?? '',
            'qty': e['qty']?.toString() ?? '1',
          };
        }
        return <String, String>{};
      }).toList();
    }"""

if old_items in content:
    content = content.replace(old_items, new_items)

# Write back
with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("quotes_screen.dart patched to fix missing quotes / stale states.")
