import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def trace_build():
    level = 0
    in_build = False
    for i in range(32, 1050):
        line = lines[i]
        if 'Widget build(BuildContext context)' in line:
            in_build = True
            level = 0
            print(f"Build starts at {i+1}")
        
        if in_build:
            level += line.count('{') - line.count('}')
            if level < 0:
                print(f"Extra closing brace in build at line {i+1}")
                break

trace_build()
