import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I will replace the NestedScrollView with SingleChildScrollView
pattern_start = r'child: NestedScrollView\(\s*headerSliverBuilder: \(context, innerBoxIsScrolled\) => \[\s*SliverToBoxAdapter\(\s*child: Column\(\s*crossAxisAlignment: CrossAxisAlignment.start,\s*children: \['

replacement_start = '''child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ['''

if re.search(pattern_start, content):
    content = re.sub(pattern_start, replacement_start, content)
    print("Replaced start")
else:
    print("Start not found")

# Remove the end of the header and the start of the body
pattern_body = r'\]\,\s*\)\,\s*\)\,\s*\]\,\s*body: Container\('
replacement_body = '''    ],
                  ),
                  const SizedBox(height: 22),
                  Container('''

if re.search(pattern_body, content):
    content = re.sub(pattern_body, replacement_body, content)
    print("Replaced body")
else:
    print("Body not found")

# Now fix the Expanded around the LayoutBuilder
# Expanded( child: LayoutBuilder(
pattern_expanded = r'Expanded\(\s*child: LayoutBuilder\('
replacement_expanded = '''LayoutBuilder('''
if re.search(pattern_expanded, content):
    content = re.sub(pattern_expanded, replacement_expanded, content)
    print("Replaced expanded layoutbuilder")
else:
    print("Expanded layoutbuilder not found")

# Now fix the Expanded around ListView.separated
pattern_expanded_list = r'Expanded\(\s*child: filtered\.isEmpty'
replacement_expanded_list = '''filtered.isEmpty'''
if re.search(pattern_expanded_list, content):
    content = re.sub(pattern_expanded_list, replacement_expanded_list, content)
    print("Replaced expanded list")
else:
    print("Expanded list not found")

# We need to add shrinkWrap and physics to ListView.separated
pattern_listview = r'ListView\.separated\('
replacement_listview = '''ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),'''
if re.search(pattern_listview, content):
    content = re.sub(pattern_listview, replacement_listview, content)
    print("Replaced listview props")
else:
    print("ListView not found")

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
