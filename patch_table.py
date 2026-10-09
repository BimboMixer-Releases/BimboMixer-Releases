# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the Euro symbol (remove one of them)
euro_target = "const Icon(Icons.euro_symbol, color: Color(0xFF10B981), size: 16),"
if euro_target in content:
    content = content.replace(euro_target, "/* const Icon(Icons.euro_symbol, color: Color(0xFF10B981), size: 16), */")

# Fix the filter Row overflow by changing to Wrap
filter_row_target = '''                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: ['''
filter_row_replacement = '''                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 12,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: ['''
content = content.replace(filter_row_target, filter_row_replacement)

# Fix the table horizontal scrolling
table_header_start = content.find("                              // Table Header")
table_body_end = content.find("                                ),\n                              ],\n                            ),\n                          ),\n                        ),\n                      ),\n                    ],\n                  ),\n                ),\n              ),\n      );\n    }")

if table_header_start != -1 and table_body_end != -1:
    table_content = content[table_header_start:table_body_end]
    
    # We need to wrap table_content in Expanded -> LayoutBuilder -> SingleChildScrollView -> SizedBox
    new_table = '''                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final minTableWidth = 800.0;
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
                              )'''
    # We have to fix the indentation of the Expanded content inside table_content since it was already Expanded.
    # Actually just replacing the whole thing is safer.
    
    # Let's write a smarter regex or just replace the chunks!

    # Wait, table_content ALREADY contains:
    # // Table Header
    # Container(...)
    # // Table Body
    # Expanded(child: filtered.isEmpty ? ... : ListView...)
    
    content = content[:table_header_start] + new_table + content[table_body_end:]

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done patch 2!')
