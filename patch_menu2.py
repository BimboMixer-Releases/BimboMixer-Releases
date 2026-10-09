import re

with open('lib/screens/menu_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_menu_item = '''            _buildMenuItem(
              context,
              LucideIcons.pieChart,
              'Bilancio Fisco',
              const BilancioFiscoScreen(),
            ),'''
content = content.replace(bad_menu_item, "")

with open('lib/screens/menu_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done menu")
