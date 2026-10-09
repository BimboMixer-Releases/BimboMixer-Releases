with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace(
    "final dt = p['date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p['date'])) : '';",
    "final dt = DateUtilsApp.formatDbDate(p['date']?.toString(), 'dd/MM/yyyy');"
)
with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed download date")