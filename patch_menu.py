import re

with open('lib/widgets/app_sidebar.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I want to add Bilancio Fisco after Fatture
old_items = '''                _buildNavItem(context, 0, LucideIcons.home, 'Dashboard'),
                _buildNavItem(context, 1, LucideIcons.arrowLeftRight, 'Movimenti'),
                _buildNavItem(context, 2, LucideIcons.fileText, 'Fatture'),
                _buildNavItem(context, 5, LucideIcons.fileSignature, 'Preventivi'),'''

new_items = '''                _buildNavItem(context, 0, LucideIcons.home, 'Dashboard'),
                _buildNavItem(context, 1, LucideIcons.arrowLeftRight, 'Movimenti'),
                _buildNavItem(context, 2, LucideIcons.fileText, 'Fatture'),
                _buildNavItem(context, 12, LucideIcons.pieChart, 'Bilancio Fisco'),
                _buildNavItem(context, 5, LucideIcons.fileSignature, 'Preventivi'),'''

content = content.replace(old_items, new_items)
with open('lib/widgets/app_sidebar.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done sidebar")

with open('lib/widgets/app_drawer.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_drawer = '''                _buildDrawerItem(
                  context,
                  2,
                  LucideIcons.fileText,
                  'Fatture',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  5,
                  LucideIcons.fileSignature,
                  'Preventivi',
                  theme.primaryColor,
                ),'''

new_drawer = '''                _buildDrawerItem(
                  context,
                  2,
                  LucideIcons.fileText,
                  'Fatture',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  12,
                  LucideIcons.pieChart,
                  'Bilancio Fisco',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  5,
                  LucideIcons.fileSignature,
                  'Preventivi',
                  theme.primaryColor,
                ),'''

content = content.replace(old_drawer, new_drawer)
with open('lib/widgets/app_drawer.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done drawer")

with open('lib/screens/main_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_main = '''      const SettingsScreen(),
      MenuScreen(role: widget.role),
    ];
  }'''

new_main = '''      const SettingsScreen(),
      MenuScreen(role: widget.role),
      const BilancioFiscoScreen(),
    ];
  }'''

if 'import \'bilancio_fisco_screen.dart\';' not in content:
    content = content.replace("import 'menu_screen.dart';", "import 'menu_screen.dart';\nimport 'bilancio_fisco_screen.dart';")

content = content.replace(old_main, new_main)
with open('lib/screens/main_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done main")

