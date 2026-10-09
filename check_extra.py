import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def find_extra_brace():
    level = 0
    for i in range(32, 1045):
        line = lines[i]
        level += line.count('{') - line.count('}')
        if level <= 0 and '}' in line:
            print(f"Extra brace found at line {i+1}: {line.strip()} (level {level})")

find_extra_brace()
