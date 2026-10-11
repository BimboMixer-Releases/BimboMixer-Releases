import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

bad_syntax = r'''                            Expanded(
                              flex: 3,
                              Checkbox(
                                value: item['checked'] == true || item['checked'] == 'true',
                                activeColor: Colors.tealAccent,
                                onChanged: (val) {
                                  setDialogState(() {
                                    item['checked'] = val;
                                  });
                                },
                              ),
                              child: TextFormField('''

good_syntax = r'''                            Checkbox(
                              value: item['checked'] == true || item['checked'] == 'true',
                              activeColor: Colors.tealAccent,
                              onChanged: (val) {
                                setDialogState(() {
                                  item['checked'] = val;
                                });
                              },
                            ),
                            Expanded(
                              flex: 3,
                              child: TextFormField('''

code = code.replace(bad_syntax, good_syntax)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("fixed syntax")
