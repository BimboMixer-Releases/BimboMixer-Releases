import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

old_list_render = r'''              children: itemsList.map((item) {
                final map = item is Map
                    ? item
                    : {'name': item.toString(), 'qty': '1'};
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          map['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        map['qty']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),'''

new_list_render = r'''              children: itemsList.asMap().entries.map((entry) {
                final idx = entry.key;
                final map = entry.value is Map
                    ? Map<String, dynamic>.from(entry.value)
                    : {'name': entry.value.toString(), 'qty': '1', 'checked': false};
                
                return StatefulBuilder(
                  builder: (context, setStateItem) {
                    bool isChecked = map['checked'] == true || map['checked'] == 'true';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: Colors.tealAccent,
                              onChanged: (val) async {
                                setStateItem(() {
                                  map['checked'] = val;
                                  isChecked = val ?? false;
                                });
                                // Aggiorna DB live
                                itemsList[idx] = map;
                                quote['items'] = itemsList;
                                await _dbHelper.updateQuote(quote['id'], {'items': itemsList});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              map['name']?.toString() ?? '',
                              style: TextStyle(
                                color: isChecked ? Colors.white38 : Colors.white70,
                                fontSize: 12,
                                decoration: isChecked ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            map['qty']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                );
              }).toList(),'''

if old_list_render in code:
    code = code.replace(old_list_render, new_list_render)
    with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
        f.write(code)
    print("patched list render")
else:
    print("could not find block")
