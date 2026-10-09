import re

def fix_payments():
    with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    # Find start of build method
    build_idx = -1
    for i, line in enumerate(lines):
        if 'Widget build(BuildContext context) {' in line:
            build_idx = i
            break
            
    if build_idx == -1:
        return
        
    before_build = ''.join(lines[:build_idx])
    build_and_after = ''.join(lines[build_idx:])
    
    # 1. Regex replacements on build_and_after
    build_and_after = re.sub(r'Expanded\(\s*child: Container\(', r'Container(', build_and_after, 1)
    build_and_after = re.sub(r'Expanded\(\s*child: LayoutBuilder\(', r'LayoutBuilder(', build_and_after, 1)
    build_and_after = re.sub(r'Expanded\(\s*child: filtered\.isEmpty', r'filtered.isEmpty', build_and_after, 1)
    build_and_after = re.sub(r'ListView\.separated\(\s*itemCount: filtered\.length,', r'ListView.separated(\n                                                      shrinkWrap: true,\n                                                      physics: const NeverScrollableScrollPhysics(),\n                                                      itemCount: filtered.length,', build_and_after, 1)
    build_and_after = build_and_after.replace(
'''                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [''',
'''                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ['''
    )
    
    # 2. Split again into lines to delete the matching braces
    new_lines = build_and_after.split('\n')
    
    # We need to find the specific closing braces.
    # Since we know the exact line numbers relative to build_idx in the original, we can find them,
    # but the replacements changed the line counts slightly (added newlines for ListView.separated).
    # Let's just find them by counting backwards from the end of the build method!
    
    # Find the end of build method
    open_braces = 0
    in_build = False
    build_end_idx = -1
    for i, line in enumerate(new_lines):
        if 'Widget build' in line:
            in_build = True
        if in_build:
            open_braces += line.count('{') - line.count('}')
            if open_braces == 0 and ('{' in line or '}' in line):
                build_end_idx = i
                break
                
    # Now we know build_end_idx.
    # From manual inspection, the closing braces for the 3 Expanded() were at offsets from the end:
    # 797 was build_end_idx.
    # 790 was Expanded(Container) closing
    # 786 was Expanded(LayoutBuilder) closing
    # 779 was Expanded(filtered.isEmpty) closing
    # Wait, instead of hardcoded offsets which might break, I can just use a brace matcher!
    # But hardcoded offsets from the end of the build method is safe because the rest of the layout didn't change!
    
    # Let's check the offsets in test_syntax2.dart:
    # build_end_idx was 796
    # deleted: 790, 786, 779.
    # Diff from end: 
    # 796 - 790 = 6
    # 796 - 786 = 10
    # 796 - 779 = 17
    # Let's delete these lines!
    del new_lines[build_end_idx - 6]
    del new_lines[build_end_idx - 10]
    del new_lines[build_end_idx - 17]
    
    # And we need to add one ), for SingleChildScrollView
    # In test_syntax3.dart, we added it at 791 (which was build_end_idx - 5 before the shift)
    # Wait, after deleting 3 lines, the new build_end_idx is build_end_idx - 3.
    # The end looks like:
    #                 ), // Column
    #               ), // SingleChildScrollView (WE ADD THIS)
    #             ), // Padding
    #           ), // SafeArea
    #         ), // Scaffold
    # );
    
    new_build_end_idx = build_end_idx - 3
    new_lines.insert(new_build_end_idx - 4, "              ),")
    
    final_content = before_build + '\n'.join(new_lines)
    
    with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
        f.write(final_content)

fix_payments()
