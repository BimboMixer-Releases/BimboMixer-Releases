import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("body: \n                      child: Container(", "body: Container(")

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
