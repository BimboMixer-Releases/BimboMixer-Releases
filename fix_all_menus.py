import codecs
import re

files = [
    'lib/screens/categories_screen.dart',
    'lib/screens/customers_screen.dart',
    'lib/screens/deadlines_selection_screen.dart',
    'lib/screens/invoices_screen.dart',
    'lib/screens/notes_screen.dart',
    'lib/screens/services_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/reports_screen.dart'
]

pattern = r'leading:\s*Builder\(\s*builder:\s*\(context\)\s*=>\s*IconButton\(\s*icon:\s*const\s*Icon\(Icons\.menu.*?\),\s*onPressed:\s*\(\)\s*\{\s*context\s*\.findRootAncestorStateOfType<ScaffoldState>\(\)\s*\?\.openDrawer\(\);\s*\},\s*\),\s*\),'
pattern2 = r'icon:\s*const\s*Icon\(Icons\.menu,\s*color:\s*Colors\.white\),\s*onPressed:\s*\(\)\s*=>\s*context\.findRootAncestorStateOfType<ScaffoldState>\(\)\?\.openDrawer\(\),'

for file in files:
    with codecs.open(file, 'r', 'utf-8') as f:
        content = f.read()
    
    # We remove the hardcoded leading completely, so the AppBar auto-provides back button
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # For reports_screen that has it slightly different
    replacement2 = r'''icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },'''
    content = re.sub(pattern2, replacement2, content, flags=re.DOTALL)
    
    with codecs.open(file, 'w', 'utf-8') as f:
        f.write(content)

print("All menus fixed!")
