with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('v1.8.90 (Build 110)', 'v1.8.91 (Build 111)')

with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
