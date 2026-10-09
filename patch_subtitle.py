# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to change the subtitle
old_code = "'\ fatture in sospeso',"
new_code = "'\ pagamenti in sospeso',"
content = content.replace(old_code, new_code)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("subtitle fixed")
