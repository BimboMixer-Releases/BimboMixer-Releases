import codecs
import re

with codecs.open('lib/screens/quotes_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

content = re.sub(
    r'icon:\s*const\s*Icon\(Icons\.menu,\s*color:\s*Colors\.white70\),\s*onPressed:\s*\(\)\s*=>\s*context\.findRootAncestorStateOfType<ScaffoldState>\(\)\?\.openDrawer\(\),',
    r'''icon: const Icon(Icons.arrow_back, color: Colors.white70),
                                    onPressed: () {
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    },''',
    content
)

with codecs.open('lib/screens/quotes_screen.dart', 'w', 'utf-8') as f:
    f.write(content)
print("Quotes menu replaced!")
