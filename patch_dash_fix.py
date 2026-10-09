with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'return compareDates(dA, dB, descending: !_sortAscending);',
    'return compareDates(dA, dB, descending: true);'
)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard sort fixed")