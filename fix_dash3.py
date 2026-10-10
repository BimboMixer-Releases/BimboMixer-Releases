import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r"m\['memo_status'\]\?\.toString\(\)\.toUpperCase\(\) != 'PAGATO'\)\.length;",
    r"m['memo_status']?.toString().toUpperCase() != 'PAGATO' && m['memo_status']?.toString().toUpperCase() != 'SALDATO').length;",
    content
)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
