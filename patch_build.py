with open('build_method.dart', 'r', encoding='utf-16') as f:
    content = f.read()

# Replace the outermost Column with SingleChildScrollView
content = content.replace(
'''                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [''',
'''                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ['''
)

# Remove the Expanded around the main Container
content = content.replace(
'''                    // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                    Expanded(
                      child: Container(''',
'''                    // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                    Container('''
)

# Remove the Expanded around LayoutBuilder
content = content.replace(
'''                              // Table Area with Horizontal Scroll for Mobile
                              Expanded(
                                child: LayoutBuilder(''',
'''                              // Table Area with Horizontal Scroll for Mobile
                              LayoutBuilder('''
)

# Remove the Expanded around filtered.isEmpty (the ListView)
content = content.replace(
'''                                            // Table Rows List
                                            Expanded(
                                              child: filtered.isEmpty''',
'''                                            // Table Rows List
                                            filtered.isEmpty'''
)

# Add shrinkWrap and physics to ListView.separated
content = content.replace(
'''                                                    child: ListView.separated(
                                                      itemCount: filtered.length,''',
'''                                                    child: ListView.separated(
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: filtered.length,'''
)

with open('build_method.dart', 'w', encoding='utf-8') as f:
    f.write(content)
