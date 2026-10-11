import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []

for i in range(len(lines)):
    line = lines[i]
    
    # 1. Patch `_showQuoteFormDialog`
    if 'List<Map<String, String>> items = [];' in line:
        new_lines.append("    List<Map<String, dynamic>> items = [];\n")
        continue
        
    if "return <String, String>{};" in line:
        new_lines.append(line.replace("<String, String>", "<String, dynamic>"))
        continue
        
    if "items = List<Map<String, String>>.from(initialData!['items']);" in line:
        # We need to map it properly because initialData might be Strings, but we want dynamic for checked
        new_lines.append("""      items = (initialData!['items'] as List).map((e) {
        if (e is Map) {
          return {
            'name': e['name']?.toString() ?? '',
            'qty': e['qty']?.toString() ?? '1',
            'checked': e['checked'] == true || e['checked'] == 'true',
          };
        }
        return <String, dynamic>{};
      }).toList();\n""")
        continue

    # 2. Patch Checkbox in _showQuoteFormDialog
    if 'child: TextFormField(' in line and i+1 < len(lines) and 'initialValue: item[\'name\'],' in lines[i+1]:
        new_lines.append('''                              Checkbox(
                                value: item['checked'] == true || item['checked'] == 'true',
                                activeColor: Colors.tealAccent,
                                onChanged: (val) {
                                  setDialogState(() {
                                    item['checked'] = val;
                                  });
                                },
                              ),
''')
        new_lines.append(line)
        continue

    # 4. Patch `take(3)` in `_buildFeaturedQuoteCard`
    if "children: itemsList.take(3).map((item) {" in line:
        new_lines.append(line.replace("take(3).", ""))
        continue
        
    if "map['name']?.toString() ?? ''," in line and "Text(" in lines[i-1]:
        # We can't do this easily line by line here, I'll do it in a second pass
        new_lines.append(line)
        continue
        
    new_lines.append(line)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("done step 1")
