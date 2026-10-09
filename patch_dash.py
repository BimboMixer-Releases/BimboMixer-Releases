# -*- coding: utf-8 -*-
import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace any non-ascii character gracefully
target = r"Text\(\s*'- [^\s]+ \$\{_totalDeadlinesPaid\.toStringAsFixed\(2\)\} scadenze pagate',\s*style: TextStyle\(color: Colors\.orangeAccent, fontSize: 12\),\s*\),"
replacement = r"Expanded(\n                      child: Text(\n                        '- € ${_totalDeadlinesPaid.toStringAsFixed(2)} scadenze pagate',\n                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12),\n                      ),\n                    ),"

new_content, count = re.subn(target, replacement, content)
if count > 0:
    with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Patched successfully.')
else:
    print('Not found')
