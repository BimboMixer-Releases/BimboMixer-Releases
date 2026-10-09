import re

def fix_scroll(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the start of NestedScrollView and replace with SingleChildScrollView
    pattern = r'child:\s*NestedScrollView\(\s*headerSliverBuilder:\s*\(context,\s*innerBoxIsScrolled\)\s*=>\s*\[\s*SliverToBoxAdapter\(\s*child:\s*(Column\(.*?const SizedBox\(height: 22\),\s*\]\,\s*\)\,\s*)\)\,\s*\]\,\s*body:\s*(Container\(.*?\)\s*)\)\s*// ends padding?'
    
    # Actually, let's just do simple text replacements instead of complex regexes
    # We want to remove NestedScrollView, headerSliverBuilder, etc.
    
    # 1. Replace NestedScrollView -> SingleChildScrollView
    content = content.replace('child: NestedScrollView(', 'child: SingleChildScrollView(physics: const BouncingScrollPhysics(), ')
    
    # 2. Replace headerSliverBuilder and SliverToBoxAdapter
    content = content.replace('headerSliverBuilder: (context, innerBoxIsScrolled) => [', '')
    content = content.replace('SliverToBoxAdapter(', '')
    
    # 3. Replace body separator
    content = content.replace('],', '', 1) # This is dangerous, let's avoid it.

fix_scroll('lib/screens/payments_screen.dart')
