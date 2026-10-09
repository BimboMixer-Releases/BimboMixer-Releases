def find_build_end():
    with open('build_method.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Simple brace counting
    open_braces = 0
    in_build = False
    
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'Widget build(BuildContext context)' in line:
            in_build = True
        
        if in_build:
            open_braces += line.count('{')
            open_braces -= line.count('}')
            if open_braces == 0 and '{' in line or open_braces == 0 and '}' in line:
                if open_braces == 0:
                    print(f"Build ends at line {i+1}")
                    print('\n'.join(lines[i-5:i+2]))
                    return

find_build_end()
