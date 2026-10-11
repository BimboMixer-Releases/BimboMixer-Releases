import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Replace dialog items list type
old_dialog_list = r'''    List<Map<String, String>> items = [];
    if (existingQuote?['items'] is List) {
      items = (existingQuote!['items'] as List).map((e) {
        if (e is Map) {
          return {
            'name': e['name']?.toString() ?? '',
            'qty': e['qty']?.toString() ?? '1',
          };
        }
        return <String, String>{};
      }).toList();
    } else if (initialData?['items'] is List) {
      items = List<Map<String, String>>.from(initialData!['items']);
    } else {
      items = [
        {'name': 'Servizio Principale', 'qty': '1'},
        {'name': 'Trasferta', 'qty': '1'},
      ];
    }'''

new_dialog_list = r'''    List<Map<String, dynamic>> items = [];
    if (existingQuote?['items'] is List) {
      items = (existingQuote!['items'] as List).map((e) {
        if (e is Map) {
          return {
            'name': e['name']?.toString() ?? '',
            'qty': e['qty']?.toString() ?? '1',
            'checked': e['checked'] == true || e['checked'] == 'true',
          };
        }
        return <String, dynamic>{};
      }).toList();
    } else if (initialData?['items'] is List) {
      items = (initialData!['items'] as List).map((e) {
        if (e is Map) {
          return {
            'name': e['name']?.toString() ?? '',
            'qty': e['qty']?.toString() ?? '1',
            'checked': e['checked'] == true || e['checked'] == 'true',
          };
        }
        return <String, dynamic>{};
      }).toList();
    } else {
      items = [
        {'name': 'Servizio Principale', 'qty': '1', 'checked': false},
        {'name': 'Trasferta', 'qty': '1', 'checked': false},
      ];
    }'''

code = code.replace(old_dialog_list, new_dialog_list)

# 2. Add checkbox to the item row
old_row = r'''                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: item['name'],'''

new_row = r'''                              Checkbox(
                                value: item['checked'] == true,
                                activeColor: Colors.tealAccent,
                                onChanged: (val) {
                                  setDialogState(() {
                                    item['checked'] = val;
                                  });
                                },
                              ),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: item['name'],'''

code = code.replace(old_row, new_row)

# 3. Add to new item:
old_add = r'''items.add({'name': 'Nuova voce', 'qty': '1'});'''
new_add = r'''items.add({'name': 'Nuova voce', 'qty': '1', 'checked': false});'''
code = code.replace(old_add, new_add)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("patched UI")
