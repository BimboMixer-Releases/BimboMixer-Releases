import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'package:shared_preferences/shared_preferences.dart' not in content:
    content = content.replace('import ''package:flutter/material.dart'';', 'import ''package:flutter/material.dart'';\nimport ''package:shared_preferences/shared_preferences.dart'';')

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
