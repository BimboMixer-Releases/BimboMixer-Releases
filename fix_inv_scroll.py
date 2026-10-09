import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace NestedScrollView with SingleChildScrollView
nested_scroll_pattern = r'''                child: NestedScrollView\(
                  headerSliverBuilder: \(context, innerBoxIsScrolled\) => \[
                    SliverToBoxAdapter\(
                      child: Column\(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: \['''

replacement = r'''                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ['''

content = re.sub(nested_scroll_pattern, replacement, content)

# 2. Remove the Expanded around Container and ListView
content = re.sub(r'Expanded\(\s*child: Container\(', r'Container(', content, 1)
content = re.sub(r'Expanded\(\s*child: filtered\.isEmpty', r'filtered.isEmpty', content, 1)
content = re.sub(r'Expanded\(\s*child: ListView\.builder\(', r'ListView.builder(', content, 1)
content = re.sub(r'ListView\.builder\(\s*itemCount: filtered\.length,', r'ListView.builder(\n                                                      shrinkWrap: true,\n                                                      physics: const NeverScrollableScrollPhysics(),\n                                                      itemCount: filtered.length,', content, 1)

# 3. Fix the closing braces. 
# We need to delete the ody: Container( closing brace? 
# Wait, the NestedScrollView structure had:
#                 ],
#               ),
#             ),
#           ],
#           body: Container(

content = content.replace('''                      ),
                    ),
                  ],
                  body: Container(''', '''                      ),
                    // body removed
                    Container(''')

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
