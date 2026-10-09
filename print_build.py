with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

idx1 = content.find('Widget build(BuildContext context) {')
idx2 = content.find('String _getShortId(String? id) {')
print(content[idx1:idx2])
