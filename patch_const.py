# -*- coding: utf-8 -*-
import sys
import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The error was at ListView.separated which was wrapped in const, or maybe Expanded(child: const ...)
content = re.sub(r'const\s+ListView\.separated', 'ListView.separated', content)
content = re.sub(r'const\s+Row\(', 'Row(', content)
content = re.sub(r'const\s+Column\(', 'Column(', content)
content = re.sub(r'const\s+InkWell\(', 'InkWell(', content)
content = re.sub(r'const\s+IconButton\(', 'IconButton(', content)
content = re.sub(r'const\s+Padding\(', 'Padding(', content)
content = re.sub(r'const\s+Expanded\(', 'Expanded(', content)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
