with open('build_method.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('\r\n', '\n')

# We already ran the first replacement because it might have matched? Let's check.
# Let's just use re.sub for safety, ignoring whitespace.
import re

content = re.sub(r'Expanded\(\s*child: Container\(', r'Container(', content, 1)
content = re.sub(r'Expanded\(\s*child: LayoutBuilder\(', r'LayoutBuilder(', content, 1)
content = re.sub(r'Expanded\(\s*child: filtered\.isEmpty', r'filtered.isEmpty', content, 1)
content = re.sub(r'ListView\.separated\(\s*itemCount: filtered\.length,', r'ListView.separated(\n                                                      shrinkWrap: true,\n                                                      physics: const NeverScrollableScrollPhysics(),\n                                                      itemCount: filtered.length,', content, 1)

with open('build_method.dart', 'w', encoding='utf-8') as f:
    f.write(content)
