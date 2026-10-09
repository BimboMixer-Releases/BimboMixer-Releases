lines = []
with open('test_syntax2.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

lines.insert(791, "              ),\n")

with open('test_syntax3.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
