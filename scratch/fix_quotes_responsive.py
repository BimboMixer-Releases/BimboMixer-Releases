import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I want to replace:
old_start = '''                    // 3. BOTTOM SECTION: Table of Quotes with Status Filter Header
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF101322).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: ['''

new_start = '''                    // 3. BOTTOM SECTION: Table of Quotes with Status Filter Header
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF101322).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double minTableWidth = 850.0;
                            final double actualWidth = constraints.maxWidth > minTableWidth
                                ? constraints.maxWidth
                                : minTableWidth;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: actualWidth,
                                child: Column(
                                  children: ['''


old_end = '''                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),'''

new_end = '''                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),'''

# It's better to process lines to fix indentation inside the block.
with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
in_table_block = False
nested_count = 0

for i, line in enumerate(lines):
    if '// 3. BOTTOM SECTION: Table of Quotes with Status Filter Header' in line:
        in_table_block = True
        new_lines.append(line)
        new_lines.append('                    Expanded(\n')
        new_lines.append('                      child: Container(\n')
        new_lines.append('                        decoration: BoxDecoration(\n')
        new_lines.append('                          color: const Color(0xFF101322).withValues(alpha: 0.7),\n')
        new_lines.append('                          borderRadius: BorderRadius.circular(16),\n')
        new_lines.append('                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),\n')
        new_lines.append('                        ),\n')
        new_lines.append('                        child: LayoutBuilder(\n')
        new_lines.append('                          builder: (context, constraints) {\n')
        new_lines.append('                            final double minTableWidth = 850.0;\n')
        new_lines.append('                            final double actualWidth = constraints.maxWidth > minTableWidth\n')
        new_lines.append('                                ? constraints.maxWidth\n')
        new_lines.append('                                : minTableWidth;\n\n')
        new_lines.append('                            return SingleChildScrollView(\n')
        new_lines.append('                              scrollDirection: Axis.horizontal,\n')
        new_lines.append('                              child: SizedBox(\n')
        new_lines.append('                                width: actualWidth,\n')
        new_lines.append('                                child: Column(\n')
        new_lines.append('                                  children: [\n')
        # Skip original lines until 'children: ['
        continue

    if in_table_block:
        if 'Expanded(' in line and 'child: Container(' in lines[i+1]:
            # skip all the original wrapper lines
            pass
        elif 'child: Column(' in line and 'children: [' in lines[i+1]:
            # skip column
            pass
        elif 'children: [' in line and 'child: Column(' in lines[i-1]:
            # skip
            pass
        elif 'decoration: BoxDecoration(' in line and 'child: Container(' in lines[i-1]:
            # wait, this logic is too brittle.
            pass

# Too brittle, let's just do a regex sub.

content_fixed = content.replace(old_start, new_start)

# End block is at:
# 990:                                     ),
# 991:                             ),
# 992:                           ],
# 993:                         ),
# 994:                       ),
# 995:                     ),

# Let's replace the end part accurately
old_end_precise = """                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),"""

new_end_precise = """                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),"""

content_fixed = content_fixed.replace(old_end_precise, new_end_precise)

# Add indentation to the middle part? Since it's inside `SizedBox` and `SingleChildScrollView`, the current indentation (which assumes it's inside `Expanded > Container > Column`) is 2 levels (4 spaces * 2) shallower. It's fine if the indentation is slightly off, Dart formatter will fix it.
with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content_fixed)
