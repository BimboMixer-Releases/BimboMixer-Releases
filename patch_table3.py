# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

table_header_start = content.find("                              // Table Header")
if table_header_start == -1:
    print("Table Header not found")
    sys.exit(1)

# Find the end of the Expanded block that contains the ListView
# We can just look for the first occurrence of:
# "                                ),\n                              ],\n                            ),"
# Or we can just count brackets. Let's do bracket matching!

stack = []
started = False
start_index = table_header_start
end_index = -1

for i in range(start_index, len(content)):
    if content[i] == '{' or content[i] == '[' or content[i] == '(':
        stack.append(content[i])
        started = True
    elif content[i] == '}' or content[i] == ']' or content[i] == ')':
        if len(stack) > 0:
            stack.pop()
        if started and len(stack) == 0:
            # We matched everything? No, we started from table_header_start.
            pass

# That's too complex. The block ends with the closing of the Column containing Table Header and Table Body.
# Wait, the Column is:
#                             children: [
#                               // Filter / Summary Row
#                               Container(...),
#                               
#                               // Table Header
#                               Container(...),
#
#                               // Table Body
#                               Expanded(...)
#                             ]

column_children_start = content.find("                            children: [", content.find("// 3. MAIN GLASS CONTAINER"))
column_children_end = content.find("                            ],", column_children_start)

if column_children_start != -1 and column_children_end != -1:
    print("Found Column boundaries!")
    # The table part is from table_header_start to column_children_end (exclusive)
    table_content = content[table_header_start:column_children_end]
    
    new_table = '''                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final minTableWidth = 900.0;
                                    final actualWidth = constraints.maxWidth < minTableWidth 
                                        ? minTableWidth 
                                        : constraints.maxWidth;
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: actualWidth,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
''' + table_content.replace('                              // Table Header', '                                            // Table Header').replace('                              // Table Body', '                                            // Table Body').replace('                              Expanded(\n                                child: filtered.isEmpty', '                                            Expanded(\n                                              child: filtered.isEmpty') + '''
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              )
'''
    
    content = content[:table_header_start] + new_table + content[column_children_end:]

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done patch 3!')
