# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoice_summary_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Reduce padding from horizontal: 16, vertical: 12 to horizontal: 8, vertical: 10
content = content.replace(
    'padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)',
    'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)'
)

# 2. Add FittedBox for the value Text in isAmount
amount_text_target = '''                child: Text(
                  value,
                  style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 18),
                ),'''
amount_text_replacement = '''                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),'''
content = content.replace(amount_text_target, amount_text_replacement)

# 3. Adjust the flex values
# Instead of replacing exact blocks, let's find the Expanded(flex: 2) and Expanded(flex: 3) inside _buildRowItem.
# We know they are inside _buildRowItem.

start_build_row = content.find('Widget _buildRowItem(')
if start_build_row != -1:
    end_build_row = content.find('}', start_build_row + 500)
    
    build_row_content = content[start_build_row:end_build_row]
    build_row_content = build_row_content.replace('flex: 2,', 'flex: 4,', 1)
    build_row_content = build_row_content.replace('flex: 3,', 'flex: 5,')
    
    content = content[:start_build_row] + build_row_content + content[end_build_row:]
else:
    print("Could not find _buildRowItem")
    sys.exit(1)

with open('lib/screens/invoice_summary_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
